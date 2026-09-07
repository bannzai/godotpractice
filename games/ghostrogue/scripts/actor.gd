extends Node2D
## 霊の外観と一時的な演出だけを所有し、ゲームの状態は持たない。

signal motion_finished(motion: String)

const DURATIONS: Dictionary = {
	"idle": 2.4, "attack": 0.58, "hurt": 0.42, "dissolve": 0.9, "move": 0.65
}
const SPIRIT_ATLAS_PATH := "res://assets/generated/spirit-cutins.png"
const SPIRIT_IDS: Array[String] = [
	"child", "warrior", "water", "beast",
	"headless", "doll", "crow", "monk",
	"moth", "fox", "bride", "bell",
]

var character_id: String = ""
var sprite: Sprite2D
var echo: Sprite2D
var detail: Sprite2D
var animator: AnimationPlayer


func setup(id: String) -> void:
	if character_id == id and is_instance_valid(sprite):
		return
	if not is_instance_valid(sprite):
		echo = Sprite2D.new()
		echo.name = "Echo"
		add_child(echo)
		sprite = Sprite2D.new()
		sprite.name = "Body"
		add_child(sprite)
		detail = Sprite2D.new()
		detail.name = "Detail"
		sprite.add_child(detail)
		animator = AnimationPlayer.new()
		animator.name = "AnimationPlayer"
		add_child(animator)
		animator.animation_finished.connect(_on_motion_finished)
	if character_id != id:
		character_id = id
		if id in SPIRIT_IDS:
			sprite.texture = _spirit_portrait(id)
			echo.texture = null
			detail.texture = null
		else:
			sprite.texture = load("res://assets/art/%s_body.svg" % id)
			detail.texture = load("res://assets/art/%s_detail.svg" % id)
			echo.texture = load("res://assets/art/%s.svg" % id)
		detail.show_behind_parent = id in ["fox", "moth", "bride", "crow", "beast", "boss"]
		_create_animations()
	play_motion("idle")


func _spirit_portrait(id: String) -> AtlasTexture:
	var atlas: Texture2D = load(SPIRIT_ATLAS_PATH)
	var index: int = SPIRIT_IDS.find(id)
	var cell_size := Vector2(float(atlas.get_width()) / 4.0, float(atlas.get_height()) / 3.0)
	var portrait := AtlasTexture.new()
	portrait.atlas = atlas
	portrait.region = Rect2(
		float(index % 4) * cell_size.x,
		float(index / 4) * cell_size.y,
		cell_size.x,
		cell_size.y
	)
	portrait.filter_clip = true
	return portrait


func _create_animations() -> void:
	if animator.has_animation_library(""):
		animator.remove_animation_library("")
	var library := AnimationLibrary.new()
	for motion: String in DURATIONS:
		var animation := Animation.new()
		animation.length = DURATIONS[motion]
		if motion == "idle":
			animation.loop_mode = Animation.LOOP_LINEAR
		_set_track(animation, "Body:position", [0.0, 1.2, 2.4],
			[Vector2.ZERO, Vector2(0, -6), Vector2.ZERO])
		_set_track(animation, "Body:scale", [0.0], [Vector2.ONE])
		_set_track(animation, "Body:rotation", [0.0], [0.0])
		_set_track(animation, "Body:modulate", [0.0], [Color.WHITE])
		_set_track(animation, "Echo:modulate", [0.0], [Color(0.6, 0.9, 0.9, 0)])
		_set_track(animation, "Echo:scale", [0.0], [Vector2.ONE])
		_set_track(animation, "Echo:position", [0.0], [Vector2.ZERO])
		match motion:
			"attack":
				_replace_track(animation, "Body:position", [0.0, 0.15, 0.24, 0.32, 0.58],
					[Vector2.ZERO, Vector2(-12, 3), Vector2(30, -4), Vector2(30, -4), Vector2.ZERO])
				_replace_track(animation, "Body:rotation", [0.0, 0.15, 0.24, 0.58],
					[0.0, -0.06, 0.12, 0.0])
				_replace_track(animation, "Echo:modulate", [0.0, 0.18, 0.24, 0.5],
					[Color(0.5, 0.9, 0.9, 0), Color(0.5, 0.9, 0.9, 0),
					Color(0.5, 0.9, 0.9, 0.42), Color(0.5, 0.9, 0.9, 0)])
			"hurt":
				_replace_track(animation, "Body:position", [0.0, 0.08, 0.14, 0.2, 0.27, 0.42],
					[Vector2.ZERO, Vector2(-10, 0), Vector2(-10, 0), Vector2(6, 0),
					Vector2(-4, 0), Vector2.ZERO])
				_replace_track(animation, "Body:modulate", [0.0, 0.08, 0.14, 0.42],
					[Color.WHITE, Color(1.9, 0.48, 0.4), Color(1.9, 0.48, 0.4), Color.WHITE])
			"dissolve":
				_replace_track(animation, "Body:position", [0.0, 0.9],
					[Vector2.ZERO, Vector2(0, -29)])
				_replace_track(animation, "Body:scale", [0.0, 0.25, 0.9],
					[Vector2.ONE, Vector2(0.96, 1.04), Vector2(0.55, 1.26)])
				_replace_track(animation, "Body:modulate", [0.0, 0.3, 0.9],
					[Color.WHITE, Color(0.8, 1.0, 1.0, 0.65), Color(0.4, 0.8, 0.9, 0)])
				_replace_track(animation, "Echo:modulate", [0.0, 0.3, 0.9],
					[Color(0.6, 0.9, 0.9, 0), Color(0.6, 0.9, 0.9, 0.36),
					Color(0.6, 0.9, 0.9, 0)])
				_replace_track(animation, "Echo:scale", [0.0, 0.9],
					[Vector2.ONE, Vector2(1.35, 1.05)])
			"move":
				_replace_track(animation, "Body:position", [0.0, 0.16, 0.32, 0.48, 0.65],
					[Vector2.ZERO, Vector2(8, -10), Vector2(0, 0), Vector2(-8, -10), Vector2.ZERO])
				_replace_track(animation, "Body:rotation", [0.0, 0.16, 0.48, 0.65],
					[0.0, 0.05, -0.05, 0.0])
		_animate_detail(animation, motion)
		library.add_animation(motion, animation)
	animator.add_animation_library("", library)


