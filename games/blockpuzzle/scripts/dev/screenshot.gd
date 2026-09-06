extends SceneTree
## 代表画面は実入力、演出と全キャラの比較は明示した検証盤面を使って撮る。

const Rules = preload("res://scripts/puzzle_rules.gd")
const Piece = preload("res://scripts/piece_sprite.gd")

var main: Control
var state: Node


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


# 描画と入力を時間順に進めるため非冪等。
func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("Session")
	state.save_enabled = false
	var success: bool = await _capture_scenes()
	await main.sound.shutdown()
	print("画面撮影 OK" if success else "画面撮影失敗")
	quit(0 if success else 1)


func _capture_scenes() -> bool:
	for capture: Callable in [_opening, _chain_scene, _garbage_scene, _result_scenes, _solo_scenes]:
		if not await capture.call():
			return false
	for kind: int in range(1, 6):
		if not await _gallery(kind):
			return false
	return true


func _opening() -> bool:
	await create_timer(0.12).timeout
	if not await _capture("transition"):
		return false
	await create_timer(0.25).timeout
	if not await _capture("title"):
		return false
	main._help()
	if not await _capture("help"):
		return false
	main._render()
	await _key(KEY_ENTER)
	await create_timer(0.5).timeout
	if not _check(state.screen == "play", "Enterでプレイ開始"):
		return false
	_populate()
	if not await _capture("play"):
		return false
	return await _pause_and_fullscreen()


func _pause_and_fullscreen() -> bool:
	await _key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	if not await _capture("pause"):
		return false
	await _key(KEY_ESCAPE)
	await _key(KEY_F11)
	await create_timer(1.0).timeout
	if not _check(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11で全画面"
	):
		return false
	await _key(KEY_F11)
	await create_timer(1.0).timeout
	return true


func _populate() -> void:
	state.boards[1].phase = "fixture"
	state.boards[1].timer = 100.0
	for side: int in range(2):
		for row: int in range(7, 12):
			for col: int in range(6):
				if (row + col + side) % 4 != 0:
					state.boards[side].board[row][col] = (row * 2 + col + side) % 4 + 1
		state.boards[side].board = Rules.gravity(state.boards[side].board)
		main._board_changed(side, "idle")


func _chain_scene() -> bool:
	state.boards[0].board = Rules.empty_board()
	state.boards[0].board[9] = [0, 0, 2, 0, 0, 0]
	state.boards[0].board[10] = [0, 2, 1, 2, 0, 0]
	state.boards[0].board[11] = [1, 1, 1, 2, 0, 0]
	state.boards[0].phase = "land"
	state.boards[0].timer = 0.1
	state.boards[0].chain = 0
	main._board_changed(0, "land")
	await create_timer(0.04).timeout
	if not await _capture("landing"):
		return false
	await create_timer(0.22).timeout
	if not await _capture("chain-first"):
		return false
	await create_timer(0.4).timeout
	if not await _capture("chain-fall"):
		return false
	await create_timer(0.3).timeout
	if not await _capture("chain-second"):
		return false
	await create_timer(0.6).timeout
	return _check(state.max_chain >= 2, "演出付きの2連鎖")


func _garbage_scene() -> bool:
	state.boards[0].pending = 12
	state._drop_nuisance(0)
	await create_timer(0.12).timeout
	if not await _capture("garbage-fall"):
		return false
	await create_timer(0.6).timeout
	return await _capture("effects-ended")


func _result_scenes() -> bool:
	state._finish(0, "検証盤面でCPUの入口が埋まりました")
	await create_timer(0.35).timeout
	if not await _capture("round"):
		return false
	await _key(KEY_ENTER)
	state._finish(0, "2本先取しました")
	await create_timer(0.35).timeout
	if not await _capture("victory"):
		return false
	await _key(KEY_ENTER)
	if not _check(state.screen == "play" and state.wins == [0, 0], "結果から再戦"):
		return false
	state.wins.assign([0, 1])
	state._finish(1, "入口まで積み上がりました")
	await create_timer(0.35).timeout
	return await _capture("defeat")


func _solo_scenes() -> bool:
	state.start_game("solo", 13)
	await create_timer(0.35).timeout
	if not await _capture("solo"):
		return false
	state.elapsed = state.LIMIT - 0.1
	await create_timer(0.5).timeout
	if not await _capture("solo-result"):
		return false
	state.show_title()
	await create_timer(0.35).timeout
	return await _capture("return-title")


func _gallery(kind: int) -> bool:
	state.show_title()
	for child: Node in main.content.get_children():
		main.content.remove_child(child)
		child.queue_free()
	main._panel(Rect2(60, 35, 1160, 650), Color("102b3c"))
	main._label("精霊 %d · 動作の連続フレーム" % kind, Rect2(100, 57, 960, 50), 30)
	var poses: Array[String] = ["idle", "move", "land", "hurt", "clear"]
	var captions: Array[String] = ["待機", "移動", "着地", "被害", "消去"]
	for col: int in range(3):
		main._label(["開始", "途中", "終了"][col], Rect2(421 + col * 260, 112, 160, 30), 18)
	for row: int in poses.size():
		main._label(captions[row], Rect2(110, 174 + row * 97, 220, 50), 22)
		for col: int in range(3):
			var actor: Node2D = Piece.new()
			main.content.add_child(actor)
			actor.position = Vector2(459 + col * 260, 192 + row * 97)
			actor.setup(kind, 92)
			var duration: float = actor.animator.get_animation(poses[row]).length
			actor.seek_pose(poses[row], duration * [0.0, 0.5, 1.0][col])
	await create_timer(0.35).timeout
	return await _capture("character-%d" % kind)


func _capture(label: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var result: Error = root.get_texture().get_image().save_png(path)
	print("screenshot: " + path)
	return _check(result == OK, "PNGの保存 " + label)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
	return condition


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
