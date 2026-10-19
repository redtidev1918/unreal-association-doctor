#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Diagnose','Repair')][string]$Mode = 'Diagnose',
    [string]$SelectorPath,
    [string[]]$SearchRoot = @(),
    [switch]$ForceRepair,
    [switch]$LauncherReportsError,
    [string]$BackupRoot = (Join-Path $env:LOCALAPPDATA 'UnrealAssociationDoctor\Backups')
)
$ErrorActionPreference = 'Stop'

function Get-RegistryDefault([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return (Get-Item -LiteralPath $Path).GetValue('') }
    return $null
}

function Get-SelectorCandidates {
    $roots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in $SearchRoot) { if ($root) { $roots.Add($root) } }
    foreach ($process in @(Get-Process EpicGamesLauncher -ErrorAction SilentlyContinue)) {
        if ($process.Path) { $roots.Add((Split-Path (Split-Path (Split-Path (Split-Path $process.Path))))) }
    }
    foreach ($view in @('Registry64','Registry32')) {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', [Microsoft.Win32.RegistryView]::$view)
        try {
            foreach ($name in @('SOFTWARE\EpicGames\Unreal Engine','SOFTWARE\EpicGames\EpicGamesLauncher')) {
                $key = $base.OpenSubKey($name)
                if ($key) {
                    try {
                        foreach ($valueName in @('INSTALLDIR','InstallLocation','AppDataPath')) {
                            $value = $key.GetValue($valueName)
                            if ($value -is [string] -and $value) { $roots.Add($value) }
                        }
                    } finally { $key.Dispose() }
                }
            }
        } finally { $base.Dispose() }
    }
    $manifest = Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (Test-Path -LiteralPath $manifest) {
        try {
            foreach ($install in (Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).InstallationList) {
                if ($install.InstallLocation) { $roots.Add($install.InstallLocation) }
            }
        } catch { Write-Warning "Could not parse Epic manifest: $($_.Exception.Message)" }
    }
    foreach ($pf in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($pf) { $roots.Add((Join-Path $pf 'Epic Games')) }
    }
    $found = New-Object 'System.Collections.Generic.List[string]'
    $command = Get-RegistryDefault 'Registry::HKEY_CLASSES_ROOT\Unreal.ProjectFile\shell\open\command'
    if ($command -match '^"([^"]+\.exe)"' -and (Test-Path -LiteralPath $Matches[1])) { $found.Add($Matches[1]) }
    foreach ($root in ($roots | Select-Object -Unique)) {
        foreach ($relative in @('UnrealVersionSelector.exe','Engine\Binaries\Win64\UnrealVersionSelector.exe','Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe','Engine\Binaries\Win64\UnrealVersionSelector-Win64-Shipping.exe')) {
            $candidate = Join-Path $root $relative
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $found.Add((Get-Item -LiteralPath $candidate).FullName) }
        }
    }
    return @($found | Sort-Object -Unique)
}

