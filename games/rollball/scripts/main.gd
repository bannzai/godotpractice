extends Node3D
## 物理フレーム・入力・演出は時間に応じた副作用を持つため、各フレームで一度だけ処理する。

const Room = preload("res://scripts/room.gd")
const Hud = preload("res://scripts/hud.gd")
const Effects = preload("res://scripts/effects.gd")
const BallScene = preload("res://assets/models/ball.tscn")
const ClaySurface = preload("res://scripts/visuals/clay_surface.gd")

var room: Node3D
var items: Node3D
var ball: CharacterBody3D
var rolling: Node3D
var core: Node3D
var ball_shape: SphereShape3D
var camera: Camera3D
var hud: Control
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sound: AudioStreamPlayer
var attached: Array[Node3D] = []
var yaw: float = 0.0
var bump_cooldown: float = 0.0
var effect_time: float = 0.0
var previous_phase: String = "title"
var demo_mode: bool = false
var demo_elapsed: float = 0.0
var demo_target: StaticBody3D
var effects: Node3D
var hit_pause: float = 0.0
var shake: float = 0.0
var growth_stage: int = 0
var music_kind: String = ""
var music_tween: Tween
var audio_stopped: bool = false
var quitting: bool = false
var quit_frame: int = 0
var title_elapsed: float = 0.0
var tutorial_step: int = 0
var tutorial_actors: Node3D
var target_highlight: Node3D
var highlight_target: StaticBody3D
var highlight_elapsed: float = 0.0
var ambience_kind: String = ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# --quit-after はエンジンが消費するため、録画入口から終了フレームを別途渡す。
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var quit_index: int = arguments.find("--audio-stop-at-frame")
	if quit_index >= 0 and quit_index + 1 < arguments.size():
		quit_frame = int(arguments[quit_index + 1])
		# 解放を待てないほど短い終了指定では、再生バッファを作らない。
		audio_stopped = quit_frame > 0 and quit_frame <= 12
	room = Room.new(RunState.selected_stage)
	add_child(room)
	items = Node3D.new()
	add_child(items)
	effects = Effects.new()
	add_child(effects)
	_create_target_highlight()
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
	hud.stage_select_requested.connect(show_stage_select)
	hud.stage_changed.connect(select_stage)
	hud.stage_start_requested.connect(begin_selected_stage)
	hud.tutorial_next_requested.connect(next_tutorial_step)
	hud.tutorial_skip_requested.connect(skip_tutorial)
	music = AudioStreamPlayer.new()
	music.volume_db = -12.0
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -27.0
	add_child(ambience)
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
		elif RunState.phase == "title":
			show_stage_select()
		elif RunState.phase == "stage_select":
			begin_selected_stage()
		elif RunState.phase == "tutorial":
			next_tutorial_step()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("cancel"):
		if RunState.phase == "tutorial":
			skip_tutorial()
		else:
			show_title()


func start_run() -> void:
	RunState.start_run()
	_clear_tutorial_actors()
	_reset_world()
	yaw = 0.0
	_update_camera(1.0, true)
	hud.show_mode("playing")
	previous_phase = "playing"
	_set_music("play")
	_set_ambience(RunState.selected_stage)


func show_stage_select() -> void:
	RunState.open_stage_select()
	_clear_tutorial_actors()
	_reset_world()
	_set_stage_camera()
	hud.show_mode("stage_select")
	hud.update_stage(RunState.selected_stage)
	previous_phase = "stage_select"
	_set_music("title")
	_set_ambience(RunState.selected_stage)


func select_stage(stage_id: String) -> void:
	if not Room.has_stage(stage_id):
		return
	RunState.select_stage(stage_id)
	_replace_room(stage_id)
	_reset_world()
	_set_stage_camera()
	hud.update_stage(stage_id)
	_set_ambience(stage_id)


func begin_selected_stage() -> void:
	if RunState.tutorial_seen:
		start_run()
	else:
		show_tutorial()


func show_tutorial() -> void:
	RunState.begin_tutorial()
	_reset_world()
	tutorial_step = 0
	_create_tutorial_actors()
	_set_tutorial_step(0)
	_set_tutorial_camera()
	hud.show_mode("tutorial")
	hud.update_tutorial(0)
	previous_phase = "tutorial"
	_set_music("title")
	_set_ambience(RunState.selected_stage)


