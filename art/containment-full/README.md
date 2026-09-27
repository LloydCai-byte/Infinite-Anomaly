# 完整功能版素材记录

日期：2026-09-27。使用 imagegen 技能的内置 `image_gen.imagegen`，每项单独调用。未使用 CLI、外部图库或 Python 改图。所有生成源文件保留于 Codex generated_images，选用图复制到项目 `assets/containment/`；用户人物参考原照未打包。

## 角色与猫眼

- `assets/containment/heroine.png`：透明完整站姿，眼镜、黑发、灰色外衫、白内搭、深色裤子，保持原阅读女主的自然普通外形。用于房间内移动与交流，轻微呼吸缩放。生成要求摘要如上，源文件 `exec-59eaaed0-719d-4782-abb8-8e67ad9f6aef.png`。
- `assets/containment/peephole-back.png`：女主背对玩家、面向门上猫眼，不展示正脸或侧面表情；与轮次漫画并排。生成要求摘要如上，源文件 `exec-5328f3dd-50e9-453c-8f04-261ea65917dd.png`。
- 阅读与喝茶保留 `assets/continuity/companion/reading.png`、`tea.png`。空卧室单独生成去人版本，保持收音机、计时器等物品的位置。

## 房间编辑提示词

### desk

输出：`assets/containment/rooms/desk.png`。参考：`D:/无限异常/assets/home/desk.png`。

```text
Edit this game room image into a straight-on eye-level wide shot facing the wooden computer desk. Keep the real small apartment layout: desk and monitor to left, balcony opening and dark green-framed window to right, cream walls, wood floor, light curtain. Camera is square to the desk wall, not a tilted corner snapshot. Entire useful desk surface visible with keyboard, monitor, a small plain notebook and a brass compact clip on the right side as game props. No text, no people. Simplified full-color manga matching prior heroine reference style: clear ink outlines, flat colors, minimal shading and wood grain. One complete 16:9 scene.
```

### kitchen_table

输出：`assets/containment/rooms/kitchen_table.png`。参考：`D:/无限异常/assets/home/kitchen.png`。

```text
Create the second viewpoint within THIS same small kitchen for a game: eye-level straight-on to the right-hand cooking countertop and brown cabinets, with the sink and same white-framed window just visible toward the left side. Preserve small real apartment proportions, cream tiles, compact black stove, brown wood cabinetry. No doorway framing, no invented island, no expansion to a luxury kitchen. Two simple dishes of home cooking on countertop. Empty floor space in front. No people, no text. Simplified full color manga, bold clean outlines, large flat colors, very few shadows, no detailed woodgrain. Single complete wide 16:9 scene.
```

### bathroom_laundry

输出：`assets/containment/rooms/bathroom_laundry.png`。参考：`D:/无限异常/assets/home/bathroom.png`。

```text
Edit this image into a second viewpoint inside the same tiny real apartment bathroom. Camera straight-on facing the washing machine on left and shower rail/window on right, no doorway foreground. Keep original cream tile, black top-loading washer, white toilet, pale blue shower curtain, shower. A small folded towel lies on the washer. Single wide 16:9 game scene. Simplified full-color manga: clean ink lines, flat warm colors, very little shading, no tile texture. No people, text, interface.
```

### balcony_sky

输出：`assets/containment/rooms/balcony_sky.png`。参考：`D:/无限异常/assets/home/balcony.png`。

```text
Edit into a second camera point of THIS same enclosed narrow apartment balcony, facing the green-framed exterior windows square on. Wide straight-on eye-level view, four simple window panes across the picture, quiet night city outside with a few stars. Preserve cream lower wall and beige tiled floor and real tiny apartment proportions. No furniture or invented rooms. Single complete 16:9 game scene, simplified full-color manga with clean ink outlines and flat color, minimal shading, no fine texture, no people, text or UI.
```

### hall_table

输出：`assets/containment/rooms/hall_table.png`。参考：`D:/无限异常/assets/home/hall.png`。

```text
Edit into a second camera angle within THIS real apartment passage, straight-on to the cream wall with the single brown chair on the LEFT HALF, a small plain wooden side table with a compact radio beside the chair. Keep bedroom doorway at far left, kitchen doorway at far right, real wood floor. Room should remain small uncluttered. Right half is empty foreground standing space for a game character, below a plain cream wall. Single complete wide 16:9 game scene. Simplified full-color manga, clean ink line, flat colors, minimal shadows and no fine textures. No people or text.
```

### bedroom

输出：`assets/containment/rooms/bedroom.png`。参考：`assets/continuity/companion/reading.png`。

```text
Edit only the woman out of this game bedroom image. Leave her chair empty, with the same plain wood backrest and black seat. Preserve absolutely the same camera, room layout, table surface, radio, small gray digital timer, mug, book, lamp, bed, bedding, curtains and wall picture in exactly their current positions. This is the unoccupied state of the same game location. No people, no extra objects, no text. Keep this simplified full-color manga style and wide aspect ratio.
```

## 集成与检查

房间轮换、人物热点、桌上书本／收容夹、收音机／番茄钟均在 Godot 场景内实际交互；截图验收位于 `.local/full-captures/`。简化彩色漫画与部分旧住宅背景的细节量仍略有差异。本次不新增三十套剧情美术。

