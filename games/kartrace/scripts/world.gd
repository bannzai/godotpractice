extends Node3D
## 同じコースデータから路面と配置物を構築する。初期構築時にだけ子ノードを追加する。

const Course = preload("res://scripts/course_data.gd")
var boxes: Array[Node3D] = []
var clock: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_track()
	_build_scenery()


func _process(delta: float) -> void:
	# 時間に沿う浮遊と回転なのでフレームごとに進める。
	clock += delta
	for index: int in range(boxes.size()):
		boxes[index].visible = get_node("/root/RaceState").box_available(index)
		boxes[index].rotation.y = clock * 1.2
		boxes[index].position.y = Course.sample(Course.ITEM_BOXES[index].progress).y + 1.2
		boxes[index].position.y += sin(clock * 2.5 + index) * 0.2


static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.5
	return result


static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node


static func cylinder(parent: Node3D, pos: Vector3, radius: float,
		height: float, color: Color, top: float = -1.0) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node


func _build_environment() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	var settings: Environment = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("99d8e4")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d5eef2")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff0d1")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	add_child(sun)
	box(self, Vector3(0, -3.6, 0), Vector3(900, 0.4, 900), Color("329da9"))
	for index: int in range(25):
		var angle: float = index * TAU / 25.0
		var pos: Vector3 = Vector3(cos(angle) * 240, -1, sin(angle) * 240)
		cylinder(self, pos, 30, 20 + index % 4 * 7, Color("78b7bb"), 3)
		box(self, pos + Vector3(0, 60 + index % 3 * 5, 0),
			Vector3(25 + index % 3 * 10, 3, 9), Color("e9f5ed"))


func _build_track() -> void:
	for index: int in range(160):
		var distance: float = float(index) / 160 * Course.LENGTH
		var point: Vector3 = Course.sample(distance)
		var next: Vector3 = Course.sample(distance + Course.LENGTH / 160)
		var tangent: Vector3 = (next - point).normalized()
		var right: Vector3 = tangent.cross(Vector3.UP).normalized()
		var middle: Vector3 = (point + next) * 0.5
		var road: MeshInstance3D = box(self, middle - Vector3(0, 0.25, 0),
			Vector3(Course.ROAD_WIDTH, 0.5, point.distance_to(next) + 0.15), Color("536975"))
		road.look_at(middle + tangent)
		for side: float in [-1.0, 1.0]:
			var color: Color = Color("fff1ce") if index % 4 < 2 else Color("ec7965")
			var curb: MeshInstance3D = box(self, middle + right * side * 5.8,
				Vector3(0.5, 0.12, point.distance_to(next) + 0.15), color)
			curb.look_at(curb.position + tangent)
			# 開いた区間では海へ落ちる。安全柵がカメラを遮らない高さにする。
			if Course.has_wall(distance, side):
				var rail: MeshInstance3D = box(self, middle + right * side * 6.3 + Vector3.UP * 0.4,
					Vector3(0.25, 0.7, point.distance_to(next) + 0.15), Color("c5ddd7"))
				rail.look_at(rail.position + tangent)
		if index % 4 == 0:
			var mark: MeshInstance3D = box(self, middle + Vector3.UP * 0.015,
				Vector3(0.12, 0.03, 1.0), Color("a9c3bb"))
			mark.look_at(mark.position + tangent)
	for placement: Dictionary in Course.ITEM_BOXES:
		var cube: Node3D = Node3D.new()
		add_child(cube)
		cube.position = point_at(placement.progress, placement.lateral) + Vector3.UP * 1.2
		var gem: MeshInstance3D = box(cube, Vector3.ZERO, Vector3.ONE * 1.2, Color("ffd669"))
		gem.rotation_degrees = Vector3(15, 0, 20)
		box(cube, Vector3(0, 0, -0.64), Vector3(0.65, 0.65, 0.06), Color("fff6d8"))
		boxes.append(cube)
	for placement: Dictionary in Course.DASH_PADS:
		var pad: Node3D = Node3D.new()
		add_child(pad)
		pad.position = point_at(placement.progress, placement.lateral) + Vector3.UP * 0.03
		pad.look_at(pad.position + Course.tangent(placement.progress))
		box(pad, Vector3.ZERO, Vector3(3, 0.06, 4), Color("25d4c0"))
		for stripe: int in range(3):
			box(pad, Vector3(0, 0.055, -1.2 + stripe * 1.1),
				Vector3(2.5, 0.04, 0.35), Color("fff1bb"))
	_build_shortcut()
	var gate: Node3D = Node3D.new()
	add_child(gate)
	gate.position = Course.sample(0)
	gate.look_at(gate.position + Course.tangent(0))
	for side: float in [-1.0, 1.0]:
		box(gate, Vector3(side * 6.8, 3, 0), Vector3(0.6, 6, 0.7), Color("f0debb"))
	box(gate, Vector3(0, 6, 0), Vector3(14.2, 1.6, 0.8), Color("174c60"))
	var sign: Label3D = Label3D.new()
	sign.text = "潮 風 カ ー ト"
	sign.font_size = 72
	sign.pixel_size = 0.015
	sign.outline_size = 4
	sign.font = load("res://assets/fonts/MPLUSRounded1c-Medium.ttf")
	sign.position = Vector3(0, 6, 0.44)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(sign)
	for row: int in range(2):
		for col: int in range(12):
			box(gate, Vector3(col - 5.5, 0.04, row - 0.5), Vector3(1, 0.04, 1),
				Color("fff5d9") if (row + col) % 2 == 0 else Color("233d4c"))


