extends Node2D
## 一文字の姿勢・大きさ・残光を動かし、キャラクターごとの六動作を表す。

const Data := preload("res://scripts/game_data.gd")
const UI := preload("res://scripts/ui.gd")
const STYLES: Dictionary = {
	"hero": {"pace": 1.0, "bob": 2.0, "tilt": 0.08, "squash": 0.06},
	"chaser": {"pace": 0.8, "bob": 3.0, "tilt": 0.14, "squash": 0.1},
	"archer": {"pace": 1.2, "bob": 1.0, "tilt": 0.04, "squash": 0.03},
	"splitter": {"pace": 0.85, "bob": 4.0, "tilt": 0.06, "squash": 0.2},
	"sleeper": {"pace": 1.65, "bob": 1.5, "tilt": 0.03, "squash": 0.12},
	"swift": {"pace": 0.55, "bob": 3.5, "tilt": 0.2, "squash": 0.1},
	"boss": {"pace": 1.4, "bob": 1.5, "tilt": 0.07, "squash": 0.05},
}

var animation: AnimationPlayer
var kind: String = "hero"
var _glyph: Label
var _afterimage: Label
var _travel_tween: Tween
var _base_scale: Vector2 = Vector2.ONE


func setup(actor_kind: String) -> void:
	kind = actor_kind
	if not is_instance_valid(_glyph):
		_afterimage = _new_glyph("Afterimage")
		_afterimage.modulate = Color(0.2, 1.0, 0.7, 0.18)
		_afterimage.position += Vector2(2, 3)
		add_child(_afterimage)
		_glyph = _new_glyph("Glyph")
		add_child(_glyph)
		animation = AnimationPlayer.new()
		animation.name = "AnimationPlayer"
		add_child(animation)
		animation.animation_finished.connect(_on_animation_finished)
	var glyph_text := "@" if kind == "hero" else str(Data.ENEMIES[kind].glyph)
	var glyph_color := UI.TEAL if kind == "hero" else Color(Data.ENEMIES[kind].color)
	for label: Label in [_glyph, _afterimage]:
		label.text = glyph_text
		label.add_theme_font_size_override("font_size", 42 if kind == "boss" else 34)
	_glyph.add_theme_color_override("font_color", glyph_color)
	_afterimage.add_theme_color_override("font_color", glyph_color)
	_afterimage.show()
	_base_scale = Vector2.ONE * (1.12 if kind == "boss" else 1.0)
	_build_animations()
	animation.play("idle")
	animation.advance(0.0)


func _new_glyph(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = Vector2(-25, -27)
	label.size = Vector2(50, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load(UI.FONT_PATH))
	label.add_theme_color_override("font_outline_color", Color("020507"))
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 行動発生ごとに演出を再生し直すため、再生時刻については冪等にしない。
func animate(action: String, direction: Vector2 = Vector2.RIGHT) -> void:
	if not is_instance_valid(animation) or not animation.has_animation(action):
		return
	if action == "attack":
		var attack: Animation = animation.get_animation("attack")
		attack.track_set_key_value(0, 1, Vector2(-25, -31) - direction.normalized() * 4.0)
		attack.track_set_key_value(0, 2, Vector2(-25, -27) + direction.normalized() * 13.0)
	animation.stop()
	animation.play(action)
	animation.advance(0.0)


func travel(target: Vector2, duration: float = 0.14) -> void:
	if position.is_equal_approx(target):
		return
	if _travel_tween != null and _travel_tween.is_valid():
		_travel_tween.kill()
	animate("move", target - position)
	_travel_tween = create_tween()
	_travel_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE)


func _build_animations() -> void:
	animation.stop()
	if animation.has_animation_library(""):
		animation.remove_animation_library("")
	var library: AnimationLibrary = AnimationLibrary.new()
	var style: Dictionary = STYLES.get(kind, STYLES.hero)
	var pace: float = float(style.pace)
	var bob: float = float(style.bob)
	var tilt: float = float(style.tilt)
	var squash: float = float(style.squash)
	var origin := Vector2(-25, -27)
	var rest: Vector2 = _base_scale
	var wide: Vector2 = rest * Vector2(1.0 + squash, 1.0 - squash)
	var tall: Vector2 = rest * Vector2(1.0 - squash, 1.0 + squash)
	_add_animation(
		library, "idle", 1.1 * pace,
		[origin, origin + Vector2(0, -bob), origin],
		[rest, wide, rest], [0.0, tilt * 0.3, 0.0],
		[Color.WHITE, Color(1.16, 1.16, 1.16), Color.WHITE]
	)
	library.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	_add_animation(
		library, "move", 0.22 * pace,
		[origin, origin + Vector2(0, -bob * 2.0), origin],
		[wide, tall, rest], [-tilt, tilt, 0.0],
		[Color.WHITE, Color(1.3, 1.3, 1.3), Color.WHITE]
	)
	_add_animation(
		library, "attack", 0.3 * pace,
		[origin, origin + Vector2(-4, 0), origin + Vector2(13, 0), origin],
		[rest, wide, tall, rest], [0.0, -tilt * 2.0, tilt * 2.0, 0.0],
		[Color.WHITE, Color.WHITE, Color(1.8, 1.4, 0.85), Color.WHITE]
	)
	_add_animation(
		library, "hurt", 0.26,
		[origin, origin + Vector2(-4, 1), origin + Vector2(3, 0), origin],
		[rest, wide, tall, rest], [0.0, -0.18, 0.12, 0.0],
		[Color(2.5, 0.35, 0.35), Color.WHITE, Color(2, 0.6, 0.6), Color.WHITE]
	)
	_add_animation(
		library, "death", 0.4 * pace,
		[origin, origin + Vector2(0, -7), origin + Vector2(0, 10)],
		[rest, tall, rest * Vector2(1.35, 0.05)], [0.0, tilt * 2.0, 0.5],
		[Color.WHITE, Color(1.4, 0.75, 0.5), Color(1, 1, 1, 0)]
	)
	_add_animation(
		library, "appear", 0.42 * pace,
		[origin + Vector2(0, -16), origin + Vector2(0, 2), origin],
		[rest * 0.1, wide * 1.15, rest], [-tilt * 2.0, tilt, 0.0],
		[Color(1, 1, 1, 0), Color(1.5, 1.4, 1.2), Color.WHITE]
	)
	animation.add_animation_library("", library)


func _add_animation(
	library: AnimationLibrary, action: String, duration: float,
	positions: Array, scales: Array, rotations: Array, colors: Array
) -> void:
	var clip: Animation = Animation.new()
	clip.length = duration
	_add_track(clip, "Glyph:position", positions)
	_add_track(clip, "Glyph:scale", scales)
	_add_track(clip, "Glyph:rotation", rotations)
	_add_track(clip, "Glyph:modulate", colors)
	library.add_animation(action, clip)


func _add_track(clip: Animation, path: NodePath, values: Array) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, path)
	clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for index: int in range(values.size()):
		var time: float = clip.length * float(index) / float(values.size() - 1)
		clip.track_insert_key(track, time, values[index])


func _on_animation_finished(action: StringName) -> void:
	if action == &"death":
		_afterimage.hide()
	elif action != &"idle":
		animation.play("idle")
