extends SceneTree
## 描画付きの操作検証。検証用の状態だけを作り、通常の保存には触れない。

var failures: int = 0
var game: Node2D
var state: Node
var output: String

func _initialize() -> void:
	call_deferred("exercise")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("確認成功: ", message)

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	root.push_input(event)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	check(error == OK, "画面保存 " + name)

func exercise() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("描画確認は --headless を付けずに実行してください")
		quit(1)
		return
	state = root.get_node("Run")
	state.persistence = false
	state.bank = 0
	state.vitality = 0
	state.mastery = 0
	state.best = 0
	output = ProjectSettings.globalize_path("res://../../tmp/dungeonlite")
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await capture("camp")
	click(Vector2(315, 455))
	check(state.phase == state.Phase.PLAY, "開始ボタンから探索")
	game.set_physics_process(false)
	state.start(72)
	for frame: int in range(90):
		state.advance(1.0 / 60.0, Vector2.RIGHT, Vector2.RIGHT)
	check(state.player.x > 440.0, "移動と戦闘時間の進行")
	state.swing()
	await capture("combat")
	key(KEY_ESCAPE)
	check(state.paused, "Escで一時停止")
	var stopped_at: Vector2 = state.player
	state.advance(1.0, Vector2.RIGHT, Vector2.RIGHT)
	check(state.player == stopped_at, "一時停止中は移動しない")
	await capture("pause")
	key(KEY_ESCAPE)
	check(not state.paused, "Escで再開")
	state.player = Vector2(400, 416)
	state.dash_wait = 0.0
	key(KEY_SPACE)
	check(state.dash_left > 0, "Spaceで回避")
	state.advance(0.06, Vector2.ZERO, Vector2.RIGHT)
	await capture("dash")
	# 部屋制圧後の到達しにくい画面は敵HPを0にしたfixtureで入口を用意する。
	for foe: Variant in state.foes:
		foe.health = 0
	state.remove_defeated()
	state.player = state.EXIT
	key(KEY_E)
	check(state.phase == state.Phase.CHOICE, "制圧後の扉から強化選択")
	await capture("choice")
	key(KEY_1)
	check(state.room == 2 and state.phase == state.Phase.PLAY, "数字キーで強化して次室")
	state.invulnerable = 0.0
	state.hurt(state.max_health)
	check(state.phase == state.Phase.RESULT, "死亡で結果画面")
	await capture("defeat")
	click(Vector2(563, 563))
	check(state.phase == state.Phase.CAMP, "結果から焚き火へ戻る")
	state.bank = 30
	game.rebuild_menu()
	await process_frame
	click(Vector2(828, 374))
	check(state.vitality == 1 and state.bank == 22, "工房の購入ボタン")
	click(Vector2(315, 455))
	check(state.max_health == 8, "再挑戦に恒久強化を反映")
	state.room = 5
	state.next_room()
	state.player = Vector2(648, 416)
	state.advance(1.0 / 60.0, Vector2.ZERO, Vector2.RIGHT)
	await capture("boss")
	for foe: Variant in state.foes:
		foe.health = 0
	state.remove_defeated()
	state.player = state.EXIT
	key(KEY_E)
	check(state.result == "迷宮に朝が戻った", "最深部の扉からクリア")
	await capture("victory")
	check(game.music.playing, "BGM再生中")
	check(game.music.stream.loop, "BGMループ設定")
	print("描画・操作検証の失敗数: ", failures)
	await game.stop_audio()
	quit(0 if failures == 0 else 1)
