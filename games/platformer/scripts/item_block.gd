class_name SupplyBlock
extends StaticBody2D

signal opened(at: Vector2, contents: String)
var contents: String = "power"
var used: bool = false
var sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	collision.shape = shape
	add_child(collision)
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/images/item_block.svg")
	add_child(sprite)


func activate() -> void:
	if used:
		return
	used = true
	sprite.modulate = Color("9ba9ad")
	opened.emit(position + Vector2(0, -44), contents)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position:y", -10.0, 0.08)
	tween.tween_property(sprite, "position:y", 0.0, 0.12)
