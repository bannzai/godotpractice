class_name FighterProjectile
extends Area2D
## 飛び道具の移動・命中は時間と入力を消費するため非冪等。1発につき命中は1回。

var target: Node2D
var source: Node2D
var direction: float = 1.0
var tint: Color = Color("55e5e0")
var move_data: Dictionary = {}
var age: float = 0.0
var spent: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	collision_layer = 4
	collision_mask = 1
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 25.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.enabled:
		return
	age += delta
	position.x += direction * 490.0 * delta
	if position.x < 30.0 or position.x > 1250.0 or age > 3.0:
		queue_free()
		return
	if not spent and is_instance_valid(target):
		for area: Area2D in get_overlapping_areas():
			if area.get_parent() == target:
				spent = true
				target.receive_hit(move_data, global_position)
				queue_free()
				break
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 33.0, Color(tint, 0.12))
	draw_circle(Vector2.ZERO, 24.0, Color(tint, 0.32))
	draw_circle(Vector2.ZERO, 14.0, tint)
	draw_circle(Vector2(direction * 6.0, -2.0), 8.0, Color("f0fffc"))
	for i: int in range(3):
		var offset: float = float(i) * 9.0
		draw_line(Vector2(-direction * (20.0 + offset), -10.0 + offset),
			Vector2(-direction * (60.0 + offset), -10.0 + offset), Color(tint, 0.6), 3.0)
	draw_arc(Vector2.ZERO, 28.0, age * 9.0, age * 9.0 + 4.2, 20, tint, 2.0)
