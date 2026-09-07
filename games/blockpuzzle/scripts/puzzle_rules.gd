class_name PuzzleRules
extends RefCounted
## 盤面は上から順に 12 行、各行 6 列。0 は空、1〜4 は色、5 はおじゃま。
## 入力盤面を変更しないため、同じ引数で呼ぶと同じ結果を返す。

const WIDTH: int = 6
const HEIGHT: int = 12
const COLORS: int = 4
const NUISANCE: int = 5
const ROTATION_KICKS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


static func empty_board() -> Array:
	var board: Array = []
	for _row: int in range(HEIGHT):
		var row: Array = []
		row.resize(WIDTH)
		row.fill(0)
		board.append(row)
	return board


static func cells(position: Vector2i, rotation: int) -> Array[Vector2i]:
	return [position, position + DIRECTIONS[posmod(rotation, 4)]]


static func fits(board: Array, position: Vector2i, rotation: int) -> bool:
	for cell: Vector2i in cells(position, rotation):
		if cell.x < 0 or cell.x >= WIDTH or cell.y >= HEIGHT or cell.y < -2:
			return false
		if cell.y >= 0 and board[cell.y][cell.x] != 0:
			return false
	return true


static func rotated(board: Array, position: Vector2i, rotation: int, direction: int) -> Dictionary:
	var next_rotation: int = posmod(rotation + direction, 4)
	for offset: Vector2i in ROTATION_KICKS:
		if fits(board, position + offset, next_rotation):
			return {"position": position + offset, "rotation": next_rotation, "valid": true}
	return {"position": position, "rotation": rotation, "valid": false}


static func drop_position(board: Array, position: Vector2i, rotation: int) -> Vector2i:
	var destination: Vector2i = position
	if not fits(board, position, rotation):
		return destination
	while fits(board, destination + Vector2i.DOWN, rotation):
		destination += Vector2i.DOWN
	return destination


static func place(board: Array, position: Vector2i, rotation: int, pair: Array) -> Dictionary:
	var result: Array = board.duplicate(true)
	if pair.size() != 2 or not fits(board, position, rotation):
		return {"board": result, "overflow": true}
	var positions: Array[Vector2i] = cells(position, rotation)
	for index: int in range(2):
		if positions[index].y < 0 or not pair[index] in range(1, COLORS + 1):
			return {"board": result, "overflow": true}
	for index: int in range(2):
		result[positions[index].y][positions[index].x] = pair[index]
	return {"board": result, "overflow": false}


static func clear_groups(board: Array) -> Dictionary:
	var result: Array = board.duplicate(true)
	var visited: Dictionary = {}
	var removed: Dictionary = {}
	for y: int in range(HEIGHT):
		for x: int in range(WIDTH):
			var origin: Vector2i = Vector2i(x, y)
			if board[y][x] not in range(1, COLORS + 1) or visited.has(origin):
				continue
			var group: Array[Vector2i] = _group(board, origin)
			for cell: Vector2i in group:
				visited[cell] = true
			if group.size() >= 4:
				for cell: Vector2i in group:
					removed[cell] = true
	var colored: int = removed.size()
	# おじゃま同士では消去を伝播させないため、色の消去集合を固定して隣接を調べる。
	for cell: Vector2i in removed.keys():
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if _inside(neighbor) and board[neighbor.y][neighbor.x] == NUISANCE:
				removed[neighbor] = true
	var cleared: Array[Vector2i] = []
	for cell: Vector2i in removed:
		result[cell.y][cell.x] = 0
		cleared.append(cell)
	return {"board": result, "cleared": cleared, "colored": colored}


static func gravity(board: Array) -> Array:
	var result: Array = empty_board()
	for x: int in range(WIDTH):
		var destination: int = HEIGHT - 1
		for y: int in range(HEIGHT - 1, -1, -1):
			if board[y][x] != 0:
				result[destination][x] = board[y][x]
				destination -= 1
	return result


