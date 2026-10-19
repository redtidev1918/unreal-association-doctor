# 排查记录与社区依据

[返回使用指南](../README.md)

Epic 提示项目文件未关联，点修复出现 `Couldn't update file associations.`。以下事实解释工具的设计，不代表所有环境有相同根因。

| 阶段 | 实际观察 | 得到的经验 |
| --- | --- | --- |
| 初始检查 | HKLM 指向不存在的 `C:\Launcher\...`，真实程序在另一目录 | 发现实际路径并检查文件存在 |
| 添加用户覆盖 | 合并视图正确，但启动器仍报错 | 不能只检查 HKCR，也不能将覆盖当作系统级修复 |
| 检查预览项 | `.uproject` / `.uplugin` 中发现 PowerToys Monaco | 先记录和备份，不能只凭安装了 PowerToys 判定根因 |
| 移开覆盖、运行官方工具 | 管理员运行后退出码 0，系统路径正确 | 执行后重新读配置验证 |
| 用户继续反馈失败 | 启动器修复按钮仍报错 | 退出码和注册表通过不等于端到端成功 |
| 完整重启 Epic | 再次进入库时没有观察到关联警告 | 重启验证必要，但不能保证永久解决 |
| PowerToys 重启后复查 | `.uproject` / `.uplugin` 的 Monaco 预览子项被重新创建 | 覆盖项会自行重建；关联已正确时再改名并重跑官方工具不会有新结果 |
| 用户再次反馈 | 快捷方式已替换成功，但点启动器“修复”仍报同样错误 | 关联可用与启动器报错是两件事，工具分状态报告，默认跳过无意义的重复修复 |

**未验证实际项目打开，也未证明所有失败均来自 PowerToys。** 早期修复进程曾持续存在，但没有证据确认用户每次看到的都是旧窗口；因此工具不把“没有弹窗”当作解决，也不把退出码当成功。

## 社区来源

- [管理员运行 selector 与错误路径案例](https://forums.unrealengine.com/t/uproject-associations-not-setup-on-fresh-installs/485770)：支持 `/fileassociations` 与路径检查的排查方向。
- [清理 HKCU 扩展名项后成功的案例](https://forums.unrealengine.com/t/couldnt-update-file-associations-for-project-files/2836277)：提示用户覆盖可能影响修复；本工具使用备份后改名保留。
- [PowerToys Monaco 冲突排查记录](https://bboydaisuke.cloudfree.jp/2026/09/11/epic-games-launcher-fails-fixing-project-file-association/)：作者报告预览子项导致修复失败，且可能被重新创建。
- [Epic 员工解释关联与引擎发现](https://forums.unrealengine.com/t/engine-association-issue/2651662/2)：文件关联调用 selector，项目版本与引擎发现是后续处理。

社区案例是线索，不是兼容性承诺。工程列表为空、引擎未注册或编译失败应分别诊断，不应继续反复重写文件关联。
