class_name TrailEnemy
extends CharacterBody2D
## 敵の物理移動と踏まれた時の遷移はゲームイベントごとに進むため非冪等。

var kind: String = "walker"
var mode: String = "walking"
var direction: float = -1.0
var sprite: AnimatedSprite2D
var sprite_normalization: Vector2 = Vector2.ONE
var age: float = 0.0
var kick_grace: float = 0.0
var hurt_time: float = 0.0
var hit_stop: float = 0.0
var session: Node
var target: Courier


func _ready() -> void:
	session = get_node("/root/Session")
	collision_layer = 4
	collision_mask = 1
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(34, 28)
	collision.shape = shape
	collision.position.y = -14
	add_child(collision)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ActorFrames.build(kind)
	sprite_normalization = ActorFrames.normalized_scale(kind, sprite.sprite_frames)
	sprite.offset.y = -24 / sprite_normalization.y
	sprite.scale = Vector2(0.83, 0.83) * sprite_normalization
	sprite.material = ActorFrames.build_comic_material()
	add_child(sprite)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if session.phase != "playing" or mode == "dead":
		sprite.speed_scale = 0.0 if session.phase == "paused" else 1.0
		return
	if hit_stop > 0.0:
		hit_stop = maxf(0.0, hit_stop - delta)
		sprite.speed_scale = 0.0
		return
	sprite.speed_scale = 1.0
	age += delta
	kick_grace = maxf(0.0, kick_grace - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	velocity.y = minf(velocity.y + 1700 * delta, 1000)
	velocity.x = direction * (470 if mode == "sliding" else 65)
	if mode == "resting":
		velocity.x = 0
	move_and_slide()
	if is_on_wall():
		direction *= -1
	if position.y > 850:
		queue_free()
	_update_visual()


func _update_visual() -> void:
	sprite.flip_h = direction < 0
	var state: String = "walk"
	if hurt_time > 0.0:
		state = "hurt"
	elif mode == "resting" or age < 0.25:
		state = "idle"
	elif mode == "sliding":
		state = "attack"
	elif is_instance_valid(target):
		var distance: Vector2 = target.position - position
		if absf(distance.x) < 115 and absf(distance.y) < 65:
			state = "attack"
	sprite.play(state)
	sprite.scale = (
		Vector2(0.83, 0.52 if mode in ["resting", "sliding"] else 0.83)
		* sprite_normalization
	)
	if mode == "sliding":
		sprite.speed_scale = 1.8


func stomp(from_x: float) -> void:
	if mode == "dead":
		return
	if kind == "walker":
		defeat()
	elif mode == "walking" or mode == "sliding":
		mode = "resting"
		hurt_time = 0.36
		_update_visual()
	else:
		mode = "sliding"
		hurt_time = 0.0
		kick_grace = 0.25
		direction = 1.0 if position.x > from_x else -1.0
		_update_visual()


func freeze(duration: float) -> void:
	hit_stop = maxf(hit_stop, duration)


func defeat() -> void:
	if mode == "dead":
		return
	mode = "dead"
	collision_layer = 0
	sprite.speed_scale = 1.0
	sprite.play("hurt")
	var tween: Tween = create_tween()
	tween.tween_interval(0.16)
	tween.tween_callback(func() -> void: sprite.play("death"))
	tween.tween_property(sprite, "position:y", -14.0, 0.18).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "position:y", 4.0, 0.25).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.20)
	tween.tween_callback(queue_free)
