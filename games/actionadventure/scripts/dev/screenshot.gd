extends SceneTree
## 本番表示を撮影する。部屋と戦闘の前提は撮影用に設定し、動作は実時間で再生する。

const Actor = preload("res://scripts/actor.gd")
var main: Node
var state: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("AdventureState")
	await _capture_scenes()
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	if not failed:
		print("screenshot OK")
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await _capture("title")
	main.start_new()
	await _capture("field-0")
	for room: int in range(1, 12):
		main.world.enter_room(room, Vector2(280, 384), false)
		await _capture("room-%02d" % room)
	main.world.enter_room(0, Vector2(380, 290), false)
	main.world.interact()
	await _capture("dialogue")
	main.close_dialogue()
	main.world.enter_room(1, Vector2(430, 290), false)
	main.world.interact()
	await _capture("shop")
	main.close_dialogue()
	state.open_chest("wind", "boomerang")
	state.open_chest("powder", "bombs")
	state.mode = "menu"
	await _capture("menu")
	main.close_menu()
	await _effects()
	await _animations()
	main.show_result(true)
	await _capture("ending")
	main.show_result(false)
	await _capture("gameover")
	main.retry_game()
	await _capture("retry")
	main.to_title()
	await _capture("return-title")


func _effects() -> void:
	main.world.enter_room(2, Vector2(760, 390), false)
	await create_timer(0.2).timeout
	main.world.facing = Vector2.RIGHT
	main.world.sword()
	await _capture("sword-hit", 0.06)
	main.world.effects.burst(Vector2(720, 320), Color("f4ce82"), 50)
	main.world.effects.popup(Vector2(720, 320), "小さな鍵 +1")
	await _capture("pickup-particles", 0.12)
	main.world.enter_room(7, Vector2(580, 384), false)
	state.tool = "boomerang"
	main.world.use_tool()
	await _capture("boomerang-out", 0.25)
	await _capture("boomerang-bridge", 0.18)
	main.world.enter_room(8, Vector2(885, 384), false)
	state.tool = "bomb"
	main.world.tool_time = 0
	main.world.use_tool()
	await _capture("bomb-fuse", 0.55)
	await _capture("bomb-explosion", 0.63)
	main.world.enter_room(9, Vector2(520, 384), false)
	await _capture("room-scroll", 0.12)


func _animations() -> void:
	main.world.enter_room(1, Vector2(-500, -500), false)
	main.world.set_physics_process(false)
	for enemy: Node in main.world.enemies:
		enemy.visible = false
	var gallery := Node2D.new()
	main.add_child(gallery)
	var characters: Array[Node2D] = []
	var names: Array[String] = [
		"hero", "wanderer", "charger", "ranger", "splitter", "boss", "villager", "merchant"
	]
	var labels: Array[String] = ["灯守", "苔甲虫", "突進猪", "花の射手", "水晶体", "石梟", "村人", "旅商人"]
	for i: int in range(names.size()):
		var actor: Node2D = Actor.new()
		actor.setup(names[i])
		actor.position = Vector2(240 + (i % 4) * 265, 275 + (i / 4) * 240)
		actor.scale = Vector2.ONE * 1.65
		gallery.add_child(actor)
		characters.append(actor)
		var label := Label.new()
		label.text = labels[i]
		label.position = actor.position + Vector2(-65, 75)
		label.add_theme_font_override("font", load("res://assets/fonts/font.ttf"))
		label.add_theme_font_size_override("font_size", 22)
		gallery.add_child(label)
	for motion: String in Actor.MOTIONS:
		main.notice = "動作の記録 / " + motion
		for actor: Node2D in characters:
			actor.sprite.play(motion)
			actor.sprite.set_frame_and_progress(0, 0)
		await _capture("actors-%s-start" % motion, 0.01)
		await _capture("actors-%s-mid" % motion, 0.16)
		await _capture("actors-%s-end" % motion, 0.17)
	gallery.queue_free()
	main.world.set_physics_process(true)


func _capture(name: String, delay: float = 0.42) -> void:
	await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		failed = true
		push_error("撮影失敗: " + name)
	print("撮影: " + name)
