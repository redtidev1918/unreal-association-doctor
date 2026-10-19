# 技术说明

[返回使用指南](../README.md)

## 参数与发现规则

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `-Mode` | `Diagnose` | 只读诊断；`Repair` 才尝试修复 |
| `-SelectorPath` | 选择唯一候选 | 指定关联工具完整路径 |
| `-SearchRoot` | 空数组 | 补充一个或多个安装根目录 |
| `-ForceRepair` | 关闭 | 即使关联已通过也重新运行官方工具 |
| `-LauncherReportsError` | 关闭 | 记录“启动器仍报错”属于已确认的关联之外的问题 |
| `-BackupRoot` | `$env:LOCALAPPDATA\UnrealAssociationDoctor\Backups` | 设置备份父目录 |

发现来源包括运行中的 Epic 启动器、32/64 位 Epic 注册表、`%ProgramData%\Epic\UnrealEngineLauncher\LauncherInstalled.dat`、现有有效关联及系统 Program Files 目录。候选去重后仅在唯一候选时自动选择。

`-SearchRoot` 检查给定目录及脚本列出的固定相对路径，如 `Launcher\Engine\Binaries\Win64`、`Engine\Binaries\Win64`。不会递归搜索或枚举所有源码构建；不匹配时应指定完整 exe 路径。

自适应指路径发现和处理歧义，不表示已经验证所有 Windows、启动器或源码版本。

## 修复流程

1. 获取当前关联、候选和选择结果，并校验当前关联是否已满足预期。
2. 已满足预期时不做任何修改，`Action=SkippedAlreadyConfigured`。用户覆盖项（例如 PowerToys 重建的预览子项）存在也不再触发修复，因为再跑一次官方工具不会改变结果。需要时用 `-ForceRepair` 显式重跑。
3. 检查 exe 名称、Epic 签名、管理员权限、已运行的修复进程及 UserChoice。
4. 校验用户覆盖的默认值或打开命令；未知处理程序会使流程停止。这不是对每个子项来源的完整识别。
5. 导出相关 HKCU/HKLM 项，再将用户级 `.uproject`、`.uplugin`、`Unreal.ProjectFile` 改名保留。
6. 从所选 exe 的目录启动 `/fileassociations`，最多等待 60 秒，`Action=OfficialToolExecuted`。
7. 验证退出码、有效扩展名映射、有效与 HKLM 打开命令，以及目标是否存在。

不自动关闭启动器、项目、PowerToys 或超时 selector；不修改项目 `EngineAssociation`、UserChoice 哈希和预览开关，也不下载 exe。

## 验证的范围

`RegistryVerified=true` 要求有效 `.uproject` 类为 `Unreal.ProjectFile`、有效与系统级打开命令均匹配 `UnrealVersionSelector.exe /editor "%1"`、目标存在，且 UserChoice 未指向其他程序。诊断模式会计入真实结果，不需要先执行修复。

`Status` 区分三种情况：

| `Status` | 含义 |
| --- | --- |
| `AssociationConfigured` | Windows 打开命令检查通过 |
| `AssociationConfiguredLauncherErrorReported` | 检查通过，但用户明确反馈 Epic 仍报错 |
| `AssociationNeedsAttention` | 关联检查未通过 |

`LauncherVerified` 和 `ProjectOpenVerified` 始终为 false，因为工具不接管启动器和项目加载，也无法判断你看到的提示来自新窗口还是旧窗口。`VerificationScope` 只说明本次检查覆盖打开命令，不覆盖启动器或项目加载。

`Start-Doctor.ps1` 的菜单 5 会把报告写到 `%LOCALAPPDATA%\UnrealAssociationDoctor\Diagnostics\launcher-*.json`，只读取配置，记录用户反馈的项目打开结果和当时的进程信息。

## 备份文件

每次使用时间和随机后缀创建独立子目录。

| 文件 | 内容 |
| --- | --- |
| `before.json` | 修复前状态 |
| `HKCU-*.reg` / `HKLM-*.reg` | 修复前存在的相关项 |
| `preserved-keys.json` | 用户项原名和保留名；未移动时可能不存在 |
| `report.json` | 进入移动/执行阶段后，在 finally 中保存的结果 |

前置检查失败可能没有备份。导出失败可能留下不完整备份，但尚未移动覆盖。执行阶段失败不自动回滚，报告也不是完整事务日志。

## 恢复说明

先关闭官方修复程序，确认它不再写注册表，再选定本次备份。

可用 `reg import` 导入相应 `.reg`，HKLM 需要管理员权限。但导入只合并旧值，不移除新增项，不能当作完整回滚。原先不存在的键也没有导出文件。

需要精确恢复时，由熟悉注册表的维护者对照导出文件、`before.json` 和改名清单，先备份当前状态，再仅处理本次变更的准确路径并恢复原项。不要删除整个 `Software\Classes`，也不要批量导入不同时间的备份。

## 测试范围

冒烟测试覆盖语法、只读诊断、临时自定义目录、多候选不自动选择和明确选择，不启动候选 exe 或执行修复。

仍需在隔离环境验证多个真实安装、不同版本、权限不足、签名失败、未知关联、PowerToys 重建覆盖、弹窗超时、中途失败、启动器重启及项目打开。
