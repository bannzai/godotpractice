class_name RouteBackdrop
extends Node2D

const CLOUD: Texture2D = preload("res://assets/images/cloud.svg")
const CRYSTAL: Texture2D = preload("res://assets/images/crystal.svg")
var stage: int = 0
var camera_x: float = 0.0


func _draw() -> void:
	var cave: bool = stage == 1
	draw_rect(Rect2(0, 0, 1280, 720), Color("142f4f") if cave else Color("bce5df"))
	var offset: float = camera_x
	if cave:
		for i: int in 22:
			var x: float = fposmod(i * 139 - offset * 0.18, 1450) - 80
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, 0), Vector2(x + 65, 170 + (i % 4) * 32), Vector2(x + 120, 0)]),
				Color("203b60"))
			draw_texture_rect(CRYSTAL, Rect2(x, 450 + (i % 3) * 25, 80, 120), false,
				Color(0.4, 0.8, 1, 0.55))
	else:
		draw_circle(Vector2(1080, 158), 76, Color("fff4c5"))
		for i: int in 8:
			var x: float = fposmod(i * 340 - offset * 0.15, 1700) - 200
			draw_circle(Vector2(x, 720), 290, Color("8dc6b0"))
			draw_circle(Vector2(x + 180, 750), 260, Color("5eaa95"))
			draw_texture_rect(CLOUD, Rect2(x, 130 + i % 3 * 48, 192, 80), false)

