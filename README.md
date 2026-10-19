# Unreal Association Doctor

**Epic 修不好 `.uproject` 文件关联？双击启动，按中文提示检查和修复。**

适用于 Epic 启动器提示 `Project files not associated`，点击修复后出现 `Couldn't update file associations.`，或移动、重装启动器后，项目打开方式仍指向旧目录的情况。

[**下载 ZIP**](https://github.com/redtidev1918/unreal-association-doctor/archive/refs/heads/main.zip) · [常见问题](docs/TROUBLESHOOTING.md) · [反馈问题](https://github.com/redtidev1918/unreal-association-doctor/issues)

## 三步使用

### 1. 下载，解压，双击

下载上方 ZIP，右键选择“全部解压”，打开解压后的文件夹，双击 **`Start.cmd`**。

请完整保留文件夹中的文件，不要在压缩包里直接运行，也不要只复制 `Start.cmd`。

### 2. 先检查，再修复

在中文菜单中输入数字，然后按回车：

| 输入 | 操作 |
| --- | --- |
| **1** | 检查当前关联和安装路径，不修改系统 |
| **2** | 备份配置并修复 |
| **3** | 打开备份文件夹 |
| **4** | 打开常见问题说明 |
| **5** | Epic 仍报错：收集诊断报告（不修改关联） |
| **0** | 退出 |

第一次使用先选 **1**。需要修复时选 **2**，在 Windows 管理员权限提示中选择“是”，然后在新打开的窗口按提示输入 **Y** 确认。

如果找到多个关联工具，向导会让你选择编号；如果没有找到，会提示你填写 `UnrealVersionSelector.exe` 的完整路径。修复前请关闭之前留下的关联修复或报错窗口。

### 3. 重启 Epic，打开项目验证

看到 **“Windows 文件关联检查已通过”** 后：

1. 从系统托盘完全退出 Epic，再重新打开。
2. 进入“虚幻引擎 → 库”，确认不再提示关联错误。
3. 双击一个已知正常的 `.uproject`，确认可以使用预期引擎打开。

工具检查通过代表 Windows 的关联配置符合预期；启动器和项目是否恢复正常，需要通过这两处实际操作确认。

## 它会做什么？

工具会寻找本机安装的关联程序，检查当前打开路径和用户覆盖配置，**先备份，再调用 Epic 自带的 `UnrealVersionSelector.exe` 修复**。支持自定义盘符和多个安装位置，不写死 UE 版本号。

修改范围是 Windows 文件关联。项目文件、资源和项目所选引擎版本不会被修改，已有的项目和启动器也不会被自动关闭。

## 遇到问题怎么办？

| 现象 | 处理方法 |
| --- | --- |
| 双击后提示禁止运行脚本或文件被阻止 | 查看[脚本运行说明](docs/TROUBLESHOOTING.md#powershell-不允许运行脚本)；受组织管理的电脑请联系管理员 |
| 找不到 `UnrealVersionSelector.exe` | 检查 Epic 安装目录中的 `Launcher\Engine\Binaries\Win64`；程序缺失时，本工具不会自动下载补齐 |
| 修复提示还有程序在运行 | 先处理旧修复窗口，再重试；不要连续开启多个修复实例 |
| 显示红色错误或长时间没有完成 | 保留完整报错，选 **4** 查看对照表；选 **3** 查看本次备份和报告 |
| 检查通过，但 Epic 仍报错 | 关联已经正确时选 **2** 不会再修改配置（`SkippedAlreadyConfigured`）。先双击 `.uproject` 看能否打开，再选 **5** 收集报告 |
| 使用 PowerToys 后问题再次出现 | 查看 [Monaco 预览冲突说明](docs/TROUBLESHOOTING.md#powertoys-一定有冲突吗)；安装了 PowerToys 不代表一定有冲突 |

备份默认位于 `%LOCALAPPDATA%\UnrealAssociationDoctor\Backups`。每次修复使用独立目录。**目前没有一键回滚**，需要恢复时请先阅读[恢复说明](docs/TECHNICAL.md#恢复说明)。

## 使用条件与适用范围

- 双击入口使用 Windows 自带的 **64 位 Windows PowerShell 5.1**；修复需要管理员权限。
- 自动修复只执行具有有效 Epic Games 签名的关联程序。源码构建可用于诊断，未签名程序不会被自动执行。
- 本工具处理文件关联，不负责安装引擎、修复项目编译错误，或解决“我的工程”列表为空等其他问题。
- 已测试中文检测菜单、脚本语法、只读诊断、自定义目录发现和多候选选择。管理员修复尚未完成跨机器、跨版本验证。

## 命令行使用

习惯终端的用户可以在仓库目录中运行以下命令。核心脚本支持 64 位 Windows PowerShell 5.1 或 PowerShell 7。

```powershell
# 只检查
.\Repair-UnrealAssociation.ps1

# 修复：请在管理员 PowerShell 中运行
.\Repair-UnrealAssociation.ps1 -Mode Repair

# 补充安装目录，帮助查找
.\Repair-UnrealAssociation.ps1 -SearchRoot 'E:\Tools\Epic Games'

# 明确指定关联工具
.\Repair-UnrealAssociation.ps1 -Mode Repair -SelectorPath 'E:\Tools\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe'
```

命令行输出为 JSON。`RegistryVerified: true` 表示 Windows 打开命令检查通过（诊断模式也会计算）；`Status` 区分“已配置”和“已配置但启动器仍报错”。`LauncherVerified` 和 `ProjectOpenVerified` 不会自动设为 true。

关联已正确时 `-Mode Repair` 会跳过修改（`Action=SkippedAlreadyConfigured`）。确认要重跑官方工具时加 `-ForceRepair`；要记录“启动器仍报错”时加 `-LauncherReportsError`。

## 技术资料

- [常见问题与报错对照表](docs/TROUBLESHOOTING.md)
- [参数、实现流程、备份与恢复](docs/TECHNICAL.md)
- [实际排查记录与社区来源](docs/CASE-STUDY.md)

运行测试：

```powershell
.\tests\Smoke.ps1
```

测试不执行系统关联修复，只创建并清理临时测试文件。