func _animate_detail(animation: Animation, motion: String) -> void:
	var pivots: Dictionary = {
		"child": Vector2(25, -10), "warrior": Vector2(-48, 62),
		"water": Vector2(-15, -65), "fox": Vector2(0, 52),
		"headless": Vector2(-65, -12), "doll": Vector2(45, 19),
		"monk": Vector2(53, 0), "moth": Vector2(0, -12),
		"bride": Vector2(0, -51), "crow": Vector2(0, -12),
		"bell": Vector2(0, 50), "beast": Vector2(-13, -42),
		"police": Vector2(-48, 26), "boss": Vector2(0, -13)
	}
	detail.offset = -pivots.get(character_id, Vector2(27, -5))
	detail.position = -detail.offset
	var swing: float = 0.09
	if character_id in ["warrior", "monk", "headless", "police"]:
		swing = 0.14
	elif character_id in ["bride", "water"]:
		swing = 0.035
	_set_track(animation, "Body/Detail:rotation", [0.0, 1.2, 2.4], [-swing, swing, -swing])
	_set_track(animation, "Body/Detail:scale", [0.0], [Vector2.ONE])
	_set_track(animation, "Body/Detail:modulate", [0.0], [Color.WHITE])
	match motion:
		"attack":
			var slash: float = -0.68 if character_id in ["warrior", "monk"] else 0.48
			_replace_track(animation, "Body/Detail:rotation", [0.0, 0.18, 0.29, 0.43, 0.58],
				[-swing, -slash * 0.8, slash, slash * 0.8, -swing])
			_replace_track(animation, "Body/Detail:scale", [0.0, 0.24, 0.4, 0.58],
				[Vector2.ONE, Vector2(1.07, 1.1), Vector2(1.07, 1.1), Vector2.ONE])
		"hurt":
			_replace_track(animation, "Body/Detail:rotation", [0.0, 0.09, 0.2, 0.32, 0.42],
				[-swing, 0.35, -0.2, 0.1, -swing])
		"dissolve":
			_replace_track(animation, "Body/Detail:rotation", [0.0, 0.9], [-swing, 0.7])
			_replace_track(animation, "Body/Detail:scale", [0.0, 0.9],
				[Vector2.ONE, Vector2(1.3, 0.65)])
			_replace_track(animation, "Body/Detail:modulate", [0.0, 0.6],
				[Color.WHITE, Color(0.7, 1.0, 1.0, 0)])
		"move":
			_replace_track(animation, "Body/Detail:rotation", [0.0, 0.16, 0.48, 0.65],
				[-swing, 0.24, -0.24, -swing])
	if character_id in ["moth", "crow", "boss"] and motion in ["idle", "move"]:
		_replace_track(animation, "Body/Detail:scale", [0.0, animation.length * 0.5, animation.length],
			[Vector2(0.85, 0.94), Vector2(1.05, 1.03), Vector2(0.85, 0.94)])


func _set_track(animation: Animation, target: String, times: Array, values: Array) -> void:
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(target))
	for index: int in range(times.size()):
		animation.track_insert_key(track, times[index], values[index])


func _replace_track(animation: Animation, target: String, times: Array, values: Array) -> void:
	animation.remove_track(animation.find_track(NodePath(target), Animation.TYPE_VALUE))
	_set_track(animation, target, times, values)


# 操作ごとの演出は、同名でも新しい動作として最初から再生する。
func play_motion(motion: String) -> void:
	if not is_instance_valid(animator) or not DURATIONS.has(motion):
		return
	animator.stop()
	animator.play(motion)
	animator.advance(0)


func seek_motion(motion: String, time: float) -> void:
	if not is_instance_valid(animator) or not DURATIONS.has(motion):
		return
	animator.play(motion)
	animator.seek(clampf(time, 0, DURATIONS[motion]), true)
	animator.pause()


func _on_motion_finished(motion: StringName) -> void:
	if motion != "dissolve":
		play_motion("idle")
	motion_finished.emit(motion)