func next_tutorial_step() -> void:
	if RunState.phase != "tutorial":
		return
	tutorial_step += 1
	if tutorial_step >= 3:
		RunState.finish_tutorial()
		start_run()
		return
	_set_tutorial_step(tutorial_step)
	hud.update_tutorial(tutorial_step)


func skip_tutorial() -> void:
	if RunState.phase != "tutorial":
		return
	RunState.finish_tutorial()
	start_run()


func show_title() -> void:
	RunState.reset()
	_clear_tutorial_actors()
	_reset_world()
	camera.position = Vector3(17.0, 17.0, 23.0)
	camera.look_at(Vector3(0.0, 0.0, -1.5))
	hud.show_mode("title")
	previous_phase = "title"
	_set_music("title")
	_set_ambience(RunState.selected_stage)


func _reset_world() -> void:
	effects.clear()
	for child: Node in items.get_children():
		child.free()
	for child: Node3D in attached:
		child.free()
	attached.clear()
	for entry: Dictionary in Room.item_layout(RunState.selected_stage):
		_spawn_item(entry)
	rolling.basis = Basis.IDENTITY
	var spawn: Vector3 = Room.stage_data(RunState.selected_stage).spawn
	ball.position = spawn + Vector3.UP * (RunState.diameter * 0.5 + 0.02)
	ball.velocity = Vector3.ZERO
	bump_cooldown = 0.0
	effect_time = 0.0
	hit_pause = 0.0
	shake = 0.0
	if is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	growth_stage = 0
	core.play_state("idle")
	demo_target = null
	highlight_target = null
	target_highlight.visible = false
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
	visual.rotation.y = float(entry.get("yaw", 0.0))
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
	core = BallScene.instantiate()
	ClaySurface.style_tree(core)
	rolling.add_child(core)


func _create_target_highlight() -> void:
	target_highlight = Node3D.new()
	target_highlight.name = "NextToyHighlight"
	add_child(target_highlight)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.57
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.albedo_color = Color("ffd76a")
	ring_material.emission_enabled = true
	ring_material.emission = Color("f4ad48")
	ring_material.emission_energy_multiplier = 1.6
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	target_highlight.add_child(ring)
	var pointer: MeshInstance3D = MeshInstance3D.new()
	var pointer_mesh: PrismMesh = PrismMesh.new()
	pointer_mesh.size = Vector3(0.34, 0.48, 0.12)
	pointer.mesh = pointer_mesh
	pointer.position = Vector3(0.0, 1.15, 0.0)
	pointer.rotation.z = PI
	pointer.material_override = ring_material
	target_highlight.add_child(pointer)
	var caption: Label3D = Label3D.new()
	caption.text = "つぎは これ！"
	caption.font = load("res://assets/fonts/KosugiMaru-Regular.ttf")
	caption.font_size = 42
	caption.pixel_size = 0.009
	caption.position = Vector3(0.0, 1.65, 0.0)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = Color("fff7df")
	caption.outline_modulate = Color("6b493e")
	caption.outline_size = 12
	target_highlight.add_child(caption)
	target_highlight.visible = false


func _replace_room(stage_id: String) -> void:
	if is_instance_valid(room) and room.stage_id == stage_id:
		return
	if is_instance_valid(room):
		room.free()
	room = Room.new(stage_id)
	add_child(room)
	move_child(room, 0)


func _set_stage_camera() -> void:
	var spawn: Vector3 = Room.stage_data(RunState.selected_stage).spawn
	if RunState.selected_stage == "playroom":
		camera.position = Vector3(18.0, 19.0, 22.0)
	else:
		camera.position = Vector3(17.0, 17.0, 23.0)
	camera.look_at(spawn.lerp(Vector3.ZERO, 0.55) + Vector3.UP * 0.7)


func _set_tutorial_camera() -> void:
	var spawn: Vector3 = Room.stage_data(RunState.selected_stage).spawn
	camera.position = spawn + Vector3(6.6, 4.6, 7.4)
	camera.look_at(spawn + Vector3(0.0, 0.75, -0.7))


