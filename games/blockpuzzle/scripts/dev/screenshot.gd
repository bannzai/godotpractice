extends SceneTree

var failures: int = 0

# 描画と入力を順に検査する一回限りの開発用シナリオ。
func _initialize() -> void:
	call_deferred("run")

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("成功: " + message)

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://../../tmp/blockpuzzle-" + name_value + ".png")
	check(error == OK, name_value + " の撮影")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../../tmp"))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	# OS のウィンドウ切替が自動入力と競合しないよう、通知は後で明示的に検査する。
	scene.pause_on_focus_loss = false
	root.add_child(scene)
	current_scene = scene
	var game: Node = root.get_node("Session")
	game.save_enabled = false
	await capture("title")
	await key(KEY_ENTER)
	check(game.phase == "playing", "Enter で開始")
	var initial_x: int = game.pivot.x
	await key(KEY_LEFT)
	check(game.pivot.x == initial_x - 1, "左入力")
	await key(KEY_RIGHT)
	check(game.pivot.x == initial_x, "右入力")
	await key(KEY_X)
	check(game.rotation == 1, "右回転入力")
	await key(KEY_Z)
	check(game.rotation == 0, "左回転入力")
	await key(KEY_SPACE)
	check(game.score > 0, "即落下入力")
	await key(KEY_P)
	check(game.phase == "paused", "一時停止入力")
	await capture("pause")
	await key(KEY_ENTER)
	check(game.phase == "playing", "再開入力")
	scene.pause_on_focus_loss = true
	scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.phase == "paused", "非アクティブ通知で停止")
	scene.pause_on_focus_loss = false
	await key(KEY_ENTER)
	await key(KEY_M)
	check(scene.muted and scene.music.volume_db == -80, "音の停止入力")
	await key(KEY_M)
	check(not scene.muted and scene.music.playing, "音の再開入力")
	check(scene.music.stream.data.size() > 0, "BGM の PCM データ")
	# 再現可能な表示用盤面を設定し、ゲーム本体の消去処理を通す。
	game.start()
	for x: int in range(6):
		for y: int in range(9 + x % 3, 12):
			game.board[y][x] = (x + y) % 4
	await capture("play")
	game._reset_board()
	for x: int in range(4):
		game.board[11][x] = 0
	game.board[10][0] = 1
	game.board[10][1] = 1
	game.board[10][2] = 1
	game.board[9][3] = 1
	game._resolve()
	await capture("chain")
	game.tick(game.CLEAR_DELAY)
	check(game.chains == 2, "描画付きの二連鎖")
	await capture("chain2")
	game._finish()
	await capture("over")
	await key(KEY_ENTER)
	check(game.phase == "playing" and game.score == 0, "結果から再挑戦")
	print("描画・入力検証: 失敗 %d 件" % failures)
	scene.sound.stop()
	scene.music.stop()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
