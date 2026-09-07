extends Node2D
## 建物と住民の青焼き線画。進行状態は simulation のタイルだけが保持する。

const ACTIONS: Array[String] = ["idle", "build", "demolish", "grow", "problem", "move"]
const DURATIONS: Dictionary = {
	"idle": 2.4, "build": 0.7, "demolish": 0.55, "grow": 0.8, "problem": 1.2, "move": 0.48
}

const INK: Color = Color("0b2c4a")
const FACE_LEFT: Color = Color("15547fb8")
const FACE_RIGHT: Color = Color("0d3c66d6")
const FACE_TOP: Color = Color("2b79a4aa")
const FACE_LIGHT: Color = Color("4da7c7a0")
const LINE: Color = Color("d9f8ff")
const LINE_SOFT: Color = Color("8fd9ee")
const ACCENT: Color = Color("76e0f4")
const WARNING: Color = Color("ffcf86")

var kind: String = ""
var visual: Node2D
var animation: AnimationPlayer
var _posing: bool = false


func setup(value: String) -> void:
	if visual == null:
		visual = Node2D.new()
		visual.name = "Visual"
		add_child(visual)
		animation = AnimationPlayer.new()
		animation.name = "AnimationPlayer"
		animation.animation_finished.connect(_on_animation_finished)
		add_child(animation)
	if kind == value:
		return
	kind = value
	_clear_visual()
	_build_visual(value)
	_make_animations()
	play_action("idle")


## 操作イベントごとに先頭から演出するため、同じ指定でも再生時刻を戻す。
func play_action(action: String) -> void:
	if animation != null and action in ACTIONS:
		_posing = false
		animation.stop()
		_reset_visual()
		animation.play(action)


func seek_pose(action: String, progress: float) -> void:
	if animation == null or action not in ACTIONS:
		return
	_posing = true
	animation.stop()
	_reset_visual()
	animation.play(action)
	animation.seek(clampf(progress, 0.0, 1.0) * animation.get_animation(action).length, true)
	animation.pause()


func _clear_visual() -> void:
	for child: Node in visual.get_children():
		visual.remove_child(child)
		child.free()


func _build_visual(value: String) -> void:
	match value:
		"residential":
			_build_residential()
		"residential_mid":
			_build_residential_mid()
		"commercial":
			_build_commercial()
		"commercial_mid":
			_build_commercial_mid()
		"industrial":
			_build_industrial()
		"industrial_mid":
			_build_industrial_mid()
		"power":
			_build_power()
		"park":
			_build_park()
		"police":
			_build_police()
		"fire":
			_build_fire()
		"tree":
			_build_tree()
		"car":
			_build_car()
		"walker":
			_build_walker()
		_:
			_build_survey_marker()


func _build_residential() -> void:
	_iso_prism(44.0, 24.0, 27.0, FACE_LEFT, FACE_RIGHT, FACE_LIGHT)
	_polygon(
		PackedVector2Array(
			[Vector2(0, -61), Vector2(0, -34), Vector2(-24, -40), Vector2(0, -54)]
		),
		FACE_TOP
	)
	_polygon(
		PackedVector2Array(
			[Vector2(0, -61), Vector2(24, -40), Vector2(0, -27), Vector2(0, -34)]
		),
		Color("1d628dcc")
	)
	_panel_left(Vector2(-8, -25), 7.0, 8.0)
	_panel_right(Vector2(7, -21), 7.0, 8.0)
	_panel_right(Vector2(2, -10), 8.0, 10.0, WARNING)
	_polygon(
		PackedVector2Array(
			[Vector2(-14, -57), Vector2(-8, -60), Vector2(-8, -48), Vector2(-14, -45)]
		),
		FACE_RIGHT
	)


func _build_residential_mid() -> void:
	_iso_prism(42.0, 24.0, 58.0, FACE_LEFT, FACE_RIGHT, FACE_TOP)
	for floor_index: int in range(3):
		var y: float = -14.0 - floor_index * 14.0
		_line(PackedVector2Array([Vector2(-20, y - 12), Vector2(0, y), Vector2(20, y - 12)]))
		_panel_left(Vector2(-9, y - 7), 6.0, 7.0)
		_panel_right(Vector2(8, y - 4), 6.0, 7.0)
	_polygon(
		PackedVector2Array(
			[Vector2(-7, -75), Vector2(0, -79), Vector2(7, -75), Vector2(0, -71)]
		),
		WARNING
	)
	_line(PackedVector2Array([Vector2(0, -79), Vector2(0, -88)]), ACCENT, 2.0)


