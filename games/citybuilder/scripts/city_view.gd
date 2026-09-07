extends Control
## 32×32 の論理地図を、一枚の等角投影図面として表示する。

const Actor = preload("res://scripts/city_actor.gd")
const Sim = preload("res://scripts/simulation.gd")
const UI = preload("res://scripts/ui.gd")
const SIDE: int = 32
const TILE_WIDTH: float = 54.0
const TILE_HEIGHT: float = 28.0
const ZONES: Array[String] = ["residential", "commercial", "industrial"]
const FACILITIES: Array[String] = ["power", "park", "police", "fire"]
const ZONE_COLORS: Dictionary = {
	"residential": Color("58e2c0"),
	"commercial": Color("63c8ff"),
	"industrial": Color("ffbf62"),
	"power": Color("ffe477"),
	"park": Color("72e7b0"),
	"police": Color("91bfff"),
	"fire": Color("ff8585"),
}

var zoom: float = 0.94
var pan: Vector2 = Vector2(520, -185)
var cursor: Vector2i = Vector2i(12, 12)
var overlay: String = "none"
var selected_kind: String = "residential"
var selection_valid: bool = false
var selection_reason: String = ""
var daylight_override: float = -1.0
var _state: Dictionary = {}
var _analysis: Dictionary = {}
var _actors: Dictionary = {}
var _signatures: Dictionary = {}
var _travelers: Array[Node2D] = []
var _roads: Array[Vector2i] = []
var _road_signature: String = ""
var _world: Node2D
var _ground: Node2D
var _roads_layer: Node2D
var _weather: Node2D
var _preview: Node2D
var _viewport: SubViewport
var _paper: ColorRect
var _light: CanvasModulate
var _clock: float = 0.0
var _redraw_clock: float = 0.0
var _shake: float = 0.0
var _impact_pause: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_paper = UI.blueprint_surface(self, Rect2(Vector2.ZERO, size), UI.INK)
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size.max(Vector2.ONE))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	container.add_child(_viewport)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	_world.add_child(_ground)
	_roads_layer = Node2D.new()
	_world.add_child(_roads_layer)
	_weather = Node2D.new()
	_weather.z_index = 200
	_weather.draw.connect(_draw_weather)
	_world.add_child(_weather)
	_preview = Actor.new()
	_preview.z_index = 180
	_world.add_child(_preview)
	_light = CanvasModulate.new()
	_viewport.add_child(_light)
	resized.connect(_resize_view)
	_sync_actors()
	_sync_roads()
	_sync_preview()


func set_city(state: Dictionary, analysis: Dictionary) -> void:
	_state = state
	_analysis = analysis
	if is_node_ready():
		_sync_actors()
		_sync_roads()
		_sync_preview()
		_ground.queue_redraw()


func set_selection(kind: String, cell: Vector2i, allowed: bool, reason: String) -> void:
	selected_kind = kind
	cursor = cell
	selection_valid = allowed
	selection_reason = reason
	if is_node_ready():
		_sync_preview()
		_ground.queue_redraw()


func cell_to_screen(cell: Vector2i) -> Vector2:
	return _iso_point(Vector2(cell)) * zoom + pan


func screen_to_cell(local: Vector2) -> Vector2i:
	var point: Vector2 = (local - pan) / zoom
	var grid := Vector2(
		point.x / TILE_WIDTH + point.y / TILE_HEIGHT,
		point.y / TILE_HEIGHT - point.x / TILE_WIDTH
	)
	return Vector2i(roundi(grid.x), roundi(grid.y))


func focus_cell(cell: Vector2i, requested_zoom: float = 1.0) -> void:
	zoom = clampf(requested_zoom, 0.48, 1.7)
	pan = size * 0.5 - _iso_point(Vector2(cell)) * zoom
	queue_redraw()


func show_overview() -> void:
	zoom = 0.5
	pan = size * 0.5 - _iso_point(Vector2(15.5, 15.5)) * zoom
	queue_redraw()


# 建設・撤去の入力イベントに対応して粒子を追加するため冪等にはしない。
func burst(cell: Vector2i, demolish: bool = false) -> void:
	if _world == null:
		return
	var origin: Vector2 = _cell_anchor(Vector2(cell))
	var particles := CPUParticles2D.new()
	particles.position = origin
	particles.one_shot = true
	particles.amount = 22
	particles.lifetime = 0.65
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 155
	particles.gravity = Vector2(0, 52)
	particles.initial_velocity_min = 18
	particles.initial_velocity_max = 62
	particles.scale_amount_min = 1.4
	particles.scale_amount_max = 3.4
	particles.color = UI.ALERT if demolish else UI.CYAN
	particles.z_index = 190
	_world.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	var flash := Polygon2D.new()
	flash.polygon = _diamond(Vector2.ZERO, 0.92)
	flash.position = _iso_point(Vector2(cell))
	flash.color = Color(UI.ALERT if demolish else UI.CYAN, 0.62)
	flash.z_index = 170
	_world.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)
	if demolish:
		_shake = 0.3
		_impact_pause = 0.065
		_viewport.process_mode = Node.PROCESS_MODE_DISABLED


