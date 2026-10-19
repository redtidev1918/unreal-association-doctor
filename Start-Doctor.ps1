#requires -Version 5.1
[CmdletBinding()]
param([switch]$RepairNow)
$ErrorActionPreference = 'Stop'
$core = Join-Path $PSScriptRoot 'Repair-UnrealAssociation.ps1'
$backups = Join-Path $env:LOCALAPPDATA 'UnrealAssociationDoctor\Backups'

function Show-Diagnosis {
    $result = & $core -Mode Diagnose | ConvertFrom-Json
    Write-Host ''
    Write-Host ('当前打开路径：' + $result.Before.OpenCommand)
    Write-Host ('路径上的程序存在：' + $result.Before.TargetExists)
    Write-Host ('发现的关联工具数量：' + @($result.Candidates).Count)
    foreach ($candidate in $result.Candidates) { Write-Host ('  ' + $candidate) }
    Write-Host ('用户覆盖配置数量：' + @($result.Before.UserOverrides).Count)
    Write-Host '这是检查结果，不代表已经修复。' -ForegroundColor Yellow
    return $result
}

function Start-Repair {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host '即将打开管理员修复窗口，请在 Windows 权限提示中选择“是”。'
        $escaped = $PSCommandPath.Replace("'", "''")
        $command = "& '$escaped' -RepairNow"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $process = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','RemoteSigned','-EncodedCommand',$encoded) -Verb RunAs -PassThru
        Write-Host '请在新打开的窗口中继续；原窗口不会宣称修复成功。'
        return
    }
    $diagnosis = Show-Diagnosis
    $candidates = @($diagnosis.Candidates)
    $selected = $diagnosis.Selected
    if (-not $selected) {
        if ($candidates.Count) {
            for ($i = 0; $i -lt $candidates.Count; $i++) { Write-Host ("{0}. {1}" -f ($i + 1), $candidates[$i]) }
            $answer = Read-Host '输入要使用的关联工具编号，或直接回车取消'
            $index = 0
            if (-not [int]::TryParse($answer, [ref]$index) -or $index -lt 1 -or $index -gt $candidates.Count) { return }
            $selected = $candidates[$index - 1]
        } else {
            Write-Host '没有自动找到关联工具。请从 Epic 安装目录中找到 UnrealVersionSelector.exe。'
            $selected = (Read-Host '粘贴 exe 完整路径，或直接回车取消').Trim().Trim('"')
            if (-not $selected) { return }
        }
    }
    Write-Host ''
    Write-Host '修复会先备份文件关联配置，再运行 Epic 官方工具。不会修改项目文件。'
    Write-Host '请先关闭旧的 UnrealVersionSelector 修复或报错窗口。'
    if ((Read-Host '输入 Y 开始修复，其他输入取消') -ne 'Y') { return }
    $result = & $core -Mode Repair -SelectorPath $selected | ConvertFrom-Json
    if ($result.RegistryVerified) {
        Write-Host 'Windows 文件关联检查已通过。' -ForegroundColor Green
        Write-Host ('本次备份：' + $result.Backup)
        Write-Host '还需要完成：'
        Write-Host '1. 从系统托盘完全退出 Epic，再重新打开“虚幻引擎 → 库”。'
        Write-Host '2. 双击一个已知正常的 .uproject，确认可以打开。'
        Write-Host '若仍有提示，选择菜单 1 重新检查，并保留报错原文。'
    } else { throw '关联检查未通过，请查看备份中的 report.json。' }
}

function Show-Failure($failure) {
    Write-Host ''
    Write-Host '本次操作未完成：' -ForegroundColor Red
    Write-Host $failure.Exception.Message -ForegroundColor Yellow
    Write-Host '请勿反复启动修复。旧弹窗需要先关闭；多个安装需要明确选择。'
    Write-Host '可选择 3 查看备份，或选择 4 阅读报错对照表。'
}

if ($RepairNow) {
    try { Start-Repair } catch { Show-Failure $_ }
    $null = Read-Host '按回车返回菜单'
}
while ($true) {
    Write-Host ''
    Write-Host '=== Unreal 文件关联修复助手 ===' -ForegroundColor Cyan
    Write-Host '1. 检查问题（不修改系统）'
    Write-Host '2. 自动备份并修复（需要管理员权限）'
    Write-Host '3. 打开备份目录'
    Write-Host '4. 打开常见问题说明'
    Write-Host '0. 退出'
    $choice = Read-Host '请输入数字'
    if ($choice -eq '0') { break }
    try {
        switch ($choice) {
            '1' { $null = Show-Diagnosis }
            '2' { Start-Repair }
            '3' {
                if (Test-Path -LiteralPath $backups) { Start-Process explorer.exe -ArgumentList ('"' + $backups + '"') }
                else { Write-Host '目前还没有备份。修复进入备份阶段后才会创建。' }
            }
            '4' { Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $PSScriptRoot 'docs\TROUBLESHOOTING.md') + '"') }
            default { Write-Host '请输入 0 到 4。' }
        }
    } catch { Show-Failure $_ }
}
