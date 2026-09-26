extends Control
signal closed
signal phone_requested
const UI = preload("res://scripts/home/ui.gd")
var paper: Panel
var caption: Label
var detail: Label
var timer: Label
var progress_line: ColorRect
var artwork: TextureRect
var selected_index: int = -1
var rendered_id: int = -99
var art_frame: Control

func _ready() -> void:
	size = Vector2(1920,1080)
	theme = UI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.line(self,Rect2(0,0,1920,1080),Color(0.025,0.019,0.016,0.83))
	paper = UI.panel(self,Rect2(174,44,1572,988),Color("#171b19"),3,Color("#776a54"))
	Home.event.connect(func(kind): if kind in ["settled","auto","focus","stage","departed"]: call_deferred("render"))
	render()

func render() -> void:
	if not is_instance_valid(paper):
		return
	for child in paper.get_children():
		paper.remove_child(child)
		child.queue_free()
	var m = Home.model
	var live: bool = m.s.mode == "MEMORY" and selected_index < 0
	var chapter_index: int = int(m.s.snapshot.stage) if live else int(m.s.stage)
	if not live and not m.s.result.is_empty():
		chapter_index = int(m.s.result.stage)
	if selected_index >= 0 and not live:
		chapter_index = selected_index
	var chapter: Dictionary = m.db.stages[chapter_index]
	rendered_id = chapter_index
	UI.text(paper,"门  /  留在这里的记忆",Rect2(30,13,840,38),20,UI.MUTED)
	UI.button(paper,"×",Rect2(1495,11,48,41),func():closed.emit())
	UI.text(paper,"%02d  %s" % [chapter_index+1,chapter.name],Rect2(30,57,1100,48),32)
	timer = UI.text(paper,"",Rect2(1226,66,310,34),20,UI.ACCENT)
	art_frame = Control.new()
	UI.place(art_frame,paper,Rect2(30,123,1128,635))
	art_frame.clip_contents = true
	artwork = UI.image(art_frame,"res://assets/memory/"+chapter.image+".png",Rect2(0,0,1128,635))
	# Two narrow insets read like comic close-ups, with their own crop of the same memory.
	var inset1 = UI.image(paper,"res://assets/memory/"+chapter.image+".png",Rect2(1172,123,370,309))
	var inset2 = UI.image(paper,"res://assets/memory/"+chapter.image+".png",Rect2(1172,448,370,310))
	var source: Texture2D = artwork.texture
	var left_crop = AtlasTexture.new()
	left_crop.atlas = source
	left_crop.region = Rect2(Vector2(source.get_width()*0.02,source.get_height()*0.38),Vector2(source.get_width()*0.32,source.get_height()*0.48))
	inset1.texture = left_crop
	var right_crop = AtlasTexture.new()
	right_crop.atlas = source
	right_crop.region = Rect2(Vector2(source.get_width()*0.52,source.get_height()*0.15),Vector2(source.get_width()*0.33,source.get_height()*0.64))
	inset2.texture = right_crop
	inset1.flip_h = false
	inset2.modulate = Color("#b7b9b0")
	UI.line(paper,Rect2(30,772,1512,2),Color("#49574b"))
	progress_line = UI.line(paper,Rect2(30,772,0,2),UI.ACCENT)
	caption = UI.text(paper,"",Rect2(30,797,1005,66),27,UI.INK,true)
	detail = UI.text(paper,"",Rect2(30,872,1005,63),20,UI.MUTED,true)
	var action_text: String = "接收上一段记忆…" if m.s.mode == "MEMORY" else "出门"
	if m.s.mode != "MEMORY" and not m.s.first_departure:
		action_text = "再次出门  →  "+m.db.stages[m.s.stage].name
	if selected_index >= 0 and m.s.mode != "MEMORY":
		action_text = "重访这段经历"
	var depart = UI.button(paper,action_text,Rect2(1063,800,479,54),depart_from_view,true)
	depart.name = "Depart"
	depart.disabled = m.s.mode == "MEMORY" or not m.can_act()
	var auto = UI.button(paper,"连续出门  "+("● 开" if m.s.auto else "○ 关"),Rect2(1063,868,267,45),func():Home.action("auto"))
	auto.name = "AutoDepart"
	UI.button(paper,"打开手机",Rect2(1341,868,201,45),func():phone_requested.emit())
	UI.text(paper,"达到任一路径即可推进",Rect2(30,944,282,26),17,UI.MUTED)
	var thresholds: Dictionary = m.db.stages[selected_index if selected_index >= 0 else m.s.stage].thresholds
	var idx: int = 0
	for b in m.db.branches:
		var stats: Dictionary = m.stats()
		var btn = UI.button(paper,"%s %d / %d" % [m.db.branches[b].name,stats[b],thresholds[b]],Rect2(320+idx*180,933,163,40),func():Home.action("focus",b))
		btn.add_theme_font_size_override("font_size",18)
		if m.s.focus == b:
			btn.add_theme_stylebox_override("normal",UI.box(Color("#35483c"),UI.ACCENT,6))
		btn.tooltip_text = "已达标" if stats[b] >= thresholds[b] else "需要在手机里提升"+m.db.branches[b].name
		idx += 1
	UI.text(paper,"Esc  收起回忆",Rect2(1290,941,252,30),17,UI.MUTED)
	update_live()

func _process(_delta: float) -> void:
	if is_instance_valid(caption):
		update_live()

func depart_from_view() -> void:
	if selected_index >= 0 and not Home.action("stage",str(selected_index)):
		return
	Home.action("depart")

func update_live() -> void:
	var m = Home.model
	var chapter: Dictionary = m.db.stages[maxi(0,rendered_id)]
	if selected_index >= 0:
		progress_line.size.x = 1512
		timer.text = "已归档  /  " + chapter.memory
		caption.text = chapter.caption
		detail.text = chapter.lore
		for past in m.s.history:
			if int(past.stage) == selected_index:
				caption.text = past.text
				detail.text = chapter.lore + "  ·  " + (m.db.branches[past.route].verb if past.success else "未能通过")
				break
		return
	if m.s.mode == "MEMORY":
		var p: float = m.progress()
		progress_line.size.x = 1512*p
		timer.text = "记忆接收  %02d:%02d" % [int(ceil(m.s.remaining))/60,int(ceil(m.s.remaining))%60]
		caption.text = chapter.caption if p < 0.48 else chapter.detail
		detail.text = "出门的人已经留在了那里。你正在接收他最后的记忆。"
		if not m.s.reduced_motion:
			artwork.scale = Vector2.ONE * (1.0+0.025*p)
			artwork.position = Vector2(-12*p,-6*p)
	else:
		progress_line.size.x = 1512 if not m.s.result.is_empty() else 0
		timer.text = "下一次出门  %d 秒" % int(ceil(m.s.auto_wait)) if m.s.auto else "门后的事，还没有结束。"
		if not m.s.result.is_empty():
			var r: Dictionary = m.s.result
			caption.text = r.text
			detail.text = ("这一段已突破。" if r.success else "你没能走得更远，但这一次没有白来。")+"  记忆 +1  ·  经验 +%d\n重复经历可以在手机里吸收；下一次，你会记得更多。" % r.xp
		else:
			caption.text = chapter.caption
			detail.text = "跨过门槛以后，你会回到这里。\n但回来的，真的是刚才出门的那个你吗？"
