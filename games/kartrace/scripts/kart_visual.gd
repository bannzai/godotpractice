class_name KartVisual
extends Node3D
## 独立した車体・ドライバー・装備を組み合わせるオリジナルカート。

@export var model_kind: int = -1

var animation_player: AnimationPlayer
var body: Node3D
var driver: Node3D
var wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var sparks: CPUParticles3D
var exhaust: CPUParticles3D
var boost_trail: CPUParticles3D
var _speed: float = 0.0
var _steer: float = 0.0
var _state: String = "idle"
var _special_time: float = 0.0
var _paint: StandardMaterial3D
var _dark: StandardMaterial3D
var _cream: StandardMaterial3D
var _metal: StandardMaterial3D
var _accent: StandardMaterial3D


func _ready() -> void:
	if model_kind >= 0 and not is_instance_valid(body):
		setup(model_kind)


func setup(kind: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	wheels.clear()
	front_wheels.clear()
	model_kind = clampi(kind, 0, 2)
	_state = "idle"
	_special_time = 0.0
	_dark = _material(Color("172b38"))
	_cream = _material(Color("fff1d1"))
	_metal = _material(Color("b6dce0"), 0.7)
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	driver = Node3D.new()
	driver.name = "Driver"
	driver.position = Vector3(0.0, 0.97, 0.12)
	body.add_child(driver)
	match model_kind:
		0:
			_build_otter()
		1:
			_build_fox()
		2:
			_build_owl()
	_build_running_gear()
	_build_effects()
	_build_animations()
	animation_player.play("idle")


func set_motion(speed: float, steer: float, drifting: bool, boosting: bool) -> void:
	_speed = speed
	_steer = clampf(steer, -1.0, 1.0)
	if not is_instance_valid(animation_player):
		return
	sparks.emitting = drifting and absf(speed) > 4.0
	boost_trail.emitting = boosting
	exhaust.emitting = absf(speed) > 0.5
	if _special_time > 0.0:
		return
	if boosting:
		play_state("boost")
	elif drifting:
		play_state("drift")
	elif absf(speed) > 0.5:
		play_state("drive")
	else:
		play_state("idle")


func play_state(state: String) -> void:
	if not is_instance_valid(animation_player) or not animation_player.has_animation(state):
		return
	if state == _state and animation_player.is_playing():
		return
	_state = state
	animation_player.play(state, 0.12)
	if state == "hit":
		_special_time = 0.65
	elif state == "celebrate":
		_special_time = 10000.0


# 車輪角度と被弾の残り時間はフレームごとに積算するため冪等ではない。
func _process(delta: float) -> void:
	_special_time = maxf(0.0, _special_time - delta)
	for wheel: Node3D in wheels:
		wheel.rotation.x -= _speed * delta / 0.3
	for front: Node3D in front_wheels:
		front.rotation.y = -_steer * 0.4


func _build_otter() -> void:
	_paint = _material(Color("58d8bf"), 0.18)
	_accent = _material(Color("ffca66"), 0.22)
	_ellipsoid(body, Vector3(0, 0.48, 0.03), Vector3(1.35, 0.62, 2.24), _paint)
	_ellipsoid(body, Vector3(0, 0.58, -0.82), Vector3(1.1, 0.3, 0.92), _cream)
	_box(body, Vector3(0, 0.35, -1.06), Vector3(1.35, 0.14, 0.16), _accent)
	for x: float in [-0.41, 0.41]:
		_ellipsoid(body, Vector3(x, 0.66, -1.0), Vector3(0.22, 0.2, 0.12), _lamp())
	_box(body, Vector3(0, 0.9, 0.58), Vector3(0.92, 0.19, 0.3), _dark)
	var fur: StandardMaterial3D = _material(Color("ad7957"))
	_ellipsoid(driver, Vector3(0, 0.15, 0), Vector3(0.76, 0.73, 0.64), fur)
	_ellipsoid(driver, Vector3(0, 0.25, -0.26), Vector3(0.52, 0.5, 0.22), _cream)
	_ellipsoid(driver, Vector3(0, 0.74, -0.06), Vector3(0.88, 0.73, 0.74), fur)
	for x: float in [-0.4, 0.4]:
		_ellipsoid(driver, Vector3(x, 0.98, -0.02), Vector3(0.28, 0.28, 0.18), fur)
		_ellipsoid(driver, Vector3(x, 0.99, -0.12), Vector3(0.15, 0.15, 0.05), _cream)
	_ellipsoid(driver, Vector3(0, 0.64, -0.4), Vector3(0.58, 0.32, 0.2), _cream)
	_ellipsoid(driver, Vector3(0, 0.74, -0.53), Vector3(0.19, 0.13, 0.11), _dark)
	_face(driver, 0.2, 0.84, -0.41, 0.12)
	_ellipsoid(driver, Vector3(0, 1.04, 0.02), Vector3(0.67, 0.24, 0.68), _paint)
	_box(driver, Vector3(0, 1.07, -0.35), Vector3(0.64, 0.065, 0.22), _accent)
	_scarf(driver, _accent)
	_arms(fur, false)
	_ellipsoid(body, Vector3(0, 0.93, 0.96), Vector3(0.45, 0.23, 0.62), fur)


func _build_fox() -> void:
	_paint = _material(Color("f57741"), 0.3)
	_accent = _material(Color("69daf4"), 0.35)
	_box(body, Vector3(0, 0.44, 0.03), Vector3(1.25, 0.32, 1.88), _paint)
	var nose: MeshInstance3D = _box(
		body, Vector3(0, 0.49, -0.81), Vector3(0.94, 0.22, 0.94), _paint)
	nose.rotation.x = -0.14
	_box(body, Vector3(0, 0.34, -1.24), Vector3(1.5, 0.09, 0.23), _dark)
	_box(body, Vector3(0, 0.63, -0.81), Vector3(0.13, 0.025, 0.94), _cream)
	for x: float in [-0.65, 0.65]:
		_box(body, Vector3(x, 0.55, 0.04), Vector3(0.25, 0.4, 1.13), _paint)
		_box(body, Vector3(x, 0.54, -0.58), Vector3(0.18, 0.13, 0.08), _lamp())
		_box(body, Vector3(x * 0.7, 0.79, 0.87), Vector3(0.1, 0.58, 0.1), _dark)
	_box(body, Vector3(0, 1.02, 0.92), Vector3(1.56, 0.1, 0.36), _accent)
	var fur: StandardMaterial3D = _material(Color("dc773d"))
	_ellipsoid(driver, Vector3(0, 0.2, 0.02), Vector3(0.65, 0.75, 0.59), _dark)
	_ellipsoid(driver, Vector3(0, 0.76, -0.04), Vector3(0.75, 0.7, 0.67), fur)
	for x: float in [-0.27, 0.27]:
		_cone(driver, Vector3(x, 1.18, 0), 0.18, 0.51, fur)
		_cone(driver, Vector3(x, 1.18, -0.045), 0.1, 0.34, _cream)
		_ellipsoid(driver, Vector3(x * 0.82, 0.63, -0.31), Vector3(0.37, 0.3, 0.27), _cream)
	_ellipsoid(driver, Vector3(0, 0.7, -0.43), Vector3(0.35, 0.25, 0.31), fur)
	_ellipsoid(driver, Vector3(0, 0.71, -0.59), Vector3(0.13, 0.11, 0.11), _dark)
	_face(driver, 0.19, 0.88, -0.34, 0.13)
	_box(driver, Vector3(0, 0.92, -0.36), Vector3(0.62, 0.055, 0.055), _accent)
	_scarf(driver, _accent)
	_arms(fur, false)
	var tail: MeshInstance3D = _ellipsoid(
		body, Vector3(0.34, 0.83, 0.83), Vector3(0.31, 0.34, 0.83), fur)
	tail.rotation.y = 0.5
	_ellipsoid(body, Vector3(0.51, 0.84, 1.16), Vector3(0.26, 0.29, 0.31), _cream)


func _build_owl() -> void:
	_paint = _material(Color("8875dc"), 0.25)
	_accent = _material(Color("ffe18d"), 0.5)
	_ellipsoid(body, Vector3(0, 0.48, 0), Vector3(1.5, 0.59, 1.94), _paint)
	_box(body, Vector3(0, 0.36, -1.0), Vector3(1.45, 0.15, 0.27), _metal)
	for x: float in [-0.72, 0.72]:
		var turbine: MeshInstance3D = _cylinder(
			body, Vector3(x, 0.68, 0.38), 0.3, 0.97, _paint)
		turbine.rotation.x = PI / 2.0
		var exhaust_ring: MeshInstance3D = _cylinder(
			body, Vector3(x, 0.68, 0.89), 0.24, 0.06, _accent)
		exhaust_ring.rotation.x = PI / 2.0
		var hole: MeshInstance3D = _cylinder(
			body, Vector3(x, 0.68, 0.93), 0.15, 0.07, _dark)
		hole.rotation.x = PI / 2.0
		_ellipsoid(body, Vector3(x * 0.68, 0.6, -0.89), Vector3(0.26, 0.22, 0.14), _lamp())
	var plumage: StandardMaterial3D = _material(Color("626098"))
	_ellipsoid(driver, Vector3(0, 0.4, 0), Vector3(0.94, 1.12, 0.77), plumage)
	_ellipsoid(driver, Vector3(0, 0.23, -0.31), Vector3(0.62, 0.62, 0.23), _cream)
	for x: float in [-0.22, 0.22]:
		_ellipsoid(driver, Vector3(x, 0.74, -0.3), Vector3(0.5, 0.52, 0.26), _cream)
		_ellipsoid(driver, Vector3(x, 0.76, -0.44), Vector3(0.25, 0.29, 0.09), _accent)
		_ellipsoid(driver, Vector3(x, 0.77, -0.5), Vector3(0.13, 0.18, 0.04), _dark)
		_ellipsoid(driver, Vector3(x - 0.035, 0.82, -0.53), Vector3(0.047, 0.065, 0.03), _cream)
		var brow: MeshInstance3D = _box(
			driver, Vector3(x, 1.04, -0.07), Vector3(0.27, 0.22, 0.31), plumage)
		brow.rotation.z = -signf(x) * 0.4
	var beak: MeshInstance3D = _cone(
		driver, Vector3(0, 0.59, -0.51), 0.13, 0.3, _accent)
	beak.rotation.x = -PI / 2.0
	_scarf(driver, _paint)
	_arms(plumage, true)
	_box(body, Vector3(0, 0.73, -0.87), Vector3(0.19, 0.1, 0.38), _accent)


func _build_running_gear() -> void:
	for x: float in [-0.8, 0.8]:
		for z: float in [-0.7, 0.7]:
			var steering: Node3D = Node3D.new()
			steering.position = Vector3(x, 0.3, z)
			body.add_child(steering)
			if z < 0.0:
				front_wheels.append(steering)
			var wheel: Node3D = Node3D.new()
			steering.add_child(wheel)
			wheels.append(wheel)
			var tire: MeshInstance3D = _cylinder(wheel, Vector3.ZERO, 0.3, 0.26, _dark)
			tire.rotation.z = PI / 2.0
			var hub: MeshInstance3D = _cylinder(
				wheel, Vector3(signf(x) * 0.145, 0, 0), 0.18, 0.045, _metal)
			hub.rotation.z = PI / 2.0
			for spoke: int in range(3):
				var stripe: MeshInstance3D = _box(
					wheel, Vector3(signf(x) * 0.174, 0, 0), Vector3(0.03, 0.26, 0.045), _accent)
				stripe.rotation.x = float(spoke) * PI / 3.0
	var steering_wheel: MeshInstance3D = _cylinder(
		body, Vector3(0, 1.07, -0.4), 0.23, 0.045, _dark)
	steering_wheel.rotation.x = 0.65


func _arms(fur: StandardMaterial3D, wing: bool) -> void:
	for side: int in [-1, 1]:
		var arm: Node3D = Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(float(side) * 0.36, 0.34, -0.05)
		driver.add_child(arm)
		_ellipsoid(arm, Vector3(0, -0.04, -0.22),
			Vector3(0.22 if wing else 0.16, 0.24, 0.47), fur)
		_ellipsoid(arm, Vector3(0, -0.11, -0.41), Vector3(0.2, 0.17, 0.17), _cream)


func _scarf(parent: Node3D, material: StandardMaterial3D) -> void:
	_ellipsoid(parent, Vector3(0, 0.44, 0.02), Vector3(0.75, 0.15, 0.69), material)
	var ribbon: MeshInstance3D = _box(
		parent, Vector3(0.14, 0.38, 0.43), Vector3(0.19, 0.08, 0.52), material)
	ribbon.rotation.x = -0.2


func _face(parent: Node3D, spacing: float, height: float, depth: float, size: float) -> void:
	for side: int in [-1, 1]:
		var pos: Vector3 = Vector3(float(side) * spacing, height, depth)
		_ellipsoid(parent, pos, Vector3(size, size * 1.25, size * 0.5), _dark)
		_ellipsoid(parent, pos + Vector3(-0.02, 0.03, -0.035),
			Vector3(0.04, 0.05, 0.03), _cream)


func _build_effects() -> void:
	sparks = _particles("Sparks", Color("ffc45a"), 26, 0.35, 0.045)
	sparks.position = Vector3(0, 0.12, 0.71)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.82, 0.02, 0.15)
	sparks.direction = Vector3(0, 0.5, 1)
	sparks.spread = 38.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.2
	sparks.gravity = Vector3(0, -6, 0)
	exhaust = _particles("Exhaust", Color(0.7, 0.86, 0.88, 0.38), 12, 0.65, 0.12)
	exhaust.position = Vector3(0, 0.49, 1.1)
	exhaust.direction = Vector3(0, 0.2, 1)
	exhaust.gravity = Vector3(0, 0.45, 0)
	exhaust.initial_velocity_min = 0.4
	exhaust.initial_velocity_max = 0.8
	boost_trail = _particles("BoostTrail", Color("72edff"), 32, 0.34, 0.12)
	boost_trail.position = Vector3(0, 0.48, 1.04)
	boost_trail.direction = Vector3(0, 0, 1)
	boost_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	boost_trail.emission_box_extents = Vector3(0.42, 0.03, 0.05)
	boost_trail.initial_velocity_min = 4.0
	boost_trail.initial_velocity_max = 7.0
	boost_trail.spread = 10.0
	boost_trail.gravity = Vector3.ZERO


