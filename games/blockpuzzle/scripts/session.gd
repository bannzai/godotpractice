extends Node
## 画面・対戦・記録を所有する。表示は signal とこの状態を参照する。

signal screen_changed
signal board_changed(side: int, pose: String)
signal effect(side: int, kind: String, cells: Array, chain: int)

const Rules = preload("res://scripts/puzzle_rules.gd")
const LIMIT: float = 90.0

var screen: String = "title"
var mode: String = "cpu"
var difficulty: int = 1
var boards: Array = []
var elapsed: float = 0.0
var score: int = 0
var max_chain: int = 0
var wins: Array[int] = [0, 0]
var round_winner: int = -1
var result_text: String = ""
var paused: bool = false
var records: Dictionary = {"high_score": 0, "best_chain": 0, "tutorial_seen": false}
var save_enabled: bool = true
var save_message: String = ""
var rng := RandomNumberGenerator.new()
var move_repeat: float = 0.0
var move_direction: int = 0


func _ready() -> void:
	load_records()


func load_records() -> void:
	if not FileAccess.file_exists("user://records.json"):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string("user://records.json")) == OK:
		records = Rules.parse_records(parser.data)


func save_records() -> void:
	records.high_score = maxi(records.high_score, score)
	records.best_chain = maxi(records.best_chain, max_chain)
	if not save_enabled:
		return
	var file := FileAccess.open("user://records.json", FileAccess.WRITE)
	if file == null:
		save_message = "記録を保存できませんでした"
		return
	file.store_string(JSON.stringify(records))
	save_message = "記録を保存しました"


# 新しい対戦の乱数列を開始するため非冪等。固定seedは検証でのみ渡す。
func start_game(selected_mode: String = "cpu", seed_value: int = -1) -> void:
	mode = selected_mode
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	wins = [0, 0]
	score = 0
	max_chain = 0
	_start_round()


func _start_round() -> void:
	boards.clear()
	elapsed = 0.0
	paused = false
	round_winner = -1
	move_direction = 0
	for side: int in range(2):
		(
			boards
			. append(
				{
					"board": Rules.empty_board(),
					"pair": [],
					"position": Vector2i(2, 0),
					"rotation": 0,
					"next": [_pair(), _pair(), _pair()],
					"phase": "spawn",
					"timer": 0.0,
					"fall": 0.0,
					"lock": 0.0,
					"resets": 0,
					"chain": 0,
					"score": 0,
					"pending": 0,
					"clear": {},
					"cpu_time": 0.0,
				}
			)
		)
		_spawn(side)
	screen = "play"
	screen_changed.emit()


# 抽選列を一組消費するため非冪等。
func _pair() -> Array:
	return [rng.randi_range(1, 4), rng.randi_range(1, 4)]


func show_title() -> void:
	screen = "title"
	paused = false
	screen_changed.emit()


func next_round() -> void:
	if screen == "round":
		_start_round()


func toggle_pause() -> void:
	if screen == "play":
		paused = not paused
		screen_changed.emit()


# 時間と入力の積分なので非冪等。
func _process(delta: float) -> void:
	if screen != "play" or paused:
		return
	elapsed += delta
	if mode == "solo" and elapsed >= LIMIT:
		_finish(-1, "時間終了")
		return
	_repeat_input(delta)
	for side: int in range(2 if mode == "cpu" else 1):
		if screen != "play":
			break
		_tick(side, delta)


func _repeat_input(delta: float) -> void:
	var direction: int = int(Input.is_action_pressed("piece_right"))
	direction -= int(Input.is_action_pressed("piece_left"))
	if direction == 0:
		move_direction = 0
		return
	if direction != move_direction:
		move_direction = direction
		move_repeat = 0.19
		move_piece(direction)
	else:
		move_repeat -= delta
		if move_repeat <= 0.0:
			move_repeat = 0.065
			move_piece(direction)


func _tick(side: int, delta: float) -> void:
	var b: Dictionary = boards[side]
	if b.phase == "falling":
		_falling(side, delta)
		return
	b.timer -= delta
	if b.timer > 0.0:
		return
	match b.phase:
		"land", "gravity":
			_check_clear(side)
		"clear":
			b.board = b.clear.board
			b.phase = "gravity"
			b.timer = 0.28
			board_changed.emit(side, "idle")
			b.board = Rules.gravity(b.board)
			board_changed.emit(side, "fall")
		"garbage":
			_spawn(side)


func _falling(side: int, delta: float) -> void:
	var b: Dictionary = boards[side]
	if side == 1:
		if b.get("cpu_planned", false):
			_cpu_move(side, delta)
			return
		b.cpu_time += delta
		if b.cpu_time >= [1.9, 1.1, 0.65][difficulty]:
			var choice: Dictionary = Rules.cpu_choice(
				b.board, b.pair, difficulty, b.next[0], b.position, b.rotation
			)
			if choice.is_empty():
				_finish(0, "入口まで積み上がりました")
				return
			b.cpu_plan = choice.path.duplicate()
			b.cpu_planned = true
			b.cpu_step = 0.0
			return
	b.fall += delta
	var interval: float = Rules.fall_interval(elapsed)
	if side == 0 and Input.is_action_pressed("soft_drop"):
		interval = 0.045
	if b.fall >= interval:
		b.fall = 0.0
		if Rules.fits(b.board, b.position + Vector2i.DOWN, b.rotation):
			b.position += Vector2i.DOWN
	if not Rules.fits(b.board, b.position + Vector2i.DOWN, b.rotation):
		b.lock += delta
		if b.lock >= 0.42:
			_lock_piece(side)
	else:
		b.lock = 0.0


