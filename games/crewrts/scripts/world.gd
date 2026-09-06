extends Node3D
## ゲーム座標を独立したキャラモデルへ写し、部位アニメーションを状態に合わせる。

const Shapes := preload("res://scripts/visuals/shapes.gd")
const Garden := preload("res://scripts/visuals/garden.gd")
const Actor := preload("res://scripts/visuals/actor.gd")
const CAPTAIN := preload("res://assets/models/captain.tscn")
const STRIKER := preload("res://assets/models/striker.tscn")
const PORTER := preload("res://assets/models/porter.tscn")
const BEETLE := preload("res://assets/models/beetle.tscn")
const THORN_BEETLE := preload("res://assets/models/thorn_beetle.tscn")
const CRYSTALS: Array[PackedScene] = [
	preload("res://assets/models/crystal_light.tscn"),
	preload("res://assets/models/crystal_medium.tscn"),
	preload("res://assets/models/crystal_heavy.tscn"),
]
const BASE := preload("res://assets/models/base.tscn")
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
var font: Font
var elapsed: float = 0.0
var whistle_time: float = 0.0
var _retired: Array[Dictionary] = []
var _base_mesh: Node3D


## 子ノードの生成を伴うため、シーンの初期化時に一度だけ呼ぶ。
func setup(model: Node, ui_font: Font) -> void:
	font = ui_font
	_lighting()
	var garden := Garden.new()
	add_child(garden)
	garden.build(model.obstacles)
	_base_mesh = BASE.instantiate()
	_base_mesh.position = model.base_position
	add_child(_base_mesh)
	var base_label: Label3D = _label("回収基地", Vector3(0, 0.8, 2.3))
	base_label.font_size = 38
	_base_mesh.add_child(base_label)
	leader_mesh = CAPTAIN.instantiate()
	add_child(leader_mesh)
	aim_ring = _ring(ORANGE, 0.8)
	add_child(aim_ring)
	camera = Camera3D.new()
	camera.fov = 48
	camera.far = 150
	add_child(camera)
	camera.make_current()


## 表示用時計と死亡演出の寿命を積算するため非冪等。
func sync(model: Node, delta: float, target: Vector3) -> void:
	elapsed += delta
	var movement: Vector3 = model.leader - leader_mesh.position
	leader_mesh.position = model.leader
	leader_mesh.set_motion("walk" if movement.length_squared() > 0.00005 else "idle")
	_face(leader_mesh, movement)
	_sync_crew(model)
	_sync_cargo(model)
	_sync_enemies(model)
	_pause_animations(delta <= 0.0)
	for index: int in range(_retired.size() - 1, -1, -1):
		_retired[index].time -= delta
		if _retired[index].time <= 0.85 and not _retired[index].dying:
			_retired[index].node.play_action("death")
			_retired[index].dying = true
		if _retired[index].time <= 0.0:
			_retired[index].node.queue_free()
			_retired.remove_at(index)
	aim_ring.visible = model.phase == "playing"
	aim_ring.position = Vector3(target.x, 0.08, target.z)
	aim_ring.rotation.y = elapsed
	whistle_time = maxf(0.0, whistle_time - delta)
	_base_mesh.beacon.rotation.y = elapsed * 0.45


func reset_view(model: Node) -> void:
	_reset_entities()
	leader_mesh.position = model.leader
	leader_mesh.rotation = Vector3.ZERO
	leader_mesh.reset_pose()
	whistle_time = 0.0


## 操作の一回演出を開始するため非冪等。入力イベントごとに一度呼ぶ。
func notify_action(event: String) -> void:
	if event in ["throw", "whistle"]:
		leader_mesh.play_action(event)


func set_camera(model: Node, yaw: float, delta: float, snap: bool = false) -> void:
	var center: Vector3 = model.leader + Vector3(0, 0.4, -1.5)
	var offset := Vector3(sin(yaw) * 15, 16, cos(yaw) * 15)
	if model.phase == "title":
		center = Vector3(-3, 0, 6)
		offset = Vector3(26, 25, 31)
	var desired: Vector3 = center + offset
	camera.position = desired if snap else camera.position.lerp(desired, minf(1, delta * 8))
	camera.look_at(center)


func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a5c3b5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c2d5d1")
	settings.ambient_light_energy = 0.32
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff5e2")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)


