extends Node2D
## 建物と住民の表示。進行状態は simulation のタイルだけが保持する。

const ACTIONS: Array[String] = ["idle", "build", "demolish", "grow", "problem", "move"]
const DURATIONS: Dictionary = {
	"idle": 2.4, "build": 0.7, "demolish": 0.55, "grow": 0.8, "problem": 1.2, "move": 0.48
}

var kind: String = ""
var sprite: Sprite2D
var animation: AnimationPlayer
var _posing: bool = false


func setup(value: String) -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = false
		add_child(sprite)
		animation = AnimationPlayer.new()
		animation.name = "AnimationPlayer"
		animation.animation_finished.connect(_on_animation_finished)
		add_child(animation)
	if kind == value:
		return
	kind = value
	var path: String = "res://assets/sprites/%s.svg" % value
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	if value == "car":
		sprite.offset = Vector2(-20, -12)
	elif value == "walker":
		sprite.offset = Vector2(-10, -29)
	else:
		sprite.offset = Vector2(-32, -68)
	_make_animations()
	play_action("idle")


# 操作イベントごとに先頭から演出するため、同じ指定でも再生時刻を戻す。
func play_action(action: String) -> void:
	if animation != null and action in ACTIONS:
		_posing = false
		animation.stop()
		_reset_sprite()
		animation.play(action)


func seek_pose(action: String, progress: float) -> void:
	if animation == null or action not in ACTIONS:
		return
	_posing = true
	animation.stop()
	_reset_sprite()
	animation.play(action)
	animation.seek(clampf(progress, 0.0, 1.0) * animation.get_animation(action).length, true)
	animation.pause()


func _reset_sprite() -> void:
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * 0.5
	sprite.modulate = Color.WHITE


func _on_animation_finished(action: StringName) -> void:
	if not _posing and action in ["build", "grow", "demolish"]:
		play_action("problem" if bool(get_meta("problem", false)) else "idle")


func _make_animations() -> void:
	animation.stop()
	if animation.has_animation_library(""):
		animation.remove_animation_library("")
	var library: AnimationLibrary = AnimationLibrary.new()
	for action: String in ACTIONS:
		var clip: Animation = Animation.new()
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
		_track(clip, "scale", [Vector2(0.5, 0.5), Vector2(0.51, 0.49), Vector2(0.5, 0.5)])
	else:
		_track(clip, "rotation", [-0.02, 0.02, -0.02])
		_track(clip, "position", [Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO])


func _track(clip: Animation, property: String, values: Array) -> void:
	var track: int = clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(track, NodePath("Sprite:" + property))
	for index: int in range(values.size()):
		clip.track_insert_key(track, clip.length * index / float(values.size() - 1), values[index])
