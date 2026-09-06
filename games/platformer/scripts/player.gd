class_name Courier
extends CharacterBody2D
## 物理更新・跳躍・演出はフレームを消費するため非冪等。

signal sound_requested(sound: String)
const WALK_SPEED: float = 255.0
const RUN_SPEED: float = 400.0
const JUMP_SPEED: float = -740.0
const GRAVITY: float = 1700.0
var sprite: Sprite2D
var body_shape: CollisionShape2D
var previous_feet: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var anim_time: float = 0.0
var transform_time: float = 0.0
var session: Node


func _ready() -> void:
	session = get_node("/root/Session")
	collision_layer = 2
	collision_mask = 1
	body_shape = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(26, 42)
	body_shape.shape = shape
	body_shape.position.y = -21
	add_child(body_shape)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/images/player.svg")
	sprite.offset.y = -24
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if session.phase != "playing":
		return
	anim_time += delta
	transform_time = maxf(0.0, transform_time - delta)
	previous_feet = position.y
	var direction: float = Input.get_axis("move_left", "move_right")
	var speed: float = RUN_SPEED if Input.is_action_pressed("dash") else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction * speed, (1550 if direction else 1900) * delta)
	coyote = 0.10 if is_on_floor() else maxf(0.0, coyote - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_SPEED
		coyote = 0.0
		jump_buffer = 0.0
		sound_requested.emit("jump")
	if Input.is_action_just_released("jump") and velocity.y < -260:
		velocity.y = -260
	velocity.y = minf(velocity.y + GRAVITY * delta, 1000)
	move_and_slide()
	position.x = maxf(18, position.x)
	for index: int in get_slide_collision_count():
		var hit: KinematicCollision2D = get_slide_collision(index)
		if hit.get_normal().y > 0.5 and hit.get_collider().has_method("activate"):
			hit.get_collider().activate()
	_update_visual()


func _update_visual() -> void:
	var height: float = 64.0 if session.powered else 42.0
	(body_shape.shape as RectangleShape2D).size.y = height
	body_shape.position.y = -height / 2.0
	var growth: float = 1.0 + 0.35 * sin(transform_time * 28) if transform_time > 0 else 1.0
	sprite.scale = Vector2(1.25 if session.powered else 1.0, height / 42.0) * growth
	if absf(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0
	sprite.rotation = sin(anim_time * 19) * 0.07 if is_on_floor() and absf(velocity.x) > 20 else 0.0
	sprite.modulate.a = 0.4 if session.invulnerable > 0 and sin(anim_time * 28) < 0 else 1.0


func transform() -> void:
	transform_time = 0.8
	_update_visual()


func bounce() -> void:
	velocity.y = -490
	sound_requested.emit("stomp")
