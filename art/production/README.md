# 正式场景素材

2026-09-26 美术参考更新：用户提供两卷全彩漫画并要求后续对齐其画风与色彩。新制作应先阅读 [美术基准：全彩漫画研究](../../docs/美术基准_全彩漫画研究.md)。本页保留已有素材的历史来源与提示词；原有“低饱和、网点”等描述须结合新基准调整，现有图片尚未因此替换。

这批图片已被 Godot 实际引用。生成采用**内置 image_gen 工具**，未使用外部 API 或 CLI 图像生成。所有交付 PNG 已复制到项目，不依赖生成缓存路径。

## 素材清单

| 游戏路径 | 内容 | 来源 |
| --- | --- | --- |
| `assets/home/entry.png` | 玄关正面，入户门与鞋柜 | 已确认的 `art/concepts/home-2026-09-25/01-玄关.png` |
| `assets/home/kitchen.png` | 狭长厨房，左侧卫生间入口 | 已确认的 02-厨房.png |
| `assets/home/bathroom.png` | 洗衣机、马桶、淋浴区 | 已确认的 03-卫生间.png |
| `assets/home/bedroom.png` | 床、灰窗帘与桌子 | 已确认的 04-卧室.png |
| `assets/home/desk.png` | 书桌与封闭阳台入口 | 已确认的 05-书桌与阳台.png |
| `assets/home/hall.png` | 过厅反向视角 | 新生成；原照片 10、11 对应门洞关系 |
| `assets/home/balcony.png` | 狭长封闭阳台内部 | 新生成；原照片 16、17、18 对应空间与外景 |
| `assets/memory/lobby.png` | 异常楼层门厅与电梯 | 新生成 |
| `assets/memory/elevator.png` | 异常电梯内部 | 新生成 |
| `assets/memory/corridor.png` | 电话与不正常的走廊 | 新生成 |
| `assets/memory/warden.png` | 住户登记处 | 新生成 |
| `assets/memory/ending.png` | 原玄关的门打开，通向普通清晨楼道 | 新生成；严格沿用玄关构图 |

尺寸均为 **1672 × 941**。游戏逻辑画布为 1920 × 1080，窗口默认 1600 × 900。手机、交互热点、状态字、门面上的记忆画面和阅读界面由 Godot 叠加，未烘焙在背景图里。

五张已确认图的原始提示词保留在 [概念图提示词](../concepts/home-2026-09-25/prompts.md)。新增图的可复用提示词规范如下；这是按最终约束整理的提示词集，不是工具调用日志的逐字导出。

## 全部画面的统一提示词

```text
Use case: stylized-concept / illustration-story.
Asset type: full-bleed background PNG for a first-person point-and-click game, 无限异常.
Create a restrained colored manga environment with precise fine black ink contours, believable architectural perspective, selective cel shadows, restrained flat color, subtle screen tone and controlled material detail.
Natural low-saturation off-white, warm wood, gray, subdued sage and teal. Readable quiet lighting. The home should feel clean, comfortable, ordinary and lived-in.
One coherent landscape viewpoint per image, approximately 16:9. No collage, cutaway floor plan, UI, menu labels, captions, watermark, logos, HUD, floating buttons or decorative typography.
For home interiors, use the user's photographs as the architecture reference. Preserve wall planes, door and window locations, room connections, real dimensions in proportion, main furniture placements and camera orientation. Tidy clutter without redesigning the apartment. Do not enlarge rooms or invent doors. Closed exterior windows, no reflected photographer, no visible personal documents.
Use the approved home illustrations as the medium and palette reference. Avoid photorealism, painterly brushwork, excessive mechanical detail, luxury renovation or abandoned/dirty interiors.
```

## 过厅 · hall.png

```text
Show the reverse-facing view of the same apartment entry/dining area, using the photograph where the bedroom doorway is on the left and the open kitchen entrance is on the right.
Preserve the broad off-white wall between the two openings, warm wood floor and dark wood bedroom door/frame. The bedroom is visible only through its existing left doorway, with gray curtains and the partial chair beyond. On the right, the real kitchen entrance reveals the tiled floor, left-wall water heater and sink/window at the rear.
Keep one modest brown chair neatly against the center wall. Remove cardboard boxes, bags, spare bedding, baskets and cleaning clutter. Keep the small apartment's actual proportions. Match the approved entry illustration's warm understated colored ink rendering. No additional room, furniture display or functional signs.
```