func _build_commercial() -> void:
	_iso_prism(52.0, 26.0, 24.0, FACE_LIGHT, FACE_RIGHT, Color("3b91b3a8"))
	_polygon(
		PackedVector2Array(
			[Vector2(-26, -18), Vector2(0, -4), Vector2(0, 2), Vector2(-26, -12)]
		),
		Color("68cde0b8")
	)
	_polygon(
		PackedVector2Array(
			[Vector2(0, -4), Vector2(26, -18), Vector2(26, -12), Vector2(0, 2)]
		),
		Color("2487aabd")
	)
	_panel_left(Vector2(-11, -17), 10.0, 9.0)
	_panel_right(Vector2(10, -14), 10.0, 9.0)
	_line(
		PackedVector2Array([Vector2(-11, -35), Vector2(0, -29), Vector2(11, -35)]),
		WARNING,
		3.0
	)
	_line(PackedVector2Array([Vector2(0, -29), Vector2(0, -9)]), LINE_SOFT, 1.2)


func _build_commercial_mid() -> void:
	_iso_prism(42.0, 24.0, 61.0, Color("236f96b8"), FACE_RIGHT, Color("50b3c9a0"))
	for floor_index: int in range(4):
		var y: float = -12.0 - floor_index * 12.0
		_panel_left(Vector2(-9, y - 7), 7.0, 6.0, ACCENT)
		_panel_right(Vector2(8, y - 4), 7.0, 6.0, ACCENT)
	_line(PackedVector2Array([Vector2(0, -61), Vector2(0, 0)]), LINE_SOFT, 1.0)
	_polygon(
		PackedVector2Array(
			[Vector2(-11, -71), Vector2(0, -77), Vector2(11, -71), Vector2(0, -65)]
		),
		WARNING
	)
	_line(PackedVector2Array([Vector2(-4, -71), Vector2(4, -71)]), INK, 1.5)


func _build_industrial() -> void:
	_iso_prism(56.0, 30.0, 23.0, Color("174d75d1"), FACE_RIGHT, Color("397d9ca8"))
	_polygon(
		PackedVector2Array(
			[
				Vector2(-28, -38),
				Vector2(-18, -50),
				Vector2(-7, -39),
				Vector2(3, -51),
				Vector2(14, -40),
				Vector2(28, -47),
				Vector2(0, -23)
			]
		),
		FACE_TOP
	)
	_chimney(Vector2(17, -44), 8.0, 27.0)
	_panel_left(Vector2(-12, -17), 11.0, 8.0)
	_panel_right(Vector2(10, -15), 11.0, 8.0, WARNING)
	_line(PackedVector2Array([Vector2(-24, -7), Vector2(0, 6), Vector2(24, -7)]), LINE_SOFT)


func _build_industrial_mid() -> void:
	_iso_prism(58.0, 32.0, 37.0, Color("12466fdd"), FACE_RIGHT, Color("2e7194b5"))
	_chimney(Vector2(-12, -53), 8.0, 32.0)
	_chimney(Vector2(14, -57), 9.0, 39.0)
	for floor_index: int in range(2):
		var y: float = -12.0 - floor_index * 14.0
		_panel_left(Vector2(-13, y - 8), 12.0, 8.0)
		_panel_right(Vector2(12, y - 5), 12.0, 8.0, WARNING)
	_line(
		PackedVector2Array(
			[Vector2(-26, -39), Vector2(-10, -49), Vector2(2, -42), Vector2(17, -51), Vector2(29, -45)]
		),
		ACCENT,
		2.0
	)


