extends SceneTree
## 実入力でゲーム全体を通す。採掘用の移動だけを既存の木の前へ短縮する。

var failed: bool = false
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await frames(20)
	_check(main.model.phase == "title", "タイトルで起動")
	await click_text("折り方手順書")
	_check(main.hud.overlay.visible, "タイトルから遊び方を開く")
	await click_text("戻る")
	_check(not main.hud.overlay.visible, "遊び方を閉じてタイトルへ戻る")
	pad(JOY_BUTTON_A, true)
	await frames(2)
	pad(JOY_BUTTON_A, false)
	await frames(12)
	_check(main.model.phase == "play", "遊び方から戻った後もパッド決定でゲーム開始")
	_check(main.hud.tutorial_step == 0 and main.hud.tutorial.visible,
		"新しい島では場面内の折り方手順書を表示")
	key(KEY_H, true)
	await frames(2)
	key(KEY_H, false)
	await frames(3)
	_check(main.hud.tutorial_step == -1 and not main.hud.tutorial.visible,
		"Hで初回手順書をスキップ")
	key(KEY_M, true)
	await frames(2)
	key(KEY_M, false)
	await frames(5)
	_check(main.paused and main.hud.overlay.visible, "Mで机上の島模型を開く")
	key(KEY_M, true)
	await frames(2)
	key(KEY_M, false)
	await frames(4)
	_check(not main.paused and not main.hud.overlay.visible, "Mでも島模型を閉じる")
	await _movement()
	prepare_tree(main)
	await frames(12)
	_check(not main.target_block.is_empty(), "視点入力で木を狙う")
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(84)
	mouse(MOUSE_BUTTON_LEFT, false)
	await frames(8)
	_check(int(main.model.inventory.get("wood", 0)) >= 1, "実マウス長押しで木材を取得")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(6)
	_check(main.paused and main.hud.overlay.visible, "Eでクラフト画面")
	await click_text("木の板")
	_check(int(main.model.inventory.get("plank", 0)) == 4, "レシピクリックで板を作る")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(4)
	await _pause_and_results()
	if DisplayServer.get_name() != "headless":
		await _fullscreen()
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	if not failed:
		print("integration OK")
	quit(1 if failed else 0)


func _movement() -> void:
	var start: Vector3 = main.player.position
	key(KEY_D, true)
	await frames(14)
	key(KEY_D, false)
	await frames(2)
	_check(main.player.position.distance_to(start) > 0.3, "キーボード移動")
	start = main.player.position
	axis(JOY_AXIS_LEFT_X, -1.0)
	await frames(14)
	axis(JOY_AXIS_LEFT_X, 0)
	await frames(2)
	_check(main.player.position.distance_to(start) > 0.3, "パッド移動")
	var height: float = main.player.position.y
	pad(JOY_BUTTON_A, true)
	await frames(6)
	pad(JOY_BUTTON_A, false)
	_check(main.player.position.y > height + 0.2, "パッドジャンプ")
	await frames(50)
	var yaw: float = main.player.rotation.y
	axis(JOY_AXIS_RIGHT_X, 0.8)
	await frames(10)
	axis(JOY_AXIS_RIGHT_X, 0)
	_check(absf(main.player.rotation.y - yaw) > 0.05, "右スティックで視点変更")


func _pause_and_results() -> void:
	pad(JOY_BUTTON_START, true)
	await frames(2)
	pad(JOY_BUTTON_START, false)
	await frames(3)
	_check(main.paused, "Startで休止")
	var time: float = main.model.day_time
	var hunger: float = main.model.hunger
	var position: Vector3 = main.player.position
	key(KEY_W, true)
	await frames(30)
	key(KEY_W, false)
	_check(main.model.day_time == time and main.model.hunger == hunger,
		"休止中は時間と空腹を固定")
	_check(main.player.position == position, "休止中はプレイヤーが移動しない")
	await click_text("遠征を終える")
	await frames(8)
	_check(main.model.phase == "failed", "休止メニューから失敗結果へ")
	pad(JOY_BUTTON_A, true)
	await frames(2)
	pad(JOY_BUTTON_A, false)
	await frames(8)
	_check(main.model.phase == "play" and main.model.inventory.is_empty(), "パッドで持ち物を失って復活")
	key(KEY_ESCAPE, true)
	await frames(2)
	key(KEY_ESCAPE, false)
	await frames(3)
	await click_text("タイトルへ")
	_check(main.model.phase == "title", "タイトルへの帰還")


func _fullscreen() -> void:
	var before: int = DisplayServer.window_get_mode()
	key(KEY_F11, true)
	await frames(2)
	key(KEY_F11, false)
	await create_timer(1.0).timeout
	_check(DisplayServer.window_get_mode() != before, "F11で全画面へ切替")
	key(KEY_F11, true)
	await frames(2)
	key(KEY_F11, false)
	await create_timer(1.0).timeout
	_check(DisplayServer.window_get_mode() == before, "F11で元の表示へ戻る")


func click_text(text: String) -> void:
	var button: Button = find_button(main, text)
	_check(button != null, "操作ボタンを見つける: " + text)
	if button == null:
		return
	var point: Vector2 = button.get_global_rect().get_center()
	mouse(MOUSE_BUTTON_LEFT, true, point)
	await frames(2)
	mouse(MOUSE_BUTTON_LEFT, false, point)
	await frames(6)


func frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("integration FAIL: " + label)


static func find_button(node: Node, text: String) -> Button:
	if node is Button and node.visible and node.text.contains(text):
		return node
	for child: Node in node.get_children():
		var found: Button = find_button(child, text)
		if found != null:
			return found
	return null


static func prepare_tree(game: Node) -> void:
	var base: int = 0
	for y: int in range(16):
		if game.model.data.get_block(Vector3i(9, y, 12)) == 4:
			base = y
			break
	var ground: int = game.model.data.surface_y(9, 15)
	game.player.setup(Vector3(9.5, ground + 1.04, 15.5))
	game.model.player_position = game.player.position
	var aim := Vector3(9.5, base + 1.5, 12.5)
	var offset: Vector3 = aim - game.player.camera.global_position
	var pitch: float = atan2(offset.y, Vector2(offset.x, offset.z).length())
	motion(Vector2(0, -pitch / game.player.look_sensitivity))
	print("検証用配置: 自然生成された木の前から採集。所持品は通常操作で取得。")


# 入力は押下・解放ごとに独立したイベントなので非冪等。
static func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func pad(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func mouse(button: int, pressed: bool, point: Vector2 = Vector2(640, 360)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	Input.flush_buffered_events()
