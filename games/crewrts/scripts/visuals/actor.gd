extends Node3D
## ゲーム座標のルートと、部位アニメーションの Rig を分離する。

const Shapes := preload("res://scripts/visuals/shapes.gd")
const CREAM := Color("fff0c7")
const INK := Color("253d43")
const GOLD := Color("f5c267")
const REST_PATHS: Array[String] = [
	"Rig:rotation", "Rig/Body:rotation", "Rig/Head:rotation",
	"Rig/LeftArm:rotation", "Rig/RightArm:rotation",
	"Rig/LeftFoot:rotation", "Rig/RightFoot:rotation",
]

static var _libraries: Dictionary = {}

var animation_player: AnimationPlayer
var rig: Node3D
var body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_foot: Node3D
var right_foot: Node3D
var species: String = "captain"
var _motion: String = "idle"
var _action: String = ""
var _action_time: float = 0.0


func _ready() -> void:
	if animation_player == null:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		add_child(animation_player)
		if not _libraries.has(species):
			_libraries[species] = _animation_library()
		animation_player.add_animation_library("", _libraries[species])
		animation_player.animation_finished.connect(_animation_finished)
	set_motion("idle")


## 一回演出の経過時間を積算するため非冪等。
func _process(delta: float) -> void:
	if _action.is_empty() or _action == "death" or animation_player.speed_scale == 0.0:
		return
	_action_time -= delta
	if _action_time <= 0.0:
		_action = ""
		set_motion(_motion)


func reset_pose() -> void:
	_action = ""
	_action_time = 0.0
	_motion = "idle"
	visible = true
	if animation_player != null:
		animation_player.stop()
		animation_player.speed_scale = 1.0
		animation_player.play("idle")
		animation_player.seek(0.0, true)


func set_motion(motion: String) -> void:
	_motion = motion
	if animation_player == null or not _action.is_empty():
		return
	if animation_player.current_animation != motion:
		animation_player.play(motion, 0.08)


## 一回の攻撃や被弾を開始するため非冪等。状態差分や入力イベントからだけ呼ぶ。
func play_action(action: String) -> void:
	if animation_player == null or _action == "death":
		return
	_action = action
	_action_time = animation_player.get_animation(action).length
	animation_player.play(action, 0.03)


func _animation_finished(animation: StringName) -> void:
	if animation == "death":
		return
	_action = ""
	set_motion(_motion)


## モデルの固有部品を取り付ける骨格。一個体の構築時に一度だけ呼ぶ。
func create_rig(head_height: float, shoulder: float, foot_span: float) -> void:
	rig = Shapes.pivot(self, "Rig", Vector3.ZERO)
	body = Shapes.pivot(rig, "Body", Vector3.ZERO)
	head = Shapes.pivot(rig, "Head", Vector3(0, head_height, 0))
	var insect: bool = species in ["beetle", "thorn_beetle"]
	# 昆虫の顎・鎌は頭部に付け、頭を傾けても付け根が離れないようにする。
	var arm_parent: Node3D = head if insect else rig
	var arm_height: float = -head_height * 0.35 if insect else head_height * 0.65
	left_arm = Shapes.pivot(arm_parent, "LeftArm", Vector3(-shoulder, arm_height, 0))
	right_arm = Shapes.pivot(arm_parent, "RightArm", Vector3(shoulder, arm_height, 0))
	left_foot = Shapes.pivot(rig, "LeftFoot", Vector3(-foot_span, 0.2, 0))
	right_foot = Shapes.pivot(rig, "RightFoot", Vector3(foot_span, 0.2, 0))


func _animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for name: String in ["idle", "walk", "attack", "hit", "death", "throw", "carry", "whistle"]:
		library.add_animation(name, _animation(name))
	return library


func _animation(motion: String) -> Animation:
	var clip := Animation.new()
	var length: float = 1.6 if motion == "idle" else 0.64
	if motion == "hit":
		length = 0.24
	elif motion == "death":
		length = 0.8
	clip.length = length
	if motion in ["idle", "walk", "attack", "carry"]:
		clip.loop_mode = Animation.LOOP_LINEAR
	var frames: Dictionary = {}
	for path: String in REST_PATHS:
		frames[path] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	frames["Rig:position"] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	frames["Rig:scale"] = [Vector3.ONE, Vector3.ONE, Vector3.ONE]
	_pose(frames, motion)
	for path: String in frames:
		var track: int = clip.add_track(Animation.TYPE_VALUE)
		var target_path: String = path
		if species in ["beetle", "thorn_beetle"]:
			target_path = target_path.replace("Rig/LeftArm", "Rig/Head/LeftArm")
			target_path = target_path.replace("Rig/RightArm", "Rig/Head/RightArm")
		clip.track_set_path(track, NodePath(target_path))
		clip.track_insert_key(track, 0.0, frames[path][0])
		clip.track_insert_key(track, length * 0.5, frames[path][1])
		clip.track_insert_key(track, length, frames[path][2])
	return clip


