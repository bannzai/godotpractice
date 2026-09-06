extends Node2D
## 地形・視界・探索済み地図は RunState の同じダンジョンを参照する。

const TILE: int = 40
const COLS: int = 23
const ROWS: int = 13
const Data := preload("res://scripts/game_data.gd")
const UI := preload("res://scripts/ui.gd")

var run: Node
var origin: Vector2i = Vector2i.ZERO
var map_open: bool = false
var textures: Dictionary = {}
var minimap: Node2D


func _ready() -> void:
	minimap = Node2D.new()
	minimap.z_index = 15
	add_child(minimap)
	minimap.draw.connect(_draw_minimap)
	run = get_node("/root/RunState")
	for kind: String in ["floor", "wall"]:
		textures[kind] = load("res://assets/tiles/" + kind + ".svg")
	for kind: String in [
		"stairs", "weapon", "shield", "herb", "food", "scroll_fire", "scroll_warp", "wand", "coin"
	]:
		textures[kind] = load("res://assets/items/" + kind + ".svg")


func refresh() -> void:
	origin = run.player_pos - Vector2i(COLS / 2, ROWS / 2)
	queue_redraw()


func point(cell: Vector2i) -> Vector2:
	return Vector2(cell - origin) * TILE + Vector2.ONE * TILE * 0.5


func _draw() -> void:
	if not is_instance_valid(run) or run.dungeon == null:
		return
	draw_rect(Rect2(0, 0, COLS * TILE, ROWS * TILE), Color("101923"))
	for y: int in range(ROWS):
		for x: int in range(COLS):
			var cell := origin + Vector2i(x, y)
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if not run.dungeon.explored.has(cell):
				continue
			var visible_cell: bool = run.dungeon.visible.has(cell)
			var tint := Color.WHITE if visible_cell else Color("465563")
			var kind: String = "floor" if run.dungeon.is_floor(cell) else "wall"
			draw_texture_rect(textures[kind], rect, false, tint)
			if cell == run.dungeon.stairs:
				draw_texture_rect(textures.stairs, rect.grow(-3), false, tint)
	for item: Dictionary in run.ground_items:
		var image_name: String = str(Data.ITEMS.get(item.kind, {}).get("image", item.kind))
		if run.dungeon.visible.has(item.pos) and textures.has(image_name):
			draw_texture_rect(
				textures[image_name],
				Rect2(point(item.pos) - Vector2(16, 16), Vector2(32, 32)),
				false
			)
	var hero: Vector2 = point(run.player_pos)
	draw_arc(hero, 19, 0, TAU, 32, UI.GOLD, 1.5, true)
	draw_line(hero + Vector2(run.facing) * 18, hero + Vector2(run.facing) * 26, UI.GOLD, 3)
	minimap.queue_redraw()


func _draw_minimap() -> void:
	var scale_map: float = 8.0 if map_open else 5.0
	var base := Vector2(950, 290)
	if map_open:
		base = Vector2(290, 135)
		minimap.draw_rect(Rect2(base - Vector2(20, 40), Vector2(345, 225)), Color("102330f5"))
	for cell: Vector2i in run.dungeon.explored:
		if not run.dungeon.is_floor(cell):
			continue
		var color := Color("547278")
		if run.dungeon.visible.has(cell):
			color = UI.TEAL.darkened(0.3)
		minimap.draw_rect(
			Rect2(base + Vector2(cell) * scale_map, Vector2.ONE * (scale_map - 1)), color
		)
	if run.dungeon.explored.has(run.dungeon.stairs):
		minimap.draw_circle(
			base + Vector2(run.dungeon.stairs) * scale_map, scale_map * 0.7, UI.GOLD
		)
	minimap.draw_circle(base + Vector2(run.player_pos) * scale_map, scale_map * 0.65, Color.WHITE)
