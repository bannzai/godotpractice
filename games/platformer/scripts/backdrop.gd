class_name RouteBackdrop
extends Node2D
## カメラの位置から視差を再計算し、繰り返し描画しても同じ構図を保つ。

const CLOUD: Texture2D = preload("res://assets/images/cloud.svg")
var stage: int = 0
var camera_x: float = 0.0
var sky: ColorRect
var far_layers: Array[Texture2D] = []
var near_layers: Array[Texture2D] = []
var age: float = 0.0


func _ready() -> void:
	for file: String in ["landscape_far", "cave_far"]:
		far_layers.append(load("res://assets/images/%s.svg" % file))
	for file: String in ["landscape_near", "cave_near"]:
		near_layers.append(load("res://assets/images/%s.svg" % file))
	sky = ColorRect.new()
	sky.size = Vector2(1280, 720)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.show_behind_parent = true
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = load("res://resources/sky.gdshader")
	sky.material = sky_material
	add_child(sky)


func _process(delta: float) -> void:
	# 雲と光の漂いは経過時間を消費するため非冪等。
	age += delta
	(sky.material as ShaderMaterial).set_shader_parameter("cave", stage == 1)
	queue_redraw()


func _draw() -> void:
	if far_layers.is_empty():
		return
	_draw_layer(far_layers[stage], 0.10)
	if stage == 0:
		for index: int in 6:
			var x: float = fposmod(index * 317 - camera_x * 0.16 + age * 3, 1660) - 190
			draw_texture_rect(CLOUD, Rect2(x, 135 + index % 3 * 51, 170, 65), false,
				Color(1, 1, 1, 0.65))
	_draw_layer(near_layers[stage], 0.28)
	for index: int in 34:
		var x: float = fposmod(index * 193.0 - camera_x * 0.42 + age * 11, 1320) - 20
		var y: float = 310 + fposmod(index * 71.0 + sin(age + index) * 14, 290)
		var glow: Color = Color("ffe9ac") if stage == 0 else Color("80eeed")
		glow.a = 0.18 + 0.22 * (sin(age * 1.4 + index) + 1) / 2
		draw_circle(Vector2(x, y), 1.7 if stage == 0 else 2.4, glow)


func _draw_layer(texture: Texture2D, speed: float) -> void:
	var x: float = -fposmod(camera_x * speed, 1600)
	draw_texture_rect(texture, Rect2(x, 0, 1600, 720), false)
	draw_texture_rect(texture, Rect2(x + 1600, 0, 1600, 720), false)
