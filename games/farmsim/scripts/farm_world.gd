extends Node2D
## タイル農場の描画と歩行可能範囲。進行状態は Farm に集約する。

const FIELD_ORIGIN := Vector2(384, 304)
const TILE_SIZE := 64
const BED := Vector2(176, 302)
const WELL := Vector2(302, 275)
const SHIPPING := Vector2(865, 418)
const TOWN := Vector2(876, 256)

var player: Node2D
var merchant: Node2D
var chicken: Node2D
var soil: TileMapLayer
var crop_layer: Node2D
var light: CanvasModulate
var overlay: Node2D
var _elapsed: float = 0.0
var _field_signature: String = ""
var _selection: Vector2 = Vector2.ZERO


func _ready() -> void:
	var ground := TileMapLayer.new()
	ground.tile_set = _tileset()
	ground.position = Vector2(32, 128)
	add_child(ground)
	for y: int in 7:
		for x: int in 14:
			var terrain: int = 1 if y == 2 or x == 11 else 0
			if x < 2 and y > 4:
				terrain = 4
			ground.set_cell(Vector2i(x, y), 0, Vector2i(terrain, 0))
	soil = TileMapLayer.new()
	soil.tile_set = ground.tile_set
	soil.position = FIELD_ORIGIN
	add_child(soil)
	crop_layer = Node2D.new()
	add_child(crop_layer)
	_prop("house", Rect2(62, 118, 227, 171))
	_prop("well", Rect2(256, 177, 96, 103))
	_prop("shipping", Rect2(817, 342, 102, 83))
	_prop("shop", Rect2(781, 107, 174, 130))
	for location: Vector2 in [Vector2(38, 414), Vector2(180, 462), Vector2(44, 240)]:
		_prop("tree", Rect2(location, Vector2(120, 132)))
	for x: int in range(5, 12):
		_prop("fence", Rect2(32 + x * 64, 136, 64, 47))
	player = _actor("farmer", Farm.player_position, 0.69)
	merchant = _actor("merchant", Vector2(829, 267), 0.65)
	chicken = _actor("chicken", Vector2(270, 407), 0.42)
	light = CanvasModulate.new()
	add_child(light)
	overlay = Node2D.new()
	add_child(overlay)
	overlay.draw.connect(_draw_selection)
	refresh()


func _tileset() -> TileSet:
	var result := TileSet.new()
	result.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/tiles/terrain.svg") as Texture2D
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x: int in 6:
		source.create_tile(Vector2i(x, 0))
	result.add_source(source, 0)
	return result


func _prop(id: String, rect: Rect2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/props/%s.svg" % id) as Texture2D
	sprite.centered = false
	sprite.position = rect.position
	sprite.scale = rect.size / sprite.texture.get_size()
	add_child(sprite)


func _actor(kind: String, at: Vector2, factor: float) -> Node2D:
	var actor: Node2D = load("res://scripts/farm_actor.gd").new()
	add_child(actor)
	actor.setup(kind)
	actor.position = at
	actor.scale = Vector2.ONE * factor
	return actor


func refresh() -> void:
	if not is_instance_valid(player):
		return
	player.position = Farm.player_position
	player.face(Farm.facing)
	var signature: String = JSON.stringify(Farm.tiles)
	if signature == _field_signature:
		return
	_field_signature = signature
	for child: Node in crop_layer.get_children():
		crop_layer.remove_child(child)
		child.queue_free()
	for index: int in Farm.tiles.size():
		var tile: Dictionary = Farm.tiles[index]
		var cell := Vector2i(index % 6, index / 6)
		soil.set_cell(cell, 0, Vector2i(3 if tile.watered else 2, 0))
		if not tile.tilled:
			soil.erase_cell(cell)
		if str(tile.crop).is_empty():
			continue
		var stage: int = Farm.crop_stage(index)
		var crop := Sprite2D.new()
		var stages: Array[String] = ["seed", "sprout", "growing", "ripe", "growing"]
		crop.texture = load("res://assets/crops/%s_%s.svg" % [tile.crop, stages[stage]])
		crop.position = cell_center(index) - Vector2(0, 5)
		crop.scale = Vector2.ONE * 58.0 / crop.texture.get_width()
		if stage == 4:
			crop.modulate = Color("8e765c")
		crop_layer.add_child(crop)


## フレーム経過による光と風の運動のため非冪等。
func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(player):
		return
	var evening: float = clampf((Farm.minutes - 960.0) / 450.0, 0.0, 1.0)
	light.color = Color.WHITE.lerp(Color("7479b2"), evening * 0.65)
	if Farm.season() == "summer":
		light.color = light.color.lerp(Color("ffdfa5"), 0.15)
	chicken.position = Vector2(270 + sin(_elapsed * 0.6) * 33, 407 + cos(_elapsed) * 7)
	var cycle: int = int(_elapsed) % 16
	chicken.animate(["walk", "hoe", "harvest", "idle"][cycle / 4])
	merchant.animate(["idle", "walk", "water", "harvest"][cycle / 4])
	_selection = target_position()
	overlay.queue_redraw()


func _draw_selection() -> void:
	if not is_instance_valid(player):
		return
	for index: int in Farm.tiles.size():
		var bounds := Rect2(cell_center(index) - Vector2(30, 30), Vector2(60, 60))
		overlay.draw_rect(bounds, Color(0.38, 0.44, 0.21, 0.19), false, 1.0)
	var target: int = target_index()
	if target >= 0:
		var bounds := Rect2(cell_center(target) - Vector2(30, 30), Vector2(60, 60))
		overlay.draw_style_box(_selection_style(), bounds)
	else:
		overlay.draw_arc(_selection, 13, 0, TAU, 24, Color(1, 0.96, 0.72, 0.65), 2)


func _selection_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 0.96, 0.74, 0.13)
	style.border_color = Color("fff1ad")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style


func cell_center(index: int) -> Vector2:
	return FIELD_ORIGIN + Vector2(index % 6, index / 6) * TILE_SIZE + Vector2(32, 32)


func target_position() -> Vector2:
	return Farm.player_position + Farm.facing.normalized() * 56.0


func target_index() -> int:
	var relative: Vector2 = target_position() - FIELD_ORIGIN
	if relative.x < 0 or relative.y < 0 or relative.x >= 384 or relative.y >= 256:
		return -1
	return int(relative.x / TILE_SIZE) + int(relative.y / TILE_SIZE) * 6


func can_walk(at: Vector2) -> bool:
	return Farm.can_walk(at)

## 入力に応じて位置を進めるため非冪等。
func move_player(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		player.animate("idle")
		return
	Farm.facing = direction.normalized()
	var movement: Vector2 = direction.normalized() * 190.0 * delta
	var next: Vector2 = Farm.player_position + Vector2(movement.x, 0)
	if can_walk(next):
		Farm.player_position = next
	next = Farm.player_position + Vector2(0, movement.y)
	if can_walk(next):
		Farm.player_position = next
	player.position = Farm.player_position
	player.face(direction)
	player.animate("walk")


## 一度の道具の使用に一度だけ粒子を出すため非冪等。
func effect(kind: String, at: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = 26
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 65
	particles.gravity = Vector2(0, 160)
	particles.initial_velocity_min = 45
	particles.initial_velocity_max = 140
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = {"water": Color("85dcec"), "hoe": Color("ad7654")}.get(
		kind, Color("ffde70"))
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	var tween := create_tween()
	tween.tween_property(player, "modulate", Color("fff0ad"), 0.08)
	tween.tween_property(player, "modulate", Color.WHITE, 0.2)
