extends Node3D

const ClaySurface = preload("res://scripts/visuals/clay_surface.gd")

const WOOD: Color = Color("bc895b")
const DARK_WOOD: Color = Color("78523f")
const TEAL: Color = Color("76b5b0")
const CREAM: Color = Color("fff0ca")
const CORAL: Color = Color("e98f79")
const ITEM_SCENES: Array[PackedScene] = [
	preload("res://assets/models/duck.tscn"),
	preload("res://assets/models/robot.tscn"),
	preload("res://assets/models/train.tscn"),
	preload("res://assets/models/plant.tscn"),
]
const ITEM_COLORS: Array[Color] = [
	Color("ed987c"), Color("79bbb4"), Color("ebc25f"),
	Color("a3b784"), Color("a7a6cd"), Color("dfad80"),
]
const FURNITURE: Array[Dictionary] = [
	{"kind": 0, "position": Vector3(-9.5, 0.0, -12.0), "size": Vector3(6.0, 3.8, 1.5)},
	{"kind": 1, "position": Vector3(8.0, 0.0, -10.0), "size": Vector3(5.0, 2.3, 3.0)},
	{"kind": 2, "position": Vector3(-11.5, 0.0, 2.5), "size": Vector3(3.0, 1.6, 5.0)},
	{"kind": 3, "position": Vector3(11.6, 0.0, 5.0), "size": Vector3(2.0, 2.6, 4.0)},
]

# Godot がシーンに追加した一度だけ、床・家具・照明の子ノードを構築する。
func _ready() -> void:
	_build_floor()
	_build_walls()
	for furniture: Dictionary in FURNITURE:
		_build_furniture(furniture)
	_build_atelier_details()
	_build_lighting()


static func item_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: int in range(15):
		for column: int in range(15):
			var point: Vector3 = Vector3(-11.2 + column * 1.6, 0.0, -11.2 + row * 1.6)
			if _inside_furniture(point):
				continue
			var distance: float = Vector2(point.x, point.z - 8.0).length()
			if distance < 1.15:
				continue
			var item_size: float = 0.45
			if distance > 5.0:
				item_size = 0.65
			if distance > 9.0:
				item_size = 0.9
			if distance > 14.0:
				item_size = 1.2
			var index: int = row * 15 + column
			result.append({
				"position": point,
				"size": item_size,
				"kind": index % 4,
				"color": ITEM_COLORS[index % ITEM_COLORS.size()],
			})
	return result


# 呼び出し側がシーンに追加するため、毎回独立した表示ノードを返す。
static func make_item_visual(item_size: float, kind: int, _color: Color) -> Node3D:
	var visual: Node3D = ITEM_SCENES[posmod(kind, ITEM_SCENES.size())].instantiate()
	ClaySurface.style_tree(visual)
	visual.scale = Vector3.ONE * item_size
	return visual


static func _inside_furniture(point: Vector3) -> bool:
	for furniture: Dictionary in FURNITURE:
		var center: Vector3 = furniture["position"]
		var half: Vector3 = furniture["size"] * 0.5
		if absf(point.x - center.x) < half.x + 1.1:
			if absf(point.z - center.z) < half.z + 1.1:
				return true
	return false


# 部屋生成時だけ呼び、見た目と物理床を同じ座標に配置する。
func _build_floor() -> void:
	_solid_box(Vector3(30, 0.5, 30), Vector3(0, -0.25, 0), WOOD, false)
	for plank: int in range(20):
		_box(self, Vector3(30, 0.006, 0.025), Vector3(0, 0.004, -15 + plank * 1.5),
			Color("a87650"))
	for row: int in range(10):
		for column: int in range(4):
			_box(self, Vector3(0.025, 0.006, 1.5),
				Vector3(-12 + column * 8 + (row % 2) * 3, 0.004, -14.25 + row * 3),
				Color("a87650"))
	_box(self, Vector3(13.2, 0.02, 13.0), Vector3(0, 0.018, 3.1), Color("749c93"))
	_box(self, Vector3(12.6, 0.024, 12.4), Vector3(0, 0.02, 3.1), Color("a2b9a3"))
	for stripe: int in range(5):
		_box(self, Vector3(11.8, 0.004, 0.035),
			Vector3(0, 0.034, -1.6 + stripe * 2.3), Color("c6cfab"))