## 初めて見える個体だけを生成し、消えた個体は死亡演出後に解放する。
func _sync_crew(model: Node) -> void:
	var living: Dictionary = {}
	for member: Dictionary in model.crew:
		var identity: int = member.id
		living[identity] = true
		if not crew_meshes.has(identity):
			var scene: PackedScene = STRIKER if member.kind == 0 else PORTER
			var created: Node3D = scene.instantiate()
			created.position = member.position
			crew_meshes[identity] = created
			add_child(created)
		var robot: Node3D = crew_meshes[identity]
		var previous: Vector3 = robot.position
		robot.position = member.position
		var state: String = member.state
		if state == "attack":
			var angle: float = identity * 2.4
			robot.position += Vector3(cos(angle), 0, sin(angle)) * 1.25
			_face(robot, model.enemies[member.target].position - robot.position)
		elif state == "carry":
			_face(robot, model.cargo[member.target].position - robot.position)
		else:
			_face(robot, robot.position - previous)
		var motion: String = "idle"
		if state in ["carry", "attack"]:
			motion = state
		elif state == "thrown":
			motion = "throw"
		elif robot.position.distance_squared_to(previous) > 0.00005:
			motion = "walk"
		robot.set_motion(motion)
	for identity: int in crew_meshes.keys():
		if not living.has(identity):
			var robot: Node3D = crew_meshes[identity]
			robot.play_action("hit")
			_retired.append({"node": robot, "time": 1.0, "dying": false})
			crew_meshes.erase(identity)


func _sync_cargo(model: Node) -> void:
	while cargo_meshes.size() < model.cargo.size():
		var index: int = cargo_meshes.size()
		var weight: int = model.cargo[index].weight
		var scene: PackedScene = CRYSTALS[clampi(weight / 2 - 1, 0, 2)]
		var item: Node3D = scene.instantiate()
		var label: Label3D = _label("", Vector3(0, 2.8 if weight == 6 else 2.3, 0))
		item.label = label
		item.add_child(label)
		add_child(item)
		cargo_meshes.append(item)
	for index: int in range(cargo_meshes.size()):
		var item: Node3D = cargo_meshes[index]
		var data: Dictionary = model.cargo[index]
		item.visible = not data.delivered
		item.position = data.position
		var workers: int = 0
		for member: Dictionary in model.crew:
			if member.state == "carry" and member.target == index:
				workers += 1
		var moving: bool = workers >= data.weight
		item.set_carried(moving)
		if moving:
			item.position.y += 0.18 + sin(elapsed * 8.0 + index) * 0.035
		item.label.text = "%d / %d" % [workers, data.weight]
		item.label.modulate = CREAM if not moving else Color("94efca")


func _sync_enemies(model: Node) -> void:
	while enemy_meshes.size() < model.enemies.size():
		var index: int = enemy_meshes.size()
		var scene: PackedScene = BEETLE if index == 0 else THORN_BEETLE
		var enemy: Node3D = scene.instantiate()
		var label: Label3D = _label("", Vector3(0, 2.2, 0))
		label.name = "Health"
		enemy.add_child(label)
		enemy.set_meta("hp", model.enemies[index].hp)
		enemy.set_meta("cooldown", model.enemies[index].cooldown)
		enemy.set_meta("hit_at", -1.0)
		add_child(enemy)
		enemy_meshes.append(enemy)
	for index: int in range(enemy_meshes.size()):
		var enemy: Node3D = enemy_meshes[index]
		var data: Dictionary = model.enemies[index]
		var previous_hp: float = enemy.get_meta("hp")
		enemy.position = data.position
		var label: Label3D = enemy.get_node("Health")
		label.visible = data.hp > 0
		label.text = ("甲虫" if index == 0 else "トゲ甲虫") + "  %d" % ceili(data.hp)
		if data.hp <= 0 and previous_hp > 0:
			enemy.play_action("death")
		elif data.hp > 0:
			if data.cooldown > float(enemy.get_meta("cooldown")) + 0.1:
				enemy.play_action("attack")
			elif data.hp < previous_hp and elapsed - float(enemy.get_meta("hit_at")) > 0.3:
				enemy.play_action("hit")
				enemy.set_meta("hit_at", elapsed)
			enemy.set_motion("idle")
		enemy.set_meta("hp", data.hp)
		enemy.set_meta("cooldown", data.cooldown)


func _pause_animations(paused: bool) -> void:
	var speed: float = 0.0 if paused else 1.0
	leader_mesh.animation_player.speed_scale = speed
	for robot: Node3D in crew_meshes.values():
		robot.animation_player.speed_scale = speed
	for enemy: Node3D in enemy_meshes:
		enemy.animation_player.speed_scale = speed
	for data: Dictionary in _retired:
		data.node.animation_player.speed_scale = speed


func _reset_entities() -> void:
	for robot: Node3D in crew_meshes.values():
		robot.queue_free()
	crew_meshes.clear()
	for item: Node3D in cargo_meshes:
		item.queue_free()
	cargo_meshes.clear()
	for enemy: Node3D in enemy_meshes:
		enemy.queue_free()
	enemy_meshes.clear()
	for data: Dictionary in _retired:
		data.node.queue_free()
	_retired.clear()


func _face(node: Node3D, direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0, direction.z)
	if flat.length_squared() > 0.0001:
		node.rotation.y = atan2(-flat.x, -flat.z)


func _label(text: String, point: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = font
	label.font_size = 44
	label.pixel_size = 0.01
	label.position = point
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 4
	label.outline_modulate = INK
	return label


func _ring(color: Color, radius: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.88
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 6
	instance.mesh = mesh
	instance.material_override = Shapes.material(color)
	return instance
