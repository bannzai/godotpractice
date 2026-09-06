extends SceneTree
## 実入力と代表状態を描画し、画面遷移・演出の途中を検証する。

const Gallery = preload("res://scripts/dev/gallery.gd")

var main: Control


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


# 入力と描画時間を進める検証のため非冪等。
func _run() -> void:
	if await _capture_scenes():
		print("入力・画面遷移 OK")
		quit(0)


func _capture_scenes() -> bool:
	if not await _opening():
		return false
	if not await _private_trap():
		return false
	if not await _battle():
		return false
	if not await _galleries():
		return false
	return await _results()


func _opening() -> bool:
	if not await _capture_title():
		return false
	if not await _navigation():
		return false
	main.content.get_node("help").pressed.emit()
	if not await _capture("help"):
		return false
	main.content.get_node("closehelp").pressed.emit()
	main.content.get_node("deck0").grab_focus()
	await _key(KEY_ENTER)
	if not _check(main.screen == "duel", "Enterでタイトルから決闘に進める"):
		return false
	await create_timer(0.5).timeout
	if not await _capture("opening"):
		return false
	await _key(KEY_N)
	await create_timer(0.6).timeout
	return _check(main.state.phase == "main", "Nでドローしてメインへ進める")


func _battle() -> bool:
	main.start_duel(0, 42)
	await create_timer(0.5).timeout
	main.state.advance_phase()
	main.state.players[0].hand = ["m00", "m08", "boost", "draw", "snare", "destroy", "m09"]
	main._render()
	main.content.get_node("hand0").grab_focus()
	await _pad(JOY_BUTTON_A)
	if not _check(main.selected_zone == "hand", "ゲームパッドAで手札を選べる"):
		return false
	await _mouse(main.content.get_node("summon").get_global_rect().get_center())
	await create_timer(0.18).timeout
	if not await _capture("summon-animation"):
		return false
	if not await _settle():
		return false
	if not _check(main.state.players[0].monsters.size() == 1, "UIから通常召喚できる"):
		return false
	main.state.turn = 3
	main.state.players[0].monsters.append(_monster("m08"))
	main.state.players[1].monsters = [_monster("m12"), _monster("m15", true)]
	main.state.players[1].spells = ["mist"]
	main.state.players[0].spells = ["snare", "spark"]
	main._render()
	main.content.get_node("hand1").grab_focus()
	if not await _capture("play"):
		return false
	return await _attack_scene()


func _attack_scene() -> bool:
	await _pad(JOY_BUTTON_Y)
	if not _check(main.state.phase == "battle", "ゲームパッドYでバトルに進める"):
		return false
	main.content.get_node("monster0_1").pressed.emit()
	main.content.get_node("monster1_0").pressed.emit()
	var retained: Node = main.content.get_node("monster1_0")
	await _key(KEY_ESCAPE)
	await _key(KEY_E)
	await _pad(JOY_BUTTON_B)
	if not _check(is_instance_valid(retained), "攻撃演出中の解除・ページ入力でカードを破棄しない"):
		return false
	await create_timer(0.10).timeout
	if not await _capture("attack-animation"):
		return false
	return await _settle()


func _results() -> bool:
	main.state.players[1].monsters.clear()
	main.state.players[1].spells.clear()
	main.state.players[1].life = 500
	main.state.players[0].monsters[0].attacked = false
	main._render()
	main.content.get_node("monster0_0").pressed.emit()
	main.content.get_node("attack").pressed.emit()
	if not await _settle():
		return false
	await create_timer(0.5).timeout
	if not _check(main.screen == "result" and main.state.winner == 0, "実攻撃から勝利結果へ進む"):
		return false
	if not await _capture("victory"):
		return false
	return await _replay_scene()


func _replay_scene() -> bool:
	main.content.get_node("retry").grab_focus()
	await _pad(JOY_BUTTON_A)
	if not _check(main.screen == "duel" and main.state.winner == -1, "パッドAで再戦できる"):
		return false
	main.state.players[0].deck.clear()
	main._next_phase()
	if not await _settle():
		return false
	await create_timer(0.5).timeout
	if not _check(main.screen == "result" and main.state.winner == 1, "ドロー不能で敗北結果へ進む"):
		return false
	if not await _capture("defeat"):
		return false
	main.content.get_node("title").pressed.emit()
	if not _check(main.screen == "title", "結果からタイトルへ戻る"):
		return false
	main.stop_audio()
	await create_timer(0.25).timeout
	main.queue_free()
	await process_frame
	return true


func _monster(id: String, defense: bool = false) -> Dictionary:
	return {"id": id, "defense": defense, "attacked": false, "boost": 0, "changed": false}


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _check(condition: bool, label: String) -> bool:
	if not condition:
		push_error("画面検証失敗: " + label)
		quit(1)
	return condition


func _capture(label: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: " + path)
		quit(1)
		return false
	print("screenshot: " + path)
	return true


func _mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _navigation() -> bool:
	main.content.get_node("deck0").grab_focus()
	await _key(KEY_RIGHT)
	if not _check(root.gui_get_focus_owner().name == "deck1", "矢印でデッキを切り替える"):
		return false
	await _pad(JOY_BUTTON_DPAD_LEFT)
	if not _check(root.gui_get_focus_owner().name == "deck0", "十字キーでデッキを切り替える"):
		return false
	await _key(KEY_F11)
	await create_timer(1.0).timeout
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	await _pad(JOY_BUTTON_START)
	await create_timer(1.0).timeout
	return _check(
		fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,
		"F11で全画面、STARTでウィンドウ表示へ戻る"
	)


func _settle() -> bool:
	for attempt: int in range(100):
		if not main.busy:
			return true
		await create_timer(0.1).timeout
	return _check(false, "演出が10秒以内に完了する")


func _effects() -> bool:
	var captions: Dictionary = {
		"draw": "ドロー",
		"summon": "召喚  日輪の王",
		"attack": "攻撃  夕焼けの竜",
		"destroy": "破壊",
		"damage": "ライフ減少  1200",
		"boost": "強化  太陽の加護",
		"trap": "罠 発動  結晶の落とし穴",
		"set": "罠をセット",
		"spell": "魔法 発動  巡る星図",
	}
	for kind: String in captions:
		for frame: int in range(3):
			main.effect.seek_effect(
				kind,
				captions[kind],
				Vector2(289, 419),
				Vector2(460, 228),
				[0.15, 0.50, 0.85][frame]
			)
			if not await _capture("effect-%s-%d" % [kind, frame]):
				return false
	main.effect.progress = 1.0
	main.effect.particles.emitting = false
	return true


func _capture_title() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.16).timeout
	if not await _capture("title-transition"):
		return false
	await create_timer(0.5).timeout
	return await _capture("title")


func _private_trap() -> bool:
	main.start_duel(0, 42)
	main.state.turn_player = 1
	main.state.phase = "main"
	main.state.players[1].hand = ["snare"]
	main._perform(main.state.set_trap(0))
	await create_timer(0.2).timeout
	if not _check(main.effect.caption == "罠をセット", "CPUの伏せカード名を演出に出さない"):
		return false
	if not await _capture("cpu-hidden-trap"):
		return false
	return await _settle()


func _galleries() -> bool:
	main.busy = true
	if not await Gallery.capture_cards(self, main):
		return false
	if not await Gallery.capture_characters(self, main):
		return false
	if not await _effects():
		return false
	main.busy = false
	return true
