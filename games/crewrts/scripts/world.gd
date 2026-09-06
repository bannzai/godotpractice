extends Node3D
## 数式で組み立てる庭と小型ロボット。ゲームの状態はモデルからだけ取得する。

const CREAM := Color("f5e8be")
const TEAL := Color("339b9c")
const ORANGE := Color("ed8753")
const INK := Color("233e42")

var camera: Camera3D
var leader_mesh: Node3D
var crew_meshes: Dictionary = {}
var cargo_meshes: Array[Node3D] = []
var enemy_meshes: Array[Node3D] = []
var aim_ring: MeshInstance3D
var whistle_ring: MeshInstance3D
var font: Font
var elapsed: float = 0.0
var whistle_time: float = 0.0
var materials: Dictionary = {}


## 子ノードの生成を伴うため、シーンの初期化時に一度だけ呼ぶ。
func setup(model: Node, ui_font: Font) -> void:
	font = ui_font
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("c6dfd8")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("fff3d6")
	settings.ambient_light_energy = 0.7
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -30, 0)
	sun.light_color = Color("fff2ce")
	sun.light_energy = 1.4
	add_child(sun)
	_box(self, Vector3(0, -0.7, 0), Vector3(50, 1.3, 50), Color("899f66"))
	_box(self, Vector3(0, -1.6, 0), Vector3(50.5, 1.3, 50.5), Color("9a7050"))
	_box(self, Vector3(0, -2.5, 0), Vector3(51, 0.6, 51), Color("70594a"))
	for index: int in range(22):
		var x: float = sin(index * 2.39) * 22.0
		var z: float = cos(index * 1.73) * 22.0
		_cylinder(self, Vector3(x, -0.015, z), 2.0, 0.025, Color("9bae73"))
	for index: int in range(14):
		var z: float = 18.0 - index * 2.8
		var stone: MeshInstance3D = _sphere(
			self, Vector3(sin(index * 0.8) * 1.4, 0.01, z), Color("c3b894")
		)
		stone.scale = Vector3(1.05, 0.12, 0.8)
	for obstacle: Vector3 in model.obstacles:
		_tree(obstacle)
	for index: int in range(34):
		var angle: float = index * TAU / 34.0
		var point := Vector3(sin(angle) * 26, 0, cos(angle) * 26)
		_tree(point)
	for index: int in range(85):
		var point := Vector3(sin(index * 5.3) * 23, 0, cos(index * 2.7) * 23)
		var sprig: MeshInstance3D = _sphere(self, point + Vector3(0, 0.2, 0), Color("6b8955"))
		sprig.scale = Vector3(0.15, 0.4, 0.15)
		if index % 3 == 0:
			var petal: MeshInstance3D = _sphere(self, point + Vector3(0, 0.52, 0), CREAM)
			petal.scale = Vector3(0.25, 0.12, 0.25)
	_base(model.base_position)
	leader_mesh = _robot(CREAM, true)
	add_child(leader_mesh)
	aim_ring = _ring(ORANGE, 0.8)
	add_child(aim_ring)
	whistle_ring = _ring(TEAL, 1.0)
	add_child(whistle_ring)
	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 140
	add_child(camera)
	camera.make_current()


## 表示用時計はアニメーションを進めるため、同じ delta の呼び直しで時間が進む。
func sync(model: Node, delta: float, target: Vector3) -> void:
	elapsed += delta
	leader_mesh.position = model.leader
	_sync_crew(model)
	_sync_cargo(model)
	_sync_enemies(model)
	aim_ring.visible = model.phase == "playing"
	aim_ring.position = Vector3(target.x, 0.08, target.z)
	aim_ring.rotation.y = elapsed
	whistle_time = maxf(0.0, whistle_time - delta)
	whistle_ring.visible = whistle_time > 0
	whistle_ring.position = model.leader + Vector3(0, 0.12, 0)
	whistle_ring.scale = Vector3.ONE * lerpf(1.0, model.WHISTLE_RANGE, 1.0 - whistle_time)


func set_camera(model: Node, yaw: float, delta: float, snap: bool = false) -> void:
	var center: Vector3 = model.leader + Vector3(0, 0, -1.5)
	var offset := Vector3(sin(yaw) * 17, 19, cos(yaw) * 17)
	if model.phase == "title":
		center = Vector3(-3, 0, 6)
		offset = Vector3(26, 25, 31)
	var desired: Vector3 = center + offset
	camera.position = desired if snap else camera.position.lerp(desired, minf(1, delta * 8))
	camera.look_at(center)


## 初めて見える個体だけノードを生成し、次のフレームから再利用する。
func _sync_crew(model: Node) -> void:
	var living: Dictionary = {}
	for member: Dictionary in model.crew:
		var identity: int = member.id
		living[identity] = true
		if not crew_meshes.has(identity):
			crew_meshes[identity] = _robot(ORANGE if member.kind == 0 else TEAL, false)
			add_child(crew_meshes[identity])
		var robot: Node3D = crew_meshes[identity]
		var previous: Vector3 = robot.position
		robot.position = member.position
		if member.state == "attack":
			var angle: float = identity * 2.4 + elapsed
			robot.position += Vector3(cos(angle), 0, sin(angle)) * 1.25
		if member.state in ["follow", "carry", "attack"]:
			robot.position.y += absf(sin(elapsed * 10.0 + identity * 1.4)) * 0.16
			robot.rotation.z = sin(elapsed * 10.0 + identity) * 0.09
		var direction: Vector3 = robot.position - previous
		direction.y = 0
		if direction.length_squared() > 0.001:
			robot.rotation.y = atan2(-direction.x, -direction.z)
	for identity: int in crew_meshes.keys():
		if not living.has(identity):
			crew_meshes[identity].queue_free()
			crew_meshes.erase(identity)


