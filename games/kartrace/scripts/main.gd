extends Node3D
## 入力イベントと経過時間を状態へ渡し、3D と HUD を同期する。

const World = preload("res://scripts/world.gd")
const Visual = preload("res://scripts/kart_visual.gd")
const Hud = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const Course = preload("res://scripts/course_data.gd")
var world: Node3D
var camera: Camera3D
var hud: Control
var audio: Node
var karts: Array[Node3D] = []
var weapons: Node3D
var state: Node
var clock: float = 0.0
var shake: float = 0.0
var hit_pause: float = 0.0
var quitting: bool = false
var stop_frame: int = 0
var last_count: int = 4
var final_music: bool = false


func _ready() -> void:
	get_tree().auto_accept_quit = false
	state = get_node("/root/RaceState")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--audio-stop-at-frame")
	if index >= 0 and index + 1 < args.size():
		stop_frame = int(args[index + 1])
	world = World.new()
	add_child(world)
	weapons = Node3D.new()
	add_child(weapons)
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 600
	add_child(camera)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.start_requested.connect(start_race)
	hud.title_requested.connect(show_title)
	hud.kart_selected.connect(select_kart)
	audio = Audio.new()
	add_child(audio)
	state.effect.connect(_effect)
	state.phase_changed.connect(_phase_changed)
	show_title()
	print("kartrace boot")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	if event.is_action_pressed("confirm") and state.phase in ["title", "results"]:
		start_race()
	if event.is_action_pressed("cancel"):
		show_title()
	if state.phase == "title":
		if event.is_action_pressed("steer_left"):
			select_kart(posmod(state.selected_kart - 1, 3))
		if event.is_action_pressed("steer_right"):
			select_kart(posmod(state.selected_kart + 1, 3))


func select_kart(kind: int) -> void:
	state.selected_kart = kind
	karts[0].setup(kind)
	audio.play_sfx("select")


func show_title() -> void:
	state.return_to_title()
	_reset_karts()
	audio.set_scene("title")
	shake = 0
	hit_pause = 0
	camera.h_offset = 0
	camera.v_offset = 0


func start_race() -> void:
	state.reset_race()
	_reset_karts()
	last_count = 4
	final_music = false
	audio.set_scene("race")
	_update_racers()
	_update_camera(1.0, true)


func _reset_karts() -> void:
	for kart: Node3D in karts:
		kart.free()
	karts.clear()
	for index: int in range(4):
		var kart: Node3D = Visual.new()
		add_child(kart)
		kart.setup(state.selected_kart if index == 0 else (state.selected_kart + index) % 3)
		karts.append(kart)
	for child: Node in weapons.get_children():
		child.free()


func _physics_process(delta: float) -> void:
	if quitting:
		return
	# 操作と経過時間を積分するためフレームごとに一度実行する。
	clock += delta
	if stop_frame > 0 and Engine.get_process_frames() >= maxi(1, stop_frame - 16):
		audio.stop_all()
	if hit_pause > 0:
		hit_pause -= delta
	else:
		state.tick(minf(delta, 0.05), Input.get_axis("brake", "accelerate"),
			Input.get_axis("steer_left", "steer_right"),
			Input.is_action_pressed("drift"), Input.is_action_just_pressed("item"))
	if state.phase == "title":
		for index: int in range(karts.size()):
			karts[index].position = World.point_at(12 + index * 4, -0.3)
			karts[index].rotation.y = -0.8
		camera.position = Vector3(62, 12, -24)
		camera.look_at(Vector3(38, 3, -11))
	elif state.phase == "results":
		for index: int in range(karts.size()):
			karts[index].play_state("celebrate")
	else:
		_update_racers()
		_update_camera(delta)
		_update_weapons()
		audio.set_engine(absf(state.racers[0].speed) / 25.0)
		if state.phase == "countdown" and ceili(state.countdown) != last_count:
			last_count = ceili(state.countdown)
			audio.play_sfx("countdown")
		if state.racers[0].lap >= 3 and not final_music:
			final_music = true
			audio.set_scene("final")
	hud.refresh()


func _update_racers() -> void:
	for index: int in range(state.racers.size()):
		var racer: Dictionary = state.racers[index]
		var target: Vector3 = World.point_at(racer.progress, racer.lateral)
		if racer.respawn_timer > 0:
			target.y -= sin(racer.respawn_timer * PI) * 4
		karts[index].position = target
		var tangent: Vector3 = Course.tangent(racer.progress)
		var yaw: float = atan2(-tangent.x, -tangent.z)
		karts[index].rotation = Vector3(0, yaw, 0)
		karts[index].set_motion(racer.speed, Input.get_axis("steer_left", "steer_right")
			if index == 0 else 0.0, racer.drifting, racer.boost > 0)


func _update_camera(delta: float, snap: bool = false) -> void:
	var racer: Dictionary = state.racers[0]
	var tangent: Vector3 = Course.tangent(racer.progress)
	var target: Vector3 = karts[0].position
	var desired: Vector3 = target - tangent * 8.5 + Vector3.UP * 4.8
	camera.position = desired if snap else camera.position.lerp(desired, minf(1, delta * 8))
	camera.look_at(target + tangent * 5 + Vector3.UP * 0.8)
	shake = maxf(0, shake - delta * 1.8)
	camera.h_offset = sin(clock * 88) * shake * 0.18
	camera.v_offset = cos(clock * 71) * shake * 0.12
	camera.fov = lerpf(camera.fov, 72 if racer.boost > 0 else 62, minf(delta * 4, 1))


func _update_weapons() -> void:
	var count: int = state.projectiles.size() + state.obstacles.size()
	while weapons.get_child_count() > count:
		weapons.get_child(weapons.get_child_count() - 1).free()
	while weapons.get_child_count() < count:
		World.cylinder(weapons, Vector3.ZERO, 0.55, 0.8, Color("ffb96d"), 0.1)
	var index: int = 0
	for group: Array in [state.projectiles, state.obstacles]:
		for shot: Dictionary in group:
			var visual: Node3D = weapons.get_child(index)
			visual.position = World.point_at(shot.progress, shot.lateral) + Vector3.UP * 0.6
			visual.rotation.y = clock * 6
			index += 1


func _effect(kind: String, racer: int) -> void:
	if racer != 0:
		if kind == "hit":
			karts[racer].play_state("hit")
		return
	match kind:
		"hit", "wall":
			karts[0].play_state("hit")
			shake = 1
			hit_pause = 0.065
			hud.popup("スピン！" if kind == "hit" else "壁に注意！", true)
			audio.play_sfx("hit")
		"boost", "drift_boost", "dash":
			hud.popup("ターボ！")
			audio.play_sfx("boost")
		"item_get", "pickup":
			hud.popup("アイテム獲得！")
			audio.play_sfx("item")
		"item_use":
			hud.popup("アイテム発動！")
			audio.play_sfx("item")
		"lap":
			hud.popup("ファイナルラップ！" if state.racers[0].lap == 3 else "次の周へ！")
			audio.play_sfx("lap")
		"respawn":
			hud.popup("チェックポイントへ復帰", true)
		"start":
			hud.popup("スタート！")
		"finish":
			audio.play_sfx("finish")


func _phase_changed() -> void:
	if state.phase == "results":
		audio.set_scene("results")
		camera.h_offset = 0
		camera.v_offset = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not quitting:
		_shutdown()


func _shutdown() -> void:
	await prepare_shutdown()
	get_tree().quit()


func prepare_shutdown() -> void:
	quitting = true
	audio.stop_all()
	for _frame: int in range(16):
		await get_tree().process_frame
