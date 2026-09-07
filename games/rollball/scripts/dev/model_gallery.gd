extends Node3D
## 同じ照明とカメラで5種類のモデルを比較する、撮影専用の展示台。

const MODELS: Array[PackedScene] = [
	preload("res://assets/models/ball.tscn"),
	preload("res://assets/models/duck.tscn"),
	preload("res://assets/models/robot.tscn"),
	preload("res://assets/models/train.tscn"),
	preload("res://assets/models/plant.tscn"),
]
const ClaySurface = preload("res://scripts/visuals/clay_surface.gd")
const NAMES: Array[String] = ["ころころ玉", "アヒル", "ロボット", "汽車", "花鉢"]
const STATES: Dictionary = {
	"idle": "待機", "move": "移動", "collect": "巻き込み",
	"bump": "衝突", "celebrate": "お祝い", "lost": "脱落・時間切れ",
}

var models: Array[Node3D] = []
var caption: Label
var layer: CanvasLayer


# 撮影用ノードがシーンに参加するとき、一度だけ展示と説明を構築する。
func _ready() -> void:
	position.z = 60.0
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(30, 0.15, 30)
	_add_mesh(floor_mesh, Vector3(0, -0.15, 0), Color("eee2c9"), false)
	var backdrop: BoxMesh = BoxMesh.new()
	backdrop.size = Vector3(30, 10, 0.1)
	_add_mesh(backdrop, Vector3(0, 3.0, -5), Color("bdd5c6"), false)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -26, 0)
	light.light_color = Color("fff1d9")
	light.light_energy = 0.55
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 20.0
	add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.6
	add_child(camera)
	camera.position = Vector3(0, 3.5, 9)
	camera.look_at(global_position + Vector3(0, 0.8, 0))
	camera.current = true
	for index: int in range(MODELS.size()):
		var pedestal: CylinderMesh = CylinderMesh.new()
		pedestal.top_radius = 0.79
		pedestal.bottom_radius = 0.83
		pedestal.height = 0.18
		pedestal.radial_segments = 32
		var x: float = (index - 2) * 1.85
		_add_mesh(pedestal, Vector3(x, 0.04, 0), Color("699d94"))
		var model: Node3D = MODELS[index].instantiate()
		ClaySurface.style_tree(model)
		add_child(model)
		model.position = Vector3(x, 0.14 + (0.69 if index == 0 else 0.0), 0)
		model.scale = Vector3.ONE * 1.38
		model.rotation_degrees.y = -17
		models.append(model)
	_build_labels(camera)


func show_pose(state: String, progress: float) -> void:
	var frame_label: String = "開始" if progress == 0.0 else "途中"
	if progress > 0.9:
		frame_label = "終了直前"
	caption.text = "%s  ／  %s  %d%%" % [STATES[state], frame_label, roundi(progress * 100)]
	for model: Node3D in models:
		var player: AnimationPlayer = model.get_node("AnimationPlayer")
		player.play(state, 0.0)
		player.seek(player.get_animation(state).length * progress, true)
		player.pause()


# ラベル位置はカメラの投影から決め、表示とモデルの対応をずらさない。
func _build_labels(camera: Camera3D) -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	var header: Label = _label("ころころ工房  ／  玩具の動き", 32)
	header.position = Vector2(48, 30)
	layer.add_child(header)
	caption = _label("", 25)
	caption.position = Vector2(48, 78)
	layer.add_child(caption)
	for index: int in range(models.size()):
		var label: Label = _label(NAMES[index], 25)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(210, 48)
		label.position = camera.unproject_position(
			global_position + Vector3((index - 2) * 1.85, -0.08, 0.7)) - Vector2(105, -18)
		layer.add_child(label)
	var note: Label = _label("独立した形・マテリアル・部位アニメーション", 20)
	note.position = Vector2(48, 656)
	layer.add_child(note)


# 展示を構築するため呼び出しごとに新しい表示ノードを追加する。
func _add_mesh(mesh: Mesh, point: Vector3, color: Color, casts_shadow: bool = true) -> void:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	ClaySurface.style_mesh(visual, color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	visual.position = point


# 展示ラベルごとに独立したコントロールを生成する。
func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font",
		preload("res://assets/fonts/KosugiMaru-Regular.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("24494b"))
	return label
