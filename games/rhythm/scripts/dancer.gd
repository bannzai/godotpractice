extends Node2D
## 各奏者の姿勢。演出の再生と時間経過は非冪等。

const POSES: Array[String] = ["idle", "dance", "hit", "miss", "celebrate"]
const ART_SCALE := 0.16
var sprite: Sprite2D
var animation: AnimationPlayer
var character: String = "fox"
var pose: String = "idle"
var reaction: float = 0.0
var frozen: float = 0.0


func setup(id: String) -> void:
	if sprite != null:
		return
	character = id
	sprite = Sprite2D.new()
	sprite.name = "Art"
	var filenames: Dictionary = {
		"fox": "fox-taiko",
		"bird": "bird-flute",
		"rabbit": "rabbit-shamisen",
	}
	sprite.texture = load("res://assets/generated/%s.png" % str(filenames[id]))
	sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	sprite.scale = Vector2.ONE * ART_SCALE
	var paper: ShaderMaterial = ShaderMaterial.new()
	paper.shader = load("res://shaders/paper_shadow.gdshader")
	sprite.material = paper
	add_child(sprite)
	animation = AnimationPlayer.new()
	add_child(animation)
	var library: AnimationLibrary = AnimationLibrary.new()
	for kind: String in POSES:
		library.add_animation(kind, _make_animation(kind))
	animation.add_animation_library("", library)
	animation.play("idle")


func _make_animation(kind: String) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = 0.6
	anim.loop_mode = Animation.LOOP_LINEAR if kind in ["idle", "dance"] else Animation.LOOP_NONE
	var direction: float = -1.0 if character == "bird" else 1.0
	var rotations: Array = [0.0, 0.025, -0.018, 0.0]
	var positions: Array = [Vector2.ZERO, Vector2(0, -4), Vector2(0, -2), Vector2.ZERO]
	var scales: Array = [
		Vector2.ONE * ART_SCALE,
		Vector2(1.02, 0.98) * ART_SCALE,
		Vector2(0.99, 1.01) * ART_SCALE,
		Vector2.ONE * ART_SCALE,
	]
	var colors: Array = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	match kind:
		"dance":
			rotations = [-0.09 * direction, 0.10 * direction, -0.07 * direction, 0.08 * direction]
			positions = [Vector2(-7, 0), Vector2(7, -18), Vector2(5, -7), Vector2(-6, -15)]
			scales = [
				Vector2(1.04, 0.96) * ART_SCALE,
				Vector2(0.95, 1.06) * ART_SCALE,
				Vector2(1.02, 0.98) * ART_SCALE,
				Vector2(0.97, 1.04) * ART_SCALE,
			]
		"hit":
			rotations = [-0.15 * direction, 0.16 * direction, -0.06 * direction, 0.0]
			positions = [Vector2(0, 5), Vector2(0, -30), Vector2(0, -12), Vector2.ZERO]
			scales = [
				Vector2(1.16, 0.84) * ART_SCALE,
				Vector2(0.91, 1.12) * ART_SCALE,
				Vector2(1.04, 0.96) * ART_SCALE,
				Vector2.ONE * ART_SCALE,
			]
		"miss":
			rotations = [0.12, -0.13, 0.08, 0.0]
			positions = [Vector2(0, 8), Vector2(-10, 0), Vector2(7, 5), Vector2.ZERO]
			scales = [
				Vector2(1.12, 0.88) * ART_SCALE,
				Vector2(0.95, 1.0) * ART_SCALE,
				Vector2(1.04, 0.94) * ART_SCALE,
				Vector2.ONE * ART_SCALE,
			]
			colors = [Color("c1a6d5"), Color("e2d4e9"), Color("eadff0"), Color.WHITE]
		"celebrate":
			rotations = [-0.2, 0.2, -0.16, 0.0]
			positions = [Vector2.ZERO, Vector2(0, -48), Vector2(0, -26), Vector2.ZERO]
			scales = [
				Vector2(1.1, 0.9) * ART_SCALE,
				Vector2(0.9, 1.12) * ART_SCALE,
				Vector2(1.06, 0.94) * ART_SCALE,
				Vector2.ONE * ART_SCALE,
			]
	_add_track(anim, "Art:rotation", rotations)
	_add_track(anim, "Art:position", positions)
	_add_track(anim, "Art:scale", scales)
	_add_track(anim, "Art:modulate", colors)
	return anim


func _add_track(anim: Animation, property: String, values: Array) -> void:
	var track: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath(property))
	for index: int in range(4):
		anim.track_insert_key(track, index * 0.15, values[index])


func react(kind: String) -> void:
	if animation == null:
		return
	pose = kind
	reaction = 0.6
	frozen = 0.045 if kind == "hit" else 0.0
	animation.play(kind)
	animation.seek(0, true)


func sync_beat(beat: float, playing: bool, delta: float) -> void:
	if animation == null:
		return
	reaction = maxf(0, reaction - delta)
	frozen = maxf(0, frozen - delta)
	animation.speed_scale = 0.0 if frozen > 0 else 1.0
	if reaction > 0:
		return
	pose = "dance" if playing else "idle"
	animation.play(pose)
	animation.seek(fposmod(beat, 1.0) * 0.6, true)


func sample(kind: String, progress: float) -> void:
	pose = kind
	reaction = 1000.0
	animation.play(kind)
	animation.pause()
	animation.seek(minf(progress * 0.6, 0.599), true)
