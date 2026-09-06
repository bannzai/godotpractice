extends Node3D
## 物理フレーム・入力・演出は時間に応じた副作用を持つため、各フレームで一度だけ処理する。

const Room = preload("res://scripts/room.gd")
const Hud = preload("res://scripts/hud.gd")

var room: Node3D
var items: Node3D
var ball: CharacterBody3D
var rolling: Node3D
var core: MeshInstance3D
var ball_shape: SphereShape3D
var camera: Camera3D
var hud: Control
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var attached: Array[Node3D] = []
var yaw: float = 0.0
var bump_cooldown: float = 0.0
var effect_time: float = 0.0
var previous_phase: String = "title"
var demo_mode: bool = false
var demo_elapsed: float = 0.0
var demo_target: StaticBody3D


func _ready() -> void:
	room = Room.new()
	add_child(room)
	items = Node3D.new()
	add_child(items)
	_create_ball()
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 90.0
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.start_requested.connect(start_run)
	hud.title_requested.connect(show_title)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/music.wav")
	music.volume_db = -12.0
	add_child(music)
	music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# 描画なし検証の Dummy 音声ドライバでは再生バッファを作らない。
	if AudioServer.get_driver_name() != "Dummy" or OS.has_feature("movie"):
		music.play()
	sound = AudioStreamPlayer.new()
	sound.volume_db = -9.0
	add_child(sound)
	show_title()
	print("rollball boot")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	if event.is_action_pressed("confirm") and RunState.phase != "playing":
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
		else:
			start_run()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("cancel"):
		show_title()


func start_run() -> void:
	RunState.start_run()
	_reset_world()
	yaw = 0.0
	_update_camera(1.0, true)
	hud.show_mode("playing")
	previous_phase = "playing"


func show_title() -> void:
	RunState.reset()
	_reset_world()
	camera.position = Vector3(17.0, 17.0, 23.0)
	camera.look_at(Vector3(0.0, 0.0, -1.5))
	hud.show_mode("title")
	previous_phase = "title"


func _reset_world() -> void:
	for child: Node in items.get_children():
		child.free()
	for child: Node3D in attached:
		child.free()
	attached.clear()
	for entry: Dictionary in Room.item_layout():
		_spawn_item(entry)
	rolling.basis = Basis.IDENTITY
	ball.position = Vector3(0.0, RunState.diameter * 0.5 + 0.02, 8.0)
	ball.velocity = Vector3.ZERO
	bump_cooldown = 0.0
	demo_target = null
	_sync_size()


## 新しいラウンドと脱落時だけ呼び出し、物理ボディを一つ追加する。
func _spawn_item(entry: Dictionary) -> StaticBody3D:
	var item: StaticBody3D = StaticBody3D.new()
	item.collision_layer = 2
	item.collision_mask = 0
	item.set_meta("entry", entry)
	item.set_meta("available_at", 0.0)
	items.add_child(item)
	item.position = entry.position
	var visual: Node3D = Room.make_item_visual(entry.size, entry.kind, entry.color)
	visual.name = "Visual"
	item.add_child(visual)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * float(entry.size) * 0.85
	collider.shape = box
	collider.position.y = float(entry.size) * 0.5
	item.add_child(collider)
	return item


func _create_ball() -> void:
	ball = CharacterBody3D.new()
	ball.collision_layer = 4
	ball.collision_mask = 3
	add_child(ball)
	var collider: CollisionShape3D = CollisionShape3D.new()
	ball_shape = SphereShape3D.new()
	collider.shape = ball_shape
	ball.add_child(collider)
	rolling = Node3D.new()
	ball.add_child(rolling)
	core = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	core.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ed795c")
	material.roughness = 0.72
	core.material_override = material
	rolling.add_child(core)
	for axis: int in range(3):
		var band: MeshInstance3D = MeshInstance3D.new()
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.48
		ring.outer_radius = 0.505
		ring.rings = 24
		ring.ring_segments = 8
		band.mesh = ring
		var stripe: StandardMaterial3D = StandardMaterial3D.new()
		stripe.albedo_color = Color("fff0c9")
		band.material_override = stripe
		band.rotation = Vector3(PI / 2.0 if axis == 1 else 0.0, 0.0, PI / 2.0 if axis == 2 else 0.0)
		core.add_child(band)


func _physics_process(delta: float) -> void:
	if demo_mode and RunState.phase == "title":
		demo_elapsed += delta
		if demo_elapsed > 1.0:
			start_run()
	if RunState.phase != "playing":
		return
	RunState.tick(delta)
	bump_cooldown = maxf(0.0, bump_cooldown - delta)
	effect_time = maxf(0.0, effect_time - delta)
	yaw += Input.get_axis("camera_left", "camera_right") * delta * 1.8
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	if demo_mode:
		direction = _demo_direction()
	var speed: float = 4.8 + RunState.diameter * 0.7
	if bump_cooldown < 0.45:
		ball.velocity.x = move_toward(ball.velocity.x, direction.x * speed, delta * 20.0)
		ball.velocity.z = move_toward(ball.velocity.z, direction.z * speed, delta * 20.0)
	ball.velocity.y = -1.0
	_collect_contacts()
	var before: Vector3 = ball.position
	ball.move_and_slide()
	for index: int in range(ball.get_slide_collision_count()):
		var contact: KinematicCollision3D = ball.get_slide_collision(index)
		var body: Object = contact.get_collider()
		if body is StaticBody3D and absf(contact.get_normal().y) < 0.65:
			if body.has_meta("entry") or body.get_meta("obstacle", false):
				_bump(contact.get_normal())
	var travel: Vector3 = ball.position - before
	travel.y = 0.0
	if travel.length() > 0.001:
		rolling.rotate(
			Vector3.UP.cross(travel).normalized(), travel.length() / (RunState.diameter * 0.5)
		)
	ball.position.y = RunState.diameter * 0.5 + 0.02
	_sync_size()
	_update_camera(delta)
	if RunState.phase != previous_phase:
		hud.show_mode(RunState.phase)
		_play_sound("win" if RunState.phase == "won" else "lose")
		previous_phase = RunState.phase


