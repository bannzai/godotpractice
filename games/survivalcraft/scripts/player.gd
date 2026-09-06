extends CharacterBody3D
## 足元を原点に持つ一人称プレイヤー。地形の StaticBody3D と箱で衝突する。

signal fell(amount: float)
signal step_taken

const BODY_SIZE: Vector3 = Vector3(0.6, 1.8, 0.6)
const EYE_HEIGHT: float = 1.62
const WALK_SPEED: float = 4.5
const GRAVITY: float = 22.0
const JUMP_SPEED: float = 7.4

var camera: Camera3D
var enabled: bool = false
var look_sensitivity: float = 0.0025
var _pitch: float = 0.0
var _step_distance: float = 0.0
var _bob_phase: float = 0.0
var _shake: float = 0.0
var _fall_speed: float = 0.0


func setup(spawn: Vector3) -> void:
	if camera == null:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = BODY_SIZE
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = BODY_SIZE.y * 0.5
		add_child(collider)
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.fov = 78.0
		camera.near = 0.06
		camera.far = 250.0
		add_child(camera)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.18
	position = spawn
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	_pitch = 0.0
	_step_distance = 0.0
	_bob_phase = 0.0
	_shake = 0.0
	_fall_speed = 0.0
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.rotation = Vector3.ZERO


func body_aabb() -> AABB:
	return AABB(global_position - Vector3(0.3, 0.0, 0.3), BODY_SIZE)


func shake(amount: float) -> void:
	_shake = clampf(amount, 0.0, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		# 入力の差分を積算して視点を動かすため、イベントごとに非冪等。
		rotate_y(-motion.relative.x * look_sensitivity)
		_pitch = clampf(_pitch - motion.relative.y * look_sensitivity, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not enabled or camera == null:
		return
	# 移動・落下は物理時間を積算するため非冪等。
	var stick: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	rotate_y(-stick.x * delta * 2.1)
	_pitch = clampf(_pitch - stick.y * delta * 1.7, -1.45, 1.45)
	var input_axis: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction: Vector3 = basis * Vector3(input_axis.x, 0.0, input_axis.y)
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	var grounded: bool = is_on_floor()
	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	elif not grounded:
		velocity.y -= GRAVITY * delta
	_fall_speed = maxf(_fall_speed, -velocity.y)
	var previous: Vector3 = position
	move_and_slide()
	if is_on_floor():
		if _fall_speed > 11.0:
			fell.emit((_fall_speed - 11.0) * 4.0)
		_fall_speed = 0.0
		var distance: float = Vector2(position.x - previous.x, position.z - previous.z).length()
		_step_distance += distance
		_bob_phase += distance * 8.0
		if _step_distance > 1.7:
			_step_distance = fmod(_step_distance, 1.7)
			step_taken.emit()
	if position.y < -16.0:
		enabled = false
		fell.emit(100.0)
	_shake = move_toward(_shake, 0.0, delta * 0.45)
	var walking: float = minf(input_axis.length(), 1.0) if is_on_floor() else 0.0
	camera.position = Vector3(
		sin(_bob_phase * 0.5) * 0.024 * walking,
		EYE_HEIGHT + sin(_bob_phase) * 0.028 * walking,
		0.0
	)
	camera.rotation = Vector3(_pitch + sin(_bob_phase + _shake * 80.0) * _shake, 0.0, _shake)
