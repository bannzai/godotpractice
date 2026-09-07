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
	_check_focused_choice(check, main, "タイトルの選択肢")
	check.call(not main.choice_preview.is_empty(), "タイトルで選んだ先のプレビューを表示")
	_check_nearest_textures(check, main, "タイトル")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(game.mode == "field" and main.tutorial_active,
		"ゲームパッド A で冒険を開始し、初回チュートリアルを表示")
	if game.mode == "field":
		await _check_tutorial(check, tree, main, game)
		await _check_region_map(check, tree, main, game)
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


static func _check_tutorial(
	check: Callable, tree: SceneTree, main: Control, game: Node
) -> void:
	check.call(main.tutorial_step == 0, "チュートリアルを移動案内から開始")
	check.call(is_instance_valid(main.tutorial_message)
		and "動か" in main.tutorial_message.text, "場面内に移動操作を案内")
	await _key(KEY_TAB, tree)
	check.call(not main.tutorial_active and main.tutorial_step == -1,
		"Tab の実入力でチュートリアルをスキップ")
	main.start_tutorial()
	main.refresh()
	await tree.process_frame
	await tree.process_frame
	await _walk(check, tree, main, game, _key_event(KEY_RIGHT), Vector2i.RIGHT,
		"チュートリアル中の矢印キー")
	check.call(main.tutorial_active and main.tutorial_step == 1,
		"一歩の成功後に話す操作の案内へ進む")
	check.call(is_instance_valid(main.tutorial_message)
		and "話す" in main.tutorial_message.text, "場面内に決定操作を案内")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(not main.tutorial_active and main.tutorial_step == -1,
		"ゲームパッド A でチュートリアルを完了")
	check.call(not main.field_context_text().is_empty()
		and main.field_objective_cell() != game.cell, "次の目的と目標地点を場面内に表示")
	_check_nearest_textures(check, main, "フィールド")


static func _check_region_map(
	check: Callable, tree: SceneTree, main: Control, game: Node
) -> void:
	await _joy_button(JOY_BUTTON_START, tree)
	check.call(main.menu_open, "START で旅支度を開く")
	var map_button: Button = _find_button(main.page, "地方図")
	check.call(map_button != null and not map_button.disabled, "旅支度から地方図を選べる")
	if map_button == null or map_button.disabled:
		main.close_menu()
		return
	map_button.grab_focus()
	await tree.process_frame
	_check_focused_choice(check, main, "地方図ボタン")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(main.region_map_open and main.menu_open, "A 決定で地方図を開く")
	check.call(not main.region_unavailable_reason.is_empty(), "現在地を選べない理由を表示")
	var current_button: Button = _find_button(main.page, "現在地")
	check.call(current_button != null and current_button.disabled,
		"地方図の現在地を選択不可として表示")
	await tree.process_frame
	await tree.process_frame
	_check_focused_choice(check, main, "地方図の移動先")
	check.call(main.region_selection == "route" and not main.region_preview.is_empty(),
		"小径をハイライトし、移動後の内容をプレビュー")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(not main.region_map_open and not main.menu_open and game.zone == "route",
		"地方図の小径をA決定して移動")
	await _open_region_map_from_menu(check, tree, main)
	check.call(main.region_selection == "town" and not main.region_preview.is_empty(),
		"小径から地方図を開くと町を移動先としてハイライト")
	await _joy_button(JOY_BUTTON_A, tree)
	check.call(not main.region_map_open and game.zone == "town",
		"地方図の町をA決定して移動")
	await _open_region_map_from_menu(check, tree, main)
	await _joy_button(JOY_BUTTON_START, tree)
	check.call(not main.region_map_open and main.menu_open,
		"地方図で START を押すと旅支度へ戻る")
	await _joy_button(JOY_BUTTON_START, tree)
	check.call(not main.menu_open, "旅支度で START を押すとフィールドへ戻る")


static func _open_region_map_from_menu(
	check: Callable, tree: SceneTree, main: Control
) -> void:
	await _joy_button(JOY_BUTTON_START, tree)
	var map_button: Button = _find_button(main.page, "地方図")
	check.call(map_button != null and not map_button.disabled, "旅支度の地方図ボタンへ到達")
	if map_button == null or map_button.disabled:
		return
	map_button.grab_focus()
	await tree.process_frame
	await _joy_button(JOY_BUTTON_A, tree)
	await tree.process_frame
	await tree.process_frame


