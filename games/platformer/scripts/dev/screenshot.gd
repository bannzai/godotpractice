extends SceneTree
## 実際の描画で代表画面を撮影する (headless では描画されないため、Makefile の screenshot target が
## --headless なしで起動する)。撮影した PNG は tmp/screenshot-<名前>.png に保存し、失敗したら quit(1) で終わる。
## ゲーム固有の状態作り (画面遷移・スコアの投入・操作の再現等) は _capture_scenes() に足す。
## autoload は --script 起動でも root から取得できる。


func _initialize() -> void:
	# BGM の autoload やゲーム側の SE が撮影中に鳴らないよう Master バスをミュートする
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 時間経過と物理で画面を進めるため、同じ実行中に重ねて呼び出さない。
func _run() -> void:
	if await _capture_scenes():
		quit(0)


## 撮影する画面の並び。雛形はメインシーン (タイトル) だけを撮る。失敗した撮影は _capture() が
## quit(1) 済みなので、false を受けたらそのまま抜ける。
func _capture_scenes() -> bool:
	var main: DeliveryGame = load("res://scenes/main.tscn").instantiate()
	var session: Node = root.get_node("Session")
	root.add_child(main)
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-title.png"):
		return false
	if not await _capture_play(main, session):
		return false
	if not await _capture_effects(main, session):
		return false
	if not await _capture_results(main, session):
		return false
	main._show_title()
	var captured: bool = await _capture_gallery_and_window(main)
	if not captured:
		return false
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	return true


func _capture_play(main: DeliveryGame, session: Node) -> bool:
	main.start_run()
	await create_timer(0.40).timeout
	main.route.player.position.x = 510
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-meadow.png"):
		return false
	main.route.blocks[0].activate()
	session.collect_power()
	main.route.player.transform()
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-transform.png"):
		return false
	main.route.enemies[0].position = main.route.player.position + Vector2(90, 0)
	main.route.enemies[0].defeat()
	await create_timer(0.15).timeout
	if not await _capture("tmp/screenshot-stomp.png"):
		return false
	session.phase = "paused"
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-pause.png"):
		return false
	main._resume()
	return true


func _capture_results(main: DeliveryGame, session: Node) -> bool:
	session.finish_stage()
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-stage-clear.png"):
		return false
	main._continue()
	await create_timer(0.40).timeout
	main.route.player.position = Vector2(2460, 528)
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-cave.png"):
		return false
	main.route.player.position = Vector2(main.route.goal_x, 624)
	await create_timer(0.45).timeout
	if not await _capture("tmp/screenshot-complete.png"):
		return false
	main.start_run()
	for attempt: int in 3:
		session.damage(true, "穴に落ちた")
		await create_timer(0.45).timeout
		if session.phase == "dead":
			main._continue()
	if not await _capture("tmp/screenshot-game-over.png"):
		return false
	return true


func _capture_window_modes() -> bool:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_F11
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.5).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		push_error("F11 で全画面に切り替わらない")
		quit(1)
		return false
	if not await _capture("tmp/screenshot-fullscreen.png"):
		return false
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.5).timeout
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		push_error("F11 でウィンドウに戻らない")
		quit(1)
		return false
	event.pressed = false
	Input.parse_input_event(event)
	DisplayServer.window_set_size(Vector2i(960, 540))
	await create_timer(0.3).timeout
	return await _capture("tmp/screenshot-resized.png")


func _capture(path: String) -> bool:
	await process_frame
	await process_frame
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true


func _capture_animation_sheet(main: DeliveryGame, kind: String) -> bool:
	var gallery: Control = Control.new()
	main.ui.add_child(gallery)
	var paper: ColorRect = ColorRect.new()
	paper.color = Color("fff8e8")
	paper.size = Vector2(1280, 720)
	gallery.add_child(paper)
	var names: Dictionary[String, String] = {
		"player": "配達人", "walker": "芽の歩行敵", "shell": "結晶の殻の敵"}
	main._label(gallery, names[kind] + "  /  動作の連続フレーム",
		Rect2(38, 18, 900, 42), 28)
	var frames: SpriteFrames = ActorFrames.build(kind)
	var states: Array[String] = (
		ActorFrames.PLAYER_STATES if kind == "player" else ActorFrames.ENEMY_STATES)
	var labels: Dictionary[String, String] = {"idle": "待機", "run": "走る", "jump": "跳躍",
		"fall": "落下", "stomp": "踏みつけ", "hurt": "被弾", "death": "退場",
		"walk": "歩く", "attack": "攻撃"}
	for column: int in 3:
		main._label(gallery, ["開始  /  1枚目", "途中  /  3枚目", "終端  /  6枚目"][column],
			Rect2(300 + column * 320, 65, 260, 28), 17)
	var spacing: float = 85.0 if kind == "player" else 115.0
	for row: int in states.size():
		var y: float = 108 + row * spacing
		main._label(gallery, labels[states[row]], Rect2(48, y + 18, 180, 35), 21)
		for column: int in 3:
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = frames.get_frame_texture(states[row], [0, 2, 5][column])
			sprite.position = Vector2(390 + column * 320, y + 34)
			sprite.scale = Vector2.ONE * (1.0 if kind == "player" else 1.6)
			gallery.add_child(sprite)
	var captured: bool = await _capture("tmp/screenshot-animation-%s.png" % kind)
	gallery.queue_free()
	await process_frame
	return captured


