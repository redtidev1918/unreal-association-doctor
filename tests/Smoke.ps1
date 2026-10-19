$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path $PSScriptRoot) 'Repair-UnrealAssociation.ps1'
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$wizard = Join-Path (Split-Path $PSScriptRoot) 'Start-Doctor.ps1'
$null = [System.Management.Automation.Language.Parser]::ParseFile($wizard, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
# Windows PowerShell 5.1 reads BOM-less files as ANSI, which turns Chinese messages into parse errors.
foreach ($file in @(Get-ChildItem -LiteralPath (Split-Path $PSScriptRoot -Parent) -Recurse -Filter *.ps1 -File)) {
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { continue }
    if (@($bytes | Where-Object { $_ -gt 0x7F }).Count) { throw "$($file.FullName) has non-ASCII text but no UTF-8 BOM" }
}
# Repair may export and rename entries, never delete user registry configuration.
foreach ($file in @($script, $wizard)) {
    $text = [IO.File]::ReadAllText($file)
    if ($text -match 'reg(?:\.exe)?\s+delete|DeleteSubKey|Remove-ItemProperty[^\r\n]*(?:HKCU|HKLM)|Remove-Item[^\r\n]*(?:HKCU|HKLM|Software\\Classes)') {
        throw "Registry deletion must not appear in $file"
    }
}
$report = & $script -Mode Diagnose | ConvertFrom-Json
if ($report.Mode -ne 'Diagnose') { throw 'Unexpected mode' }
if ($report.LauncherVerified -or $report.ProjectOpenVerified) { throw 'Diagnosis must not claim launcher or project verification' }
if ($report.Action -ne 'None') { throw 'Diagnosis must be read-only' }
if ($null -ne $report.Backup) { throw 'Diagnosis must not create a backup or modify state' }
if (-not $report.Before) { throw 'Missing state' }
Write-Output 'PASS: parser and read-only diagnostic smoke test'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('UnrealAssociationDoctor-Test-' + [guid]::NewGuid().ToString('N'))
try {
    $bin = Join-Path $fixture 'Launcher\Engine\Binaries\Win64'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $fake = Join-Path $bin 'UnrealVersionSelector.exe'
    [IO.File]::WriteAllText($fake, 'Discovery fixture only; never execute')
    $custom = & $script -Mode Diagnose -SearchRoot $fixture | ConvertFrom-Json
    if ($custom.Candidates -notcontains $fake) { throw 'Custom installation root was not discovered' }
    if ($custom.Candidates.Count -gt 1 -and $custom.Selected) { throw 'Ambiguous installations must not be silently selected' }
    $explicit = & $script -Mode Diagnose -SelectorPath $fake | ConvertFrom-Json
    if ($explicit.Selected -ne $fake) { throw 'Explicit candidate selection failed' }
    Write-Output 'PASS: custom roots, ambiguous candidates and explicit selection (no executable launched)'
} finally {
    $tempParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $fixtureParent = [IO.Path]::GetFullPath((Split-Path $fixture -Parent)).TrimEnd('\')
    if ($fixtureParent -eq $tempParent -and (Split-Path $fixture -Leaf) -like 'UnrealAssociationDoctor-Test-*' -and (Test-Path -LiteralPath $fixture)) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