static func _check_focused_choice(check: Callable, main: Control, label: String) -> void:
	check.call(is_instance_valid(main.focused_choice) and main.focused_choice.has_focus(),
		label + "をハイライト")
	check.call(is_instance_valid(main.focused_choice)
		and main.focused_choice.text.begins_with("▶ "), label + "に選択カーソルを表示")


static func _find_button(parent: Node, caption: String) -> Button:
	for child: Node in parent.find_children("*", "Button", true, false):
		var button: Button = child as Button
		var choice_text: String = str(button.get_meta("choice_text", button.text))
		if caption in choice_text:
			return button
	return null


static func _check_nearest_textures(check: Callable, parent: Node, label: String) -> void:
	var textured_nodes := 0
	var linear_nodes: Array[String] = []
	for child: Node in parent.find_children("*", "", true, false):
		var uses_texture := (
			(child is TextureRect and child.texture != null)
			or (child is Sprite2D and child.texture != null)
			or (child is AnimatedSprite2D and child.sprite_frames != null)
		)
		if not uses_texture:
			continue
		textured_nodes += 1
		if not _inherits_nearest(child as CanvasItem):
			linear_nodes.append(str(child.get_path()))
	check.call(textured_nodes > 0, label + "に画像を表示")
	check.call(linear_nodes.is_empty(), "%sの画像をニアレストで表示: %s" % [
		label, ", ".join(linear_nodes),
	])


static func _inherits_nearest(item: CanvasItem) -> bool:
	var current: CanvasItem = item
	while current != null:
		if current.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST:
			return true
		if current.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return false
		current = current.get_parent() as CanvasItem
	return false


static func _check_walks(check: Callable, tree: SceneTree, main: Control, game: Node) -> void:
	game.zone = "town"
	game.cell = Vector2i(11, 7)
	main.refresh()
	await tree.process_frame
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
	_check_focused_choice(check, main, "旅支度の先頭候補")
	check.call(not main.choice_preview.is_empty(), "旅支度の選択結果をプレビュー")
	var potion_info: Dictionary = main.action_info("field_potion")
	check.call(not potion_info.enabled and not str(potion_info.reason).is_empty(),
		"満タン時に回復を選べない理由を用意")
	var storage_button: Button = _find_button(main.page, "預かり交換")
	check.call(storage_button != null and storage_button.disabled
		and not str(storage_button.get_meta("choice_preview", "")).is_empty(),
		"町では預かり交換を選べず理由を表示")
	var focused: Control = tree.root.gui_get_focus_owner()
	check.call(
		focused is Button and Catalog.SPECIES.ember.name in focused.text and not focused.disabled,
		"メニューの先頭個体へフォーカスし、背面ボタンを選ばない"
	)
	await _joy_button(JOY_BUTTON_DPAD_DOWN, tree)
	focused = tree.root.gui_get_focus_owner()
	check.call(focused is Button and Catalog.SPECIES.sprout.name in focused.text,
		"方向パッドの下で縦並びの二体目を選択")
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
		main.menu_open and focused is Button and "挑戦する" in focused.text,
		"隊長の隣で A を押すと対話が開く"
	)
	await _joy_button(JOY_BUTTON_A, tree)
	var idle: bool = await _settle(main, tree)
	check.call(idle and game.mode == "battle" and game.trainer, "A 決定で隊長との戦闘へ移る")
	if game.mode != "battle":
		return
	check.call(game.active_index == 1, "選択した仲間を先頭にして戦闘を開始")
	_check_nearest_textures(check, main, "戦闘")
	_check_focused_choice(check, main, "戦闘の技")
	var first_preview: String = main.battle_preview
	check.call(not first_preview.is_empty(), "選択中の技の威力・相性・結果をプレビュー")
	var potion_info: Dictionary = main.action_info("potion")
	check.call(not potion_info.enabled and not str(potion_info.reason).is_empty(),
		"HP満タン時は回復を選べない理由を表示")
	var first_move: Button = main.focused_choice
	await _joy_button(JOY_BUTTON_DPAD_DOWN, tree)
	check.call(is_instance_valid(main.focused_choice) and main.focused_choice != first_move,
		"方向パッドの下で縦並びの次の技へ移動")
	check.call(not main.battle_preview.is_empty() and main.battle_preview != first_preview,
		"技の選択に合わせてプレビューを更新")
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