# 手前はカメラを遮らない高さにし、衝突形状はほかの壁と揃える。
func _build_walls() -> void:
	_solid_box(Vector3(30, 5, 0.4), Vector3(0, 2.5, -15), TEAL)
	_solid_box(Vector3(0.4, 5, 30), Vector3(-15, 2.5, 0), TEAL.darkened(0.12))
	_solid_box(Vector3(0.4, 5, 30), Vector3(15, 2.5, 0), TEAL.lightened(0.12))
	var front: StaticBody3D = StaticBody3D.new()
	front.set_meta("obstacle", true)
	_collision(front, Vector3(30, 5, 0.4), Vector3(0, 2.5, 15))
	add_child(front)
	_box(self, Vector3(30, 0.2, 0.5), Vector3(0, 0.1, 15), DARK_WOOD)
	_box(self, Vector3(29.5, 0.22, 0.1), Vector3(0, 0.11, -14.75), CREAM)
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.1, 0.22, 29.5), Vector3(side * 14.75, 0.11, 0), CREAM)
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.12, 1.5, 29.5),
			Vector3(side * 14.72, 0.98, 0), Color("b3cec1"))
		_box(self, Vector3(0.18, 0.11, 29.5), Vector3(side * 14.69, 1.76, 0), CREAM)
	_box(self, Vector3(29.5, 1.5, 0.12), Vector3(0, 0.98, -14.72), Color("b3cec1"))
	_box(self, Vector3(29.5, 0.11, 0.18), Vector3(0, 1.76, -14.69), CREAM)
	for board: int in range(29):
		_box(self, Vector3(0.035, 1.48, 0.025),
			Vector3(-14 + board, 0.98, -14.64), Color("93b3a7"))
	_build_window()
	for index: int in range(3):
		var center: Vector3 = Vector3(7 + index * 2.1, 3.55, -14.68)
		_box(self, Vector3(1.7, 1.7, 0.18), center, DARK_WOOD)
		_box(self, Vector3(1.53, 1.53, 0.19), center + Vector3(0, 0, 0.03), CREAM)
		_box(self, Vector3(1.3, 1.3, 0.2), center + Vector3(0, 0, 0.05),
			ITEM_COLORS[index].lightened(0.25))
		var art: Node3D = make_item_visual(0.92, index, CREAM)
		art.position = center + Vector3(0, -0.45, 0.25)
		art.rotation_degrees.y = -15
		add_child(art)


# 窓の各層に距離をつけ、追従カメラの移動で遠景と窓枠に視差を出す。
func _build_window() -> void:
	_box(self, Vector3(6.5, 3.15, 0.18), Vector3(0.8, 3.2, -14.67), DARK_WOOD)
	_box(self, Vector3(6.24, 2.9, 0.2), Vector3(0.8, 3.2, -14.53), CREAM)
	_box(self, Vector3(5.9, 2.6, 0.2), Vector3(0.8, 3.2, -14.38), Color("b8dcd9"))
	for index: int in range(4):
		var hill: PrismMesh = PrismMesh.new()
		hill.size = Vector3(1.7, 0.65 + (index % 2) * 0.23, 0.04)
		_mesh(self, hill, Vector3(-1.18 + index * 1.3, 1.91 + hill.size.y * 0.5, -14.17),
			Color("94bab0") if index % 2 == 0 else Color("83aca0"))
	_sphere(self, Vector3(2.45, 3.85, -14.2), Vector3(0.3, 0.3, 0.035), Color("ffe3a0"))
	for cloud_index: int in range(3):
		var cloud: Node3D = Node3D.new()
		cloud.name = "Cloud%d" % cloud_index
		cloud.position = Vector3(-1.25 + cloud_index * 1.7,
			3.8 - (cloud_index % 2) * 0.42, -14.08)
		add_child(cloud)
		for puff: int in range(3):
			_sphere(cloud, Vector3((puff - 1) * 0.2, 0.06 if puff == 1 else 0.0, 0),
				Vector3(0.25, 0.17, 0.045), Color("fff6df"))
	_box(self, Vector3(0.14, 2.75, 0.16), Vector3(0.8, 3.2, -13.97), CREAM)
	_box(self, Vector3(6.1, 0.14, 0.16), Vector3(0.8, 3.2, -13.97), CREAM)
	_box(self, Vector3(6.75, 0.14, 0.7), Vector3(0.8, 1.67, -14.15), WOOD)
	_box(self, Vector3(7.3, 0.09, 0.09), Vector3(0.8, 4.9, -13.93), DARK_WOOD)
	for side: float in [-1.0, 1.0]:
		for fold: int in range(4):
			_cylinder(self, 0.16, 0.11, 2.9,
				Vector3(0.8 + side * (3.0 + fold * 0.16), 3.3, -13.97),
				CORAL.lightened(0.12 + fold * 0.03))