func _create_tutorial_actors() -> void:
	_clear_tutorial_actors()
	tutorial_actors = Node3D.new()
	tutorial_actors.name = "TutorialActors"
	add_child(tutorial_actors)
	var spawn: Vector3 = Room.stage_data(RunState.selected_stage).spawn
	for data: Dictionary in [
		{"scene": preload("res://assets/models/duck.tscn"), "offset": Vector3(-1.5, 0, -1.0)},
		{"scene": preload("res://assets/models/robot.tscn"), "offset": Vector3(1.5, 0, -1.25)},
	]:
		var actor: Node3D = data.scene.instantiate()
		ClaySurface.style_tree(actor)
		actor.position = spawn + data.offset
		actor.rotation_degrees.y = 180.0
		actor.scale = Vector3.ONE * 1.2
		tutorial_actors.add_child(actor)


func _clear_tutorial_actors() -> void:
	if is_instance_valid(tutorial_actors):
		tutorial_actors.free()
	tutorial_actors = null


func _set_tutorial_step(step: int) -> void:
	core.play_state(["move", "bump", "collect"][step])
	if not is_instance_valid(tutorial_actors):
		return
	var actors: Array[Node] = tutorial_actors.get_children()
	if actors.size() < 2:
		return
	(actors[0] as Node3D).play_state(["move", "idle", "collect"][step])
	(actors[1] as Node3D).play_state(["idle", "bump", "celebrate"][step])


func _update_target_highlight(delta: float) -> void:
	highlight_elapsed += delta
	if is_instance_valid(highlight_target):
		var highlighted_entry: Dictionary = highlight_target.get_meta("entry")
		if not RunState.can_collect(highlighted_entry.size):
			highlight_target = null
	if not is_instance_valid(highlight_target) or highlight_target.get_parent() != items:
		highlight_target = _nearest_collectible()
	if not is_instance_valid(highlight_target):
		target_highlight.visible = false
		return
	var entry: Dictionary = highlight_target.get_meta("entry")
	var item_size: float = float(entry.size)
	target_highlight.visible = true
	target_highlight.position = highlight_target.position + Vector3.UP * (item_size * 0.06 + 0.04)
	target_highlight.scale = Vector3.ONE * maxf(0.72, item_size * 1.32)
	target_highlight.rotation.y = highlight_elapsed * 0.75
	var pointer: MeshInstance3D = target_highlight.get_child(1)
	pointer.position.y = 1.15 + sin(highlight_elapsed * 4.2) * 0.13


