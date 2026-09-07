extends Node

signal changed
signal cleared_group(cells: Array[Vector2i], chain: int)
signal landed
signal ended

const WIDTH: int = 6
const HEIGHT: int = 12
const COLOR_COUNT: int = 4
const CLEAR_DELAY: float = 0.42
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

@export var record_path: String = "user://record.cfg"

var board: Array = []
var pair: Array[int] = []
var next_pair: Array[int] = []
var pivot: Vector2i = Vector2i(2, 1)
var rotation: int = 0
var score: int = 0
var best_score: int = 0
var chains: int = 0
var best_chain: int = 0
var level: int = 1
var cleared: int = 0
var phase: String = "ready"
var pending: Array[Vector2i] = []
var save_enabled: bool = true
var _fall_time: float = 0.0
var _clear_time: float = 0.0
var _resume_phase: String = "playing"
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var data: ConfigFile = ConfigFile.new()
	if data.load(record_path) == OK:
		best_score = maxi(0, int(data.get_value("record", "score", 0)))
	_reset_board()
	next_pair = _new_pair()


# 新しい一局ごとに乱数を消費するため、開始操作は冪等ではない。
func start() -> void:
	_reset_board()
	score = 0
	chains = 0
	best_chain = 0
	cleared = 0
	level = 1
	pending.clear()
	_fall_time = 0.0
	_clear_time = 0.0
	next_pair = _new_pair()
	_spawn()


func _reset_board() -> void:
	board.clear()
	for y: int in range(HEIGHT):
		var row: Array[int] = []
		row.resize(WIDTH)
		row.fill(-1)
		board.append(row)


# ペアの供給ごとに乱数列を進める必要がある。
func _new_pair() -> Array[int]:
	return [_random.randi_range(0, COLOR_COUNT - 1), _random.randi_range(0, COLOR_COUNT - 1)]


# 次のペアを消費するゲーム進行なので、冪等ではない。
func _spawn() -> void:
	pair = next_pair.duplicate()
	next_pair = _new_pair()
	pivot = Vector2i(2, 1)
	rotation = 0
	_fall_time = 0.0
	phase = "playing"
	if not _fits(pivot, rotation):
		_finish()
	changed.emit()


func cells() -> Array[Vector2i]:
	return [pivot, pivot + DIRECTIONS[rotation]]


func ghost_cells() -> Array[Vector2i]:
	var target: Vector2i = pivot
	while _fits(target + Vector2i.DOWN, rotation):
		target += Vector2i.DOWN
	return [target, target + DIRECTIONS[rotation]]


func _fits(position: Vector2i, turn: int) -> bool:
	for cell: Vector2i in [position, position + DIRECTIONS[turn]]:
		if cell.x < 0 or cell.x >= WIDTH or cell.y < 0 or cell.y >= HEIGHT:
			return false
		if board[cell.y][cell.x] != -1:
			return false
	return true


# 入力一回ごとに位置を変えるため、冪等ではない。
func move(dx: int) -> bool:
	if phase != "playing" or absi(dx) != 1:
		return false
	if not _fits(pivot + Vector2i(dx, 0), rotation):
		return false
	pivot.x += dx
	changed.emit()
	return true


# 回転入力を累積するため、冪等ではない。蹴りは一マスに限りすり抜けを防ぐ。
func rotate_piece(direction: int) -> bool:
	if phase != "playing" or absi(direction) != 1:
		return false
	var target_rotation: int = posmod(rotation + direction, 4)
	for kick: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if _fits(pivot + kick, target_rotation):
			pivot += kick
			rotation = target_rotation
			changed.emit()
			return true
	return false


# 落下を一段進める操作なので、冪等ではない。
func step() -> void:
	if phase != "playing":
		return
	if _fits(pivot + Vector2i.DOWN, rotation):
		pivot.y += 1
		changed.emit()
	else:
		_lock_pair()


# 即落下はペアを固定し次の手番に進めるため、冪等ではない。
func drop() -> void:
	if phase != "playing":
		return
	var destination: Vector2i = ghost_cells()[0]
	score += (destination.y - pivot.y) * 2
	pivot = destination
	_lock_pair()


# 経過時間を積算するゲームループなので、冪等ではない。
func tick(delta: float) -> void:
	if phase == "playing":
		_fall_time += maxf(delta, 0.0)
		var interval: float = maxf(0.13, 0.85 - (level - 1) * 0.065)
		if _fall_time >= interval:
			_fall_time = 0.0
			step()
	elif phase == "clearing":
		_clear_time += maxf(delta, 0.0)
		if _clear_time >= CLEAR_DELAY:
			for cell: Vector2i in pending:
				board[cell.y][cell.x] = -1
			pending.clear()
			_apply_gravity()
			_resolve()


# 一時停止のトグルは入力ごとに状態を反転するため、冪等ではない。
func toggle_pause() -> void:
	if phase == "paused":
		phase = _resume_phase
	elif phase == "playing" or phase == "clearing":
		_resume_phase = phase
		phase = "paused"
	changed.emit()


# 固定は盤面と手番を進めるため、冪等ではない。
func _lock_pair() -> void:
	var positions: Array[Vector2i] = cells()
	for index: int in range(2):
		board[positions[index].y][positions[index].x] = pair[index]
	chains = 0
	_apply_gravity()
	landed.emit()
	_resolve()


func _apply_gravity() -> void:
	for x: int in range(WIDTH):
		var destination: int = HEIGHT - 1
		for y: int in range(HEIGHT - 1, -1, -1):
			if board[y][x] != -1:
				var color: int = board[y][x]
				board[y][x] = -1
				board[destination][x] = color
				destination -= 1


func _matching_cells() -> Array[Vector2i]:
	var matches: Array[Vector2i] = []
	var visited: Dictionary = {}
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var origin: Vector2i = Vector2i(x, y)
			if board[y][x] < 0 or visited.has(origin):
				continue
			var group: Array[Vector2i] = [origin]
			visited[origin] = true
			var index: int = 0
			while index < group.size():
				for direction: Vector2i in DIRECTIONS:
					var neighbor: Vector2i = group[index] + direction
					if neighbor.x < 0 or neighbor.x >= WIDTH or neighbor.y < 0 or neighbor.y >= HEIGHT:
						continue
					if not visited.has(neighbor) and board[neighbor.y][neighbor.x] == board[y][x]:
						visited[neighbor] = true
						group.append(neighbor)
				index += 1
			if group.size() >= 4:
				matches.append_array(group)
	return matches


# 消去成立時に得点と連鎖段数を一回加算し、次の手番へ進める。
func _resolve() -> void:
	pending = _matching_cells()
	if pending.is_empty():
		_spawn()
		return
	chains += 1
	best_chain = maxi(best_chain, chains)
	cleared += pending.size()
	level = 1 + floori(float(cleared) / 24.0)
	score += pending.size() * 10 * chains * chains
	best_score = maxi(best_score, score)
	phase = "clearing"
	_clear_time = 0.0
	cleared_group.emit(pending.duplicate(), chains)
	changed.emit()


func _finish() -> void:
	if phase == "over":
		return
	phase = "over"
	best_score = maxi(best_score, score)
	if save_enabled:
		var data: ConfigFile = ConfigFile.new()
		data.set_value("record", "score", best_score)
		var error: Error = data.save(record_path)
		if error != OK:
			push_warning("記録の保存に失敗しました: %s" % error_string(error))
	ended.emit()