# 装飾だけを追加し、既存の床・家具の衝突と小物配置を保つ。
func _build_atelier_details() -> void:
	for stitch: int in range(28):
		for side: float in [-1.0, 1.0]:
			_box(self, Vector3(0.23, 0.005, 0.025),
				Vector3(-5.8 + stitch * 0.43, 0.036, 3.1 + side * 5.98), CREAM)
	for stitch: int in range(28):
		for side: float in [-1.0, 1.0]:
			_box(self, Vector3(0.025, 0.005, 0.23),
				Vector3(side * 6.08, 0.036, -2.65 + stitch * 0.43), CREAM)
	for index: int in range(13):
		var flag: PrismMesh = PrismMesh.new()
		flag.size = Vector3(0.48, 0.55, 0.04)
		var bunting: MeshInstance3D = _mesh(self, flag,
			Vector3(-12.8 + index * 2.1, 4.62 - sin(index * 0.4) * 0.12, -14.51),
			ITEM_COLORS[index % ITEM_COLORS.size()])
		bunting.rotation.z = PI
	_box(self, Vector3(27, 0.025, 0.025), Vector3(0, 4.82, -14.53), CREAM)
	for index: int in range(4):
		var display: Node3D = make_item_visual(0.65, index, CREAM)
		display.position = Vector3(-11.8 + index * 1.5, 3.58, -11.6)
		add_child(display)
	for index: int in range(5):
		var brush: MeshInstance3D = _cylinder(self, 0.035, 0.035, 0.85,
			Vector3(9.3 + index * 0.1, 3.19, -10), DARK_WOOD)
		brush.rotation.z = -0.2 + index * 0.11
		_sphere(self, Vector3(9.24 + index * 0.13, 3.59, -10),
			Vector3(0.065, 0.12, 0.065), ITEM_COLORS[index])
	var spool: MeshInstance3D = _cylinder(self, 0.23, 0.23, 0.8,
		Vector3(8.4, 2.55, -10.5), TEAL)
	spool.rotation.z = PI / 2.0
	for side: float in [-1.0, 1.0]:
		var cap: MeshInstance3D = _cylinder(self, 0.29, 0.29, 0.055,
			Vector3(8.4 + side * 0.42, 2.55, -10.5), CREAM)
		cap.rotation.z = PI / 2.0


