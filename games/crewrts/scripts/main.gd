extends Node3D
## 入力・描画・音を接続する。ゲーム進行の正は Expedition autoload。

const WorldView = preload("res://scripts/world.gd")
const HudView = preload("res://scripts/hud.gd")
const EffectsView = preload("res://scripts/effects.gd")
const AudioDirector = preload("res://scripts/audio_director.gd")
const UI_FONT = preload("res://assets/fonts/MPLUSRounded1c-Regular.ttf")

var model: Node
var world: Node3D
var hud: CanvasLayer
var yaw: float = 0.0
var aim := Vector3.ZERO
var paused: bool = false
var mouse_aim: bool = false
var pointer_position := Vector2.ZERO
var throw_cooldown: float = 0.0
var effects: Node3D
var audio: Node
var impact_time: float = 0.0
var closing: bool = false


## シーン生成時の接続・音声開始は一度だけ実行する。
func _ready() -> void:
	get_tree().auto_accept_quit = false
	model = get_node("/root/Expedition")
	model.start_day()
	model.show_title()
	world = WorldView.new()
	add_child(world)
	world.setup(model, UI_FONT)
	effects = EffectsView.new()
	add_child(effects)
	effects.font = UI_FONT
	effects.reset(model)
	hud = HudView.new()
	add_child(hud)
	hud.setup(UI_FONT)
	hud.start_requested.connect(start_day)
	hud.title_requested.connect(show_title)
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup()
	effects.hit_presented.connect(func() -> void: audio.play_event("hit"))
	world.set_camera(model, yaw, 0.0, true)
	print("crewrts boot")


func start_day() -> void:
	model.start_day()
	world.reset_view(model)
	paused = false
	yaw = 0.0
	mouse_aim = false
	throw_cooldown = 0.0
	impact_time = 0.0
	effects.reset(model)
	effects.set_paused(false)
	hud.set_paused(false)
	world.set_camera(model, yaw, 0.0, true)


func show_title() -> void:
	model.show_title()
	paused = false
	hud.set_paused(false)


## 入力イベントの発生回数に応じた操作なので冪等にはしない。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if event is InputEventMouseMotion:
		mouse_aim = true
		pointer_position = event.position
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		mouse_aim = false
	if event.is_action_pressed("pause") and model.phase == "playing":
		paused = not paused
		hud.set_paused(paused)
		effects.set_paused(paused)
		get_viewport().set_input_as_handled()


## 押下で一度だけ発行する命令。長押し投擲は _physics_process の間隔で制限する。
func _unhandled_input(event: InputEvent) -> void:
	if model.phase != "playing" or paused:
		return
	if event.is_action_pressed("whistle"):
		model.whistle()
	if event.is_action_pressed("dismiss"):
		model.dismiss()
	if event.is_action_pressed("switch_kind"):
		model.selected_kind = 1 - model.selected_kind
		audio.play_event("switch")
	if event.is_action_pressed("throw") and throw_cooldown <= 0:
		model.throw_at(aim)
		throw_cooldown = 0.18


## 実時間によるシミュレーションとアニメーションの進行は非冪等。
func _physics_process(delta: float) -> void:
	if model == null:
		return
	impact_time = maxf(0.0, impact_time - delta)
	if model.phase == "playing" and not paused and impact_time <= 0.0:
		yaw -= Input.get_axis("camera_left", "camera_right") * delta * 1.8
		var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var movement := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
		if movement.length_squared() > 0.01:
			world.leader_mesh.rotation.y = atan2(-movement.x, -movement.z)
		_update_aim()
		throw_cooldown = maxf(0.0, throw_cooldown - delta)
		if Input.is_action_pressed("throw") and throw_cooldown <= 0:
			model.throw_at(aim)
			throw_cooldown = 0.18
		model.step(delta, movement)
		_consume_events()
	world.set_camera(model, yaw, delta)
	world.sync(model, 0.0 if paused else delta, aim)
	effects.sync(model, 0.0 if paused else delta, world.camera)
	hud.refresh(model)
	audio.update_state(model)


func _update_aim() -> void:
	aim = model.leader + Vector3(0, 0, -8).rotated(Vector3.UP, yaw)
	if mouse_aim:
		var origin: Vector3 = world.camera.project_ray_origin(pointer_position)
		var ray: Vector3 = world.camera.project_ray_normal(pointer_position)
		if ray.y < -0.01:
			aim = origin + ray * (-origin.y / ray.y)
	var direction: Vector3 = aim - model.leader
	direction.y = 0
	aim = model.leader + direction.limit_length(10.0)
	# パッドとキーボードでも対象を狙えるよう、照準近くの対象に吸着する。
	var best: float = 2.3
	for item: Dictionary in model.cargo:
		if item.delivered:
			continue
		var distance: float = aim.distance_to(item.position)
		if distance < best and model.leader.distance_to(item.position) <= 10:
			best = distance
			aim = item.position
	for enemy: Dictionary in model.enemies:
		var distance: float = aim.distance_to(enemy.position)
		if enemy.hp > 0 and distance < best and model.leader.distance_to(enemy.position) <= 10:
			best = distance
			aim = enemy.position


## イベントは一度だけ鳴らして消費する。
func _consume_events() -> void:
	for event: String in model.events:
		audio.play_event(event)
		world.notify_action(event)
		effects.notify_event(event, model)
		hud.notify_event(event)
		if event == "whistle":
			world.whistle_time = 1.0
		if event == "defeat" or event == "lost":
			impact_time = 0.06
	model.events.clear()


func stop_audio() -> void:
	if is_instance_valid(audio):
		audio.stop_audio()


func _exit_tree() -> void:
	stop_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		stop_audio()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()
