extends Node3D
## 本番と同じキャラクターを並べ、各クリップの同じ進行率を比較する撮影用の展示。

const FONT := preload("res://assets/fonts/MPLUSRounded1c-Regular.ttf")
const Creature := preload("res://scripts/actors/creature.gd")
const SPECIES: Array[String] = ["player", "mossling", "wisp"]
const MOTIONS: Array[String] = ["idle", "walk", "attack", "hurt", "vanish"]
const NAMES: Array[String] = ["灯守の手と道具", "苔むす獣", "宙を泳ぐ灯"]
const LABELS: Array[String] = ["待機", "移動", "攻撃", "被弾", "消滅"]

var actors: Array[Node3D] = []
var heading: Label


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0e2636")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bedddd")
	settings.ambient_light_energy = 0.85
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.3
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 19, 17)
	camera.look_at(Vector3(0, 0.2, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.8
	camera.current = true
	for row: int in range(3):
		for column: int in range(5):
			var actor: Node3D = Creature.new()
			add_child(actor)
			actor.configure(SPECIES[row])
			actor.position = Vector3((column - 2) * 3.1, 0.5, (row - 1) * 4.7)
			actor.rotation.y = 0.28
			if row == 0:
				actor.position.y += 0.6
				actor.set_tool_level(2)
			actors.append(actor)
			_podium(Vector3(actor.position.x, 0, actor.position.z))
			_label(NAMES[row] + " / " + LABELS[column],
				Vector3(actor.position.x, -0.05, actor.position.z + 1.0))
	var layer := CanvasLayer.new()
	add_child(layer)
	heading = Label.new()
	heading.position = Vector2(45, 20)
	heading.add_theme_font_override("font", FONT)
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("f5d49c"))
	layer.add_child(heading)


func pose(fraction: float, caption: String) -> void:
	heading.text = "灯守の島   キャラクターの動き / " + caption
	for index: int in range(actors.size()):
		var animator: AnimationPlayer = actors[index].animation_player
		var motion: String = MOTIONS[index % MOTIONS.size()]
		animator.play(motion)
		animator.seek(animator.get_animation(motion).length * fraction, true)
		animator.pause()


func _podium(point: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.15
	mesh.bottom_radius = 1.25
	mesh.height = 0.2
	mesh.radial_segments = 8
	node.mesh = mesh
	node.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("244854")
	node.material_override = material
	add_child(node)


func _label(text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 28
	label.outline_size = 3
	label.pixel_size = 0.008
	label.modulate = Color("f5d49c")
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