func _build_power() -> void:
	_iso_prism(42.0, 25.0, 18.0, FACE_LEFT, FACE_RIGHT, FACE_TOP)
	var base_left := Vector2(-18, -24)
	var base_right := Vector2(18, -24)
	var crown_left := Vector2(-8, -66)
	var crown_right := Vector2(8, -66)
	_line(PackedVector2Array([base_left, crown_left, crown_right, base_right]), LINE, 2.4)
	_line(PackedVector2Array([base_left, crown_right]), LINE_SOFT, 1.3)
	_line(PackedVector2Array([base_right, crown_left]), LINE_SOFT, 1.3)
	_line(PackedVector2Array([Vector2(-13, -46), Vector2(13, -46)]), LINE, 2.0)
	_line(PackedVector2Array([Vector2(-19, -52), Vector2(19, -52)]), ACCENT, 1.8)
	_line(PackedVector2Array([Vector2(-27, -52), Vector2(-19, -52)]), LINE_SOFT, 1.2)
	_line(PackedVector2Array([Vector2(19, -52), Vector2(27, -52)]), LINE_SOFT, 1.2)
	_polygon(
		PackedVector2Array(
			[
				Vector2(2, -43),
				Vector2(-7, -31),
				Vector2(-1, -31),
				Vector2(-5, -20),
				Vector2(8, -35),
				Vector2(2, -35)
			]
		),
		WARNING,
		LINE
	)


func _build_park() -> void:
	_polygon(
		PackedVector2Array(
			[Vector2(0, -30), Vector2(31, -14), Vector2(0, 2), Vector2(-31, -14)]
		),
		Color("247ba075")
	)
	_line(
		PackedVector2Array([Vector2(-25, -13), Vector2(-3, -2), Vector2(23, -15)]),
		WARNING,
		3.0
	)
	_tree_at(Vector2(-13, -19), 0.8)
	_tree_at(Vector2(11, -20), 0.68)
	_tree_at(Vector2(0, -31), 0.58)
	_polygon(
		PackedVector2Array(
			[Vector2(6, -9), Vector2(17, -15), Vector2(23, -12), Vector2(12, -6)]
		),
		Color("69d1e0a0")
	)


func _build_police() -> void:
	_iso_prism(48.0, 27.0, 31.0, FACE_LEFT, Color("17496fd9"), FACE_TOP)
	_panel_left(Vector2(-11, -20), 8.0, 9.0)
	_panel_right(Vector2(11, -17), 8.0, 9.0)
	_polygon(
		PackedVector2Array(
			[
				Vector2(0, -25),
				Vector2(8, -21),
				Vector2(7, -11),
				Vector2(0, -5),
				Vector2(-7, -11),
				Vector2(-8, -21)
			]
		),
		Color("58b8d0b8"),
		LINE
	)
	_line(PackedVector2Array([Vector2(0, -21), Vector2(0, -10)]), WARNING, 1.8)
	_line(PackedVector2Array([Vector2(-4, -16), Vector2(4, -16)]), WARNING, 1.8)
	_polygon(
		PackedVector2Array(
			[Vector2(-7, -47), Vector2(0, -51), Vector2(7, -47), Vector2(0, -43)]
		),
		WARNING
	)


func _build_fire() -> void:
	_iso_prism(52.0, 28.0, 33.0, Color("1c5b82ce"), FACE_RIGHT, FACE_TOP)
	_polygon(
		PackedVector2Array(
			[Vector2(-18, -20), Vector2(0, -10), Vector2(0, 1), Vector2(-18, -9)]
		),
		Color("2f87a2b8")
	)
	for rail: int in range(3):
		var rail_y: float = -16.0 + rail * 5.0
		_line(PackedVector2Array([Vector2(-17, rail_y), Vector2(0, rail_y + 9)]), LINE_SOFT)
	_polygon(
		PackedVector2Array(
			[
				Vector2(8, -29),
				Vector2(15, -22),
				Vector2(13, -14),
				Vector2(7, -10),
				Vector2(3, -17)
			]
		),
		WARNING,
		LINE
	)
	_line(PackedVector2Array([Vector2(-20, -39), Vector2(0, -48), Vector2(20, -39)]), ACCENT, 2.2)


func _build_tree() -> void:
	_tree_at(Vector2.ZERO, 1.2)


func _build_car() -> void:
	_polygon(
		PackedVector2Array(
			[Vector2(-20, -12), Vector2(-6, -20), Vector2(20, -10), Vector2(5, -2)]
		),
		FACE_LIGHT
	)
	_polygon(
		PackedVector2Array(
			[Vector2(-8, -20), Vector2(1, -26), Vector2(15, -20), Vector2(5, -14)]
		),
		Color("58b8d0c2")
	)
	_polygon(
		PackedVector2Array(
			[Vector2(-5, -19), Vector2(1, -23), Vector2(7, -20), Vector2(1, -16)]
		),
		INK,
		LINE_SOFT
	)
	_wheel(Vector2(-11, -7))
	_wheel(Vector2(10, -3))
	_line(PackedVector2Array([Vector2(14, -12), Vector2(19, -10)]), WARNING, 2.6)


