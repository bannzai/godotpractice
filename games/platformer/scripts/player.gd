class_name Courier
extends CharacterBody2D
## 物理更新・跳躍・演出はフレームを消費するため非冪等。

signal sound_requested(sound: String)
signal landed(at: Vector2)
const WALK_SPEED: float = 255.0
const RUN_SPEED: float = 400.0
const JUMP_SPEED: float = -740.0
const GRAVITY: float = 1700.0
var sprite: AnimatedSprite2D
var sprite_normalization: Vector2 = Vector2.ONE
var body_shape: CollisionShape2D
var previous_feet: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var anim_time: float = 0.0
var transform_time: float = 0.0
var hurt_time: float = 0.0
var stomp_time: float = 0.0
var hit_stop: float = 0.0
var dead: bool = false
var squash: Vector2 = Vector2.ONE
var squash_tween: Tween
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
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ActorFrames.build("player")
	sprite_normalization = ActorFrames.normalized_scale("player", sprite.sprite_frames)
	sprite.offset.y = -36 / sprite_normalization.y
	sprite.material = ActorFrames.build_comic_material()
	add_child(sprite)
	sprite.play("idle")
	_update_visual()


func _physics_process(delta: float) -> void:
	if session.phase != "playing":
		sprite.speed_scale = 0.0 if session.phase == "paused" else 1.0
		return
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
		sprite.speed_scale = 0.0
		return
	sprite.speed_scale = 1.0
	anim_time += delta
	transform_time = maxf(0.0, transform_time - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	stomp_time = maxf(0.0, stomp_time - delta)
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
		_squash(Vector2(0.82, 1.16))
		sound_requested.emit("jump")
	if Input.is_action_just_released("jump") and velocity.y < -260:
		velocity.y = -260
	var was_grounded: bool = is_on_floor()
	var fall_speed: float = velocity.y
	velocity.y = minf(velocity.y + GRAVITY * delta, 1000)
	move_and_slide()
	position.x = maxf(18, position.x)
	if not was_grounded and is_on_floor() and fall_speed > 180:
		_squash(Vector2(1.19, 0.83))
		landed.emit(position)
	for index: int in get_slide_collision_count():
		var hit: KinematicCollision2D = get_slide_collision(index)
		if hit.get_normal().y > 0.5 and hit.get_collider().has_method("activate"):
			hit.get_collider().activate()
	_update_visual()


func _update_visual() -> void:
	var height: float = 64.0 if session.powered else 42.0
	(body_shape.shape as RectangleShape2D).size.y = height
	body_shape.position.y = -height / 2.0
	var growth: float = 1.0 + 0.10 * sin(transform_time * 28) if transform_time > 0 else 1.0
	sprite.scale = (
		Vector2(0.90 if session.powered else 0.72, height / 62.0)
		* sprite_normalization
		* growth
		* squash
	)
	if absf(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0
	sprite.modulate.a = 0.42 if session.invulnerable > 0 and sin(anim_time * 28) < 0 else 1.0
	var state: String = "idle"
	if dead:
		state = "death"
	elif hurt_time > 0.0:
		state = "hurt"
	elif stomp_time > 0.0:
		state = "stomp"
	elif not is_on_floor():
		state = "jump" if velocity.y < -40 else "fall"
	elif absf(velocity.x) > 20:
		state = "run"
	sprite.play(state)
	if state == "run":
		sprite.speed_scale = 1.1 if absf(velocity.x) > WALK_SPEED else 0.85


func transform() -> void:
	transform_time = 0.8
	_squash(Vector2(0.88, 1.15))
	_update_visual()


func hurt() -> void:
	hurt_time = 0.43
	transform()


func bounce() -> void:
	velocity.y = -490
	stomp_time = 0.34
	_squash(Vector2(1.15, 0.87))
	sound_requested.emit("stomp")
	_update_visual()


func freeze(duration: float) -> void:
	hit_stop = maxf(hit_stop, duration)


func die() -> void:
	if dead:
		return
	dead = true
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1.0
	sprite.play("death")
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position:y", -26.0, 0.24).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "position:y", 12.0, 0.32).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(sprite, "modulate:a", 0.30, 0.32)


func _squash(value: Vector2) -> void:
	if is_instance_valid(squash_tween):
		squash_tween.kill()
	squash = value
	squash_tween = create_tween()
	squash_tween.tween_property(self, "squash", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD)
