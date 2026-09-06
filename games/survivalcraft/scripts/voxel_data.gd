extends RefCounted
## 小島のブロック配置。座標は各ブロックの最小端を表す。

const SIZE := Vector3i(32, 16, 32)
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const WOOD := 4
const LEAVES := 5
const SAND := 6
const WATER := 7
const PLANK := 8
const BENCH := 9
const TORCH := 10
const ORE := 11
const ITEMS := {
	GRASS: "dirt", DIRT: "dirt", STONE: "stone", WOOD: "wood", LEAVES: "leaf",
	SAND: "sand", WATER: "water", PLANK: "plank", BENCH: "bench", TORCH: "torch", ORE: "ore"
}
const HARDNESS := {
	GRASS: 0.65, DIRT: 0.55, STONE: 1.8, WOOD: 1.1, LEAVES: 0.25, SAND: 0.45,
	WATER: 99.0, PLANK: 0.6, BENCH: 0.8, TORCH: 0.2, ORE: 2.4
}

var blocks: Dictionary = {}
var seed_value: int = 0
var spawn: Vector3 = Vector3.ZERO


func generate(world_seed: int) -> void:
	blocks.clear()
	seed_value = world_seed
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.1
	for x: int in SIZE.x:
		for z: int in SIZE.z:
			var radius: float = Vector2(x - 15.5, z - 15.5).length()
			var height: int = clampi(int(7.5 - radius * 0.29 + noise.get_noise_2d(x, z) * 2), 1, 9)
			if x >= 13 and x <= 19 and z >= 13 and z <= 19:
				height = 6
			for y: int in range(height + 1):
				var id: int = STONE if y < height - 2 else DIRT
				if y == height:
					id = SAND if height <= 3 else GRASS
				if y == height - 2 and (x * 17 + z * 11 + world_seed) % 19 == 0:
					id = ORE
				set_block(Vector3i(x, y, z), id)
			for y: int in range(height + 1, 4):
				set_block(Vector3i(x, y, z), WATER)
	for point: Vector2i in [Vector2i(9, 12), Vector2i(23, 18), Vector2i(11, 23), Vector2i(21, 8)]:
		_grow_tree(point)
	spawn = Vector3(16.5, surface_y(16, 16) + 1.05, 16.5)


func _grow_tree(point: Vector2i) -> void:
	var ground: int = surface_y(point.x, point.y)
	for y: int in range(ground + 1, ground + 5):
		set_block(Vector3i(point.x, y, point.y), WOOD)
	for x: int in range(-2, 3):
		for z: int in range(-2, 3):
			for y: int in range(ground + 3, ground + 6):
				var cell := Vector3i(point.x + x, y, point.y + z)
				if abs(x) + abs(z) < 4 and get_block(cell) == AIR:
					set_block(cell, LEAVES)


func in_bounds(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.z >= 0 and cell.x < SIZE.x \
		and cell.y < SIZE.y and cell.z < SIZE.z


func get_block(cell: Vector3i) -> int:
	return int(blocks.get(cell, AIR))


func set_block(cell: Vector3i, id: int) -> void:
	if not in_bounds(cell) or id < AIR or id > ORE:
		return
	if id == AIR:
		blocks.erase(cell)
	else:
		blocks[cell] = id


func is_solid(cell: Vector3i) -> bool:
	return get_block(cell) not in [AIR, WATER, TORCH]


func surface_y(x: int, z: int) -> int:
	for y: int in range(SIZE.y - 1, -1, -1):
		if is_solid(Vector3i(x, y, z)):
			return y
	return -1


func serialize() -> Dictionary:
	var cells: Array = []
	for cell: Vector3i in blocks:
		cells.append([cell.x, cell.y, cell.z, blocks[cell]])
	return {"seed": seed_value, "spawn": [spawn.x, spawn.y, spawn.z], "cells": cells}


func deserialize(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["seed", "spawn", "cells"]):
		return false
	if not _integer(value.seed) or not value.cells is Array or value.cells.size() > 16384:
		return false
	if not value.spawn is Array or value.spawn.size() != 3 \
		or not _valid_coordinates(value.spawn):
		return false
	var restored: Dictionary = _decode_cells(value.cells)
	if restored.is_empty():
		return false
	var point := Vector3(float(value.spawn[0]), float(value.spawn[1]), float(value.spawn[2]))
	if point.x < 0 or point.x >= SIZE.x or point.z < 0 or point.z >= SIZE.z \
		or point.y < 0 or point.y > SIZE.y + 2:
		return false
	blocks = restored
	spawn = point
	seed_value = int(value.seed)
	return true


func _valid_coordinates(coordinates: Array) -> bool:
	for coordinate: Variant in coordinates:
		if not coordinate is float and not coordinate is int:
			return false
		if not is_finite(float(coordinate)):
			return false
	return true


func _decode_cells(rows: Array) -> Dictionary:
	var restored: Dictionary = {}
	for row: Variant in rows:
		if not row is Array or row.size() != 4:
			return {}
		for number: Variant in row:
			if not _integer(number):
				return {}
		var cell := Vector3i(int(row[0]), int(row[1]), int(row[2]))
		if not in_bounds(cell) or int(row[3]) < GRASS or int(row[3]) > ORE or restored.has(cell):
			return {}
		restored[cell] = int(row[3])
	return restored


func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floorf(float(value))
