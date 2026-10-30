# 无限异常 · 当前像素版 0.40.0

2026-10-31 当前可运行游戏备份，版本 `0.40.0-ground-shadows`。

当前内容包括七房间主神空间、轩轩四向36帧、五人战斗与装备成长、同图十波、2000房间进度规则、前20个已制作场景、前十关独立双封面、统一字体UI和人物/怪物脚底阴影。2000房间是系统目录与推进规则，正式可用美术仍为20房间。

## 直接运行

从本次 GitHub Release 或飞书项目的“20 Windows 游戏包与项目参考”下载 `InfiniteAnomaly-Pixel-Home-0.40.0-Windows.zip`，完整解压后运行 `InfiniteAnomaly.exe`，保留 PCK 和 GodotSharp 目录。

## 恢复工程

本分支及 Source ZIP 保存当前包的全部源码和资源、构建脚本、运行测试、脚底阴影前后对比。使用 Godot 4.7.1 打开 `project.godot`，或运行 `tools/build_ground_shadows.ps1 -Godot <Godot控制台程序路径>` 重建，再使用根目录启动游戏.cmd。Python 3 + Pillow 仅用于重新生成脚位配置，运行游戏不需要。

本分支从上次0.11备份提交继续保存历史，工作树收敛到当前包依赖。旧版文件仍在 Git 历史和旧备份分支，历史 Release 不覆盖。原工作目录和正常存档不修改。

## 同步位置

- GitHub：https://github.com/LloydCai-byte/Infinite-Anomaly
- 飞书项目：https://c4onokeos5.feishu.cn/wiki/SAMIwCrpWi5fX5k6UPnc4U0EnYe
- 飞书工程版本：https://c4onokeos5.feishu.cn/wiki/I008wZaMliIlX5kPSZZcFvojndb
- 飞书游戏包：https://c4onokeos5.feishu.cn/wiki/MqD6wfSQziTWg1kjoSNcJrDBnUe

## 验证与范围

0.40原交付的实际包466检查通过，303资源已核对。此次备份另校验所有文件、ZIP内容和恢复后的实际包。原交付不等于视觉已获用户认可。脚底对比见 `art/shadows-20261030/index.html`。

独立场景生产队列、未接入游戏的候选素材、私人文档快照/录音、凭据、缓存、个人玩家存档不属于本次公开工程快照。游戏素材与代码按现有项目授权归档；字体及Godot许可证随附。
