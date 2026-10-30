extends RefCounted
const ART="res://art/turnbased-20261014/"
const HEROES=["粉粉","高哥","七七","大东老师","老王"]
const ROLES=["近战 · 连斩","近战 · 破甲","远程 · 扫射","支援 · 机器人","远程 · 法阵"]
const THEMES=["百鬼夜行","深海旧港","赤砂王陵"]
const IDS=["hyakki","abyss","tomb"]
const SCENES=[["面具商店街","无人钱汤","祭典空巷","千灯神社","鬼王门庭"],["潮湿码头","盐雾鱼市","沉船船坞","深渊灯塔","潮神祭场"],["沙门驿站","石像长廊","封印墓室","星砂观象台","赤金王座"]]
const ENEMIES=[["赤鬼","河童","独眼唐伞"],["珊瑚蟹","潜水亡骸","潮汐祭司"],["墓卫木乃伊","豺首守卫","金甲圣甲虫"]]
const HERO_POS=[Vector2(520,690),Vector2(565,790),Vector2(245,785),Vector2(150,610),Vector2(345,595)]
const ENEMY_POS=[Vector2(1080,660),Vector2(1390,625),Vector2(1355,790),Vector2(1040,790),Vector2(1500,740)]
const HEIGHTS=[275.0,282.0,248.0,258.0,270.0]
const LORE=["灯下的店主都没有影子。鬼王收藏的面具，记着每个来客的名字。","港口的钟停在退潮前一秒。潜水服里传来的呼吸声，和我们一样。","王陵壁画画着五个陌生旅人。他们的衣服，正是我们今天穿的这一套。"]
static func background(theme:int,scene:int)->String:return ART+"backgrounds/%s-%02d.png"%[IDS[theme],scene+1]
