# 0.11.0 游戏备份 · 2026-10-04

本次备份是当前可运行的《无限异常》游戏及可恢复工程。使用现有飞书「代码仓库」和GitHub；此前独立美术图同步不是这次游戏备份。

- 当前版本：`0.11.0-earth-kaidan`。Windows包来自 `builds/InfiniteAnomaly-Earth-0.11.0`，保留原始EXE、PCK、GodotSharp和校验清单，不重新构建或替换美术。
- 源码保留既有Git历史，并备份当前project.godot、scripts、scenes、data、assets、tests、构建工具及启动脚本。新生成但未接入游戏的独立美术图不作为这次新增备份内容。
- 游戏功能：七房间与五人小队培养、装备/召唤、旧300关，以及客厅黑门内八尺大人和裂口女两个新异常。当前新增花子、Mary等美术尚未接入这个游戏。
- 当前背景源高724–727像素；2K/4K视口支持不等于原生4K美术。角色仍使用临时序列帧或两姿势反馈，完整正式动作待制作。

## 下载与恢复

[飞书代码仓库项目](https://c4onokeos5.feishu.cn/wiki/SAMIwCrpWi5fX5k6UPnc4U0EnYe)保留「10 工程版本与恢复清单」和「20 Windows 游戏包与项目参考」。Windows ZIP和源码ZIP都带逐文件SHA-256，另有飞书v1 Git bundle＋素材分块恢复清单。

Windows ZIP完整解压后双击 `InfiniteAnomaly.exe`。源码ZIP解压后，用Godot 4.7.1打开 `project.godot`，等待重新导入资源；缓存、引擎安装包、凭据和个人玩家存档不在源码包内。运行 `tools/build_earth.ps1` 可重建Windows包，Godot路径可通过 `-Godot` 指定。

Git备份分支 `codex/game-backup-0.11.0-20261004`；对应发布标记 `backup-2026-10-04-earth-0.11.0`，Windows ZIP从该Release下载。游戏工作目录和正常存档保持原状。

本次验证包括：现有发行包所有checksums一致；PCK与0.11.0既有验收哈希一致；976个包条目对应的源文件/导入缓存边界完整；ZIP内逐文件SHA-256一致；飞书发布后下载/恢复验证；Git远端提交及Release资源校验。具体完成证据以备份回执为准。