func _particles(label: String, color: Color, count: int,
		lifetime: float, size: float) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = label
	particles.amount = count
	particles.lifetime = lifetime
	particles.emitting = false
	particles.local_coords = false
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material: StandardMaterial3D = _material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	particles.mesh = mesh
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	add_child(particles)
	return particles


func _build_animations() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var library: AnimationLibrary = AnimationLibrary.new()
	for state: String in ["idle", "drive", "drift", "boost", "hit", "celebrate"]:
		var animation: Animation = Animation.new()
		animation.length = 0.65 if state == "hit" else 1.2
		animation.loop_mode = Animation.LOOP_NONE if state == "hit" else Animation.LOOP_LINEAR
		var sway: float = 0.035 + float(model_kind) * 0.012
		var lean: Vector3 = Vector3.ZERO
		var hop: float = 0.022
		match state:
			"drive":
				lean.x = -0.1
				hop = 0.04
			"drift":
				lean = Vector3(-0.06, 0.15, 0.24)
				sway = 0.1
			"boost":
				lean.x = -0.28
				hop = 0.065
			"hit":
				lean = Vector3(0.2, 0.0, 0.35)
				hop = 0.17
			"celebrate":
				hop = 0.24
				sway = 0.13
		_add_track(animation, "Body/Driver:position", [
			Vector3(0, 0.97, 0.12), Vector3(0, 0.97 + hop, 0.12), Vector3(0, 0.97, 0.12)])
		_add_track(animation, "Body/Driver:rotation", [
			lean + Vector3(0, 0, -sway), lean + Vector3(0, 0, sway),
			lean + Vector3(0, 0, -sway)])
		_add_track(animation, "Body:rotation", [Vector3.ZERO,
			Vector3(0.012, PI if state == "hit" else 0.0, -lean.z * 0.3),
			Vector3(0, TAU if state == "hit" else 0.0, 0)])
		for arm: String in ["LeftArm", "RightArm"]:
			var raised: float = 2.5 if state == "celebrate" else 0.0
			var side: float = -1.0 if arm == "LeftArm" else 1.0
			_add_track(animation, "Body/Driver/" + arm + ":rotation", [
				Vector3(raised, 0, side * raised * 0.2),
				Vector3(raised + hop, 0, side * (raised * 0.2 + sway)),
				Vector3(raised, 0, side * raised * 0.2)])
		library.add_animation(state, animation)
	animation_player.add_animation_library("", library)


func _add_track(animation: Animation, path: String, values: Array) -> void:
	var track: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for index: int in range(values.size()):
		animation.track_insert_key(track, float(index) * animation.length / 2.0, values[index])


func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.38 if metallic > 0.0 else 0.72
	return material


func _lamp() -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(Color("fff2b1"))
	material.emission_enabled = true
	material.emission = Color("fff2b1")
	material.emission_energy_multiplier = 1.1
	return material


func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance: MeshInstance3D = _mesh(parent, pos, mesh, material)
	instance.scale = size
	return instance


func _box(parent: Node3D, pos: Vector3, size: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(parent, pos, mesh, material)


func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return _mesh(parent, pos, mesh, material)


func _cone(parent: Node3D, pos: Vector3, radius: float, height: float,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 4
	return _mesh(parent, pos, mesh, material)


func _mesh(parent: Node3D, pos: Vector3, mesh: Mesh,
		material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance
