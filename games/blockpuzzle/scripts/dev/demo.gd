extends SceneTree
## 通常の対戦を実キー入力だけで26秒操作する。盤面・抽選列の書き換えは行わない。

const Rules = preload("res://scripts/puzzle_rules.gd")
const TOTAL_FRAMES: int = 780
const RELEASE_FRAMES: int = 16

var main: Control
var state: Node
var target: Dictionary = {}
var held_key: int = 0
var placements: int = 0
var clears: int = 0


func _initialize() -> void:
	_run.call_deferred()


# 入力の列と実時間を一度だけ進めるため非冪等。
func _run() -> void:
	state = root.get_node("Session")
	state.save_enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state.effect.connect(_observe_effect)
	var start_frame: int = Engine.get_process_frames()
	while Engine.get_process_frames() - start_frame < TOTAL_FRAMES - RELEASE_FRAMES:
		await process_frame
		var frame: int = Engine.get_process_frames() - start_frame
		if held_key != 0:
			_key(held_key, false)
			held_key = 0
		if frame == 30:
			_press(KEY_ENTER)
		elif frame > 45 and frame % 4 == 0:
			_drive(frame)
	main.set_process(false)
	state.set_process(false)
	await main.sound.shutdown()
	while Engine.get_process_frames() - start_frame < TOTAL_FRAMES:
		await process_frame
	if placements < 4 or clears < 1:
		push_error("プレイ録画の操作不足: 固定%d回、消去%d回" % [placements, clears])
		quit(1)
		return
	print("プレイ録画 OK: 実入力26秒、固定%d回、消去%d回" % [placements, clears])
	quit(0)


func _drive(frame: int) -> void:
	if state.screen in ["round", "result"]:
		if frame % 60 == 0:
			_press(KEY_ENTER)
		return
	if not state.can_control():
		target = {}
		return
	var b: Dictionary = state.boards[0]
	if target.is_empty():
		target = Rules.cpu_choice(b.board, b.pair, 2, b.next[0])
		if target.is_empty():
			_press(KEY_SPACE)
			return
	if b.rotation != target.rotation:
		_press(KEY_X)
	elif b.position.x != target.position.x:
		_press(KEY_RIGHT if b.position.x < target.position.x else KEY_LEFT)
	else:
		_press(KEY_SPACE)
		target = {}


func _observe_effect(side: int, kind: String, _cells: Array, _chain: int) -> void:
	if side != 0:
		return
	if kind == "land":
		placements += 1
	elif kind == "clear":
		clears += 1


func _press(key: int) -> void:
	_key(key, true)
	held_key = key


func _key(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
