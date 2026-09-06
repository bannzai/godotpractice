extends SceneTree
## 実入力とメインシーンの物理処理で、操作・完走・再走の一連を検証する。

const Controls = preload("res://scripts/dev/demo.gd")
var _main: Node
var _state: Node
var _failures: int = 0
var _effects: Dictionary = {}
var _used_keyboard_item: bool = false
var _used_pad_item: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


# 入力と物理フレームを順に進める統合シナリオ。
func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_state = root.get_node("RaceState")
	_state.save_enabled = false
	_state.effect.connect(func(kind: String, racer: int) -> void:
		if racer == 0:
			_effects[kind] = int(_effects.get(kind, 0)) + 1)
	await _frames(2)
	_expect(_state.phase == "title", "タイトルから開始")
	await _tap(KEY_RIGHT)
	_expect(_state.selected_kart == 1, "キーボードでカート選択")
	await _tap(KEY_LEFT)
	_expect(_state.selected_kart == 0, "逆方向のカート選択")
	await _tap(KEY_F11)
	await _window_transition()
	if DisplayServer.get_name() != "headless":
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
			"F11で全画面化")
	await _tap(KEY_F11)
	await _window_transition()
	if DisplayServer.get_name() != "headless":
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
			"F11でウィンドウへ復帰")
	# マウスで車種を選んだ後も Enter がカード再選択に奪われない。
	_main.hud.cards[0].grab_focus()
	await _tap(KEY_ENTER)
	_expect(_state.phase == "countdown", "Enterでレース開始")
	await _frames(190)
	_expect(_state.phase == "racing", "カウントダウン後に走行")
	Controls.key(KEY_UP, true)
	await _frames(75)
	_expect(_state.racers[0].speed > 8.0, "キーボードで加速")
	var lateral: float = _state.racers[0].lateral
	Controls.key(KEY_RIGHT, true)
	await _frames(18)
	Controls.key(KEY_RIGHT, false)
	_expect(_state.racers[0].lateral > lateral, "右ステア")
	Controls.key(KEY_LEFT, true)
	await _frames(18)
	Controls.key(KEY_LEFT, false)
	_expect(_state.racers[0].lateral < lateral + 0.5, "左ステア")
	Controls.key(KEY_RIGHT, true)
	Controls.key(KEY_SPACE, true)
	await _frames(46)
	_expect(_state.racers[0].drifting, "Spaceでドリフト")
	Controls.key(KEY_SPACE, false)
	Controls.key(KEY_RIGHT, false)
	await _frames(2)
	_expect(_state.racers[0].boost > 0.0, "Space解除でブースト")
	if _state.racers[0].item > 0:
		await _tap(KEY_E)
		_expect(_state.racers[0].item == 0, "Eでアイテム使用")
	Controls.key(KEY_UP, false)
	Controls.key(KEY_DOWN, true)
	await _frames(170)
	_expect(_state.racers[0].speed < -1.0 and _state.racers[0].wrong_way, "バックと逆走表示")
	Controls.key(KEY_DOWN, false)
	await _tap(KEY_ESCAPE)
	_expect(_state.phase == "title", "Escでタイトルへ復帰")
	Controls.button(JOY_BUTTON_A, true)
	await _frames(2)
	Controls.button(JOY_BUTTON_A, false)
	_expect(_state.phase == "countdown", "パッドAでレース開始")
	await _frames(190)
	Controls.axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(80)
	_expect(_state.racers[0].speed > 8.0, "パッドRTで加速")
	Controls.axis(JOY_AXIS_LEFT_X, 0.45)
	Controls.button(JOY_BUTTON_X, true)
	await _frames(46)
	_expect(_state.racers[0].drifting, "パッドXとスティックでドリフト")
	Controls.button(JOY_BUTTON_X, false)
	Controls.axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_expect(_state.racers[0].boost > 0.0, "ドリフト解除でブースト")
	Controls.axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	Controls.axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(190)
	_expect(_state.racers[0].speed < -1.0, "パッドLTでブレーキとバック")
	Controls.axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	Controls.axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _finish_with_inputs()
	_expect(_state.phase == "results", "入力だけで3周を完走し全車結果へ")
	_expect(_effects.has("pickup"), "配置アイテムを走行中に取得")
	_expect(_used_keyboard_item, "Eで取得アイテムを使用")
	_expect(_used_pad_item, "パッドBで取得アイテムを使用")
	_expect(_state.racers[0].lap_times.size() == 3, "3周のラップタイムを記録")
	_expect(_state.best_time > 0.0, "ベストタイムを更新")
	Controls.release_all()
	await _tap(KEY_ENTER)
	_expect(_state.phase == "countdown" and _state.elapsed == 0, "結果から再走")
	await _tap(KEY_ESCAPE)
	_expect(_state.phase == "title", "再走からタイトルへ戻る")
	await _main.prepare_shutdown()
	_main.queue_free()
	await process_frame
	if _failures == 0:
		print("integration OK")
	quit(0 if _failures == 0 else 1)


# スティックの実イベントで車線を補正し、取得したアイテムを使って最後まで走る。
func _finish_with_inputs() -> void:
	var previous_uses: int = int(_effects.get("item_use", 0))
	var pending_keyboard: bool = false
	for frame: int in range(12000):
		if int(_effects.get("item_use", 0)) > previous_uses:
			if pending_keyboard:
				_used_keyboard_item = true
			else:
				_used_pad_item = true
			previous_uses = int(_effects.get("item_use", 0))
		if _state.phase == "results":
			return
		var racer: Dictionary = _state.racers[0]
		var desired: float = -3.0
		var steer: float = clampf((desired - racer.lateral) * 0.6 - 0.085, -0.8, 0.8)
		Controls.axis(JOY_AXIS_LEFT_X, steer)
		var fire: bool = racer.item > 0 and frame % 12 == 0
		var keyboard_fire: bool = fire and not _used_keyboard_item
		if fire:
			pending_keyboard = keyboard_fire
		Controls.key(KEY_E, keyboard_fire)
		Controls.button(JOY_BUTTON_B, fire and not keyboard_fire)
		await physics_frame
	_expect(false, "レース完走の制限フレームを超過")


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await physics_frame


func _tap(code: Key) -> void:
	Controls.key(code, true)
	await _frames(2)
	Controls.key(code, false)
	await _frames(2)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("不成立: " + label)
	else:
		print("確認: " + label)


# macOSの全画面移行アニメーションはエンジン時刻とは別に進む。
func _window_transition() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var deadline: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < deadline:
		await process_frame
