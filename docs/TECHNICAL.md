# 技术说明

[返回使用指南](../README.md)

## 参数与发现规则

| 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `-Mode` | `Diagnose` | 只读诊断；`Repair` 才尝试修复 |
| `-SelectorPath` | 选择唯一候选 | 指定关联工具完整路径 |
| `-SearchRoot` | 空数组 | 补充一个或多个安装根目录 |
| `-BackupRoot` | `$env:LOCALAPPDATA\UnrealAssociationDoctor\Backups` | 设置备份父目录 |

发现来源包括运行中的 Epic 启动器、32/64 位 Epic 注册表、`%ProgramData%\Epic\UnrealEngineLauncher\LauncherInstalled.dat`、现有有效关联及系统 Program Files 目录。候选去重后仅在唯一候选时自动选择。

`-SearchRoot` 检查给定目录及脚本列出的固定相对路径，如 `Launcher\Engine\Binaries\Win64`、`Engine\Binaries\Win64`。不会递归搜索或枚举所有源码构建；不匹配时应指定完整 exe 路径。

自适应指路径发现和处理歧义，不表示已经验证所有 Windows、启动器或源码版本。

## 修复流程

1. 获取当前关联、候选和选择结果。
2. 检查 exe 名称、Epic 签名、管理员权限、已运行的修复进程及 UserChoice。
3. 校验用户覆盖的默认值或打开命令；未知处理程序会使流程停止。这不是对每个子项来源的完整识别。
4. 导出相关 HKCU/HKLM 项，再将用户级 `.uproject`、`.uplugin`、`Unreal.ProjectFile` 改名保留。
5. 从所选 exe 的目录启动 `/fileassociations`，最多等待 60 秒。
6. 验证退出码、有效扩展名映射、有效与 HKLM 打开命令，以及目标是否存在。

不自动关闭启动器、项目、PowerToys 或超时 selector；不修改项目 `EngineAssociation`、UserChoice 哈希和预览开关，也不下载 exe。

## 验证的范围

`RegistryVerified=true` 要求退出码为 0、有效 `.uproject` 类为 `Unreal.ProjectFile`、有效与系统级打开命令均匹配所选 exe 的 `/editor "%1"`，且目标存在。

未逐项验证所有右键菜单，也未加载项目。`LauncherVerified` 和 `ProjectOpenVerified` 始终为 false，留待人工确认；诊断模式的全部验证字段也保持 false。

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
