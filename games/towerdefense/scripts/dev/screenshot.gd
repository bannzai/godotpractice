extends SceneTree
## 画面と全キャラの動作を同じ描画条件で記録する。撮影は時間を進めるため非冪等。

const Catalog := preload("res://scripts/catalog.gd")
const Actor := preload("res://scripts/actor.gd")
const Ui := preload("res://scripts/ui.gd")

var main: Control
var run: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	run = root.get_node("Run")
	run.save_path = "res://tmp/screenshot-save.json"
	root.add_child(main)
	await _capture_scenes()
	await root.get_node("Sound").shutdown()
	print("screenshot OK" if not failed else "撮影失敗")
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await create_timer(0.6).timeout
	await _capture("title")
	await _key(KEY_ENTER)
	await create_timer(0.4).timeout
	await _capture("preparation")
	main._pause()
	await _capture("pause")
	main._pause()
	main.set_process(false)
	_invest()
	run.start_wave()
	for tick: int in range(190):
		run.step(1.0 / 60.0)
	main._reset_board()
	main.board._sync_actors()
	main._update_hud(1.0)
	await _capture("play")
	for type: String in ["build", "upgrade", "base", "death"]:
		var event: Dictionary = {"type": type, "kind": "mortar",
			"position": Vector2(360, 360), "from": Catalog.SITES[0],
			"to": Vector2(310, 285), "target": -1, "splash": 66, "reward": 17}
		main.board.event(event)
		await create_timer(0.12).timeout
		await _capture("effect-" + type)
	for kind: String in Catalog.TOWERS:
		main.board.event({"type": "shot", "kind": kind, "from": Catalog.SITES[0],
			"to": Vector2(265, 310), "position": Vector2(265, 310), "target": -1,
			"splash": Catalog.TOWERS[kind].splash})
		await create_timer(0.08).timeout
		await _capture("effect-shot-" + kind)
		await create_timer(0.5).timeout
	if not main.board.enemy_nodes.is_empty():
		main.board.enemy_nodes.values()[0].act("hurt")
		await _capture("effect-hurt")
	await _battle_to_results()
	await _gallery()


func _invest() -> void:
	for entry: Array in [[0, "arrow"], [2, "sun"], [4, "frost"], [3, "mortar"],
		[7, "sun"], [1, "arrow"]]:
		run.build(entry[0], entry[1])
	for level: int in [1, 2]:
		for tower: Dictionary in run.towers:
			if tower.level == level:
				run.upgrade(tower.site)


func _battle_to_results() -> void:
	var boss_captured: bool = false
	for tick: int in range(60000):
		if run.phase != "play":
			break
		if not run.active:
			_invest()
			run.start_wave()
		run.step(1.0 / 60.0)
		if not boss_captured and run.wave == 10:
			for enemy: Dictionary in run.enemies:
				if enemy.kind == "boss" and enemy.distance > 170:
					main._reset_board()
					main.board._sync_actors()
					main._notify("警戒！ 朽木の巨獣が森を進む", 5)
					main._update_hud(0.1)
					await _capture("boss")
					boss_captured = true
		run.events.clear()
		if tick % 120 == 0:
			await process_frame
	if run.phase != "win" or not boss_captured:
		failed = true
		push_error("通常資金の防衛でボス戦と勝利へ到達できない")
	main._reset_board()
	main._show_phase()
	await create_timer(0.5).timeout
	main.result_value = run.hp
	main.result_count.text = "守り抜いた灯  %02d / %02d" % [run.hp, Catalog.MAX_HP]
	await _capture("win")
	# 敗北はHPを操作せず、無防備の通常ルールで再現する。
	run.new_run()
	main._reset_board()
	for tick: int in range(18000):
		if run.phase != "play":
			break
		if not run.active:
			run.start_wave()
		run.step(1.0 / 60.0)
		run.events.clear()
	main._show_phase()
	await create_timer(0.5).timeout
	await _capture("lose")


func _gallery() -> void:
	main.screen.hide()
	main.board.hide()
	var gallery := Control.new()
	gallery.theme = main.theme
	root.add_child(gallery)
	var bg := ColorRect.new()
	bg.color = Color("183b41")
	bg.size = Vector2(1280, 720)
	gallery.add_child(bg)
	var heading: Label = Ui.label(gallery, "", Vector2(35, 20), 27, Ui.GOLD)
	var actors: Array[Node2D] = []
	var keys: Array = Catalog.TOWERS.keys() + Catalog.ENEMIES.keys()
	for index: int in range(keys.size()):
		var point := Vector2(30 + (index % 3) * 416, 83 + (index / 3) * 207)
		Ui.panel(gallery, Rect2(point, Vector2(389, 190)))
		var kind: String = keys[index]
		var data: Dictionary = Catalog.TOWERS.get(kind, Catalog.ENEMIES.get(kind, {}))
		Ui.label(gallery, data.name, point + Vector2(18, 15), 23, Ui.GOLD)
		Ui.label(gallery, data.get("role", "敵の動作"), point + Vector2(18, 53), 17, Ui.MUTED)
		var actor: Node2D = Actor.new()
		actor.position = point + Vector2(290, 107)
		gallery.add_child(actor)
		actor.setup(kind, false)
		actor.sprite.scale = Vector2.ONE * 1.1
		actors.append(actor)
	var names: Array[String] = ["待機", "移動・建設", "攻撃・突破", "被弾", "消滅"]
	for row: int in range(Actor.MOTIONS.size()):
		for frame: int in [0, 3, 5]:
			heading.text = "全9種類の動作  ·  %s  ·  %s" % [names[row],
				"開始" if frame == 0 else ("途中" if frame == 3 else "終了")]
			for actor: Node2D in actors:
				actor.pose(Actor.MOTIONS[row], frame)
			await _capture("actors-%s-%d" % [Actor.MOTIONS[row], frame])
	gallery.queue_free()
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	if root.get_texture().get_image().save_png(path) != OK:
		failed = true
		push_error("撮影保存失敗: " + path)
	print("screenshot: " + path)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