# 見た目の時刻・移動を毎フレーム進める。ゲームの状態は変更しない。
func _process(delta: float) -> void:
	if _world == null:
		return
	if _impact_pause > 0.0:
		_impact_pause = maxf(0.0, _impact_pause - delta)
		if _impact_pause > 0.0:
			return
		_viewport.process_mode = Node.PROCESS_MODE_INHERIT
	_clock += delta
	_redraw_clock += delta
	_shake = maxf(0, _shake - delta)
	_world.scale = Vector2.ONE * zoom
	_world.position = pan + Vector2(sin(_clock * 100), cos(_clock * 79)) * _shake * 10
	var daylight: float = (sin(float(_state.get("month", 0)) * 0.7 + _clock * 0.025) + 1) / 2
	if daylight_override >= 0:
		daylight = clampf(daylight_override, 0.0, 1.0)
	_light.color = Color("8aa7c7").lerp(Color("ffffff"), 0.38 + daylight * 0.62)
	_animate_travelers()
	if _redraw_clock >= 0.08:
		_redraw_clock = 0.0
		_ground.queue_redraw()
		_weather.queue_redraw()


func _resize_view() -> void:
	if _viewport != null:
		_viewport.size = Vector2i(size.max(Vector2.ONE))
	if _paper != null:
		_paper.size = size


func _sync_actors() -> void:
	var tiles: Array = _state.get("tiles", [])
	_roads.clear()
	for index: int in range(tiles.size()):
		var tile: Dictionary = tiles[index]
		var kind: String = str(tile.get("kind", "empty"))
		var level: int = int(tile.get("level", 0))
		var cell := Vector2i(index % SIDE, index / SIDE)
		if kind == "road":
			_roads.append(cell)
		var visual: String = ""
		if kind in ZONE_COLORS and (level > 0 or kind not in ZONES):
			visual = kind + ("_mid" if level >= 2 and kind in ZONES else "")
		elif tile.get("terrain", "flat") == "forest" and kind == "empty":
			visual = "tree"
		var signature: String = "%s:%s" % [visual, level]
		if _signatures.get(index, "") == signature:
			continue
		var previous: String = str(_signatures.get(index, ""))
		_signatures[index] = signature
		if visual.is_empty():
			if _actors.has(index):
				var departing: Node2D = _actors[index]
				departing.play_action("demolish")
				var removal: Tween = create_tween()
				removal.tween_interval(0.55)
				removal.tween_callback(departing.queue_free)
				_actors.erase(index)
			continue
		var actor: Node2D
		if _actors.has(index):
			actor = _actors[index]
		else:
			actor = Actor.new()
			_world.add_child(actor)
			_actors[index] = actor
		actor.position = _cell_anchor(Vector2(cell))
		actor.z_index = cell.x + cell.y + 20
		actor.setup(visual)
		if not previous.is_empty():
			actor.play_action("grow" if previous.begins_with(kind) else "build")
	_sync_problems()
	_sync_travelers()


func _sync_roads() -> void:
	var indexes: Array[String] = []
	for cell: Vector2i in _roads:
		indexes.append("%d:%d" % [cell.x, cell.y])
	var signature := ",".join(indexes)
	if signature == _road_signature:
		return
	_road_signature = signature
	for child: Node in _roads_layer.get_children():
		child.queue_free()
	for cell: Vector2i in _roads:
		var slab := Polygon2D.new()
		slab.polygon = _diamond(_iso_point(Vector2(cell)), 0.84)
		slab.color = Color("0c3458e8")
		_roads_layer.add_child(slab)
		var edge := Line2D.new()
		var outline := _diamond(_iso_point(Vector2(cell)), 0.84)
		outline.append(outline[0])
		edge.points = outline
		edge.default_color = Color(UI.PAPER, 0.58)
		edge.width = 1.0
		edge.antialiased = true
		_roads_layer.add_child(edge)
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not _is_road(cell + direction):
				continue
			var route := Line2D.new()
			route.points = PackedVector2Array(
				[_iso_point(Vector2(cell)), _iso_point(Vector2(cell + direction))]
			)
			route.default_color = Color(UI.CYAN, 0.74)
			route.width = 7.0
			route.antialiased = true
			_roads_layer.add_child(route)
			var center := Line2D.new()
			center.points = route.points
			center.default_color = UI.INK
			center.width = 3.5
			center.antialiased = true
			_roads_layer.add_child(center)


func _sync_problems() -> void:
	var powered: Array = _analysis.get("powered", [])
	var tiles: Array = _state.get("tiles", [])
	for index: int in _actors:
		var actor: Node2D = _actors[index]
		var problem: bool = (
			index < powered.size()
			and not bool(powered[index])
			and tiles[index].kind in ZONES
		)
		if problem != bool(actor.get_meta("problem", false)):
			actor.set_meta("problem", problem)
			actor.play_action("problem" if problem else "idle")


func _sync_travelers() -> void:
	if _travelers.is_empty():
		for index: int in range(16):
			var actor: Node2D = Actor.new()
			_world.add_child(actor)
			actor.setup("walker" if index % 3 == 0 else "car")
			actor.play_action("move")
			actor.z_index = 160
			_travelers.append(actor)
	for actor: Node2D in _travelers:
		actor.visible = not _roads.is_empty()


func _sync_preview() -> void:
	if _preview == null:
		return
	_preview.visible = (
		selected_kind not in ["road", "empty"]
		and _inside(cursor)
		and not _state.is_empty()
	)
	if not _preview.visible:
		return
	_preview.setup(selected_kind)
	_preview.position = _cell_anchor(Vector2(cursor))
	_preview.modulate = Color(UI.CYAN if selection_valid else UI.ALERT, 0.46)


func _animate_travelers() -> void:
	if _roads.is_empty():
		return
	for index: int in range(_travelers.size()):
		var start: Vector2i = _roads[(index * 7) % _roads.size()]
		var end: Vector2i = start
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			if _is_road(start + direction):
				end = start + direction
				break
		var progress: float = (sin(_clock * (0.8 + index * 0.03) + index) + 1) * 0.5
		_travelers[index].position = _cell_anchor(Vector2(start).lerp(Vector2(end), progress))


func _is_road(cell: Vector2i) -> bool:
	if not _inside(cell):
		return false
	var tiles: Array = _state.get("tiles", [])
	return (
		tiles.size() > cell.y * SIDE + cell.x
		and tiles[cell.y * SIDE + cell.x].get("kind") == "road"
	)


func _draw_ground() -> void:
	var tiles: Array = _state.get("tiles", [])
	for index: int in range(tiles.size()):
		var cell := Vector2i(index % SIDE, index / SIDE)
		var center := _iso_point(Vector2(cell))
		var tile: Dictionary = tiles[index]
		var terrain: String = str(tile.get("terrain", "flat"))
		var kind: String = str(tile.get("kind", "empty"))
		var color := Color("084879d8") if (cell.x + cell.y) % 2 == 0 else Color("074473d8")
		if terrain == "water":
			color = Color("086292d8")
		elif terrain == "forest":
			color = Color("075a79d8")
		if kind in ZONE_COLORS:
			color = Color(ZONE_COLORS[kind], 0.24)
		var diamond := _diamond(center)
		_ground.draw_colored_polygon(diamond, color)
		var closed := diamond.duplicate()
		closed.append(diamond[0])
		_ground.draw_polyline(closed, Color(UI.MUTED, 0.34), 0.8, true)
		if terrain == "water":
			var wave: float = sin(_clock * 1.8 + cell.y) * 4
			_ground.draw_line(
				center + Vector2(-11 + wave, 1),
				center + Vector2(8 + wave, 10),
				Color(UI.CYAN, 0.35),
				1.0
			)
		elif kind in ZONES and int(tile.get("level", 0)) == 0:
			_draw_hatching(center, ZONE_COLORS[kind])
		_draw_overlay(index, center)
	_draw_dimensions()
	_draw_selection()


func _draw_hatching(center: Vector2, color: Color) -> void:
	for offset: float in [-10.0, 0.0, 10.0]:
		_ground.draw_line(
			center + Vector2(offset - 8, -7),
			center + Vector2(offset + 8, 7),
			Color(color, 0.65),
			1.1
		)


func _draw_selection() -> void:
	if _state.is_empty():
		return
	for y: int in range(maxi(0, cursor.y - 3), mini(SIDE, cursor.y + 4)):
		for x: int in range(maxi(0, cursor.x - 3), mini(SIDE, cursor.x + 4)):
			var cell := Vector2i(x, y)
			if not Sim.can_place(_state, cell, selected_kind):
				continue
			var outline := _diamond(_iso_point(Vector2(cell)), 0.78)
			outline.append(outline[0])
			_ground.draw_polyline(outline, Color(UI.CYAN, 0.18), 1.0, true)
	if not _inside(cursor):
		return
	var cursor_shape := _diamond(_iso_point(Vector2(cursor)), 0.92)
	_ground.draw_colored_polygon(
		cursor_shape, Color(UI.CYAN if selection_valid else UI.ALERT, 0.2)
	)
	cursor_shape.append(cursor_shape[0])
	_ground.draw_polyline(
		cursor_shape, UI.CYAN if selection_valid else UI.ALERT, 2.7, true
	)


func _draw_dimensions() -> void:
	var north := _iso_point(Vector2(0, 0)) + Vector2(0, -28)
	var east := _iso_point(Vector2(31, 0)) + Vector2(28, -14)
	var south := _iso_point(Vector2(31, 31)) + Vector2(0, 28)
	var west := _iso_point(Vector2(0, 31)) + Vector2(-28, 14)
	var border := PackedVector2Array([north, east, south, west, north])
	_ground.draw_polyline(border, Color(UI.PAPER, 0.7), 1.3, true)
	for index: int in range(0, SIDE, 4):
		var top := _iso_point(Vector2(index, 0))
		var left := _iso_point(Vector2(0, index))
		_ground.draw_line(top + Vector2(0, -16), top + Vector2(0, -30), UI.PAPER, 1.0)
		_ground.draw_line(left + Vector2(-12, 6), left + Vector2(-25, 13), UI.PAPER, 1.0)


func _draw_overlay(index: int, center: Vector2) -> void:
	if overlay == "none":
		return
	var tiles: Array = _state.get("tiles", [])
	if overlay == "power" and (index >= tiles.size() or tiles[index].kind == "empty"):
		return
	var key: String = {"power": "powered", "fire": "fire_risk"}.get(overlay, overlay)
	var values: Array = _analysis.get(key, [])
	if index >= values.size():
		return
	var color: Color
	if key in ["powered", "road_access"]:
		color = Color(UI.CYAN, 0.36) if bool(values[index]) else Color(UI.ALERT, 0.48)
	else:
		color = Color(UI.ALERT, clampf(float(values[index]) / 100.0, 0.0, 0.68))
	_ground.draw_colored_polygon(_diamond(center, 0.88), color)


func _draw_weather() -> void:
	var tiles: Array = _state.get("tiles", [])
	var powered: Array = _analysis.get("powered", [])
	for index: int in _actors:
		if index >= tiles.size():
			continue
		var kind: String = str(tiles[index].get("kind", "empty"))
		var point: Vector2 = _cell_anchor(Vector2(index % SIDE, index / SIDE)) + Vector2(9, -42)
		if kind in ["industrial", "power"]:
			for puff: int in range(3):
				var progress: float = fmod(_clock * 0.4 + puff / 3.0 + index * 0.13, 1.0)
				_weather.draw_circle(
					point + Vector2(progress * 13, -progress * 24),
					2.5 + progress * 4.0,
					Color(UI.PAPER, (1 - progress) * 0.2)
				)
		if (
			index < powered.size()
			and not bool(powered[index])
			and kind in ZONES
		):
			_weather.draw_circle(point + Vector2(4, -4), 6, UI.ORANGE)
			_weather.draw_polyline(
				PackedVector2Array(
					[
						point + Vector2(5, -9),
						point + Vector2(1, -4),
						point + Vector2(6, -4),
						point + Vector2(3, 1),
					]
				),
				UI.INK,
				1.5
			)
	for mark: int in range(5):
		var x: float = fmod(_clock * 7 + mark * 319, 1800) - 280
		var origin := Vector2(x, 120 + mark * 132)
		_weather.draw_line(origin, origin + Vector2(55, 0), Color(UI.PAPER, 0.055), 1.0)


func _iso_point(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_WIDTH * 0.5, (cell.x + cell.y) * TILE_HEIGHT * 0.5)


func _cell_anchor(cell: Vector2) -> Vector2:
	return _iso_point(cell) + Vector2(0, TILE_HEIGHT * 0.5)


func _diamond(center: Vector2, scale: float = 1.0) -> PackedVector2Array:
	return PackedVector2Array(
		[
			center + Vector2(0, -TILE_HEIGHT * 0.5 * scale),
			center + Vector2(TILE_WIDTH * 0.5 * scale, 0),
			center + Vector2(0, TILE_HEIGHT * 0.5 * scale),
			center + Vector2(-TILE_WIDTH * 0.5 * scale, 0),
		]
	)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIDE and cell.y < SIDE
