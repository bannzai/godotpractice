class_name QuestWorld
extends Node2D
## 地形はセルと地域だけで決まり、進行状況は保持しない。

const GRID := Vector2i(24, 14)
const CELL_SIZE := 40
const FONT = preload("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
const INK := Color("283e43")

var visual_player: Sprite2D
var _ground: TileMapLayer
var _zone := "town"


func setup(zone: String) -> void:
	_zone = zone
	if not is_instance_valid(_ground):
		_ground = TileMapLayer.new()
		_ground.show_behind_parent = true
		_ground.scale = Vector2.ONE * float(CELL_SIZE) / 48.0
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load("res://assets/tiles.svg") as Texture2D
		atlas.texture_region_size = Vector2i(48, 48)
		for index in range(6):
			atlas.create_tile(Vector2i(index, 0))
		var tiles := TileSet.new()
		tiles.tile_size = Vector2i(48, 48)
		tiles.add_source(atlas, 0)
		_ground.tile_set = tiles
		add_child(_ground)
		visual_player = Sprite2D.new()
		visual_player.texture = load("res://assets/player.svg") as Texture2D
		visual_player.scale = Vector2.ONE * float(CELL_SIZE) / 48.0
		visual_player.z_index = 0
		add_child(visual_player)
	_ground.clear()
	for y in range(GRID.y):
		for x in range(GRID.x):
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, 0, Vector2i(tile(zone, cell), 0))
	queue_redraw()


func set_player(cell: Vector2i) -> void:
	visual_player.position = Vector2(cell * CELL_SIZE) + Vector2.ONE * CELL_SIZE / 2.0


static func tile(zone: String, cell: Vector2i) -> int:
	if not Rect2i(Vector2i.ZERO, GRID).has_point(cell):
		return 3
	if zone == "home" or zone == "clinic":
		return 5
	if cell.y == 0 or cell.y == 13 or cell.x == 0 or cell.x == 23:
		if cell == Vector2i(23, 7) and zone == "town":
			return 1
		if cell == Vector2i(0, 7) and zone == "route":
			return 1
		return 3
	return _route_tile(cell) if zone == "route" else _town_tile(cell)


static func walkable(zone: String, cell: Vector2i) -> bool:
	if not Rect2i(Vector2i.ZERO, GRID).has_point(cell):
		return false
	if zone == "home" or zone == "clinic":
		return _indoor_walkable(zone, cell)
	if zone == "town":
		if Rect2i(3, 2, 5, 4).has_point(cell) or Rect2i(9, 2, 5, 4).has_point(cell):
			return false
		if cell == Vector2i(18, 6):
			return false
	return tile(zone, cell) != 3 and tile(zone, cell) != 4


static func is_grass(zone: String, cell: Vector2i) -> bool:
	return zone == "route" and tile(zone, cell) == 2


static func portal(zone: String, cell: Vector2i) -> Dictionary:
	if zone == "town":
		match cell:
			Vector2i(23, 7):
				return {"zone": "route", "cell": Vector2i(1, 7)}
			Vector2i(5, 6):
				return {"zone": "home", "cell": Vector2i(11, 11)}
			Vector2i(11, 6):
				return {"zone": "clinic", "cell": Vector2i(11, 11)}
	if zone == "route" and cell == Vector2i(0, 7):
		return {"zone": "town", "cell": Vector2i(22, 7)}
	if cell == Vector2i(11, 12):
		if zone == "home":
			return {"zone": "town", "cell": Vector2i(5, 7)}
		if zone == "clinic":
			return {"zone": "town", "cell": Vector2i(11, 7)}
	return {}


static func _town_tile(cell: Vector2i) -> int:
	if Rect2i(1, 9, 3, 3).has_point(cell):
		return 4
	if cell.y == 7 or cell.y == 8:
		return 1
	if cell.x in [5, 11, 18] and cell.y >= 6 and cell.y <= 11:
		return 1
	if Rect2i(16, 4, 5, 3).has_point(cell):
		return 1
	return 0


static func _route_tile(cell: Vector2i) -> int:
	if Rect2i(11, 2, 3, 4).has_point(cell):
		return 4
	if cell.y == 7 or cell.y == 8:
		return 1
	if Rect2i(3, 2, 7, 4).has_point(cell) or Rect2i(3, 9, 7, 3).has_point(cell):
		return 2
	if Rect2i(15, 2, 7, 10).has_point(cell):
		return 2
	return 0


static func _indoor_walkable(zone: String, cell: Vector2i) -> bool:
	if not Rect2i(2, 2, 20, 11).has_point(cell):
		return false
	if cell.y == 12:
		return cell.x == 11
	if zone == "home":
		return not (Rect2i(3, 3, 5, 3).has_point(cell)
			or Rect2i(16, 3, 5, 3).has_point(cell))
	return not (Rect2i(4, 3, 5, 3).has_point(cell)
		or Rect2i(15, 3, 5, 3).has_point(cell))