function Get-AssociationState {
    $command = Get-RegistryDefault 'Registry::HKEY_CLASSES_ROOT\Unreal.ProjectFile\shell\open\command'
    $target = $null
    if ($command -match '^"([^"]+\.exe)"') { $target = $Matches[1] }
    $overrides = @()
    foreach ($name in @('.uproject','.uplugin','Unreal.ProjectFile')) {
        $path = "HKCU:\Software\Classes\$name"
        if (Test-Path -LiteralPath $path) {
            $preview = Get-RegistryDefault ($path + '\shellex\{8895b1c6-b41f-4c1c-a562-0d564250836f}')
            $overrides += [pscustomobject]@{ Name=$name; Default=(Get-RegistryDefault $path); HasChildren=(@(Get-ChildItem -LiteralPath $path).Count -gt 0); PreviewHandler=$preview; MonacoPreviewDetected=($preview -eq '{D8034CFA-F34B-41FE-AD45-62FCBB52A6DA}') }
        }
    }
    [pscustomobject]@{
        ExtensionClass = Get-RegistryDefault 'Registry::HKEY_CLASSES_ROOT\.uproject'
        OpenCommand = $command
        MachineOpenCommand = Get-RegistryDefault 'HKLM:\Software\Classes\Unreal.ProjectFile\shell\open\command'
        TargetExists = [bool]($target -and (Test-Path -LiteralPath $target -PathType Leaf))
        UserOverrides = $overrides
        MonacoPreviewKeys = @($overrides | Where-Object MonacoPreviewDetected | ForEach-Object Name)
        UserChoice = if (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.uproject\UserChoice') {
            (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.uproject\UserChoice').ProgId
        } else { $null }
        LauncherRunning = [bool](Get-Process EpicGamesLauncher -ErrorAction SilentlyContinue)
        PowerToysRunning = [bool](Get-Process PowerToys -ErrorAction SilentlyContinue)
    }
}

function Test-AssociationConfiguration($State, [string]$ExpectedSelector) {
    if ($State.ExtensionClass -ne 'Unreal.ProjectFile' -or -not $State.TargetExists) { return $false }
    if ($State.UserChoice -and $State.UserChoice -ne 'Unreal.ProjectFile') { return $false }
    if ($State.OpenCommand -notmatch '^"([^\"]+UnrealVersionSelector(?:-Win64-Shipping)?\.exe)"\s+/editor\s+"%1"$') { return $false }
    if ($ExpectedSelector -and $Matches[1] -ne $ExpectedSelector) { return $false }
    return $State.OpenCommand -eq $State.MachineOpenCommand
}

function Get-AssociationStatus([bool]$Configured, [bool]$LauncherError) {
    if ($Configured -and $LauncherError) { return 'AssociationConfiguredLauncherErrorReported' }
    if ($Configured) { return 'AssociationConfigured' }
    return 'AssociationNeedsAttention'
}

function Invoke-AssociationDoctor {
    if (-not [Environment]::Is64BitProcess -and [Environment]::Is64BitOperatingSystem) {
        throw 'Use 64-bit PowerShell so registry inspection and repair use the same registry view.'
    }
    $before = Get-AssociationState
    $candidates = @(Get-SelectorCandidates)
    if ($SelectorPath) {
        $selected = (Resolve-Path -LiteralPath $SelectorPath).Path
    } elseif ($candidates.Count -eq 1) { $selected = $candidates[0] }
    else { $selected = $null }
    $configured = Test-AssociationConfiguration $before $selected
    $report = [ordered]@{ Mode=$Mode; Candidates=$candidates; Selected=$selected; Before=$before; After=$null; Backup=$null; ToolExitCode=$null; RegistryVerified=$configured; LauncherVerified=$false; ProjectOpenVerified=$false; LauncherErrorReported=[bool]$LauncherReportsError; Status=(Get-AssociationStatus $configured ([bool]$LauncherReportsError)); Action='None'; VerificationScope='Windows open command only; launcher and project loading are not tested' }
    if ($Mode -eq 'Diagnose') { return [pscustomobject]$report }
    if ($configured -and -not $ForceRepair) {
        $report.Action = 'SkippedAlreadyConfigured'
        Write-Warning 'Windows association already matches. No registry changes made and the official tool was not run. If Epic still reports an error, diagnose with -LauncherReportsError; -ForceRepair only reruns the official tool.'
        return [pscustomobject]$report
    }
    if (-not $selected) { throw 'No unique selector found. Use -SelectorPath with the intended launcher executable, or -SearchRoot with its installation directory.' }
    if ([IO.Path]::GetFileName($selected) -notmatch '^UnrealVersionSelector(?:-Win64-Shipping)?\.exe$') { throw 'The selected executable is not named UnrealVersionSelector.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $selected
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Epic Games') {
        throw 'Automatic repair requires a valid Epic Games signed selector. Source builds can be inspected in Diagnose mode; run their trusted selector manually.'
    }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Repair requires an elevated PowerShell window. Diagnose does not require administrator rights.' }
    if (@(Get-Process UnrealVersionSelector -ErrorAction SilentlyContinue).Count) { throw 'Close existing UnrealVersionSelector dialogs before repairing. An old error dialog must not be mistaken for a new result.' }
    if ($before.UserChoice -and $before.UserChoice -ne 'Unreal.ProjectFile') { throw 'Windows UserChoice selects another app. Change the .uproject default app in Windows Settings first; this tool does not modify protected UserChoice hashes.' }
    # Validate every override before making changes. Unknown registrations are preserved.
    foreach ($entry in $before.UserOverrides) {
        if ($entry.Name -in @('.uproject','.uplugin')) {
            $expected = if ($entry.Name -eq '.uproject') { 'Unreal.ProjectFile' } else { 'Unreal.PluginFile' }
            if ($entry.Default -and $entry.Default -ne $expected) { throw "Unknown association for $($entry.Name); leaving it unchanged." }
        } else {
            $userCommand = Get-RegistryDefault 'HKCU:\Software\Classes\Unreal.ProjectFile\shell\open\command'
            if ($userCommand -notmatch 'UnrealVersionSelector[^"\\]*\.exe"?\s+/editor') { throw 'Unknown user-level project handler; leaving it unchanged.' }
        }
    }
    $backup = Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $report.Backup = $backup
    $before | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $backup 'before.json') -Encoding UTF8
    foreach ($hive in @('HKCU','HKLM')) {
        foreach ($name in @('.uproject','.uplugin','Unreal.ProjectFile','Unreal.PluginFile')) {
            if (Test-Path -LiteralPath "${hive}:\Software\Classes\$name") {
                & reg.exe export "$hive\Software\Classes\$name" (Join-Path $backup "$hive-$name.reg") /y | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Backup failed for $hive/$name. No overrides have been moved." }
            }
        }
    }
    $moves = @()
    try {
        foreach ($entry in $before.UserOverrides) {
            $oldPath = "HKCU:\Software\Classes\$($entry.Name)"
            $newName = $entry.Name + '.AssociationDoctor-' + [guid]::NewGuid().ToString('N')
            Rename-Item -LiteralPath $oldPath -NewName $newName
            $moves += [pscustomobject]@{ Original=$entry.Name; Preserved=$newName }
            $moves | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'preserved-keys.json') -Encoding UTF8
        }
        $p = Start-Process -FilePath $selected -ArgumentList '/fileassociations' -WorkingDirectory (Split-Path $selected) -PassThru
        if (-not $p.WaitForExit(60000)) { throw 'Selector is still running. Inspect its dialog; do not launch another instance. Backups and preserved keys are retained.' }
        $report.ToolExitCode = $p.ExitCode
        $report.Action = 'OfficialToolExecuted'
        $after = Get-AssociationState
        $report.After = $after
        $report.RegistryVerified = Test-AssociationConfiguration $after $selected
        $report.Status = Get-AssociationStatus $report.RegistryVerified ([bool]$LauncherReportsError)
        if ($p.ExitCode -ne 0 -or -not $report.RegistryVerified) { throw 'Official tool failed or registry verification failed; see report.json. Registry state and tool exit code are recorded separately.' }
    } finally {
        $report.After = Get-AssociationState
        $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $backup 'report.json') -Encoding UTF8
    }
    Write-Warning 'Registry verified only. Fully exit and restart Epic, enter Unreal Engine > Library, and open a known project to verify the complete workflow. PowerToys preview may recreate user overrides.'
    return [pscustomobject]$report
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-AssociationDoctor | ConvertTo-Json -Depth 10
}
