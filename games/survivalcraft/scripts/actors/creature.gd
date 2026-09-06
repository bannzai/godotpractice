extends Node3D
## 位置と当たり判定を持つルートから Rig の部位アニメーションを分離する。

const Shapes := preload("res://scripts/actors/shapes.gd")
const MODELS: Dictionary = {
	"mossling": preload("res://scripts/actors/mossling.gd"),
	"wisp": preload("res://scripts/actors/wisp.gd"),
	"player": preload("res://scripts/actors/player.gd"),
}
const PARTS: Array[String] = ["Body", "Head", "LeftArm", "RightArm", "LeftFoot", "RightFoot"]
const STATES: Array[String] = ["idle", "walk", "attack", "hurt", "vanish"]

var animation_player: AnimationPlayer
var kind: String = ""
var rig: Node3D
var _motion: String = "idle"
var _action: String = ""
var _tool_level: int = -1


func configure(species: String) -> void:
	if kind == species or not MODELS.has(species):
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	kind = species
	rig = Shapes.pivot(self, "Rig", Vector3.ZERO)
	Shapes.pivot(rig, "Body", Vector3.ZERO)
	Shapes.pivot(rig, "Head", Vector3(0, 0.83, -0.40) if kind == "mossling"
		else Vector3(0, 0.9, 0))
	var span: float = 0.47 if kind == "mossling" else 0.4
	for index: int in range(4):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var point := Vector3(side * span, 0.4, -0.35 if index < 2 else 0.4)
		if kind == "wisp":
			point = Vector3(side * 0.38, 0.92 if index < 2 else 0.36, 0)
		elif kind == "player":
			point = Vector3(side * 0.31, -0.35, -0.65 if index < 2 else 0.0)
		Shapes.pivot(rig, PARTS[index + 2], point)
	MODELS[kind].build(rig)
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var library := AnimationLibrary.new()
	for state: String in STATES:
		library.add_animation(state, _make_clip(state))
	animation_player.add_animation_library("", library)
	animation_player.animation_finished.connect(_finished)
	_action = ""
	_motion = "idle"
	animation_player.play("idle")
	_tool_level = -1
	set_tool_level(0)


func set_tool_level(level: int) -> void:
	if kind != "player" or level == _tool_level:
		return
	_tool_level = level
	var tool: Node3D = rig.get_node("RightArm/Tool")
	tool.visible = level > 0
	var color := Color("d4ac72") if level == 1 else Color("a7c4c5")
	for part: String in ["Blade", "Tip"]:
		var mesh: MeshInstance3D = tool.get_node(part)
		var material: StandardMaterial3D = mesh.material_override
		material.albedo_color = color
	tool.get_node("Tip").visible = level >= 2


func animate(state: String) -> void:
	if animation_player == null or not STATES.has(state):
		return
	if state in ["idle", "walk"]:
		_motion = state
		if not _action.is_empty():
			return
	else:
		if _action == "vanish" or _action == state:
			return
		_action = state
	if animation_player.current_animation != state:
		animation_player.play(state, 0.045)


func reset_animation() -> void:
	if animation_player == null:
		return
	_action = ""
	_motion = "idle"
	animation_player.stop()
	animation_player.speed_scale = 1.0
	animation_player.play("idle")
	animation_player.seek(0.0, true)


func _finished(state: StringName) -> void:
	if state == "vanish":
		return
	_action = ""
	animation_player.play(_motion, 0.06)


func _make_clip(state: String) -> Animation:
	var clip := Animation.new()
	clip.length = 1.8 if state == "idle" else 0.72
	if state == "hurt":
		clip.length = 0.3
	elif state == "attack":
		clip.length = 0.42 if kind == "player" else 0.7
	if state in ["idle", "walk"]:
		clip.loop_mode = Animation.LOOP_LINEAR
	var frames: Dictionary = {
		"Rig:position": [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
		"Rig:rotation": [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO],
		"Rig:scale": [Vector3.ONE, Vector3.ONE, Vector3.ONE],
	}
	for part: String in PARTS:
		frames["Rig/%s:rotation" % part] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	_pose(frames, state)
	for path: String in frames:
		var track: int = clip.add_track(Animation.TYPE_VALUE)
		clip.track_set_path(track, NodePath(path))
		for index: int in range(3):
			clip.track_insert_key(track, clip.length * 0.5 * float(index), frames[path][index])
	return clip


func _pose(frames: Dictionary, state: String) -> void:
	match state:
		"idle":
			frames["Rig:position"][1] = Vector3(0, 0.1 if kind == "wisp" else 0.022, 0)
			frames["Rig/Head:rotation"][1] = Vector3(0.06, 0.12, 0.05)
			frames["Rig/LeftArm:rotation"][1] = Vector3(0.06, 0, 0.11)
			frames["Rig/RightArm:rotation"][1] = Vector3(-0.06, 0, -0.11)
		"walk":
			frames["Rig:position"][1] = Vector3(0, 0.07, 0)
			frames["Rig/Head:rotation"][1] = Vector3(-0.12, 0, 0.08)
			var stride: float = 0.12 if kind == "player" else 0.42
			for index: int in range(4):
				var direction: float = -1.0 if index in [0, 3] else 1.0
				var pose := Vector3(stride * direction, 0, 0.15 if kind == "wisp" else 0)
				frames["Rig/%s:rotation" % PARTS[index + 2]] = [pose, -pose, pose]
		"attack":
			frames["Rig:position"][1] = Vector3(0, 0.03, -0.23)
			frames["Rig/Head:rotation"][1] = Vector3(0.35, 0, 0)
			frames["Rig/Body:rotation"][1] = Vector3(0.20, 0, 0)
			frames["Rig/LeftArm:rotation"][1] = Vector3(-0.8, 0, -0.35)
			frames["Rig/RightArm:rotation"] = [Vector3(-0.85, 0, 0.35),
				Vector3(1.3, 0, -0.45), Vector3.ZERO]
			if kind == "wisp":
				frames["Rig/LeftArm:rotation"][1] = Vector3(-0.9, 0, -1.2)
				frames["Rig/RightArm:rotation"][1] = Vector3(-0.9, 0, 1.2)
				frames["Rig/Head:rotation"][1] = Vector3(0, 0.8, 0)
		"hurt":
			frames["Rig:rotation"][1] = Vector3(-0.2, 0.12, -0.2)
			frames["Rig/Head:rotation"][1] = Vector3(-0.25, 0, 0.2)
			frames["Rig/LeftArm:rotation"][1] = Vector3(-0.3, 0, -0.5)
			frames["Rig/RightArm:rotation"][1] = Vector3(0.4, 0, 0.5)
		"vanish":
			frames["Rig:position"] = [Vector3.ZERO, Vector3(0, 0.4, 0), Vector3(0, 0.7, 0)]
			frames["Rig:scale"] = [Vector3.ONE, Vector3.ONE * 1.12, Vector3.ONE * 0.001]
			frames["Rig:rotation"] = [Vector3.ZERO, Vector3(0, 0.8, 0.3), Vector3(0, 2, 0.7)]
			frames["Rig/LeftArm:rotation"][1] = Vector3(0.3, 0, -1.4)
			frames["Rig/RightArm:rotation"][1] = Vector3(-0.3, 0, 1.4)
