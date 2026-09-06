class_name RogueDungeon
extends RefCounted
## seed と階で一意になる部屋・通路。視界は床から導出する。

const WIDTH: int = 38
const HEIGHT: int = 22
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var rooms: Array[Rect2i] = []
var floor_cells: Dictionary = {}
var visible: Dictionary = {}
var explored: Dictionary = {}
var stairs: Vector2i = Vector2i.ZERO
var entrance: Vector2i = Vector2i.ZERO


func generate(seed_value: int, depth: int) -> void:
	rooms.clear()
	floor_cells.clear()
	visible.clear()
	explored.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + depth * 104729
	var slots: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7]
	for index: int in range(slots.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: int = slots[index]
		slots[index] = slots[other]
		slots[other] = value
	for index: int in range(rng.randi_range(4, 8)):
		var slot: int = slots[index]
		var origin: Vector2i = Vector2i(1 + (slot % 4) * 9, 1 + (slot / 4) * 10)
		var room: Rect2i = Rect2i(origin + Vector2i(rng.randi_range(0, 1),
			rng.randi_range(0, 2)), Vector2i(rng.randi_range(5, 7), rng.randi_range(5, 7)))
		rooms.append(room)
		for x: int in range(room.position.x, room.end.x):
			for y: int in range(room.position.y, room.end.y):
				floor_cells[Vector2i(x, y)] = true
		if index > 0:
			_carve_corridor(rooms[index - 1].get_center(), room.get_center())
	entrance = rooms[0].get_center()
	stairs = rooms[-1].get_center()
	update_visibility(entrance)


func is_floor(cell: Vector2i) -> bool:
	return floor_cells.has(cell)


func can_step(from: Vector2i, to: Vector2i) -> bool:
	var difference: Vector2i = to - from
	if not is_floor(to) or absi(difference.x) > 1 or absi(difference.y) > 1:
		return false
	if difference.x != 0 and difference.y != 0:
		return is_floor(from + Vector2i(difference.x, 0)) and is_floor(
			from + Vector2i(0, difference.y))
	return true


func room_at(cell: Vector2i) -> int:
	for index: int in range(rooms.size()):
		if rooms[index].has_point(cell):
			return index
	return -1


func same_room(first: Vector2i, second: Vector2i) -> bool:
	return room_at(first) >= 0 and room_at(first) == room_at(second)


func line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	var previous: Vector2i = from
	for index: int in range(1, steps + 1):
		var point: Vector2i = Vector2i(Vector2(from).lerp(Vector2(to), float(index) / steps).round())
		if index < steps and not is_floor(point):
			return false
		var difference: Vector2i = point - previous
		if difference.x != 0 and difference.y != 0:
			if not is_floor(previous + Vector2i(difference.x, 0)) or not is_floor(
				previous + Vector2i(0, difference.y)):
				return false
		previous = point
	return true


func update_visibility(position: Vector2i) -> void:
	visible.clear()
	var room_index: int = room_at(position)
	for x: int in range(WIDTH):
		for y: int in range(HEIGHT):
			var cell: Vector2i = Vector2i(x, y)
			var in_room: bool = room_index >= 0 and rooms[room_index].grow(1).has_point(cell)
			if in_room or (position.distance_to(cell) <= 4.2 and line_of_sight(position, cell)):
				visible[cell] = true
				explored[cell] = true


func connected() -> bool:
	var found: Dictionary = {entrance: true}
	var pending: Array[Vector2i] = [entrance]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = cell + direction
			if is_floor(next) and not found.has(next):
				found[next] = true
				pending.append(next)
	return found.size() == floor_cells.size() and found.has(stairs)


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	var cursor: Vector2i = from
	while cursor.x != to.x:
		floor_cells[cursor] = true
		cursor.x += signi(to.x - cursor.x)
	while cursor.y != to.y:
		floor_cells[cursor] = true
		cursor.y += signi(to.y - cursor.y)
	floor_cells[to] = true
