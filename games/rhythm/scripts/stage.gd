extends Node2D
## 背景、ノーツ、奏者の表示。判定そのものはRhythmStateに委ねる。

const Dancer = preload("res://scripts/dancer.gd")
const Rules = preload("res://scripts/rhythm_rules.gd")
const CREAM := Color("fff0cf")
const CORAL := Color("ff8c89")
const MINT := Color("87dfcf")
const LINE_X: float = 275.0
const SPEED: float = 340.0
const LANE_Y: Array[float] = [260.0, 370.0]
var state: Node
var dancers: Array[Node2D] = []
var layers: Array[Sprite2D] = []
var textures: Dictionary = {}
var elapsed: float = 0.0
var shake: float = 0.0
var flash: float = 0.0
var pulses: Array[float] = [0.0, 0.0]
var last_kind: String = ""
var effect_time: float = 0.0
var last_combo: int = 0
var font: Font
var particles: Array[CPUParticles2D] = []
var frozen_view: bool = false


func _ready() -> void:
	state = get_node("/root/RhythmState")
	font = load("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
	for layer_name: String in ["sky", "city", "foreground"]:
		var layer: Sprite2D = Sprite2D.new()
		layer.texture = load("res://assets/backgrounds/%s.svg" % layer_name)
		layer.centered = false
		layer.show_behind_parent = true
		add_child(layer)
		layers.append(layer)
		if layer_name == "sky":
			var glow: ShaderMaterial = ShaderMaterial.new()
			glow.shader = load("res://shaders/night_glow.gdshader")
			layer.material = glow
	for key: String in ["coral", "mint", "long"]:
		textures[key] = load("res://assets/ui/note-%s.svg" % key)
	for index: int in range(3):
		var dancer: Node2D = Dancer.new()
		add_child(dancer)
		dancer.setup(["fox", "bird", "rabbit"][index])
		dancers.append(dancer)
	for lane: int in range(2):
		var burst: CPUParticles2D = CPUParticles2D.new()
		burst.position = Vector2(LINE_X, LANE_Y[lane])
		burst.emitting = false
		burst.one_shot = true
		burst.amount = 22
		burst.lifetime = 0.5
		burst.explosiveness = 1.0
		burst.direction = Vector2.UP
		burst.spread = 180
		burst.initial_velocity_min = 70
		burst.initial_velocity_max = 240
		burst.gravity = Vector2(0, 180)
		burst.scale_amount_min = 2
		burst.scale_amount_max = 5
		burst.color = CORAL if lane == 0 else MINT
		burst.z_index = 3
		add_child(burst)
		particles.append(burst)
	state.judged.connect(on_judged)


func _process(delta: float) -> void:
	if frozen_view:
		return
	elapsed += delta
	var playing: bool = state.screen == "play"
	var beat: float = state.song_time * float(state.chart.get("bpm", 112)) / 60.0
	if not playing:
		beat = elapsed * 1.4
	for index: int in range(layers.size()):
		layers[index].position.x = sin(elapsed * 0.12) * index * 5
		layers[index].modulate = Color.WHITE if not playing else Color(0.78, 0.82, 0.94)
	for index: int in range(dancers.size()):
		if playing:
			dancers[index].position = Vector2(780 + index * 155, 633)
			dancers[index].scale = Vector2.ONE * 0.66
		elif state.screen == "title":
			dancers[index].position = Vector2(800 + index * 150, 586 - (index % 2) * 32)
			dancers[index].scale = Vector2.ONE * (1.0 if index == 0 else 0.84)
		elif state.screen == "select":
			dancers[index].position = Vector2(830 + index * 140, 612)
			dancers[index].scale = Vector2.ONE * 0.7
		else:
			dancers[index].position = Vector2(860 + index * 140, 610)
			dancers[index].scale = Vector2.ONE * 0.7
		dancers[index].sync_beat(beat + index * 0.09, playing, delta)
	shake = maxf(0.0, shake - delta)
	position.x = sin(elapsed * 80.0) * shake * 20
	flash = maxf(0.0, flash - delta)
	effect_time = maxf(0.0, effect_time - delta)
	for lane: int in range(2):
		pulses[lane] = maxf(0.0, pulses[lane] - delta * 3)
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	if state.screen != "play":
		return
	_draw_lanes()
	_draw_notes()
	_draw_judgment()
	if state.gauge >= 0.999:
		for index: int in range(18):
			var x: float = fposmod(index * 83.0 + elapsed * 23, 1280)
			var y: float = 495 + sin(elapsed * 2 + index) * 55
			draw_circle(Vector2(x, y), 2.0 + sin(elapsed + index), CREAM)
	if flash > 0:
		draw_rect(Rect2(0, 156, 1280, 280), Color(1, 0.93, 0.8, flash * 0.45))


func _draw_lanes() -> void:
	for lane: int in range(2):
		var color: Color = CORAL if lane == 0 else MINT
		var y: float = LANE_Y[lane]
		draw_style_box(_box(Color("1c3049"), 18, Color("476078")), Rect2(64, y - 47, 1152, 94))
		draw_rect(Rect2(210, y - 43, 6, 86), color)
		draw_line(Vector2(216, y), Vector2(1212, y), Color(0.7, 0.8, 0.9, 0.11), 2)
		draw_circle(Vector2(LINE_X, y), 35 + pulses[lane] * 8, Color(color, 0.12))
		draw_arc(Vector2(LINE_X, y), 33, 0, TAU, 64, color, 3, true)
		draw_arc(Vector2(LINE_X, y), 25, 0, TAU, 64, Color(color, 0.4), 1, true)
		draw_string(
			font,
			Vector2(91, y + 9),
			"コーラル" if lane == 0 else "ミント",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			19,
			color
		)
		var beat_seconds: float = 60.0 / float(state.chart.bpm)
		var first_beat: int = int(floor(state.song_time / beat_seconds))
		for beat: int in range(first_beat, first_beat + 8):
			var x: float = LINE_X + (beat * beat_seconds - state.song_time) * SPEED
			if x > 320 and x < 1200:
				draw_line(Vector2(x, y - 32), Vector2(x, y + 32), Color(1, 1, 1, 0.06), 1)
	draw_line(Vector2(LINE_X, 196), Vector2(LINE_X, 427), Color(CREAM, 0.6), 2)


func _draw_notes() -> void:
	for note: Dictionary in state.notes:
		if note.status == "judged":
			continue
		var x: float = LINE_X + (Rules.note_time(note, state.chart) - state.song_time) * SPEED
		var y: float = LANE_Y[int(note.lane)]
		var color: Color = CORAL if int(note.lane) == 0 else MINT
		if note.type == "long":
			var end_x: float = (
				LINE_X + (Rules.end_time(note, state.chart) - state.song_time) * SPEED
			)
			if end_x < 216 or x > 1210:
				continue
			var start: float = maxf(LINE_X if note.status == "holding" else 217, x)
			var finish: float = minf(1200, end_x)
			draw_line(Vector2(start, y), Vector2(finish, y), Color(color, 0.25), 37, true)
			draw_line(Vector2(start, y), Vector2(finish, y), color, 4, true)
			draw_circle(Vector2(finish, y), 16, color)
			draw_string(
				font, Vector2(start + 38, y - 9), "長押し", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CREAM
			)
			if note.status == "holding":
				x = LINE_X
		if x < 217 or x > 1210:
			continue
		var key: String = str(note.type)
		draw_texture_rect(textures[key], Rect2(x - 29, y - 29, 58, 58), false)


func _draw_judgment() -> void:
	if effect_time <= 0:
		return
	var color: Color = CREAM
	if last_kind in ["Miss", "ghost"]:
		color = Color("b9a8db")
	var alpha: float = minf(1.0, effect_time * 3)
	var lift: float = (0.8 - effect_time) * 20
	var text: String = {"Perfect": "パーフェクト", "Good": "グッド", "Miss": "ミス", "ghost": "空打ち"}.get(
		last_kind, last_kind
	)
	draw_string(
		font, Vector2(285, 493 - lift), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(color, alpha)
	)
	if last_combo > 0:
		draw_string(
			font,
			Vector2(288, 529 - lift),
			"%d コンボ" % last_combo,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			22,
			Color(CREAM, alpha)
		)


func _box(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(1)
	box.border_color = border
	return box


func on_judged(kind: String, lane: int) -> void:
	last_kind = kind
	last_combo = state.combo
	effect_time = 0.8
	pulses[lane] = 1.0
	var success: bool = kind in ["Perfect", "Good"]
	for dancer: Node2D in dancers:
		dancer.react("hit" if success else "miss")
	if success:
		particles[lane].restart()
		particles[lane].emitting = true
		flash = 0.12
	else:
		shake = 0.15


func celebrate() -> void:
	for dancer: Node2D in dancers:
		dancer.react("celebrate")