func _build_walker() -> void:
	_polygon(
		PackedVector2Array(
			[
				Vector2(-4, -32),
				Vector2(0, -35),
				Vector2(4, -32),
				Vector2(5, -27),
				Vector2(0, -24),
				Vector2(-5, -27)
			]
		),
		WARNING
	)
	_polygon(
		PackedVector2Array(
			[Vector2(-6, -23), Vector2(5, -23), Vector2(7, -10), Vector2(-7, -10)]
		),
		FACE_LIGHT
	)
	_line(PackedVector2Array([Vector2(-5, -20), Vector2(-10, -10)]), LINE, 2.2)
	_line(PackedVector2Array([Vector2(5, -20), Vector2(10, -12)]), LINE, 2.2)
	_line(PackedVector2Array([Vector2(-3, -10), Vector2(-6, 0)]), LINE, 2.4)
	_line(PackedVector2Array([Vector2(3, -10), Vector2(7, 0)]), LINE, 2.4)
	_line(PackedVector2Array([Vector2(-8, 0), Vector2(-4, 0)]), ACCENT, 2.5)
	_line(PackedVector2Array([Vector2(5, 0), Vector2(9, 0)]), ACCENT, 2.5)


func _build_survey_marker() -> void:
	_line(PackedVector2Array([Vector2(-18, 0), Vector2(0, -10), Vector2(18, 0)]), LINE)
	_line(PackedVector2Array([Vector2(0, -10), Vector2(0, -48)]), ACCENT, 2.0)
	_polygon(
		PackedVector2Array([Vector2(0, -48), Vector2(16, -42), Vector2(0, -35)]),
		FACE_LIGHT
	)


func _iso_prism(
	width: float,
	depth: float,
	height: float,
	left_color: Color,
	right_color: Color,
	top_color: Color
) -> void:
	var half_width: float = width * 0.5
	var half_depth: float = depth * 0.5
	var front_bottom := Vector2(0, 0)
	var left_bottom := Vector2(-half_width, -half_depth)
	var right_bottom := Vector2(half_width, -half_depth)
	var front_top := Vector2(0, -height)
	var left_top := left_bottom - Vector2(0, height)
	var right_top := right_bottom - Vector2(0, height)
	var back_top := Vector2(0, -height - depth)
	_polygon(PackedVector2Array([left_top, front_top, front_bottom, left_bottom]), left_color)
	_polygon(
		PackedVector2Array([front_top, right_top, right_bottom, front_bottom]), right_color
	)
	_polygon(PackedVector2Array([back_top, right_top, front_top, left_top]), top_color)


func _panel_left(
	center: Vector2, width: float, height: float, color: Color = Color("0b2c4a")
) -> void:
	_polygon(
		PackedVector2Array(
			[
				center + Vector2(-width, -width * 0.5),
				center,
				center + Vector2(0, height),
				center + Vector2(-width, height - width * 0.5)
			]
		),
		color,
		LINE_SOFT,
		1.1
	)


func _panel_right(
	center: Vector2, width: float, height: float, color: Color = Color("0b2c4a")
) -> void:
	_polygon(
		PackedVector2Array(
			[
				center,
				center + Vector2(width, -width * 0.5),
				center + Vector2(width, height - width * 0.5),
				center + Vector2(0, height)
			]
		),
		color,
		LINE_SOFT,
		1.1
	)


func _chimney(origin: Vector2, width: float, height: float) -> void:
	var half_width: float = width * 0.5
	_polygon(
		PackedVector2Array(
			[
				origin + Vector2(-half_width, 0),
				origin + Vector2(0, half_width * 0.5),
				origin + Vector2(0, height),
				origin + Vector2(-half_width, height - half_width * 0.5)
			]
		),
		FACE_LEFT
	)
	_polygon(
		PackedVector2Array(
			[
				origin + Vector2(0, half_width * 0.5),
				origin + Vector2(half_width, 0),
				origin + Vector2(half_width, height - half_width * 0.5),
				origin + Vector2(0, height)
			]
		),
		FACE_RIGHT
	)
	_polygon(
		PackedVector2Array(
			[
				origin + Vector2(0, -half_width * 0.5),
				origin + Vector2(half_width, 0),
				origin + Vector2(0, half_width * 0.5),
				origin + Vector2(-half_width, 0)
			]
		),
		WARNING
	)


