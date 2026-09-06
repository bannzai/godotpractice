extends RefCounted
## 仮想ゲームパッドとキーボードの実イベントを GUI に配送する統合検証。
## OS による実機の認識や、コントローラー本体のボタン表記は検証対象に含まない。


## 入力による状態遷移を検証するため、固定の冒険を開始して操作を進める。
static func run(check: Callable, tree: SceneTree) -> void:
	var game: Node = tree.root.get_node("Game")
	game.new_game()
	game.mode = "title"
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main: Control = scene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	await tree.process_frame
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(game.mode == "field", "ゲームパッド A でタイトルから冒険を開始")
	if game.mode == "field":
		await _check_walks(check, tree, main, game)
		await _check_menu(check, tree, main, game)
		await _check_battle(check, tree, main, game)
	if DisplayServer.get_name() != "headless":
		await _check_fullscreen(check, tree)
	await _settle(main, tree)
	main.music.stop()
	main.sound.stop()
	main.queue_free()
	await tree.create_timer(0.2).timeout
	await tree.process_frame
	await tree.process_frame
	game.new_game()
	game.mode = "title"


static func _check_walks(check: Callable, tree: SceneTree, main: Control, game: Node) -> void:
	await _walk(check, tree, main, game, _key_event(KEY_RIGHT), Vector2i.RIGHT, "矢印キー")
	await _walk(check, tree, main, game, _key_event(KEY_A), Vector2i.LEFT, "WASD キー")
	await _walk(check, tree, main, game, _joy_event(JOY_BUTTON_DPAD_RIGHT), Vector2i.RIGHT, "方向パッド")
	var axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
	axis.device = 0
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = -1.0
	await _walk(check, tree, main, game, axis, Vector2i.LEFT, "左スティック")


## 長押しの繰り返しを混ぜないよう、最初の移動を検出してから入力を離す。
static func _walk(
	check: Callable, tree: SceneTree, main: Control, game: Node,
	event: InputEvent, direction: Vector2i, label: String
) -> void:
	await _settle(main, tree)
	var before: Vector2i = game.cell
	Input.parse_input_event(event)
	var deadline: int = Time.get_ticks_msec() + 1500
	while game.cell == before and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	_release(event)
	await _settle(main, tree)
	check.call(game.cell == before + direction, label + "でグリッドを一歩移動")


static func _check_menu(check: Callable, tree: SceneTree, main: Control, game: Node) -> void:
	game.party.append(Catalog.create_monster("sprout", 6))
	await _joy_button(JOY_BUTTON_START, tree)
	check.call(main.menu_open, "START で手持ちメニューを開く")
	var focused: Control = tree.root.gui_get_focus_owner()
	check.call(
		focused is Button and Catalog.SPECIES.ember.name in focused.text and not focused.disabled,
		"メニューの先頭個体へフォーカスし、背面ボタンを選ばない"
	)
	await _joy_button(JOY_BUTTON_DPAD_RIGHT, tree)
	focused = tree.root.gui_get_focus_owner()
	check.call(focused is Button and Catalog.SPECIES.sprout.name in focused.text, "方向パッドで二体目を選択")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(game.active_index == 1, "A 決定で手持ちの先頭を交代")
	await _key(KEY_TAB, tree)
	check.call(not main.menu_open, "Tab でメニューを閉じる")
	# 失敗したチェックの後も、次の独立した入力経路を固定状態から検証する。
	main.menu_open = false
	main.refresh()
	await _joy_button(JOY_BUTTON_START, tree)
	await _key(KEY_ESCAPE, tree)
	check.call(not main.menu_open, "Esc でメニューを閉じる")


static func _check_battle(check: Callable, tree: SceneTree, main: Control, game: Node) -> void:
	game.zone = "town"
	game.cell = Vector2i(18, 7)
	main.menu_open = false
	main.refresh()
	await tree.process_frame
	await _joy_button(JOY_BUTTON_A, tree)
	var focused: Control = tree.root.gui_get_focus_owner()
	check.call(
		main.menu_open and focused is Button and focused.text == "挑戦する",
		"隊長の隣で A を押すと対話が開く"
	)
	await _joy_button(JOY_BUTTON_A, tree)
	var idle: bool = await _settle(main, tree)
	check.call(idle and game.mode == "battle" and game.trainer, "A 決定で隊長との戦闘へ移る")
	if game.mode != "battle":
		return
	check.call(game.active_index == 1, "選択した仲間を先頭にして戦闘を開始")
	var before_hp: int = game.enemy.hp
	await _joy_button(JOY_BUTTON_A, tree)
	idle = await _settle(main, tree)
	check.call(idle and game.mode in ["battle", "clear"], "技の決定後に攻撃演出が完了する")
	check.call(game.enemy.hp < before_hp, "A で選択した技が敵へダメージを与える")


static func _check_fullscreen(check: Callable, tree: SceneTree) -> void:
	var before: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	await _key(KEY_F11, tree)
	var deadline: int = Time.get_ticks_msec() + 3000
	while DisplayServer.window_get_mode() == before and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.05).timeout
	check.call(
		DisplayServer.window_get_mode() != before,
		"F11 で全画面表示を切り替える（元=%d 現在=%d）" % [
			before, DisplayServer.window_get_mode(),
		]
	)
	# macOS の全画面アニメーション中の入力欠落を避けるため、モード値の変更後も待つ。
	await tree.create_timer(1.0).timeout
	await _key(KEY_F11, tree)
	deadline = Time.get_ticks_msec() + 3000
	while DisplayServer.window_get_mode() != before and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.05).timeout
	check.call(
		DisplayServer.window_get_mode() == before,
		"F11 を再度押すと元の表示へ戻る（元=%d 現在=%d）" % [
			before, DisplayServer.window_get_mode(),
		]
	)


static func _settle(main: Control, tree: SceneTree) -> bool:
	var deadline: int = Time.get_ticks_msec() + 8000
	while (main.busy or main.step_clock > 0.0) and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.01).timeout
	await tree.process_frame
	return not main.busy and main.step_clock <= 0.0


## ボタンの押下・解放は実際の一操作を再現するため非冪等。
static func _joy_button(button: JoyButton, tree: SceneTree) -> void:
	var event: InputEventJoypadButton = _joy_event(button)
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame
	_release(event)
	await tree.process_frame
	await tree.process_frame


## キーの押下・解放は実際の一操作を再現するため非冪等。
static func _key(code: Key, tree: SceneTree) -> void:
	var event: InputEventKey = _key_event(code)
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame
	_release(event)
	await tree.process_frame
	await tree.process_frame


static func _joy_event(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	return event


static func _key_event(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


static func _release(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		event.axis_value = 0.0
	else:
		event.pressed = false
	Input.parse_input_event(event)
