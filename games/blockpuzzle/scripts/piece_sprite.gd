class_name PieceSprite
extends Node2D
## 精霊の独自画像と、撮影時にも時刻を固定できるアニメーション。

const TEXTURES: Array[Texture2D] = [
	preload("res://assets/art/piece_1.svg"),
	preload("res://assets/art/piece_2.svg"),
	preload("res://assets/art/piece_3.svg"),
	preload("res://assets/art/piece_4.svg"),
	preload("res://assets/art/piece_5.svg"),
]

var kind: int = 1
var animator: AnimationPlayer
var _rig: Node2D
var _body: Sprite2D


func setup(piece_kind: int, side: float = 40.0) -> void:
	kind = clampi(piece_kind, 1, TEXTURES.size())
	if not is_instance_valid(_rig):
		_build()
	_rig.scale = Vector2.ONE * side / 128.0
	_body.texture = TEXTURES[kind - 1]
	play_pose("idle")


## 操作への反応は毎回再生するため、同名でも再開する。
func play_pose(pose: String) -> void:
	if not is_instance_valid(animator) or not animator.has_animation(pose):
		return
	animator.stop()
	_body.scale = Vector2.ONE
	_body.position = Vector2.ZERO
	_body.rotation = 0.0
	_body.modulate = Color.WHITE
	animator.play(pose)
	animator.advance(0.0)


func seek_pose(pose: String, time: float) -> void:
	play_pose(pose)
	animator.seek(time, true)
	animator.pause()


func _build() -> void:
	_rig = Node2D.new()
	_rig.name = "Rig"
	add_child(_rig)
	_body = Sprite2D.new()
	_body.name = "Body"
	_rig.add_child(_body)
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	add_child(animator)
	var library: AnimationLibrary = AnimationLibrary.new()
	library.add_animation("idle", _pose(
		1.8, [Vector2.ONE, Vector2(1.035, 0.965), Vector2.ONE],
		[Vector2.ZERO, Vector2(0, -3), Vector2.ZERO], [0.0, 0.025, 0.0], true))
	library.add_animation("move", _pose(
		0.2, [Vector2.ONE, Vector2(0.85, 1.13), Vector2.ONE],
		[Vector2.ZERO, Vector2(0, -5), Vector2.ZERO], [0.0, -0.16, 0.0]))
	library.add_animation("land", _pose(
		0.32, [Vector2(0.91, 1.1), Vector2(1.23, 0.77), Vector2.ONE],
		[Vector2(0, -8), Vector2(0, 10), Vector2.ZERO], [0.0, 0.035, 0.0]))
	var clear: Animation = _pose(
		0.48, [Vector2.ONE, Vector2(1.22, 1.22), Vector2(0.18, 0.18)],
		[Vector2.ZERO, Vector2(0, -10), Vector2(0, -20)], [0.0, -0.13, 0.2])
	_track(clear, "Rig/Body:modulate", [Color.WHITE, Color(1.6, 1.5, 1.3),
		Color(1.0, 1.0, 1.0, 0.0)])
	library.add_animation("clear", clear)
	var hurt: Animation = _pose(
		0.3, [Vector2.ONE, Vector2(1.12, 0.88), Vector2.ONE],
		[Vector2(-5, 0), Vector2(6, 0), Vector2.ZERO], [-0.1, 0.1, 0.0])
	_track(hurt, "Rig/Body:modulate", [Color.WHITE, Color(1.5, 0.55, 0.55), Color.WHITE])
	library.add_animation("hurt", hurt)
	animator.add_animation_library("", library)
	animator.animation_finished.connect(_on_animation_finished)


func _pose(
	duration: float, sizes: Array, positions: Array, rotations: Array, loop: bool = false
) -> Animation:
	var animation: Animation = Animation.new()
	animation.length = duration
	if loop:
		animation.loop_mode = Animation.LOOP_LINEAR
	_track(animation, "Rig/Body:scale", sizes)
	_track(animation, "Rig/Body:position", positions)
	_track(animation, "Rig/Body:rotation", rotations)
	return animation


func _track(animation: Animation, path: String, values: Array) -> void:
	var index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(path))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_CUBIC)
	for i: int in range(values.size()):
		animation.track_insert_key(index, animation.length * float(i) / 2.0, values[i])


func _on_animation_finished(pose: StringName) -> void:
	if pose != &"clear":
		play_pose("idle")