# 家具の各部品をまとめて生成するため、部屋初期化時に一度呼ぶ。
func _build_furniture(data: Dictionary) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = data["position"]
	body.set_meta("obstacle", true)
	add_child(body)
	var size: Vector3 = data["size"]
	_collision(body, size, Vector3(0, size.y * 0.5, 0))
	match int(data["kind"]):
		0:
			_box(body, Vector3(size.x, size.y, 0.15), Vector3(0, size.y / 2, -0.6), DARK_WOOD)
			for shelf: int in range(4):
				_box(body, Vector3(size.x, 0.16, size.z), Vector3(0, 0.2 + shelf * 1.1, 0), WOOD)
				for book: int in range(6):
					_box(body, Vector3(0.48, 0.7, 0.48),
						Vector3(-2.5 + book * 0.92, 0.63 + shelf * 1.1, 0),
						ITEM_COLORS[(book + shelf) % ITEM_COLORS.size()])
			for side: float in [-1.0, 1.0]:
				_box(body, Vector3(0.2, size.y, size.z),
					Vector3(side * (size.x / 2 - 0.1), size.y / 2, 0), WOOD)
		1:
			_box(body, Vector3(size.x, 0.28, size.z), Vector3(0, size.y - 0.14, 0), WOOD)
			for side_x: float in [-1.0, 1.0]:
				for side_z: float in [-1.0, 1.0]:
					_box(body, Vector3(0.25, 2.1, 0.25),
						Vector3(side_x * 2.1, 1.05, side_z * 1.15), DARK_WOOD)
			_box(body, Vector3(1.5, 0.12, 1.2), Vector3(-0.9, 2.36, 0), CREAM)
			_cylinder(body, 0.36, 0.3, 0.7, Vector3(1.5, 2.65, 0), CORAL)
		2:
			_box(body, Vector3(size.x, 0.6, size.z), Vector3(0, 0.5, 0), CORAL.darkened(0.15))
			_box(body, Vector3(0.5, 1.6, size.z), Vector3(-1.25, 0.8, 0), CORAL)
			for seat: int in range(3):
				_box(body, Vector3(2.3, 0.3, 1.45), Vector3(0.25, 0.95, -1.55 + seat * 1.55),
					CORAL.lightened(0.15))
			for end: float in [-1.0, 1.0]:
				_box(body, Vector3(3, 1.3, 0.35), Vector3(0, 0.65, end * 2.3), CORAL)
		3:
			_box(body, size, Vector3(0, size.y / 2, 0), DARK_WOOD)
			for drawer: int in range(3):
				_box(body, Vector3(0.12, 0.68, 3.7), Vector3(-1.04, 0.45 + drawer * 0.78, 0), WOOD)
				_box(body, Vector3(0.15, 0.12, 0.48),
					Vector3(-1.17, 0.45 + drawer * 0.78, 0), CREAM)

	for part: Node in body.get_children():
		if part is MeshInstance3D:
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# 描画環境は部屋の生存期間に合わせて一度だけ生成する。
func _build_lighting() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("dfc9a7")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff2db")
	environment.environment.ambient_light_energy = 0.3
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45
	add_child(sun)


# 呼び出しごとに指定した親へ新しい形状を追加する生成関数。
static func _mesh(parent: Node3D, mesh: Mesh, point: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	ClaySurface.style_mesh(instance, color)
	instance.position = point
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


# 呼び出しごとに独立した部品を生成する。
static func _box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, point, color)


# 呼び出しごとに独立した円柱部品を生成する。
static func _cylinder(parent: Node3D, top: float, bottom: float, height: float,
		point: Vector3, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	return _mesh(parent, mesh, point, color)


# 固定物の表示と衝突を同じ大きさで一度に生成する。
func _solid_box(size: Vector3, point: Vector3, color: Color, obstacle: bool = true) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("obstacle", obstacle)
	add_child(body)
	var visual: MeshInstance3D = _box(body, size, point, color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_collision(body, size, point)


# 物理ノード生成時に一度だけ衝突形状を追加する。
static func _collision(body: StaticBody3D, size: Vector3, point: Vector3) -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = point
	body.add_child(shape)


# 球の頂点数を抑え、背景の丸い装飾に共有材質を使う。
static func _sphere(parent: Node3D, point: Vector3, size: Vector3,
		color: Color) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var visual: MeshInstance3D = _mesh(parent, sphere, point, color)
	visual.scale = size
	return visual