func _capture_effects(main: DeliveryGame, session: Node) -> bool:
	for kind: String in ["coin", "block", "land", "power", "stomp", "hurt", "death", "clear"]:
		main.start_run()
		await create_timer(0.45).timeout
		main.route.player.position.x = 510
		if kind == "hurt":
			session.collect_power()
			session.invulnerable = 0
		await create_timer(0.1).timeout
		match kind:
			"coin":
				session.collect_coin()
				main.route.impact("coin", main.route.player.position + Vector2(0, -45), "+100")
			"block":
				main.route.blocks[0].activate()
			"land":
				main.route.effects.burst("land", main.route.player.position)
			"power":
				session.collect_power()
				main.route.player.transform()
				main.route.impact("power", main.route.player.position + Vector2(0, -35), "+500")
			"stomp":
				main.route.enemies[0].position = main.route.player.position + Vector2(75, 0)
				main.route.enemies[0].defeat()
				main.route.player.bounce()
				main.route.impact("stomp", main.route.enemies[0].position, "+200")
			"hurt":
				session.damage()
				main.route.player.hurt()
				main.route.impact("hurt", main.route.player.position + Vector2(0, -25), "-1")
			"death":
				session.damage(true, "撮影用の被弾")
			"clear":
				main.route.player.position.x = main.route.goal_x
		for sample: int in 3:
			await create_timer([0.02, 0.14, 0.55][sample]).timeout
			if not await _capture("tmp/screenshot-effect-%s-%d.png" % [kind, sample]):
				return false
	return true


func _capture_gallery_and_window(main: DeliveryGame) -> bool:
	for kind: String in ["player", "walker", "shell"]:
		if not await _capture_animation_sheet(main, kind):
			return false
	if not await _capture_objects(main):
		return false
	return await _capture_window_modes()


func _capture_objects(main: DeliveryGame) -> bool:
	var gallery: Control = Control.new()
	main.ui.add_child(gallery)
	var paper: ColorRect = ColorRect.new()
	paper.size = Vector2(1280, 720)
	paper.color = Color("fff8e8")
	gallery.add_child(paper)
	main._label(gallery, "郵便路の道具と地形  /  オブジェクト別の素材",
		Rect2(40, 26, 1160, 50), 28)
	var files: Array[String] = ["coin", "power", "item_block", "item_block_used", "goal",
		"ground", "ground_fill", "underground", "underground_fill", "particle",
		"ui_score", "ui_coin", "ui_life", "ui_time", "title_logo"]
	var labels: Array[String] = ["ひかり", "加護", "補給ケース", "開封後", "ポスト",
		"草原の足場", "草原の地中", "洞窟の足場", "洞窟の岩", "光の粒",
		"スコア", "収集数", "残機", "時計", "郵便局のロゴ"]
	for index: int in files.size():
		var at: Vector2 = Vector2(50 + (index % 5) * 246, 125 + floori(index / 5.0) * 187)
		var texture: Texture2D = load("res://assets/images/%s.svg" % files[index])
		var size: Vector2 = texture.get_size()
		size *= minf(146.0 / size.x, 105.0 / size.y)
		main._picture(gallery, files[index], Rect2(at + Vector2((190 - size.x) / 2, 0), size))
		main._label(gallery, labels[index], Rect2(at.x, at.y + 116, 205, 36), 18,
			DeliveryGame.INK, HORIZONTAL_ALIGNMENT_CENTER)
	var captured: bool = await _capture("tmp/screenshot-objects.png")
	gallery.queue_free()
	await process_frame
	return captured
