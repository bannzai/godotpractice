extends SceneTree
## 28秒の実入力プレイ。通常ルールの道路脇へ住宅をドラッグし9月のクリアまで進める。

const FPS: int = 30
const DURATION: int = 28
var main: Node
var city: Node
var failed: bool = false
var saw_clear: bool = false
var built_houses: bool = false
var pointer: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


# 時刻に沿った実入力のシナリオなので同じツリーでは一度だけ実行する。
func _run() -> void:
	city = root.get_node("City")
	city.saving_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(FPS * DURATION):
		_operate(frame)
		if city.phase == "result" and city.state.outcome == "clear":
			saw_clear = true
		if frame == 4 * FPS:
			built_houses = city.state.tiles[16 * 32 + 8].kind == "residential"
			built_houses = built_houses and city.state.tiles[16 * 32 + 10].kind == "residential"
		if frame == FPS * DURATION - 12:
			await root.get_node("Sound").shutdown()
		await process_frame
	_check(built_houses, "実マウスドラッグで道路沿いに住宅を追加")
	_check(saw_clear, "通常の月次成長で600人を超えてクリア結果を表示")
	_check(city.phase == "title", "結果からEnterでタイトルへ帰還")
	# 描画ノードはツリー終了時に解放し、録画末尾をタイトルのまま保つ。
	print("demo OK" if not failed else "demo FAIL")
	quit(1 if failed else 0)


func _operate(frame: int) -> void:
	if frame in [30, 33, 660, 663]:
		_key(KEY_ENTER, frame in [30, 660])
	if frame in [60, 63]:
		_key(KEY_SPACE, frame == 60)
	if frame in [90, 95, 100]:
		_point(Vector2i(8 + (frame - 90) / 5, 16))
		if frame == 90:
			_mouse(true)
	if frame == 105:
		_mouse(false)
	for seconds: int in [4, 6, 8, 10, 12, 14, 16, 18, 20]:
		if frame in [seconds * FPS, seconds * FPS + 3]:
			_key(KEY_N, frame == seconds * FPS)
	for seconds: int in [9, 11, 13, 15, 17]:
		if frame in [seconds * FPS, seconds * FPS + 3]:
			_key(KEY_O, frame == seconds * FPS)


func _point(cell: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	pointer = main.view.position + main.view.cell_to_screen(cell)
	event.position = pointer
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if cell.x > 8 else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = pointer
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("demo FAIL: " + message)
