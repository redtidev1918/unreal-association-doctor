# 常见问题

[返回使用指南](../README.md)

## PowerShell 不允许运行脚本

先用文本编辑器检查脚本，确认它来自本仓库。若提示下载文件被阻止，可解除单个脚本的下载标记：

```powershell
Unblock-File -LiteralPath '.\Repair-UnrealAssociation.ps1'
```

如果是执行策略禁止运行，查看来源：

```powershell
Get-ExecutionPolicy -List
```

个人电脑且没有组织策略限制时，可仅对当前窗口设置：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

关闭窗口后失效。如果 `MachinePolicy` 或 `UserPolicy` 受组织管理，请联系管理员，不要绕过组织策略。

## 报错对照表

| 提示关键词 | 下一步 |
| --- | --- |
| `Use 64-bit PowerShell` | 使用 64 位 PowerShell，不要用 x86 版本 |
| `No unique selector found` | 诊断查看 `Candidates`；未找到用 `-SearchRoot`，多个候选用 `-SelectorPath` |
| `not named UnrealVersionSelector` | 指定关联工具，而不是 `UnrealEditor.exe` 或启动器本身 |
| `valid Epic Games signed selector` | 签名校验失败；确认程序来自本机官方安装，不要改名或下载不明 exe |
| `elevated PowerShell` | 右键 PowerShell，以管理员身份运行，再进入仓库目录 |
| `Close existing UnrealVersionSelector dialogs` | 先处理旧修复窗口；看不到窗口时检查任务管理器中的相关进程 |
| `Windows UserChoice selects another app` | 在 Windows“设置 → 应用 → 默认应用”中检查 `.uproject` 的默认应用 |
| `Unknown association` / `Unknown user-level project handler` | 存在无法确认用途的自定义关联；工具停止修改，先确认来源 |
| `Backup failed` | 检查备份目录权限或指定 `-BackupRoot`；此时尚未移动用户覆盖项 |
| `Selector is still running` | 超过 60 秒未退出；查看官方工具弹窗，先不要再启动一个实例 |
| `Registry verification failed` | 查看本次备份中的 `report.json`；不能只凭退出码判断成功 |

## 找不到关联工具

通常在启动器的 `Launcher\Engine\Binaries\Win64` 下。先用 `-SearchRoot` 指定安装目录，或用 `-SelectorPath` 指定完整路径。工具不全盘递归搜索，也不从网络补齐缺失文件。

安装中确实缺失时，应检查官方启动器安装。源码构建和旧版程序可能没有满足自动修复要求的签名，不能假定所有版本都可以自动修复。

## 检查通过，Epic 仍提示修复

关闭旧修复窗口，从托盘完整退出 Epic，再重新打开引擎库。这能排除旧窗口或未重新加载配置的影响，但不是所有错误的确定原因。

仍失败时，保存新的诊断结果：

```powershell
.\Repair-UnrealAssociation.ps1 | Out-File -FilePath '.\diagnosis.txt' -Encoding utf8
```

记录触发操作、完整报错，以及 `Selected`、`Before.OpenCommand`、`Before.UserOverrides` 和本次修复的 `report.json`。分享前检查本机用户名和目录路径。

## PowerToys 一定有冲突吗？

不是。`PowerToysRunning: true` 仅说明进程存在。本次案例发现了 Monaco 预览项，社区也有相关冲突反馈。

如果重启 PowerToys 后 `.uproject` / `.uplugin` 覆盖反复出现，可在 PowerToys 的文件资源管理器加载项中关闭“源代码文件（Monaco）”预览，再尝试修复。界面名称可能随版本变化。这会影响其他源码文件预览，因此工具不自动关闭。详见[案例与来源](CASE-STUDY.md)。

## 可以一键恢复吗？

目前没有一键回滚。注册表导入是合并，不等于恢复到完全相同的状态。请阅读[恢复说明](TECHNICAL.md#恢复说明)，不要一起导入所有历史备份。
