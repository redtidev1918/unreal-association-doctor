$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'Repair-UnrealAssociation.ps1')
$selector = 'E:\Epic\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe'
$command = '"' + $selector + '" /editor "%1"'
$state = [pscustomobject]@{ ExtensionClass='Unreal.ProjectFile'; TargetExists=$true; UserChoice=$null; OpenCommand=$command; MachineOpenCommand=$command; UserOverrides=@() }
if (-not (Test-AssociationConfiguration $state $selector)) { throw 'Valid association rejected' }
if ((Get-AssociationStatus $true $true) -ne 'AssociationConfiguredLauncherErrorReported') { throw 'Launcher error must be distinct' }
if ((Get-AssociationStatus $false $true) -ne 'AssociationNeedsAttention') { throw 'Broken association must remain actionable' }
$state.TargetExists = $false
if (Test-AssociationConfiguration $state $selector) { throw 'Missing target accepted' }
$state.TargetExists = $true
$state.MachineOpenCommand = 'old-path'
if (Test-AssociationConfiguration $state $selector) { throw 'Stale machine configuration accepted' }
$state.MachineOpenCommand = $command
$state.UserChoice = 'Other.App'
if (Test-AssociationConfiguration $state $selector) { throw 'Different UserChoice accepted' }
$state.UserChoice = $null
if (Test-AssociationConfiguration $state 'E:\Other\UnrealVersionSelector.exe') { throw 'Different selector accepted' }
# Exercise the no-op repair branch with mocked state; any write/tool execution is an error.
# Recreated Monaco-style overrides must not re-trigger a repair that cannot change the outcome.
$state.UserOverrides = @([pscustomobject]@{ Name='.uproject'; Default='Unreal.ProjectFile'; HasChildren=$true; PreviewHandler='{D8034CFA-F34B-41FE-AD45-62FCBB52A6DA}'; MonacoPreviewDetected=$true })
function Get-AssociationState { return $state }
function Get-SelectorCandidates { return @($selector) }
function Start-Process { throw 'No-op repair must not launch a process' }
function New-Item { throw 'No-op repair must not create backups' }
function Rename-Item { throw 'No-op repair must not change registry' }
$Mode = 'Repair'
$LauncherReportsError = $true
$WarningPreference = 'SilentlyContinue'
$result = Invoke-AssociationDoctor
if ($result.Action -ne 'SkippedAlreadyConfigured' -or $result.Backup -or $result.ToolExitCode) { throw 'Expected no-op repair' }
if ($result.Status -ne 'AssociationConfiguredLauncherErrorReported') { throw 'User symptom was lost' }
Write-Output 'PASS: association state, persistent launcher error and no-write repair guard'