func _build_shortcut() -> void:
	var data: Dictionary = Course.SHORTCUT
	for index: int in range(30):
		var distance: float = lerpf(data.start, data.end, index / 29.0)
		var point: Vector3 = point_at(distance, data.lateral)
		var plank: MeshInstance3D = box(self, point - Vector3.UP * 0.1,
			Vector3(data.width, 0.2, 1.6), Color("bd9870"))
		plank.look_at(point + Course.tangent(distance))


static func point_at(distance: float, lateral: float) -> Vector3:
	return Course.sample(distance) + Course.right(distance) * lateral


func _build_scenery() -> void:
	cylinder(self, Vector3(0, -2.5, 0), 27, 3, Color("eddaa8"))
	cylinder(self, Vector3(0, -0.9, 0), 23, 0.3, Color("81b28b"))
	for index: int in range(22):
		var angle: float = index * 2.399
		var radius: float = 10 + index % 4 * 3
		var pos: Vector3 = Vector3(cos(angle) * radius, -0.7, sin(angle) * radius)
		_palm(pos, 0.8 + (index % 3) * 0.2)
	cylinder(self, Vector3(1, 5.2, 0), 2.4, 12, Color("fff1ce"), 1.6)
	for stripe: int in range(3):
		cylinder(self, Vector3(1, 1.5 + stripe * 3.5, 0), 2.2 - stripe * 0.2,
			1.1, Color("ec7965"))
	cylinder(self, Vector3(1, 11.8, 0), 2.5, 0.5, Color("174c60"))
	cylinder(self, Vector3(1, 13, 0), 1.4, 2, Color("ffe4a0"))
	cylinder(self, Vector3(1, 14.6, 0), 2.5, 1.8, Color("e77b67"), 0)
	for index: int in range(12):
		var distance: float = index * Course.LENGTH / 12
		var point: Vector3 = point_at(distance, -9)
		cylinder(self, point + Vector3.UP * 2, 0.1, 4, Color("f4e6bd"))
		box(self, point + Vector3(0.5, 3.5, 0), Vector3(1, 0.7, 0.08),
			Color("f9c960") if index % 2 == 0 else Color("f28e76"))
	for index: int in range(16):
		var pos: Vector3 = Vector3(-100 + index * 14, -3.3, -75 - index % 3 * 15)
		box(self, pos, Vector3(8, 0.03, 0.18), Color("a2ddd3"))


func _palm(pos: Vector3, size: float) -> void:
	var trunk: MeshInstance3D = cylinder(self, pos + Vector3.UP * 2.5 * size,
		0.35 * size, 5 * size, Color("a67e58"), 0.2 * size)
	trunk.rotation.z = 0.1
	for leaf: int in range(5):
		var angle: float = leaf * TAU / 5
		var mesh: MeshInstance3D = box(self,
			pos + Vector3(cos(angle), 4.8, sin(angle)) * size,
			Vector3(0.85, 0.13, 3.7) * size, Color("41977b"))
		mesh.rotation = Vector3(0.3, -angle + PI / 2, 0)
