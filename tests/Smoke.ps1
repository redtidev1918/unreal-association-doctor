$ErrorActionPreference = 'Stop'
$script = Join-Path (Split-Path $PSScriptRoot) 'Repair-UnrealAssociation.ps1'
$tokens = $null
$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$report = & $script -Mode Diagnose | ConvertFrom-Json
if ($report.Mode -ne 'Diagnose') { throw 'Unexpected mode' }
if ($report.RegistryVerified -or $report.LauncherVerified -or $report.ProjectOpenVerified) { throw 'Diagnosis must not claim successful repair' }
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