# CPUも現在の位置から到達可能な経路を一手ずつ進める。
func _cpu_move(side: int, delta: float) -> void:
	var b: Dictionary = boards[side]
	b.cpu_step -= delta
	if b.cpu_step > 0.0:
		return
	b.cpu_step = 0.025
	if b.cpu_plan.is_empty():
		_lock_piece(side)
		return
	var action: String = b.cpu_plan.pop_front()
	if action in ["left", "right", "down"]:
		var offset: Vector2i = {
			"left": Vector2i.LEFT, "right": Vector2i.RIGHT, "down": Vector2i.DOWN
		}[action]
		b.position += offset
	else:
		var turn: Dictionary = Rules.rotated(
			b.board, b.position, b.rotation, 1 if action == "rotate_right" else -1
		)
		b.position = turn.position
		b.rotation = turn.rotation


func can_control() -> bool:
	return screen == "play" and not paused and boards[0].phase == "falling"


# 相対移動入力を一回適用するため非冪等。
func move_piece(direction: int) -> void:
	if not can_control():
		return
	var b: Dictionary = boards[0]
	if Rules.fits(b.board, b.position + Vector2i(direction, 0), b.rotation):
		b.position.x += direction
		_reset_lock(b)
		effect.emit(0, "move", [], 0)


func rotate_piece(direction: int) -> void:
	if not can_control():
		return
	var b: Dictionary = boards[0]
	var result: Dictionary = Rules.rotated(b.board, b.position, b.rotation, direction)
	if result.valid:
		b.position = result.position
		b.rotation = result.rotation
		_reset_lock(b)
		effect.emit(0, "rotate", [], 0)


func _reset_lock(b: Dictionary) -> void:
	if b.resets < 8:
		b.lock = 0.0
		b.resets += 1


func hard_drop() -> void:
	if not can_control():
		return
	boards[0].position = Rules.drop_position(
		boards[0].board, boards[0].position, boards[0].rotation
	)
	_lock_piece(0)


func _lock_piece(side: int) -> void:
	var b: Dictionary = boards[side]
	var placed: Dictionary = Rules.place(b.board, b.position, b.rotation, b.pair)
	if placed.overflow:
		_finish(1 - side, "盤面の入口まで積み上がりました")
		return
	b.board = Rules.gravity(placed.board)
	b.phase = "land"
	b.timer = 0.20
	b.chain = 0
	board_changed.emit(side, "land")
	effect.emit(side, "land", Rules.cells(b.position, b.rotation), 0)


func _check_clear(side: int) -> void:
	var b: Dictionary = boards[side]
	b.clear = Rules.clear_groups(b.board)
	if b.clear.colored == 0:
		if b.pending > 0:
			_drop_nuisance(side)
		else:
			_spawn(side)
		return
	b.chain += 1
	var points: int = Rules.score_for(b.clear.colored, b.chain)
	b.score += points
	if side == 0:
		score += points
		max_chain = maxi(max_chain, b.chain)
	if mode == "cpu":
		var attack: int = Rules.attack_for(b.chain, b.clear.colored)
		var cancel: int = mini(attack, b.pending)
		b.pending -= cancel
		boards[1 - side].pending += attack - cancel
	b.phase = "clear"
	b.timer = 0.55
	effect.emit(side, "clear", b.clear.cleared, b.chain)


func _drop_nuisance(side: int) -> void:
	var b: Dictionary = boards[side]
	var amount: int = mini(b.pending, 12)
	b.pending -= amount
	var added: Dictionary = Rules.add_nuisance(b.board, amount, rng.randi_range(0, 5))
	b.board = added.board
	if added.overflow:
		_finish(1 - side, "予告ブロックで入口が埋まりました")
		return
	b.phase = "garbage"
	b.timer = 0.48
	board_changed.emit(side, "garbage")
	effect.emit(side, "garbage", added.placed, 0)


func _spawn(side: int) -> void:
	var b: Dictionary = boards[side]
	b.pair = b.next.pop_front()
	b.next.append(_pair())
	b.position = Vector2i(2, 0)
	b.rotation = 0
	b.fall = 0.0
	b.lock = 0.0
	b.resets = 0
	b.cpu_time = 0.0
	b.cpu_planned = false
	b.phase = "falling"
	if not Rules.fits(b.board, b.position, b.rotation):
		_finish(1 - side, "入口まで積み上がりました")
		return
	board_changed.emit(side, "spawn")


func _finish(winner: int, reason: String) -> void:
	if screen != "play":
		return
	round_winner = winner
	result_text = reason
	if mode == "cpu":
		wins[winner] += 1
		screen = "result" if wins[winner] >= 2 else "round"
	else:
		screen = "result"
	save_records()
	screen_changed.emit()
