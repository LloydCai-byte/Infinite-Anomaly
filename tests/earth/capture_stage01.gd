extends SceneTree
const Main=preload("res://scripts/earth/main.gd")
const OUT="res://art/earth-production/stage01-cel-motion-test-20261002/previews/"
var game: Control
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	game.battlefield.queue_redraw()
	game.refresh_battle()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	root.size=Vector2i(1920,1080)
	game=Main.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.stage01_preview=true
	game.transient=true
	game.start_stage01_preview()
	await shot("game-opening")
	for i in range(180): game.model.tick(1.0/60)
	await shot("game-combat")
	for i in range(5):
		game.preview_street_segment(i)
		await shot("game-street-%d"%(i+1))
	quit()
