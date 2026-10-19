# Unreal Association Doctor

**检查并修复 Windows 下 Unreal 项目文件的打开方式。**

Epic 提示 `Project files not associated`，点击修复又出现 `Couldn't update file associations.`？这个工具会寻找本机的 `UnrealVersionSelector.exe`，备份关联配置，再调用 Epic 自带的程序修复。

默认只检查，不修改系统。支持自定义安装目录和多个安装位置，不写死盘符或 UE 版本。

> 已通过本机只读诊断、自定义目录和多候选测试。管理员修复尚未完成跨机器、跨版本验证；修复后仍需在启动器和实际项目中确认。

## 适用哪些问题？

| 情况 | 能做什么 |
| --- | --- |
| Epic 反复要求修复 `.uproject` 关联 | 检查覆盖配置和打开命令，尝试重建关联 |
| 移动或重装后，关联仍指向旧路径 | 发现当前安装位置，重新注册 |
| 双击 `.uproject` 无法打开 | 检查打开方式；引擎缺失或编译问题需要另行处理 |
| 装了多个引擎或启动器 | 列出发现的工具，由你明确选择 |
| 项目列表为空、编译失败、引擎版本不匹配 | 不属于本工具直接修复的范围 |

## 快速开始

### 推荐：双击启动，无需输入命令

1. 点击 [下载 ZIP](https://github.com/redtidev1918/unreal-association-doctor/archive/refs/heads/main.zip)，**完整解压**，不要在压缩包内直接运行。
2. 双击 **`Start.cmd`**，看到中文菜单后输入 **1** 检查问题。
3. 输入 **2** 修复；Windows 请求管理员权限时选择“是”，在新窗口按提示确认。多个安装会让你选择，不会乱选版本。
4. 看到“Windows 文件关联检查已通过”后，完整退出并重新打开 Epic，再双击项目验证。

菜单 **3** 可以打开备份目录，**4** 打开排错说明，**0** 退出。窗口会保留错误信息，不会一闪而过。修复不会自动关闭你的项目或启动器。

如果双击提示禁止运行脚本或文件被阻止，参见[脚本运行问题](docs/TROUBLESHOOTING.md#powershell-不允许运行脚本)。受组织管理的电脑请遵循管理员策略。

### 命令行方式（进阶）

需要 **Windows、64 位 Windows PowerShell 5.1 或 PowerShell 7**，以及已经安装的 Epic 关联工具。不会自动下载安装 Unreal Engine。

### 1. 下载并打开目录

在仓库页点击 **Code → Download ZIP**，解压到容易找到的目录。也可以使用 Git：

```powershell
git clone https://github.com/redtidev1918/unreal-association-doctor.git
```

公开仓库可直接下载，无需 GitHub 账号。

从开始菜单打开 **Windows PowerShell**（不要选名称带 `x86` 的版本），进入解压或克隆后的目录。下面是示例，请换成你的实际路径：

```powershell
Set-Location 'D:\Tools\unreal-association-doctor-main'
```

### 2. 先诊断

```powershell
.\Repair-UnrealAssociation.ps1
```

输出是 JSON 格式，先看下面几项即可：

| 字段 | 如何理解 |
| --- | --- |
| `Candidates` | 找到的关联工具路径；空列表表示未找到 |
| `Selected` | 选中的工具；多个候选时通常为 `null`，需要明确指定 |
| `Before.TargetExists` | 当前打开命令指向的文件是否存在；`false` 需要进一步检查 |
| `Before.UserOverrides` | 当前用户的覆盖配置；存在覆盖不代表一定有冲突 |

诊断时三个 `Verified` 字段均为 `false`，表示**没有执行对应验证**，不代表三项都坏了。

若提示禁止运行脚本，参见[脚本运行问题](docs/TROUBLESHOOTING.md#powershell-不允许运行脚本)。

### 3. 修复

关闭已有的 `UnrealVersionSelector` 报错窗口。从开始菜单右键 **Windows PowerShell → 以管理员身份运行**，再次进入仓库目录，然后执行：

```powershell
.\Repair-UnrealAssociation.ps1 -Mode Repair
```

工具会先备份，再将需要移开的用户配置改名保留。它不修改 `.uproject` 内容、引擎版本或项目资源。

提示没有唯一候选时，按下方“指定安装位置”操作。出现红色错误时，查看[报错对照表](docs/TROUBLESHOOTING.md)，不要反复启动修复程序。

### 4. 判断是否修好

1. 输出显示 `RegistryVerified: true`：Windows 关联检查通过。
2. 从系统托盘完整退出 Epic，再打开“虚幻引擎 → 库”，确认不再提示关联错误。
3. 双击一个已知能使用的 `.uproject`，确认用预期引擎打开。

后两步需要你操作。工具不会打开项目，所以 `LauncherVerified` 和 `ProjectOpenVerified` 保持 `false`。**只有退出码 `0`，不代表整个问题已经解决。**

## 指定安装位置

工具检查运行中的启动器、Epic 注册表、安装清单、现有关联和常见目录。找不到时，提供安装根目录；这不会递归扫描整个硬盘：

```powershell
.\Repair-UnrealAssociation.ps1 -SearchRoot 'E:\Tools\Epic Games', 'F:\UE_Source'
```

多个候选时，从 `Candidates` 选择实际使用的启动器所附带的 exe，明确指定：

```powershell
.\Repair-UnrealAssociation.ps1 -Mode Repair -SelectorPath 'E:\Tools\Epic Games\Launcher\Engine\Binaries\Win64\UnrealVersionSelector.exe'
```

这里选择的是关联工具，不是把所有项目切换到某个 UE 版本。自动修复要求有效的 Epic Games 签名；未签名源码构建可以诊断，但不能由本工具自动执行。

## 备份与进一步排查

备份默认保存在 `%LOCALAPPDATA%\UnrealAssociationDoctor\Backups`，每次修复使用独立目录。成功输出中的 `Backup` 给出具体位置。

- [常见问题](docs/TROUBLESHOOTING.md)：权限、工具缺失、超时、PowerToys、修复后仍报错。
- [技术说明与恢复方法](docs/TECHNICAL.md)：参数、发现规则、备份文件和验证范围。
- [排查记录与社区依据](docs/CASE-STUDY.md)：已经确认的事实与尚未验证的部分。

## 开发与测试

```powershell
.\tests\Smoke.ps1
```

测试检查语法、只读诊断、自定义目录发现、多候选和明确选择。只创建并清理临时测试文件，不执行关联修复或修改真实注册表。
