# Unreal Association Doctor

Windows 下 Unreal `.uproject` 关联问题的自适应诊断与修复工具。针对 Epic 的 `Couldn't update file associations.`，采用“发现 → 诊断 → 备份 → 官方工具修复 → 分层验证”的流程。

## 使用

在 **64 位 Windows PowerShell 5.1 或 PowerShell 7** 中运行。默认仅诊断，不修改配置：

```powershell
.\Repair-UnrealAssociation.ps1
```

以管理员身份打开 PowerShell，执行修复：

```powershell
.\Repair-UnrealAssociation.ps1 -Mode Repair
```

自定义盘符、迁移过的安装或源码环境：

```powershell
.\Repair-UnrealAssociation.ps1 -SearchRoot 'E:\Tools\Epic Games', 'F:\UE_Source'
.\Repair-UnrealAssociation.ps1 -Mode Repair -SelectorPath 'E:\Tools\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe'
```

发现来源包括正在运行的启动器、32/64 位 Epic 注册表、`LauncherInstalled.dat`、现有有效关联、系统 Program Files 路径和用户指定目录。多个候选时要求指定，避免擅自选择其他安装。不会全盘扫描或假定 UE 版本。源码构建可诊断；自动执行仅接受 Epic 有效签名的程序。

## 修复行为与边界

- 检查管理员权限、已有修复窗口、Windows UserChoice 和未知自定义关联；不满足条件时停止。
- 导出关联相关的 HKCU/HKLM 项，记录修复前状态。默认备份路径为 `%LOCALAPPDATA%\UnrealAssociationDoctor\Backups`。
- 将已识别的用户级 `.uproject`、`.uplugin`、`Unreal.ProjectFile` 覆盖项改名保留，然后从其安装目录调用官方 selector 的 `/fileassociations`。
- 重新读取合并视图与系统级打开命令，验证是否指向所选 exe。不会硬编码引擎安装位置，也不修改项目的 `EngineAssociation`。
- 不自动关闭启动器、项目或 PowerToys，不关闭所有源码预览，不修改受保护的 UserChoice，不下载第三方 exe。
- 超时不终止修复进程，不自动回滚正在执行的注册表更改；保留报告供诊断。若有弹窗，请先处理弹窗，避免多次启动。

`RegistryVerified=true` 只代表关联检查通过。请完整退出 Epic（包括托盘）再进入“虚幻引擎 → 库”，最后打开已知项目。工具始终不把 `LauncherVerified` 或 `ProjectOpenVerified` 自动标为 true。

## 恢复

先关闭修复工具。备份目录中的 `.reg` 是原始键导出，可检查后使用 `reg import` 恢复（HKLM 需要管理员权限）。`preserved-keys.json` 记录改名保留的用户项。注册表导入是合并操作，不会删除新增值，因此不是完整事务回滚；需要精确恢复时，对照清单仅处理本工具影响的键，再恢复原键，避免删除未知内容。不要批量导入所有历史备份。

## 本次实际排查所得

1. 原系统级命令指向不存在的 `C:\Launcher\...`，真实 selector 位于另一安装目录。路径错误是明确事实。
2. 最初添加 HKCU 覆盖只修好了合并视图，Epic 仍报错。覆盖方案不应当作系统级修复完成。
3. `.uproject` / `.uplugin` 下发现 PowerToys Monaco 预览处理器；社区有同样冲突案例。但不能只凭安装了 PowerToys 就判定根因。
4. 备份并移开用户覆盖、从实际目录运行管理员 selector 后，退出码为 0，系统级路径正确。用户随后仍报告启动器修复按钮报错：不能把退出码等同于端到端成功。
5. 完整重启 Epic 并进入库后，现场没有再次出现警告。项目实际打开未验证，不能声称已覆盖所有情况或永久解决。

如果重启 PowerToys 后关联项重新出现，可在 PowerToys 的文件资源管理器加载项中关闭源码（Monaco）预览后重试。这会影响其他源码文件预览，因此工具不代替用户关闭。

## 社区依据

- [管理员运行 selector /fileassociations 与错误路径案例](https://forums.unrealengine.com/t/uproject-associations-not-setup-on-fresh-installs/485770)
- [清理 HKCU .uproject / .uplugin 后修复成功的案例](https://forums.unrealengine.com/t/couldnt-update-file-associations-for-project-files/2836277)
- [PowerToys Monaco 冲突的作者排查记录](https://bboydaisuke.cloudfree.jp/2026/09/11/epic-games-launcher-fails-fixing-project-file-association/)
- [Epic 员工解释关联与引擎发现](https://forums.unrealengine.com/t/engine-association-issue/2651662/2)

社区案例是排查线索，不能保证适用于每个版本。项目未出现在库、引擎版本未注册、项目编译失败需要分别诊断。

## 验证

```powershell
.\tests\Smoke.ps1
```

测试解析脚本，并执行只读诊断检查输出结构，不修改真实关联。管理员修复需在 Windows 测试机上验证，尤其要覆盖多安装、自定义盘符、权限不足、未知关联和工具弹窗场景。