func _draw() -> void:
	if _zone == "town":
		_draw_town()
	elif _zone == "route":
		_draw_route()
	else:
		_draw_room()
	draw_rect(Rect2(0, 0, 960, 560), Color("597a61"), false, 3.0)


func _draw_town() -> void:
	_draw_building(Vector2(120, 80), "旅人の家", Color("c67c57"), false)
	_draw_building(Vector2(360, 80), "回復と預かり", Color("63aaa6"), true)
	_draw_flowers(Vector2(60, 210), Color("ffddb5"))
	_draw_flowers(Vector2(600, 410), Color("f6adc2"))
	_draw_flowers(Vector2(820, 410), Color("ffe1a3"))
	_draw_sign(Vector2(636, 111), "見守り隊の広場")
	draw_rect(Rect2(655, 178, 170, 94), Color("ccb99a"))
	draw_rect(Rect2(660, 182, 160, 84), Color("e1d0af"), false, 3.0)
	_draw_captain(Vector2(740, 260))
	_draw_sign(Vector2(805, 335), "草原へ →")
	_draw_sign(Vector2(202, 451), "こもれびの町")
	_draw_bench(Vector2(556, 355))
	draw_arc(Vector2(92, 417), 27, 0.1, 2.7, 20, Color("b7dfdc"), 2.0)
	for point in [Vector2(61, 390), Vector2(123, 447)]:
		draw_circle(point, 8, Color("82ad68"))
		draw_circle(point + Vector2(3, -2), 3, Color("f0d89f"))


func _draw_route() -> void:
	_draw_sign(Vector2(74, 337), "← こもれびの町")
	_draw_sign(Vector2(439, 392), "草むらで仲間を探そう")
	_draw_flowers(Vector2(431, 445), Color("f0d5a5"))
	_draw_flowers(Vector2(546, 254), Color("f4a9b8"))
	for index in range(3):
		var center := Vector2(468 + index * 20, 121 + index * 29)
		draw_arc(center, 13, 0.2, 2.5, 16, Color("b8e2df"), 2.0)
	_draw_bench(Vector2(476, 350))


func _draw_building(origin: Vector2, title: String, roof: Color, clinic: bool) -> void:
	draw_rect(Rect2(origin + Vector2(5, 15), Vector2(190, 149)), Color("496650", 0.3))
	draw_rect(Rect2(origin + Vector2(12, 50), Vector2(176, 110)), Color("f0d9ae"))
	draw_rect(Rect2(origin + Vector2(12, 142), Vector2(176, 18)), Color("c0a47b"))
	var points := PackedVector2Array([
		origin + Vector2(0, 58), origin + Vector2(28, 0),
		origin + Vector2(172, 0), origin + Vector2(200, 58)])
	draw_colored_polygon(points, roof)
	draw_line(origin + Vector2(0, 58), origin + Vector2(200, 58), roof.darkened(0.22), 6)
	for index in range(4):
		draw_line(origin + Vector2(30 + index * 43, 9),
			origin + Vector2(16 + index * 54, 48), roof.lightened(0.14), 2)
	for x in [34, 138]:
		draw_rect(Rect2(origin + Vector2(x, 80), Vector2(28, 34)), Color("78b3bd"))
		draw_rect(Rect2(origin + Vector2(x, 80), Vector2(28, 34)), Color("fff0cd"), false, 3)
		draw_line(origin + Vector2(x + 14, 80), origin + Vector2(x + 14, 114),
			Color("fff0cd"), 2)
	draw_rect(Rect2(origin + Vector2(82, 116), Vector2(36, 44)), Color("655549"))
	draw_rect(Rect2(origin + Vector2(80, 160), Vector2(40, 36)), Color("d3bda0"))
	draw_rect(Rect2(origin + Vector2(85, 166), Vector2(30, 22)), roof.darkened(0.1))
	_draw_label(origin + Vector2(23, 76), title, 15, INK)
	if clinic:
		draw_rect(Rect2(origin + Vector2(92, 15), Vector2(16, 33)), Color("eef8e5"))
		draw_rect(Rect2(origin + Vector2(83, 24), Vector2(34, 15)), Color("eef8e5"))


func _draw_captain(center: Vector2) -> void:
	draw_ellipse_shadow(center + Vector2(0, 12))
	draw_rect(Rect2(center + Vector2(-10, -1), Vector2(20, 22)), Color("597891"))
	draw_circle(center + Vector2(0, -9), 10, Color("efc699"))
	draw_rect(Rect2(center + Vector2(-12, -20), Vector2(24, 9)), Color("3d526c"))
	draw_rect(Rect2(center + Vector2(-15, -13), Vector2(30, 4)), Color("3d526c"))
	draw_circle(center + Vector2(5, 4), 3, Color("efd18a"))
	_draw_label(center + Vector2(-18, -29), "隊長", 15, INK)