func _sync_cargo(model: Node) -> void:
	while cargo_meshes.size() < model.cargo.size():
		var item := Node3D.new()
		var gem: MeshInstance3D = _sphere(item, Vector3(0, 0.9, 0), Color("efbd63"))
		gem.mesh = PrismMesh.new()
		gem.scale = Vector3(1.45, 1.7, 1.3)
		gem.rotation.z = 0.18
		_cylinder(item, Vector3(0, 0.15, 0), 0.9, 0.2, Color("80664c"))
		var label: Label3D = _label("", Vector3(0, 2.35, 0))
		item.add_child(label)
		add_child(item)
		cargo_meshes.append(item)
	for index: int in range(cargo_meshes.size()):
		var item: Node3D = cargo_meshes[index]
		if index >= model.cargo.size():
			item.visible = false
			continue
		var data: Dictionary = model.cargo[index]
		item.visible = not data.delivered
		item.position = data.position
		var workers: int = 0
		for member: Dictionary in model.crew:
			if member.state == "carry" and member.target == index:
				workers += 1
		var label: Label3D = item.get_child(2)
		label.text = "%d / %d" % [workers, data.weight]
		label.modulate = CREAM if workers < data.weight else Color("94efca")


func _sync_enemies(model: Node) -> void:
	while enemy_meshes.size() < model.enemies.size():
		var enemy := Node3D.new()
		var shell: MeshInstance3D = _sphere(enemy, Vector3(0, 0.7, 0), Color("845b78"))
		shell.scale = Vector3(1.1, 0.8, 1.3)
		for side: float in [-0.5, 0.5]:
			var eye: MeshInstance3D = _sphere(enemy, Vector3(side, 1.05, -1.0), CREAM)
			eye.scale = Vector3.ONE * 0.28
			var pupil: MeshInstance3D = _sphere(enemy, Vector3(side, 1.07, -1.22), INK)
			pupil.scale = Vector3.ONE * 0.12
		enemy.add_child(_label("", Vector3(0, 2.1, 0)))
		add_child(enemy)
		enemy_meshes.append(enemy)
	for index: int in range(enemy_meshes.size()):
		var enemy: Node3D = enemy_meshes[index]
		var data: Dictionary = model.enemies[index]
		enemy.visible = data.hp > 0
		enemy.position = data.position
		enemy.rotation.z = sin(elapsed * 3.5 + index) * 0.07
		var label: Label3D = enemy.get_child(5)
		label.text = "敵  %d" % ceili(data.hp)


func _robot(color: Color, captain: bool) -> Node3D:
	var robot := Node3D.new()
	var size: float = 1.45 if captain else 0.8
	_cylinder(robot, Vector3(0, 0.35, 0), 0.34, 0.5, color)
	var visor: MeshInstance3D = _sphere(robot, Vector3(0, 0.53, -0.2), INK)
	visor.scale = Vector3(0.3, 0.2, 0.18)
	for side: float in [-0.11, 0.11]:
		var eye: MeshInstance3D = _sphere(robot, Vector3(side, 0.55, -0.37), CREAM)
		eye.scale = Vector3.ONE * 0.06
	var antenna: MeshInstance3D = _sphere(robot, Vector3(0, 0.95, 0), color)
	antenna.scale = Vector3(0.13, 0.23, 0.13)
	_cylinder(robot, Vector3(0, 0.04, 0), 0.38, 0.025, Color("617353"))
	robot.scale = Vector3.ONE * size
	return robot


func _tree(point: Vector3) -> void:
	_cylinder(self, point + Vector3(0, 0.85, 0), 0.45, 1.7, Color("806247"))
	var crown: MeshInstance3D = _sphere(self, point + Vector3(0, 2.5, 0), Color("548467"))
	crown.scale = Vector3(1.5, 1.8, 1.5)
	var top: MeshInstance3D = _sphere(self, point + Vector3(-0.35, 3.5, 0), Color("749858"))
	top.scale = Vector3(1.15, 1.4, 1.15)


func _base(point: Vector3) -> void:
	_cylinder(self, point + Vector3(0, 0.02, 0), 2.6, 0.15, Color("d6cca1"))
	_cylinder(self, point + Vector3(0, 0.2, 0), 1.5, 0.4, TEAL)
	var pod: MeshInstance3D = _sphere(self, point + Vector3(0, 1.4, 0), CREAM)
	pod.scale = Vector3(1.25, 1.5, 1.25)
	var glass: MeshInstance3D = _sphere(self, point + Vector3(0, 1.7, 1), TEAL)
	glass.scale = Vector3(0.7, 0.55, 0.35)
	_cylinder(self, point + Vector3(0, 3.1, 0), 0.08, 1.0, INK)
	_box(self, point + Vector3(0.35, 3.5, 0), Vector3(0.7, 0.4, 0.06), ORANGE)
	add_child(_label("回収基地", point + Vector3(0, 4.1, 0)))


func _label(text: String, point: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 48
	label.pixel_size = 0.012
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.outline_modulate = INK
	return label


func _material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		materials[color] = material
	return materials[color]


func _sphere(parent: Node3D, point: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 12
	mesh.rings = 6
	return _mesh(parent, point, mesh, color)


func _cylinder(
	parent: Node3D, point: Vector3, radius: float, height: float, color: Color
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(parent, point, mesh, color)


func _box(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, point, mesh, color)


func _mesh(parent: Node3D, point: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = point
	parent.add_child(instance)
	return instance


func _ring(color: Color, radius: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.88
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 6
	instance.mesh = mesh
	instance.material_override = _material(color)
	return instance