func _tree_at(origin: Vector2, scale_factor: float) -> void:
	var trunk_half: float = 3.0 * scale_factor
	var trunk_height: float = 18.0 * scale_factor
	_polygon(
		PackedVector2Array(
			[
				origin + Vector2(-trunk_half, -trunk_height),
				origin + Vector2(trunk_half, -trunk_height),
				origin + Vector2(trunk_half, 0),
				origin + Vector2(-trunk_half, 0)
			]
		),
		FACE_RIGHT
	)
	var canopy_width: float = 16.0 * scale_factor
	var canopy_height: float = 30.0 * scale_factor
	_polygon(
		PackedVector2Array(
			[
				origin + Vector2(0, -trunk_height - canopy_height),
				origin + Vector2(canopy_width, -trunk_height - canopy_height * 0.45),
				origin + Vector2(0, -trunk_height),
				origin + Vector2(-canopy_width, -trunk_height - canopy_height * 0.45)
			]
		),
		Color("2c82a39e")
	)
	_line(
		PackedVector2Array(
			[
				origin + Vector2(-canopy_width * 0.65, -trunk_height - canopy_height * 0.45),
				origin + Vector2(0, -trunk_height - canopy_height * 0.66),
				origin + Vector2(canopy_width * 0.65, -trunk_height - canopy_height * 0.45)
			]
		),
		ACCENT,
		1.2
	)


func _wheel(center: Vector2) -> void:
	_polygon(
		PackedVector2Array(
			[
				center + Vector2(-4, 0),
				center + Vector2(-2, -3),
				center + Vector2(2, -3),
				center + Vector2(4, 0),
				center + Vector2(2, 3),
				center + Vector2(-2, 3)
			]
		),
		INK,
		LINE_SOFT,
		1.0
	)


func _polygon(
	points: PackedVector2Array,
	color: Color,
	outline: Color = Color("d9f8ff"),
	width: float = 1.6
) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	visual.add_child(polygon)
	if outline.a <= 0.0:
		return
	var border := Line2D.new()
	border.points = points
	border.closed = true
	border.width = width
	border.default_color = outline
	border.antialiased = true
	visual.add_child(border)


func _line(
	points: PackedVector2Array, color: Color = Color("d9f8ff"), width: float = 1.4
) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.antialiased = true
	visual.add_child(line)


func _reset_visual() -> void:
	visual.position = Vector2.ZERO
	visual.rotation = 0.0
	visual.scale = Vector2.ONE * 0.5
	visual.modulate = Color.WHITE


func _on_animation_finished(action: StringName) -> void:
	if not _posing and action in ["build", "grow", "demolish"]:
		play_action("problem" if bool(get_meta("problem", false)) else "idle")


func _make_animations() -> void:
	animation.stop()
	if animation.has_animation_library(""):
		animation.remove_animation_library("")
	var library := AnimationLibrary.new()
	for action: String in ACTIONS:
		var clip := Animation.new()
		clip.length = float(DURATIONS[action])
		if action in ["idle", "problem", "move"]:
			clip.loop_mode = Animation.LOOP_LINEAR
		match action:
			"idle":
				_idle_tracks(clip)
			"build":
				_build_tracks(clip)
			"grow":
				_grow_tracks(clip)
			"demolish":
				_demolish_tracks(clip)
			"problem":
				_problem_tracks(clip)
			"move":
				_move_tracks(clip)
		library.add_animation(action, clip)
	animation.add_animation_library("", library)


func _idle_tracks(clip: Animation) -> void:
	_track(clip, "scale", [Vector2(0.5, 0.5), Vector2(0.5, 0.511), Vector2(0.5, 0.5)])
	if kind == "tree":
		_track(clip, "rotation", [-0.025, 0.025, -0.025])
	elif kind == "walker":
		_track(clip, "position", [Vector2.ZERO, Vector2(0, -0.7), Vector2.ZERO])