static func resolve(board: Array) -> Dictionary:
	var current: Array = gravity(board)
	var steps: Array[Dictionary] = []
	var score: int = 0
	var attack: int = 0
	while true:
		var cleared: Dictionary = clear_groups(current)
		if cleared.colored == 0:
			break
		var chain: int = steps.size() + 1
		var step_score: int = score_for(cleared.colored, chain)
		var step_attack: int = attack_for(chain, cleared.colored)
		var fallen: Array = gravity(cleared.board)
		steps.append(
			{
				"before": current,
				"cleared": cleared.cleared,
				"after_clear": cleared.board,
				"after_gravity": fallen,
				"chain": chain,
				"score": step_score,
				"attack": step_attack,
				"colored": cleared.colored
			}
		)
		score += step_score
		attack += step_attack
		current = fallen
	return {
		"board": current, "chains": steps.size(), "score": score, "attack": attack, "steps": steps
	}


static func score_for(cleared: int, chain: int) -> int:
	if cleared < 4 or chain < 1:
		return 0
	return cleared * 10 * (1 << mini(chain - 1, 18))


static func attack_for(chain: int, cleared: int) -> int:
	if chain < 1 or cleared < 4:
		return 0
	return maxi(0, cleared - 4) + (1 << mini(chain - 1, 8))


static func fall_interval(elapsed: float) -> float:
	return maxf(0.12, 0.85 - maxf(0.0, elapsed) * 0.004)


static func add_nuisance(board: Array, count: int, start_column: int = 0) -> Dictionary:
	var result: Array = gravity(board)
	var placed: Array[Vector2i] = []
	for index: int in range(maxi(0, count)):
		var x: int = posmod(start_column + index, WIDTH)
		var y: int = HEIGHT - 1
		while y >= 0 and result[y][x] != 0:
			y -= 1
		if y < 0:
			return {"board": result, "overflow": true, "placed": placed}
		result[y][x] = NUISANCE
		placed.append(Vector2i(x, y))
	return {"board": result, "overflow": false, "placed": placed}


static func parse_records(value: Variant) -> Dictionary:
	var records: Dictionary = {"high_score": 0, "best_chain": 0, "tutorial_seen": false}
	if not value is Dictionary:
		return records
	for key: String in ["high_score", "best_chain"]:
		var raw: Variant = value.get(key)
		if (raw is int or raw is float) and is_finite(float(raw)):
			records[key] = int(clampf(float(raw), 0.0, 1000000000.0))
	if value.get("tutorial_seen") is bool:
		records.tutorial_seen = value.tutorial_seen
	records.best_chain = mini(records.best_chain, (WIDTH * HEIGHT) >> 2)
	return records


static func cpu_choice(
	board: Array,
	pair: Array,
	difficulty: int,
	next_pair: Array = [],
	start_position: Vector2i = Vector2i(2, 0),
	start_rotation: int = 0
) -> Dictionary:
	var best: Dictionary = {}
	var best_value: float = -INF
	var lookahead_cache: Dictionary = {}
	for candidate: Dictionary in reachable_landings(board, start_position, start_rotation):
		var placement: Dictionary = place(board, candidate.position, candidate.rotation, pair)
		if placement.overflow:
			continue
		var outcome: Dictionary = resolve(placement.board)
		var value: float = _evaluation(outcome.board, difficulty)
		value += outcome.score * (0.2 if difficulty == 0 else 3.0)
		if difficulty >= 2 and next_pair.size() == 2:
			# 分離落下や消去で同じ盤面になる候補は、次組の探索を共有する。
			var board_key: PackedByteArray = var_to_bytes(outcome.board)
			if not lookahead_cache.has(board_key):
				lookahead_cache[board_key] = _lookahead(outcome.board, next_pair)
			value += lookahead_cache[board_key] * 0.7
		if value > best_value:
			best_value = value
			best = candidate
	return best