## 封闭阳台 · balcony.png

```text
View from inside the apartment's narrow enclosed balcony, preserving the actual geometry shown in photos 16 and 17. The desaturated dark teal exterior window frames and closed glazing run along the left; the right is the real light-colored apartment wall / sill. Preserve pale lower wall tiles and small square floor tiles, tight depth and ordinary residential proportions.
Use photo 18 only for the neighboring residential buildings outside, softly lit windows and night atmosphere. Remove hanging laundry, floor clutter and cleaning tools. No open terrace, expanded outdoor space, invented furniture or futuristic skyline. Same restrained colored manga rendering as the approved desk/balcony view.
```

## 不存在的一层 · lobby.png

```text
An ordinary Chinese residential building's elevator lobby seen at eye level, translated into the game's restrained colored manga style. Closed brushed metal elevator doors ahead, an unassuming dark display with a small red 13, stairwell at the side, wall-mounted letterboxes and a modest desk with an old black telephone. Gray tiled floor, off-white walls with muted gray-green lower paint, practical ceiling lighting.
The unease comes from familiar architecture being subtly wrong. Keep clear large shapes and believable perspective, no gore, fantasy dungeon, elaborate machinery, large signage or interface text. Use the same ink and material simplification as the clean apartment.
```

## 反向上升 · elevator.png

```text
A compact ordinary residential elevator cabin, inside-facing viewpoint, brushed dull metal wall panels, closed doors, a simple control panel and handrail. Slightly cold pale practical light. Controlled dark reflections without showing the player or camera.
Create quiet spatial unease through symmetry, light and one restrained floor indicator. Keep the scene readable and uncluttered. Precise black architectural ink, low-saturation cel color consistent with the lobby image. No monster, no weapons, no science-fiction controls or baked-in UI.
```

## 没有接线的电话 / 墙后的出口 · corridor.png

```text
A residential corridor belonging to the same impossible building: off-white upper walls, subdued gray-green lower walls, ordinary tiled floor, simple wood apartment doors and restrained ceiling lights. A black landline telephone is an important readable foreground object; a long passage continues toward a subtly impossible exit.
Make the physical arrangement coherent even though the destination feels wrong. Selective detail, quiet suspense and believable manga perspective. Preserve the established lobby/elevator palette. No blood, decorative occult symbols, lavish technology or game menus.
```

## 住户确认 / 把名字还给它 · warden.png

```text
An unsettlingly ordinary residential registration desk within the same building. A restrained shadowed attendant shape behind a modest counter, an open registration book and familiar office objects. Keep the attendant anonymous and avoid exaggerated horror anatomy.
The counter, ledger and surrounding doorway should be visually distinct at game resolution. Quiet overhead lighting, warm-gray surfaces, precise fine ink and limited cel shadows consistent with the lobby. No legible personal data, no large captions, no HUD and no elaborate machinery.
```

## 唯一结局 · ending.png

```text
Use the approved entry illustration as the exact composition reference. Preserve the cabinet positions, entry wall, wood floor, switches, door frame and camera. Change the front door from closed to open, revealing an ordinary residential landing filled with gentle early-morning light.
The emotional result is release and returning to normal life: comfortable, restrained and recognizably the same home. Do not create a magical portal, heavenly landscape, different apartment or dramatic science-fiction effect. Same colored manga line quality and material treatment. No text, people or UI baked into the image.
```

## 本次生成缓存来源记录

新增图最初由内置工具保存在 Codex 的 generated_images 目录，项目只使用上面的本地副本：

- hall：`exec-e9577ccc-e81c-4878-911e-77bf9b32b438.png`
- balcony：`exec-1dde830f-56d5-4023-81c1-d6bfe5d6a352.png`
- lobby：`exec-60b38319-dcea-477a-8d3f-6784646bf8c7.png`
- elevator：`exec-476d5a3f-d502-453b-8924-211f95c2e590.png`
- corridor：`exec-1a135147-8312-4bc6-9f0a-1aec2d85a63c.png`
- warden：`exec-442b520f-b5cf-4b71-9da1-7ebb7d97e457.png`
- ending：`exec-d5797b2a-c4ef-45ee-8418-04a104fea11a.png`

原始个人照片仅作本地生成参考，没有打包进游戏资源目录。游戏背景去除了散乱物品、可读个人屏幕内容、摄影者倒影与商品标识。
