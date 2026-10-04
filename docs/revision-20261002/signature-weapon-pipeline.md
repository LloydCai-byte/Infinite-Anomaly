# 强力专属武器动作制作入口

文档原话是“超级强力专属武器可以用视频做完整序列帧动画”。本轮沿用现有完整形象工作流：角色＋战斗服＋配套武器一起生成动作视频，再导入序列帧。属性装备召唤精灵不改变该绑定。

五角色的正式套装图集固定入口为 `assets/earth/actors/{dadong,fenfen,gao,wang,qiqi}/t{1,2,3}/sprite_frames.tres`，运行时已优先加载正式图集，缺少时回退当前临时动作。`tools/import_earth_actions.py` 已有视频提帧、抠底、图集和 Godot 导入流程；既有动作队列与导入模板继续保留。

每套需覆盖 idle / move / attack / hit / fall，行走按实际位移驱动帧并校准步幅。强力专属攻击可增加 attack 动作长度/帧数；不能把只生成一个攻击视频写成全套动作已完成。先定造型，验一个角色一个套装，再批量制作。

2026-10-02后续更新：用户已暂定粉粉C长外套方向，细化依据是 `art/character-designs/fenfen-combat-suits-20261002-v01/references/fenfen-long-coat-user-provisional.png`。暂定造型不等于正式动作完成，也未确定套装档位。旧2400积分视频请求仍未获确认；本轮没有创建付费视频任务，专属武器正式视频/帧动画仍属后续美术制作。