func _process(_delta: float) -> void:
	hud.update_values(effect_time, bump_cooldown)


## 接触した未回収ボディだけを一度消費し、表示メッシュを玉の子へ移す。
func _collect_contacts() -> void:
	for item: StaticBody3D in items.get_children():
		var entry: Dictionary = item.get_meta("entry")
		if not RunState.can_collect(entry.size):
			continue
		if float(item.get_meta("available_at")) > Time.get_ticks_msec() / 1000.0:
			continue
		var flat: Vector3 = item.position - ball.position
		flat.y = 0.0
		if flat.length() <= RunState.diameter * 0.5 + float(entry.size) * 0.55 + 0.12:
			_attach_item(item)
			if RunState.phase != "playing":
				break


func _attach_item(item: StaticBody3D) -> void:
	var entry: Dictionary = item.get_meta("entry")
	var visual: Node3D = item.get_node("Visual")
	var direction: Vector3 = item.position + Vector3.UP * float(entry.size) * 0.5 - ball.position
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	visual.reparent(rolling)
	visual.set_meta("anchor", rolling.basis.inverse() * direction.normalized())
	visual.set_meta("entry", entry)
	attached.append(visual)
	items.remove_child(item)
	item.queue_free()
	RunState.collect(pow(float(entry.size), 3.0) * 0.8)
	effect_time = 0.65
	_sync_size()
	_play_sound("pickup")
	_spawn_sparkles()


func _sync_size() -> void:
	ball_shape.radius = RunState.diameter * 0.5
	core.scale = Vector3.ONE * RunState.diameter
	for visual: Node3D in attached:
		visual.position = Vector3(visual.get_meta("anchor")) * RunState.diameter * 0.46


## 衝突ごとに一度だけ反発・脱落させる。連続接触はクールダウンで抑制する。
func _bump(normal: Vector3) -> void:
	if bump_cooldown > 0.0 or RunState.phase != "playing":
		return
	bump_cooldown = 0.85
	ball.velocity = normal * 6.0
	_play_sound("bump")
	if attached.is_empty():
		return
	var visual: Node3D = attached.pop_back()
	var entry: Dictionary = visual.get_meta("entry").duplicate()
	RunState.shed()
	entry.position = ball.position + normal * (RunState.diameter * 0.5 + float(entry.size) + 0.8)
	entry.position.y = 0.0
	entry.position.x = clampf(entry.position.x, -13.0, 13.0)
	entry.position.z = clampf(entry.position.z, -13.0, 13.0)
	visual.queue_free()
	var dropped: StaticBody3D = _spawn_item(entry)
	dropped.set_meta("available_at", Time.get_ticks_msec() / 1000.0 + 1.0)
	_sync_size()


func _update_camera(delta: float, snap: bool = false) -> void:
	var distance: float = 6.0 + RunState.diameter * 2.0
	var offset: Vector3 = Vector3(0.0, 4.0 + RunState.diameter * 1.2, distance)
	var target: Vector3 = ball.position + offset.rotated(Vector3.UP, yaw)
	target.x = clampf(target.x, -13.6, 13.6)
	target.z = clampf(target.z, -13.6, 13.6)
	var focus: Vector3 = ball.position + Vector3.UP * RunState.diameter * 0.2
	target = target if snap else camera.position.lerp(target, 1.0 - exp(-delta * 7.0))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(focus, target, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = Vector3(hit.position) + (focus - Vector3(hit.position)).normalized() * 0.3
	camera.position = target
	camera.look_at(focus)


func _play_sound(kind: String) -> void:
	if AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie"):
		return
	sound.stream = load("res://assets/audio/%s.wav" % kind)
	sound.play()


## 短命な演出ノードを生成し、Tween 完了時に解放する。
func _spawn_sparkles() -> void:
	for index: int in range(6):
		var sparkle: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.11
		mesh.radial_segments = 6
		mesh.rings = 3
		sparkle.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffe7a1")
		sparkle.material_override = material
		add_child(sparkle)
		sparkle.position = ball.position
		var angle: float = float(index) * TAU / 6.0
		var end: Vector3 = ball.position + Vector3(cos(angle), 1.3, sin(angle)) * RunState.diameter
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(sparkle, "position", end, 0.45)
		tween.tween_property(sparkle, "scale", Vector3.ONE * 0.05, 0.45)
		tween.chain().tween_callback(sparkle.queue_free)


## 開発用録画も通常と同じ移動・衝突・回収処理を通す。
func _demo_direction() -> Vector3:
	if not is_instance_valid(demo_target) or demo_target.get_parent() != items:
		var nearest: float = INF
		demo_target = null
		for item: StaticBody3D in items.get_children():
			var entry: Dictionary = item.get_meta("entry")
			if not RunState.can_collect(entry.size):
				continue
			var distance: float = ball.position.distance_squared_to(item.position)
			if distance < nearest:
				nearest = distance
				demo_target = item
	if demo_target == null:
		return Vector3.ZERO
	var direction: Vector3 = demo_target.position - ball.position
	direction.y = 0.0
	return direction.normalized()


func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
	if is_instance_valid(sound):
		sound.stop()
