class_name FighterProjectile
extends Area2D
## 飛び道具の移動・命中は時間と入力を消費するため非冪等。1発につき命中は1回。

const WAVES: Array[Texture2D] = [
	preload("res://assets/effects/wave-teal.svg"), preload("res://assets/effects/wave-amber.svg")
]

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
	var texture: Texture2D = WAVES[0]
	if is_instance_valid(source) and source.character_index == 1:
		texture = WAVES[1]
	var pulse: float = 1.0 + sin(age * 23.0) * 0.07
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(direction, pulse))
	draw_texture_rect(texture, Rect2(-66, -40, 132, 80), false)
	draw_set_transform(Vector2.ZERO)