func _build_tracks(clip: Animation) -> void:
	_track(
		clip,
		"position",
		[Vector2(0, -28), Vector2(0, -12), Vector2(0, 2), Vector2(0, -5), Vector2.ZERO]
	)
	_track(
		clip,
		"scale",
		[
			Vector2(0.32, 0.32),
			Vector2(0.45, 0.55),
			Vector2(0.6, 0.4),
			Vector2(0.47, 0.55),
			Vector2(0.5, 0.5)
		]
	)
	_track(clip, "rotation", [-0.08, 0.025, -0.02, 0.012, 0.0])
	_track(
		clip,
		"modulate",
		[Color(1.1, 1.1, 0.8, 0.2), Color.WHITE, Color(1.45, 1.35, 1.1), Color.WHITE, Color.WHITE]
	)


func _grow_tracks(clip: Animation) -> void:
	_track(
		clip,
		"position",
		[Vector2.ZERO, Vector2(0, -5), Vector2(0, -8), Vector2(0, -2), Vector2.ZERO]
	)
	_track(
		clip,
		"scale",
		[
			Vector2(0.5, 0.38),
			Vector2(0.48, 0.56),
			Vector2(0.55, 0.6),
			Vector2(0.49, 0.53),
			Vector2(0.5, 0.5)
		]
	)
	_track(
		clip,
		"modulate",
		[
			Color.WHITE,
			Color(1.4, 1.5, 1.25),
			Color(1.7, 1.7, 1.3),
			Color(1.2, 1.25, 1.1),
			Color.WHITE
		]
	)


func _demolish_tracks(clip: Animation) -> void:
	_track(
		clip,
		"position",
		[Vector2.ZERO, Vector2(1, -2), Vector2(4, 4), Vector2(7, 8), Vector2(9, 12)]
	)
	_track(
		clip,
		"scale",
		[
			Vector2(0.5, 0.5),
			Vector2(0.52, 0.48),
			Vector2(0.48, 0.34),
			Vector2(0.3, 0.15),
			Vector2(0.02, 0.02)
		]
	)
	_track(clip, "rotation", [0.0, -0.1, 0.18, 0.3, 0.4])
	_track(
		clip,
		"modulate",
		[
			Color.WHITE,
			Color(1.15, 0.9, 0.75),
			Color(0.7, 0.65, 0.58, 0.8),
			Color(0.7, 0.65, 0.58, 0.4),
			Color(0.7, 0.65, 0.58, 0.0)
		]
	)


func _problem_tracks(clip: Animation) -> void:
	_track(clip, "rotation", [0.0, -0.045, 0.045, -0.035, 0.0])
	_track(
		clip,
		"position",
		[Vector2.ZERO, Vector2(-1, 0), Vector2(1, -1), Vector2(-1, 0), Vector2.ZERO]
	)
	_track(
		clip,
		"modulate",
		[
			Color.WHITE,
			Color(1.2, 0.7, 0.45),
			Color(1.45, 0.8, 0.52),
			Color(1.2, 0.7, 0.45),
			Color.WHITE
		]
	)


func _move_tracks(clip: Animation) -> void:
	if kind == "walker":
		_track(clip, "rotation", [-0.16, 0.0, 0.16, 0.0, -0.16])
		_track(
			clip,
			"position",
			[Vector2(-1, 0), Vector2(0, -2.5), Vector2(1, 0), Vector2(0, -2.5), Vector2(-1, 0)]
		)
		_track(
			clip,
			"scale",
			[
				Vector2(0.5, 0.5),
				Vector2(0.48, 0.54),
				Vector2(0.5, 0.5),
				Vector2(0.48, 0.54),
				Vector2(0.5, 0.5)
			]
		)
	elif kind == "car":
		_track(clip, "rotation", [-0.025, 0.025, -0.025])
		_track(
			clip,
			"position",
			[Vector2.ZERO, Vector2(0, -0.8), Vector2.ZERO, Vector2(0, -0.5), Vector2.ZERO]
		)
		_track(
			clip,
			"scale",
			[Vector2(0.5, 0.5), Vector2(0.51, 0.49), Vector2(0.5, 0.5)]
		)
	else:
		_track(clip, "rotation", [-0.02, 0.02, -0.02])
		_track(clip, "position", [Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO])


func _track(clip: Animation, property: String, values: Array) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath("Visual:" + property))
	for index: int in range(values.size()):
		clip.track_insert_key(track, clip.length * index / float(values.size() - 1), values[index])
