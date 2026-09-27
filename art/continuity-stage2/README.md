# 阶段 2 美术与音频

2026-09-27 使用内置 `image_gen` 生成并接入游戏。最终图片与完整提示词都已保存在工作区。

| 素材 | 用途 |
| --- | --- |
| `assets/continuity/companion/reading.png` | 原住宅卧室，女主阅读；桌上收音机和番茄钟 |
| `assets/continuity/companion/tea.png` | 同一房间、同一角色的喝茶姿态 |
| `assets/continuity/companion/peephole.png` | 猫眼画面右侧，女主靠近门观察 |
| `assets/continuity/companion/entry.png` | 保留玄关布局，在原桌上加入收货箱 |

提示词与所用参考见 [prompts.json](prompts.json)。`reading-detailed-draft.png` 是未用于游戏的初稿；因衣物纹理与发丝太细，另生成更简练的版本作为最终图。

女主外形参考用户本轮提供的照片；保留圆框眼镜、黑发、松散束发和自然神态，不使用照片界面、文字、手机或自拍动作。照片原件不打入游戏包。卧室基于已有住宅图，玄关在已使用画面上编辑，门窗和房间开口关系保持。

新增四张系统素材，不计入“三个故事各五张图”的故事图数量。当前日常表现为两种姿态切换，尚无骨骼动画或连续行走动画。挂机的左侧仍复用第一故事的五图固定序列，没有宣称已生成随机变体。

新增音频 `assets/continuity/audio/quiet-room.wav` 为原创 48 秒电钢琴慢拍循环，`bell.wav` 为计时完成提示音；由 `tools/generate_stage2_music.py` 确定性合成，不采样第三方歌曲。两种声音与既有环境声分别控制。
