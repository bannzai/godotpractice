extends SceneTree
## 実入力イベントだけで30秒の対局を録画する。盤面・体力・デッキは書き換えない。

const FRAME_LIMIT: int = 900

var main: Control
var run: Node
var frames: int = 0
var next_frame: int = 30
var step: int = 0
var acting: bool = false
var failed: bool = false
var completed: bool = false
var placed: int = 0
var advanced: int = 0
var reached_battle: bool = false
var reached_result: bool = false
var finishing: bool = false


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	run = root.get_node("Run")
	run.save_path = "res://tmp/demo-save.json"
	run.stage = "title"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.seed_input.text = "31"
	print("実入力録画 開始: 30 fps / 30 秒 / 旅路の種31")


# フレームと実イベントで一本の録画を進めるため非冪等。
func _process(_delta: float) -> bool:
	frames += 1
	if frames >= FRAME_LIMIT - 26 and not finishing:
		finishing = true
		_finish.call_deferred()
	elif is_instance_valid(main) and not finishing and not acting and not completed:
		if frames >= next_frame and not main.busy:
			acting = true
			_act.call_deferred()
	return false


func _act() -> void:
	match step:
		0:
			await _click("start")
			_check(run.stage == "map", "開始操作で旅路を表示")
			step = 1
			next_frame = frames + 45
		1:
			await _click("route_0_0")
			_check(run.stage == "battle", "ノード選択で対局へ")
			reached_battle = run.stage == "battle"
			step = 2
			next_frame = frames + 20
		2:
			await _click("hand_0")
			step = 3
			next_frame = frames + 10
		3:
			await _click("cell_0_2")
			placed += 1
			step = 4
			next_frame = frames + 12
		4:
			await _key(KEY_R)
			step = 5
			next_frame = frames + 15
		5:
			await _click("move")
			await _click("cell_0_1")
			step = 6
			next_frame = frames + 22
		6:
			if run.stage == "result":
				reached_result = true
				step = 9
				next_frame = frames + 30
			elif frames >= 700:
				step = 7
			else:
				await _key(KEY_E)
				advanced += 1
				next_frame = frames + 12
		7:
			# 録画の終盤はプレイヤーの明示操作で降参し、結果→タイトルも記録する。
			await _click("pause")
			step = 8
			next_frame = frames + 12
		8:
			await _click("concede")
			_check(run.stage == "result", "降参操作で結果へ")
			reached_result = run.stage == "result"
			step = 9
			next_frame = frames + 25
		9:
			await _click("result_title")
			_check(run.stage == "title", "結果からタイトルへ")
			completed = run.stage == "title"
	acting = false


func _finish() -> void:
	main.stop_audio()
	_check(reached_battle and reached_result and completed, "タイトル・対局・結果・タイトルを通過")
	_check(placed > 0 and advanced > 0, "実配置・登場・移動・手番進行を記録")
	while frames < FRAME_LIMIT:
		await process_frame
	print("demo OK" if not failed else "demo FAIL")
	quit(1 if failed else 0)


func _click(name: String) -> void:
	var button: Control = main.content.find_child(name, true, false)
	if not _check(is_instance_valid(button), "操作対象: " + name):
		return
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	print("フレーム%d: クリック %s / %s" % [frames, name, run.stage])


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _check(condition: bool, description: String) -> bool:
	if not condition:
		failed = true
		push_error(description)
	return condition
