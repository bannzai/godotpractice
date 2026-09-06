extends SceneTree
## 実入力と代表状態を描画し、画面遷移・演出の途中を検証する。

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
	if not await _battle():
		return false
	return await _results()


func _opening() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.4).timeout
	if not await _capture("title"):
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
	if not await _capture("opening"):
		return false
	await _key(KEY_N)
	await create_timer(0.6).timeout
	return _check(main.state.phase == "main", "Nでドローしてメインへ進める")


func _battle() -> bool:
	main.start_duel(0, 42)
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
	await create_timer(0.5).timeout
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
	await create_timer(0.18).timeout
	if not await _capture("attack-animation"):
		return false
	await create_timer(1.9).timeout
	return true


func _results() -> bool:
	main.state.players[1].monsters.clear()
	main.state.players[1].spells.clear()
	main.state.players[1].life = 500
	main.state.players[0].monsters[0].attacked = false
	main._render()
	main.content.get_node("monster0_0").pressed.emit()
	main.content.get_node("attack").pressed.emit()
	await create_timer(1.5).timeout
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
	await create_timer(0.3).timeout
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
