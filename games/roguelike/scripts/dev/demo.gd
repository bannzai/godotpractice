extends SceneTree
## 通常の入力経路だけで探索・道具使用・戦闘・敗北を撮影する 900 フレームのデモ。

const DEMO_SEED: int = 731
const STEP_KEYS: Dictionary = {
	Vector2i.LEFT: KEY_A, Vector2i.RIGHT: KEY_D,
	Vector2i.UP: KEY_W, Vector2i.DOWN: KEY_S,
	Vector2i(-1, -1): KEY_Q, Vector2i(1, -1): KEY_E,
	Vector2i(-1, 1): KEY_Z, Vector2i(1, 1): KEY_C,
}

var main: Node
var run: Node
var failures: Array[String] = []
var _releases: Array[InputEvent] = []
var _attacked: bool = false
var _used_item: bool = false
var _saw_result: bool = false
var _result_frame: int = -1


func _initialize() -> void:
	_run_demo.call_deferred()


## 入力とフレームを進める撮影処理なので、同じツリー上で重ねて実行しない。
func _run_demo() -> void:
	run = root.get_node("RunState")
	run.save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for frame: int in range(900):
		_release_inputs()
		_demo_frame(frame)
		await process_frame
	_release_inputs()
	_check(_used_item, "デモ中に道具を使用した")
	_check(_attacked, "デモ中に敵へ通常攻撃した")
	_check(_saw_result, "デモ中に自然な敗北で結果へ遷移した")
	_check(run.status == "title" and main.current_screen == "title", "デモがタイトルで終了した")
	await root.get_node("Sound").shutdown()
	main.queue_free()
	if failures.is_empty():
		print("demo OK: 実入力で探索・道具使用・戦闘・敗北・タイトル復帰")
	quit(0 if failures.is_empty() else 1)


## 各フレームに割り当てた操作を一度ずつ投入するので非冪等。
func _demo_frame(frame: int) -> void:
	match frame:
		45:
			_click("深層へ潜る")
		47:
			# 通常開始後、経路を再現できる seed だけを固定する。HP や敵は変更しない。
			if run.status == "playing":
				run.start_run(DEMO_SEED)
		180:
			_key(KEY_I)
		210:
			_click("灯り草")
		240:
			_click("使う / 装備")
		242:
			_used_item = run.inventory.count("herb") == 1
		275, 315:
			_key(KEY_M)
		875:
			root.get_node("Sound").shutdown()
	if frame >= 70 and frame < 175 and frame % 9 == 0 and run.status == "playing":
		_explore_step()
	if frame >= 335 and frame < 780 and frame % 7 == 0 and run.status == "playing":
		_approach_enemy()
	if run.status == "dead" and main.current_screen == run.status:
		if not _saw_result:
			_result_frame = frame
		_saw_result = true
		if frame >= 800 and frame < 875 and frame >= _result_frame + 18:
			_click("タイトルへ")


func _explore_step() -> void:
	var target: Vector2i = run.dungeon.rooms[0].position + Vector2i(1, 1)
	if run.player_pos == target:
		target = run.dungeon.rooms[0].end - Vector2i(2, 2)
	var step: Vector2i = next_step(run, target)
	if step != Vector2i.ZERO:
		_key(STEP_KEYS[step])


func _approach_enemy() -> void:
	if main.busy or main.cooldown > 0.0:
		return
	var nearest: Vector2i = run.player_pos
	var distance: float = INF
	for enemy: Dictionary in run.enemies:
		var cell: Vector2i = enemy.pos
		if run.player_pos.distance_to(cell) < distance:
			distance = run.player_pos.distance_to(cell)
			nearest = cell
	if distance < 1.5 and run.dungeon.can_step(run.player_pos, nearest):
		if not _attacked:
			_key(STEP_KEYS[nearest - run.player_pos])
			_attacked = true
		else:
			_key(KEY_SPACE)
	else:
		var step: Vector2i = next_step(run, nearest)
		if step != Vector2i.ZERO:
			_key(STEP_KEYS[step])


static func next_step(state: Node, target: Vector2i) -> Vector2i:
	var origin: Vector2i = state.player_pos
	var pending: Array[Vector2i] = [origin]
	var previous: Dictionary = {origin: origin}
	var cursor: int = 0
	while cursor < pending.size():
		var cell: Vector2i = pending[cursor]
		cursor += 1
		if cell == target:
			while previous[cell] != origin and cell != origin:
				cell = previous[cell]
			return cell - origin
		for direction: Vector2i in STEP_KEYS:
			var next: Vector2i = cell + direction
			if not previous.has(next) and state.dungeon.can_step(cell, next):
				previous[next] = cell
				pending.append(next)
	return Vector2i.ZERO


static func find_button(node: Node, caption: String) -> Button:
	for button: Node in node.find_children("*", "Button", true, false):
		if button is Button and button.text.begins_with(caption) and button.is_visible_in_tree():
			return button
	return null


## キーの押下と次フレームの解放は、実操作と同じ入力イベントとして投入する。
func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	_releases.append(release)


## GUI の pressed シグナルを直接呼ばず、座標を持つマウス入力を送る。
func _click(caption: String) -> void:
	var button: Button = find_button(main, caption)
	if button == null:
		_check(false, "デモのボタンが見つかる: " + caption)
		return
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = root.get_final_transform() * button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	_releases.append(release)


func _release_inputs() -> void:
	for event: InputEvent in _releases:
		Input.parse_input_event(event)
	_releases.clear()


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