func _pose(frames: Dictionary, motion: String) -> void:
	var insect: bool = species in ["beetle", "thorn_beetle"]
	var stride: float = 0.35 if insect else 0.65
	match motion:
		"idle":
			frames["Rig:position"][1] = Vector3(0, 0.065, 0)
			frames["Rig/Head:rotation"][1] = Vector3(0, 0.13, -0.06)
			frames["Rig/LeftArm:rotation"][1] = Vector3(0.1, 0, -0.08)
			frames["Rig/RightArm:rotation"][1] = Vector3(-0.1, 0, 0.08)
		"walk", "carry":
			frames["Rig/LeftFoot:rotation"] = [Vector3(stride, 0, 0), Vector3(-stride, 0, 0),
				Vector3(stride, 0, 0)]
			frames["Rig/RightFoot:rotation"] = [Vector3(-stride, 0, 0), Vector3(stride, 0, 0),
				Vector3(-stride, 0, 0)]
			var lift: float = 0.16 if species == "porter" else 0.08
			frames["Rig:position"][1] = Vector3(0, lift, 0)
			frames["Rig/Head:rotation"][1] = Vector3(0.1, 0, 0.1)
			if species == "striker":
				frames["Rig/Body:rotation"][1] = Vector3(0, 0, -0.1)
			if motion == "carry" and not insect:
				frames["Rig/LeftArm:rotation"] = [Vector3(-1.3, 0, -0.3),
					Vector3(-1.5, 0, -0.4), Vector3(-1.3, 0, -0.3)]
				frames["Rig/RightArm:rotation"] = [Vector3(-1.3, 0, 0.3),
					Vector3(-1.5, 0, 0.4), Vector3(-1.3, 0, 0.3)]
			elif not insect:
				frames["Rig/LeftArm:rotation"] = frames["Rig/RightFoot:rotation"]
				frames["Rig/RightArm:rotation"] = frames["Rig/LeftFoot:rotation"]
		"attack":
			frames["Rig/RightArm:rotation"] = [Vector3(-1.5, 0, -0.1),
				Vector3(0.8, 0, 0.2), Vector3(-1.5, 0, -0.1)]
			frames["Rig/LeftArm:rotation"][1] = Vector3(-0.7, 0, -0.4)
			frames["Rig/Head:rotation"][1] = Vector3(0.4, 0, 0)
			frames["Rig/Body:rotation"][1] = Vector3(0.3, 0.2, 0)
			frames["Rig:position"][1] = Vector3(0, 0.12, -0.22)
			if insect:
				frames["Rig/LeftArm:rotation"] = [Vector3(0, 0.25, 0),
					Vector3(0, -0.55, 0), Vector3(0, 0.25, 0)]
				frames["Rig/RightArm:rotation"] = [Vector3(0, -0.25, 0),
					Vector3(0, 0.55, 0), Vector3(0, -0.25, 0)]
				frames["Rig:position"][1] = Vector3(0, 0.15, -0.5)
		"hit":
			frames["Rig:rotation"][1] = Vector3(-0.4, 0, 0.3)
			frames["Rig/Head:rotation"][1] = Vector3(-0.25, 0, -0.25)
			frames["Rig/LeftArm:rotation"][1] = Vector3(0, 0, 0.7)
			frames["Rig/RightArm:rotation"][1] = Vector3(0, 0, -0.7)
		"death":
			frames["Rig:position"] = [Vector3.ZERO, Vector3(0, 0.6, 0), Vector3(0, 0.1, 0)]
			frames["Rig:rotation"] = [Vector3.ZERO, Vector3(0.3, 0, 1.0), Vector3(0, 0, 1.6)]
			frames["Rig:scale"] = [Vector3.ONE, Vector3.ONE, Vector3.ONE * 0.03]
			frames["Rig/LeftArm:rotation"][1] = Vector3(0, 0, 1.2)
			frames["Rig/RightArm:rotation"][1] = Vector3(0, 0, -1.2)
		"throw":
			frames["Rig:rotation"][1] = Vector3(-1.0, 0, 0.4)
			frames["Rig/LeftArm:rotation"][1] = Vector3(0, 0, 1.5)
			frames["Rig/RightArm:rotation"][1] = Vector3(-2.0, 0, -1.0)
			frames["Rig/LeftFoot:rotation"][1] = Vector3(-0.9, 0, 0)
			frames["Rig/RightFoot:rotation"][1] = Vector3(0.9, 0, 0)
		"whistle":
			frames["Rig/RightArm:rotation"][1] = Vector3(-1.8, 0, -0.7)
			frames["Rig/LeftArm:rotation"][1] = Vector3(-0.3, 0, 1.4)
			frames["Rig/Head:rotation"][1] = Vector3(-0.18, 0, 0.15)
			frames["Rig:position"][1] = Vector3(0, 0.18, 0)
