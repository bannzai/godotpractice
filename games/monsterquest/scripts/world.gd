class_name QuestWorld
extends Node2D
## 地形はセルと地域だけで決まり、進行状況は保持しない。

const GRID := Vector2i(24, 14)
const CELL_SIZE := 40
const FONT = preload("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
const INK := Color("283e43")
const TILE_NAMES: Array[String] = ["meadow", "path", "grass", "hedge", "water", "wood"]

var visual_player: QuestActor
var _ground: TileMapLayer
var _scenery: Node2D
var _zone := "town"


func setup(zone: String) -> void:
	_zone = zone
	if not is_instance_valid(_ground):
		_build_ground()
		_scenery = Node2D.new()
		add_child(_scenery)
		visual_player = QuestActor.new()
		add_child(visual_player)
		visual_player.setup("player", Rect2(0, 0, 54, 54))
		# セル中心を使う移動 Tween と、中央寄せした画像の座標系を揃える。
		visual_player.sprite.position = Vector2.ZERO
	for child: Node in _scenery.get_children():
		_scenery.remove_child(child)
		child.queue_free()
	_ground.clear()
	for y in range(GRID.y):
		for x in range(GRID.x):
			var cell := Vector2i(x, y)
			_ground.set_cell(cell, tile(zone, cell), Vector2i.ZERO)
	if zone == "town":
		_decorate_town()
	elif zone == "route":
		_decorate_route()
	else:
		_decorate_room()
	if zone in ["town", "route"]:
		_place("canopy_shadow", Rect2(0, 0, 960, 560))
		_add_pollen()
	queue_redraw()


func _build_ground() -> void:
	_ground = TileMapLayer.new()
	_ground.show_behind_parent = true
	_ground.scale = Vector2.ONE * float(CELL_SIZE) / 48.0
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(48, 48)
	for index in range(TILE_NAMES.size()):
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load("res://assets/world/tile_%s.svg" % TILE_NAMES[index]) as Texture2D
		atlas.texture_region_size = Vector2i(48, 48)
		atlas.create_tile(Vector2i.ZERO)
		tiles.add_source(atlas, index)
	_ground.tile_set = tiles
	add_child(_ground)


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
	draw_rect(Rect2(0, 0, 960, 560), Color("597a61"), false, 3.0)


func _decorate_town() -> void:
	_place("home", Rect2(110, 66, 220, 200))
	_place("clinic", Rect2(350, 66, 220, 200))
	_label(Rect2(129, 145, 181, 23), "旅人の家", 15)
	_label(Rect2(369, 145, 181, 23), "回復と預かり", 15)
	_place("flowers", Rect2(51, 210, 86, 58))
	_place("flowers", Rect2(591, 405, 86, 58))
	_place("flowers", Rect2(811, 405, 86, 58))
	_sign(Vector2(638, 112), "見守り隊の広場", 186.0)
	_place("captain_plaza", Rect2(649, 175, 186, 98))
	_actor("captain", Rect2(710, 220, 60, 60))
	_label(Rect2(710, 208, 60, 20), "隊長", 13)
	_sign(Vector2(799, 335), "草原へ →", 137.0)
	_sign(Vector2(190, 445), "こもれびの町", 178.0)
	_place("bench", Rect2(549, 349, 84, 54))
	_water(Rect2(40, 360, 120, 120))
	_place("lily", Rect2(44, 366, 44, 44))
	_place("lily", Rect2(112, 432, 36, 36))


func _decorate_route() -> void:
	_sign(Vector2(66, 337), "← こもれびの町", 191.0)
	_sign(Vector2(423, 399), "草むらで仲間を探そう", 241.0)
	_place("flowers", Rect2(417, 445, 86, 58))
	_place("flowers", Rect2(542, 235, 86, 58))
	_place("bench", Rect2(467, 344, 84, 54))
	_water(Rect2(440, 80, 120, 160))
	_place("lily", Rect2(445, 112, 44, 44))
	_place("lily", Rect2(511, 191, 39, 39))


func _decorate_room() -> void:
	_place("room_walls", Rect2(0, 0, 960, 560))
	_place("rug", Rect2(320, 282, 320, 160))
	var title := "旅人の家 ・ ひと休み" if _zone == "home" else "回復と預かりの家"
	_label(Rect2(185, 17, 590, 37), title, 25, Color("fff0ce"))
	_sign(Vector2(377, 508), "町へ戻る ↓", 170.0)
	if _zone == "home":
		_place("bed", Rect2(113, 113, 216, 128))
		_place("storage_shelf", Rect2(633, 113, 216, 128))
		_label(Rect2(104, 254, 265, 28), "ここで冒険を保存できます", 18)
		_label(Rect2(351, 349, 270, 34), "おかえりなさい", 25)
	else:
		_place("healing_table", Rect2(153, 113, 216, 128))
		_place("storage_shelf", Rect2(593, 113, 216, 128))
		_actor("healer", Rect2(231, 80, 58, 58))
		_label(Rect2(173, 254, 188, 28), "みんなを回復", 19)
		_label(Rect2(609, 254, 206, 28), "仲間の預かり所", 19)
		_label(Rect2(351, 349, 270, 34), "安心して休もう", 25)


func _place(image_name: String, rect: Rect2) -> void:
	var picture := Sprite2D.new()
	picture.texture = load("res://assets/world/%s.svg" % image_name) as Texture2D
	picture.centered = false
	picture.position = rect.position
	picture.scale = rect.size / picture.texture.get_size()
	_scenery.add_child(picture)


func _actor(character_id: String, rect: Rect2) -> void:
	var actor := QuestActor.new()
	_scenery.add_child(actor)
	actor.setup(character_id, rect)


func _sign(origin: Vector2, title: String, width: float) -> void:
	_place("sign", Rect2(origin, Vector2(width, 51)))
	_label(Rect2(origin + Vector2(7, 1), Vector2(width - 14, 27)), title, 15)


func _label(rect: Rect2, value: String, font_size: int, color: Color = INK) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_scenery.add_child(label)


func _water(rect: Rect2) -> void:
	var surface := ColorRect.new()
	surface.position = rect.position
	surface.size = rect.size
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 wave = UV * vec2(15.0, 21.0);
    float ripple = sin(wave.y + TIME * 1.1 + sin(wave.x + TIME * 0.45) * 1.2);
    float gleam = smoothstep(0.92, 1.0, ripple) * (0.5 + sin(wave.x * 0.8) * 0.5);
    COLOR = vec4(0.85, 0.96, 0.81, gleam * 0.24);
}
"""
	var surface_material := ShaderMaterial.new()
	surface_material.shader = shader
	surface.material = surface_material
	_scenery.add_child(surface)


func _add_pollen() -> void:
	var pollen := CPUParticles2D.new()
	pollen.position = Vector2(480, 260)
	pollen.amount = 22
	pollen.lifetime = 10.0
	pollen.preprocess = 10.0
	pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pollen.emission_rect_extents = Vector2(440, 230)
	pollen.direction = Vector2(0.6, -1.0)
	pollen.spread = 32.0
	pollen.gravity = Vector2.ZERO
	pollen.initial_velocity_min = 4.0
	pollen.initial_velocity_max = 9.0
	pollen.scale_amount_min = 0.16
	pollen.scale_amount_max = 0.3
	pollen.color = Color(1.0, 0.95, 0.7, 0.48)
	pollen.texture = load("res://assets/world/pollen.svg") as Texture2D
	_scenery.add_child(pollen)