func draw_ellipse_shadow(center: Vector2) -> void:
	draw_set_transform(center, 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 18, Color(0.16, 0.24, 0.19, 0.25))
	draw_set_transform(Vector2.ZERO)


func _draw_flowers(origin: Vector2, color: Color) -> void:
	for index in range(7):
		var point := origin + Vector2((index * 19) % 65, (index * 13) % 34)
		draw_line(point, point + Vector2(0, 9), Color("547a50"), 2)
		draw_circle(point, 4, color)
		draw_circle(point, 1.5, Color("f9edb6"))


func _draw_sign(origin: Vector2, title: String) -> void:
	var width := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20
	draw_rect(Rect2(origin + Vector2(width / 2 - 3, 18), Vector2(6, 20)), Color("846f50"))
	draw_rect(Rect2(origin, Vector2(width, 28)), Color("efdbac"))
	draw_rect(Rect2(origin, Vector2(width, 28)), Color("a98c62"), false, 2)
	_draw_label(origin + Vector2(10, 20), title, 15, INK)


func _draw_bench(origin: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(5, 15), Vector2(7, 12)), Color("706b55"))
	draw_rect(Rect2(origin + Vector2(49, 15), Vector2(7, 12)), Color("706b55"))
	draw_rect(Rect2(origin, Vector2(62, 9)), Color("b49667"))
	draw_rect(Rect2(origin + Vector2(0, 12), Vector2(62, 8)), Color("ccb386"))


func _draw_room() -> void:
	draw_rect(Rect2(0, 0, 960, 80), Color("647f78"))
	draw_rect(Rect2(0, 80, 80, 480), Color("8aa69a"))
	draw_rect(Rect2(880, 80, 80, 480), Color("8aa69a"))
	draw_rect(Rect2(80, 480, 800, 80), Color("8aa69a"))
	draw_rect(Rect2(80, 78, 800, 6), Color("bbcfb2"))
	draw_rect(Rect2(440, 480, 40, 40), Color("e5cb96"))
	draw_rect(Rect2(328, 285, 304, 152), Color("b9c5a2"))
	draw_rect(Rect2(337, 294, 286, 134), Color("d9dfc0"), false, 3)
	var title := "旅人の家 ・ ひと休み" if _zone == "home" else "回復と預かりの家"
	_draw_label(Vector2(100, 52), title, 25, Color("fff0ce"))
	_draw_sign(Vector2(408, 522), "町へ戻る ↓")
	if _zone == "home":
		_draw_home_furniture()
	else:
		_draw_clinic_furniture()


func _draw_home_furniture() -> void:
	draw_rect(Rect2(120, 120, 200, 120), Color("8e7359"))
	draw_rect(Rect2(130, 126, 180, 102), Color("e7c899"))
	draw_rect(Rect2(143, 136, 44, 35), Color("f7edcf"))
	draw_rect(Rect2(195, 132, 105, 86), Color("79a8a0"))
	draw_line(Vector2(205, 132), Vector2(205, 218), Color("b6d3b8"), 5)
	_draw_shelf(Vector2(640, 120))
	_draw_label(Vector2(129, 272), "ここで冒険を保存できます", 18, INK)
	_draw_label(Vector2(352, 365), "おかえりなさい", 25, INK)


func _draw_clinic_furniture() -> void:
	draw_rect(Rect2(160, 120, 200, 120), Color("ae9472"))
	draw_rect(Rect2(166, 126, 188, 100), Color("e3dbb5"))
	draw_circle(Vector2(260, 166), 29, Color("7da9a0"))
	draw_rect(Rect2(252, 146, 16, 40), Color("f5f1d5"))
	draw_rect(Rect2(240, 158, 40, 16), Color("f5f1d5"))
	_draw_shelf(Vector2(600, 120))
	_draw_label(Vector2(196, 272), "みんなを回復", 19, INK)
	_draw_label(Vector2(632, 272), "仲間の預かり所", 19, INK)
	_draw_label(Vector2(355, 365), "安心して休もう", 25, INK)


func _draw_shelf(origin: Vector2) -> void:
	draw_rect(Rect2(origin, Vector2(200, 120)), Color("8e7359"))
	for row in range(2):
		for column in range(4):
			var point := origin + Vector2(13 + column * 46, 12 + row * 51)
			draw_rect(Rect2(point, Vector2(36, 40)), Color("c3b28a"))
			draw_circle(point + Vector2(18, 21), 8, Color("83a9a2"))
			draw_line(point + Vector2(11, 21), point + Vector2(25, 21), INK, 2)


func _draw_label(at: Vector2, value: String, size: int, color: Color) -> void:
	draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
