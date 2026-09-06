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
	if not await _capture_results(main, session):
		return false
	main._show_title()
	if not await _capture_window_modes():
		return false
	main.queue_free()
	await create_timer(0.2).timeout
	return true


func _capture_play(main: DeliveryGame, session: Node) -> bool:
	main.start_run()
	await create_timer(0.15).timeout
	main.route.player.position.x = 510
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-meadow.png"):
		return false
	main.route.blocks[0].activate()
	session.collect_power()
	main.route.player.transform()
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-transform.png"):
		return false
	main.route.enemies[0].position = main.route.player.position + Vector2(90, 0)
	main.route.enemies[0].defeat()
	await create_timer(0.15).timeout
	if not await _capture("tmp/screenshot-stomp.png"):
		return false
	session.phase = "paused"
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-pause.png"):
		return false
	main._resume()
	return true


func _capture_results(main: DeliveryGame, session: Node) -> bool:
	session.finish_stage()
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-stage-clear.png"):
		return false
	main._continue()
	await create_timer(0.15).timeout
	main.route.player.position = Vector2(2460, 528)
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-cave.png"):
		return false
	main.route.player.position = Vector2(main.route.goal_x, 624)
	await create_timer(0.10).timeout
	if not await _capture("tmp/screenshot-complete.png"):
		return false
	main.start_run()
	for attempt: int in 3:
		session.damage(true, "穴に落ちた")
		await create_timer(0.10).timeout
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
