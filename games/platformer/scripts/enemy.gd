class_name TrailEnemy
extends CharacterBody2D
## 敵の物理移動と踏まれた時の遷移はゲームイベントごとに進むため非冪等。

var kind: String = "walker"
var mode: String = "walking"
var direction: float = -1.0
var sprite: Sprite2D
var age: float = 0.0
var kick_grace: float = 0.0
var session: Node


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
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/images/%s.svg" % kind)
	sprite.offset.y = -16
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if session.phase != "playing" or mode == "dead":
		return
	age += delta
	kick_grace = maxf(0.0, kick_grace - delta)
	velocity.y = minf(velocity.y + 1700 * delta, 1000)
	velocity.x = direction * (370 if mode == "sliding" else 65)
	if mode == "resting":
		velocity.x = 0
	move_and_slide()
	if is_on_wall():
		direction *= -1
	if position.y > 850:
		queue_free()
	sprite.flip_h = direction > 0
	sprite.rotation = sin(age * 13) * 0.08 if mode == "walking" else 0.0


func stomp(from_x: float) -> void:
	if mode == "dead":
		return
	if kind == "walker":
		defeat()
	elif mode == "walking" or mode == "sliding":
		mode = "resting"
		sprite.scale.y = 0.55
	else:
		mode = "sliding"
		kick_grace = 0.25
		direction = 1.0 if position.x > from_x else -1.0


func defeat() -> void:
	if mode == "dead":
		return
	mode = "dead"
	collision_layer = 0
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.18), 0.13)
	tween.tween_interval(0.28)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