func _nearest_collectible() -> StaticBody3D:
	var nearest: StaticBody3D
	var nearest_distance: float = INF
	for item: StaticBody3D in items.get_children():
		var entry: Dictionary = item.get_meta("entry")
		if not RunState.can_collect(entry.size):
			continue
		if float(item.get_meta("available_at")) > Time.get_ticks_msec() / 1000.0:
			continue
		var distance: float = ball.position.distance_squared_to(item.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = item
	return nearest


func _physics_process(delta: float) -> void:
	if demo_mode and RunState.phase == "title":
		demo_elapsed += delta
		if demo_elapsed > 1.0:
			start_run()
	if RunState.phase != "playing":
		return
	RunState.tick(delta)
	if RunState.phase != "playing":
		_finish_run()
		return
	if RunState.remaining <= 30.0:
		_set_music("urgent")
	if hit_pause > 0.0:
		hit_pause = maxf(0.0, hit_pause - delta)
		return
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
	if core.visual_state not in ["collect", "bump"]:
		core.play_state("move" if travel.length() > 0.001 else "idle")
	_sync_size()
	_update_camera(delta)
	_update_target_highlight(delta)
	if RunState.phase != previous_phase:
		_finish_run()


func _finish_run() -> void:
	if RunState.phase == previous_phase:
		return
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	hud.show_mode(RunState.phase)
	var won: bool = RunState.phase == "won"
	core.play_state("celebrate" if won else "lost")
	for visual: Node3D in attached:
		visual.play_state("celebrate" if won else "lost")
	_play_sound("win" if won else "lose")
	_set_music("finish" if won else "timeout")
	if won:
		effects.burst(ball.position, RunState.diameter, "win")
	previous_phase = RunState.phase


func _process(delta: float) -> void:
	if quit_frame > 0 and Engine.get_process_frames() >= maxi(0, quit_frame - 12):
		stop_audio()
	shake = maxf(0.0, shake - delta)
	if RunState.phase == "title":
		title_elapsed += delta
		camera.position = Vector3(17.0 + sin(title_elapsed * 0.18) * 0.7, 17.0, 23.0)
		camera.look_at(Vector3(0.0, 0.0, -1.5))
	elif RunState.phase == "stage_select":
		title_elapsed += delta
		var focus: Vector3 = Room.stage_data(RunState.selected_stage).spawn.lerp(
			Vector3.ZERO, 0.55
		)
		camera.position.x += sin(title_elapsed * 0.45) * delta * 0.12
		camera.look_at(focus + Vector3.UP * 0.7)
	elif RunState.phase == "tutorial":
		highlight_elapsed += delta
		if is_instance_valid(tutorial_actors):
			tutorial_actors.rotation.y = sin(highlight_elapsed * 0.8) * 0.035
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
	if item == highlight_target:
		highlight_target = null
	items.remove_child(item)
	item.queue_free()
	var before_diameter: float = RunState.diameter
	RunState.collect(pow(float(entry.size), 3.0) * 0.8)
	visual.play_state("collect")
	core.play_state("collect")
	effect_time = 0.65
	_sync_size()
	_play_sound("pickup")
	effects.burst(ball.position, RunState.diameter, "pickup")
	hud.show_pickup(RunState.diameter - before_diameter)
	var stage: int = floori((RunState.diameter - RunState.INITIAL_DIAMETER) / 0.6)
	if stage > growth_stage:
		growth_stage = stage
		effects.burst(ball.position, RunState.diameter, "growth")
		hud.show_growth()
		_play_sound("growth")
		shake = 0.16


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
	hit_pause = 0.055
	shake = 0.28
	core.play_state("bump")
	hud.show_bump(not attached.is_empty())
	effects.burst(ball.position, RunState.diameter, "bump")
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
	dropped.get_node("Visual").play_state("bump")
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
	if shake > 0.0 and not snap:
		var time: float = Time.get_ticks_msec() * 0.001
		camera.h_offset = sin(time * 67.0) * shake * 0.18
		camera.v_offset = cos(time * 53.0) * shake * 0.12
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _play_sound(kind: String) -> void:
	if audio_stopped or (AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie")):
		return
	sound.stream = load("res://assets/audio/%s.wav" % kind)
	sound.play()


func _set_music(kind: String) -> void:
	if music_kind == kind or audio_stopped:
		return
	music_kind = kind
	if AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie"):
		return
	if music_tween:
		music_tween.kill()
	music.stop()
	music.stream = load("res://assets/audio/%s.wav" % kind)
	music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# インポート後は QOA 圧縮されるため、バイト数ではなく長さからサンプル数を求める。
	music.stream.loop_end = roundi(music.stream.get_length() * music.stream.mix_rate)
	music.volume_db = -28.0
	music.play()
	music_tween = create_tween()
	music_tween.tween_property(music, "volume_db", -12.0, 0.6)


func _set_ambience(stage_id: String) -> void:
	if ambience_kind == stage_id or audio_stopped:
		return
	ambience_kind = stage_id
	if AudioServer.get_driver_name() == "Dummy" and not OS.has_feature("movie"):
		return
	ambience.stop()
	ambience.stream = load("res://assets/audio/ambience_%s.wav" % stage_id)
	ambience.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience.stream.loop_end = roundi(ambience.stream.get_length() * ambience.stream.mix_rate)
	ambience.play()


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


func stop_audio() -> void:
	audio_stopped = true
	if music_tween:
		music_tween.kill()
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null


## 音声スレッドが停止通知を消費してから終了するため、複数フレームを待つ。
func prepare_shutdown() -> void:
	stop_audio()
	for _frame: int in range(8):
		await get_tree().process_frame


func request_quit() -> void:
	if quitting:
		return
	quitting = true
	set_physics_process(false)
	await prepare_shutdown()
	get_tree().quit(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func _exit_tree() -> void:
	stop_audio()