## 指定した現在位置から到達できる接地位置と、そこへ至る最短の操作列。
static func reachable_landings(
	board: Array, start_position: Vector2i = Vector2i(2, 0), start_rotation: int = 0
) -> Array[Dictionary]:
	var spawn: Vector3i = Vector3i(start_position.x, start_position.y, posmod(start_rotation, 4))
	var landings: Array[Dictionary] = []
	if not fits(board, Vector2i(spawn.x, spawn.y), spawn.z):
		return landings
	var valid: Dictionary = {}
	for y: int in range(-2, HEIGHT):
		for x: int in range(WIDTH):
			for rotation: int in range(4):
				if fits(board, Vector2i(x, y), rotation):
					valid[Vector3i(x, y, rotation)] = true
	var queue: Array[Vector3i] = [spawn]
	var parents: Dictionary = {spawn: spawn}
	var actions: Dictionary = {}
	var index: int = 0
	while index < queue.size():
		var current: Vector3i = queue[index]
		var position: Vector2i = Vector2i(current.x, current.y)
		var can_fall: bool = valid.has(current + Vector3i(0, 1, 0))
		if not can_fall and position.y >= 0 and position.y + DIRECTIONS[current.z].y >= 0:
			landings.append(
				{
					"position": position,
					"rotation": current.z,
					"path": _input_path(current, spawn, parents, actions)
				}
			)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor: Vector3i = Vector3i(
				current.x + direction.x, current.y + direction.y, current.z
			)
			if parents.has(neighbor) or not valid.has(neighbor):
				continue
			parents[neighbor] = current
			actions[neighbor] = (
				"down" if direction.y == 1 else ("left" if direction.x == -1 else "right")
			)
			queue.append(neighbor)
		for direction: int in [-1, 1]:
			var rotation: int = posmod(current.z + direction, 4)
			for kick: Vector2i in ROTATION_KICKS:
				var neighbor: Vector3i = Vector3i(current.x + kick.x, current.y + kick.y, rotation)
				if not valid.has(neighbor):
					continue
				if not parents.has(neighbor):
					parents[neighbor] = current
					actions[neighbor] = "rotate_left" if direction == -1 else "rotate_right"
					queue.append(neighbor)
				break
		index += 1
	return landings


static func _input_path(
	destination: Vector3i, spawn: Vector3i, parents: Dictionary, actions: Dictionary
) -> Array[String]:
	var path: Array[String] = []
	var current: Vector3i = destination
	while current != spawn:
		path.append(actions[current])
		current = parents[current]
	path.reverse()
	return path


static func _lookahead(board: Array, pair: Array) -> float:
	var best_value: float = -10000.0
	for candidate: Dictionary in reachable_landings(board):
		var placement: Dictionary = place(board, candidate.position, candidate.rotation, pair)
		if placement.overflow:
			continue
		var outcome: Dictionary = resolve(placement.board)
		best_value = maxf(best_value, outcome.score * 3.0 + _evaluation(outcome.board, 1))
	return best_value


static func _evaluation(board: Array, difficulty: int) -> float:
	var value: float = 0.0
	for x: int in range(WIDTH):
		var height: int = 0
		for y: int in range(HEIGHT):
			if board[y][x] == 0:
				continue
			height = maxi(height, HEIGHT - y)
			if difficulty > 0 and board[y][x] != NUISANCE:
				for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
					var neighbor: Vector2i = Vector2i(x, y) + direction
					if _inside(neighbor) and board[neighbor.y][neighbor.x] == board[y][x]:
						value += 13.0
		value -= height * height * (2.0 if difficulty > 0 else 5.0)
		if x == 2 and height >= HEIGHT - 2:
			value -= 500.0
	return value


static func _group(board: Array, origin: Vector2i) -> Array[Vector2i]:
	var group: Array[Vector2i] = [origin]
	var index: int = 0
	while index < group.size():
		for direction: Vector2i in DIRECTIONS:
			var neighbor: Vector2i = group[index] + direction
			if not _inside(neighbor) or group.has(neighbor):
				continue
			if board[neighbor.y][neighbor.x] == board[origin.y][origin.x]:
				group.append(neighbor)
		index += 1
	return group


static func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT
