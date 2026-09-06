extends Control
## 独立キャンバスで街だけを昼夜変化させ、操作 UI のコントラストを保つ。

const Actor = preload("res://scripts/city_actor.gd")
const SIDE: int = 32
const TILE: float = 32.0
const ZONE_COLORS: Dictionary = {
	"residential": Color("7da86a"),
	"commercial": Color("69a6b0"),
	"industrial": Color("c4ad66"),
	"power": Color("bda27d"),
	"park": Color("76a65c"),
	"police": Color("788cac"),
	"fire": Color("bb8072"),
}

var zoom: float = 1.0
var pan: Vector2 = Vector2(-45, -185)
var cursor: Vector2i = Vector2i(12, 12)
var overlay: String = "none"
var daylight_override: float = -1.0
var _state: Dictionary = {}
var _analysis: Dictionary = {}
var _actors: Dictionary = {}
var _signatures: Dictionary = {}
var _travelers: Array[Node2D] = []
var _roads: Array[Vector2i] = []
var _world: Node2D
var _ground: Node2D
var _weather: Node2D
var _viewport: SubViewport
var _light: CanvasModulate
var _clock: float = 0.0
var _redraw_clock: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var container: SubViewportContainer = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(size.max(Vector2.ONE))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	container.add_child(_viewport)
	_world = Node2D.new()
	_viewport.add_child(_world)
	_ground = Node2D.new()
	_ground.draw.connect(_draw_ground)
	_world.add_child(_ground)
	_weather = Node2D.new()
	_weather.z_index = 100
	_weather.draw.connect(_draw_weather)
	_world.add_child(_weather)
	_light = CanvasModulate.new()
	_viewport.add_child(_light)
	resized.connect(_resize_view)
	_sync_actors()


func set_city(state: Dictionary, analysis: Dictionary) -> void:
	_state = state
	_analysis = analysis
	if is_node_ready():
		_sync_actors()
		_ground.queue_redraw()


func cell_to_screen(cell: Vector2i) -> Vector2:
	return (Vector2(cell) * TILE + Vector2.ONE * TILE / 2) * zoom + pan


func screen_to_cell(local: Vector2) -> Vector2i:
	return Vector2i(((local - pan) / zoom / TILE).floor())


# 建設・撤去の入力イベントに対応して粒子を追加するため冪等にはしない。
func burst(cell: Vector2i, demolish: bool = false) -> void:
	if _world == null:
		return
	var origin: Vector2 = Vector2(cell) * TILE + Vector2.ONE * TILE / 2
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = origin
	particles.one_shot = true
	particles.amount = 18
	particles.lifetime = 0.65
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180
	particles.gravity = Vector2(0, 55)
	particles.initial_velocity_min = 18
	particles.initial_velocity_max = 60
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color("e4c38d") if demolish else Color("fff2aa")
	particles.z_index = 90
	_world.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	var flash: Polygon2D = Polygon2D.new()
	flash.polygon = PackedVector2Array(
		[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
	)
	flash.position = origin
	flash.color = Color(1, 0.9, 0.55, 0.7)
	flash.z_index = 80
	_world.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	tween.tween_callback(flash.queue_free)
	if demolish:
		_shake = 0.3


# 見た目の時刻・移動を毎フレーム進める。ゲームの状態は変更しない。
func _process(delta: float) -> void:
	if _world == null:
		return
	_clock += delta
	_redraw_clock += delta
	_shake = maxf(0, _shake - delta)
	_world.scale = Vector2.ONE * zoom
	_world.position = pan + Vector2(sin(_clock * 100), cos(_clock * 79)) * _shake * 10
	var daylight: float = (sin(float(_state.get("month", 0)) * 0.7 + _clock * 0.025) + 1) / 2
	if daylight_override >= 0:
		daylight = clampf(daylight_override, 0.0, 1.0)
	_light.color = Color("c1cbe1").lerp(Color("fff5dc"), daylight)
	_animate_travelers()
	if _redraw_clock >= 0.08:
		_redraw_clock = 0.0
		_ground.queue_redraw()
		_weather.queue_redraw()


func _resize_view() -> void:
	if _viewport != null:
		_viewport.size = Vector2i(size.max(Vector2.ONE))


func _sync_actors() -> void:
	var tiles: Array = _state.get("tiles", [])
	_roads.clear()
	for index: int in range(tiles.size()):
		var tile: Dictionary = tiles[index]
		var kind: String = str(tile.get("kind", "empty"))
		var level: int = int(tile.get("level", 0))
		var cell: Vector2i = Vector2i(index % SIDE, index / SIDE)
		if kind == "road":
			_roads.append(cell)
		var visual: String = ""
		if (
			kind in ZONE_COLORS
			and (level > 0 or kind not in ["residential", "commercial", "industrial"])
		):
			visual = (
				kind
				+ (
					"_mid"
					if level >= 2 and kind in ["residential", "commercial", "industrial"]
					else ""
				)
			)
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
		actor.position = Vector2(cell) * TILE + Vector2(16, 25)
		actor.z_index = cell.y + 1
		actor.setup(visual)
		if not previous.is_empty():
			actor.play_action("grow" if previous.begins_with(kind) else "build")
	_sync_problems()
	_sync_travelers()


func _sync_problems() -> void:
	var powered: Array = _analysis.get("powered", [])
	var tiles: Array = _state.get("tiles", [])
	for index: int in _actors:
		var actor: Node2D = _actors[index]
		var problem: bool = (
			index < powered.size()
			and not bool(powered[index])
			and tiles[index].kind in ["residential", "commercial", "industrial"]
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
			actor.z_index = 60
			_travelers.append(actor)
	for actor: Node2D in _travelers:
		actor.visible = not _roads.is_empty()


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
		_travelers[index].position = (
			Vector2(start).lerp(Vector2(end), progress) * TILE
			+ Vector2(16, 20 if index % 3 == 0 else 14)
		)


func _is_road(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIDE or cell.y >= SIDE:
		return false
	var tiles: Array = _state.get("tiles", [])
	return (
		tiles.size() > cell.y * SIDE + cell.x
		and tiles[cell.y * SIDE + cell.x].get("kind") == "road"
	)


func _draw_ground() -> void:
	_ground.draw_rect(Rect2(Vector2(-2048, -2048), Vector2(5120, 5120)), Color("263d43"))
	var tiles: Array = _state.get("tiles", [])
	for index: int in range(tiles.size()):
		var cell: Vector2i = Vector2i(index % SIDE, index / SIDE)
		var point: Vector2 = Vector2(cell) * TILE
		var tile: Dictionary = tiles[index]
		var terrain: String = str(tile.get("terrain", "flat"))
		var kind: String = str(tile.get("kind", "empty"))
		var color: Color = Color("839878") if (cell.x + cell.y) % 2 == 0 else Color("809475")
		if terrain == "water":
			color = Color("416e7b")
		elif terrain == "forest":
			color = Color("718764")
		if kind in ZONE_COLORS:
			color = ZONE_COLORS[kind]
		_ground.draw_rect(Rect2(point, Vector2.ONE * TILE), color)
		_ground.draw_rect(Rect2(point, Vector2.ONE * TILE), Color(0.15, 0.25, 0.19, 0.1), false)
		if terrain == "water":
			var wave: float = sin(_clock * 1.8 + cell.y) * 4
			_ground.draw_line(
				point + Vector2(6 + wave, 12),
				point + Vector2(19 + wave, 12),
				Color(0.65, 0.86, 0.9, 0.25),
				1
			)
		elif kind == "road":
			_draw_road(cell, point)
		elif (
			kind in ZONE_COLORS
			and int(tile.get("level", 0)) == 0
			and kind in ["residential", "commercial", "industrial"]
		):
			_ground.draw_rect(
				Rect2(point + Vector2(5, 5), Vector2(22, 22)), Color(1, 1, 1, 0.35), false, 1
			)
			_ground.draw_line(
				point + Vector2(8, 24), point + Vector2(24, 8), Color(1, 1, 1, 0.2), 1
			)
		_draw_overlay(index, point)
	if cursor.x >= 0 and cursor.y >= 0 and cursor.x < SIDE and cursor.y < SIDE:
		_ground.draw_rect(
			Rect2(Vector2(cursor) * TILE, Vector2.ONE * TILE), Color("ffecb1"), false, 2.5
		)


func _draw_road(cell: Vector2i, point: Vector2) -> void:
	_ground.draw_rect(Rect2(point, Vector2.ONE * TILE), Color("92968a"))
	_ground.draw_rect(Rect2(point + Vector2(4, 4), Vector2(24, 24)), Color("4c5555"))
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if _is_road(cell + direction):
			var center: Vector2 = point + Vector2(16, 16)
			_ground.draw_line(center, center + Vector2(direction) * 17, Color("4c5555"), 24)
			_ground.draw_line(
				center + Vector2(direction) * 6,
				center + Vector2(direction) * 12,
				Color("d7cda4"),
				1.5
			)


func _draw_overlay(index: int, point: Vector2) -> void:
	if overlay == "none":
		return
	var key: String = {"power": "powered", "fire": "fire_risk"}.get(overlay, overlay)
	var values: Array = _analysis.get(key, [])
	if index >= values.size():
		return
	var color: Color
	if key == "powered" or key == "road_access":
		color = Color(0.3, 0.9, 0.8, 0.4) if bool(values[index]) else Color(0.8, 0.25, 0.22, 0.5)
	else:
		color = Color(0.95, 0.22, 0.13, clampf(float(values[index]) / 100.0, 0.0, 0.75))
	_ground.draw_rect(Rect2(point, Vector2.ONE * TILE), color)


func _draw_weather() -> void:
	var tiles: Array = _state.get("tiles", [])
	var powered: Array = _analysis.get("powered", [])
	for index: int in _actors:
		if index >= tiles.size():
			continue
		var kind: String = str(tiles[index].get("kind", "empty"))
		var point: Vector2 = Vector2(index % SIDE, index / SIDE) * TILE + Vector2(18, -3)
		if kind in ["industrial", "power"]:
			for puff: int in range(3):
				var progress: float = fmod(_clock * 0.4 + puff / 3.0 + index * 0.13, 1.0)
				_weather.draw_circle(
					point + Vector2(progress * 16, -progress * 26),
					3 + progress * 5,
					Color(0.24, 0.28, 0.28, (1 - progress) * 0.38)
				)
		if (
			index < powered.size()
			and not bool(powered[index])
			and kind in ["residential", "commercial", "industrial"]
		):
			_weather.draw_circle(point + Vector2(4, -5), 6, Color("f6c969"))
			_weather.draw_polyline(
				PackedVector2Array(
					[
						point + Vector2(5, -10),
						point + Vector2(1, -5),
						point + Vector2(6, -5),
						point + Vector2(3, 0)
					]
				),
				Color("704b31"),
				1.5
			)
	for cloud: int in range(5):
		var origin: Vector2 = Vector2(fmod(_clock * 5 + cloud * 261, 1280) - 120, 80 + cloud * 155)
		_weather.draw_circle(origin, 29, Color(0.95, 0.97, 0.9, 0.075))
		_weather.draw_circle(origin + Vector2(33, 5), 22, Color(0.95, 0.97, 0.9, 0.07))
