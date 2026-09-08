extends Control
## 背景と漂う霧は画面部品の更新から独立して寿命を持つ。

const INK_VEIL = preload("res://scripts/ink_veil.gdshader")

var layers: Array[TextureRect] = []
var elapsed: float = 0.0
var travel: float = 0.0
var shade: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: ColorRect = ColorRect.new()
	base.color = Color("192c32")
	base.size = Vector2(1280, 720)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	for id: String in ["bg_sky", "bg_village", "bg_foreground"]:
		var layer: TextureRect = SpiritUI.art(self, id, Rect2(-20, -10, 1320, 740))
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layers.append(layer)
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.09, 0.24)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var veil: ColorRect = ColorRect.new()
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink: ShaderMaterial = ShaderMaterial.new()
	ink.shader = INK_VEIL
	veil.material = ink
	add_child(veil)


# 経過時間に従う視差と霧の周期運動なので非冪等。
func _process(delta: float) -> void:
	elapsed += delta
	for index: int in layers.size():
		layers[index].position.x = -20 + sin(elapsed * 0.11) * (index + 1) * 4 + travel
	queue_redraw()


func _draw() -> void:
	for index: int in 24:
		var x: float = fposmod(index * 131.0 + elapsed * (4 + index % 3), 1400) - 60
		var y: float = 160 + fposmod(index * 93.0, 520) + sin(elapsed + index) * 12
		var opacity: float = 0.13 + 0.13 * sin(elapsed * 1.2 + index)
		draw_circle(Vector2(x, y), 2.0 + index % 3, Color(0.63, 0.86, 0.77, opacity))
	for index: int in 5:
		var offset: float = sin(elapsed * 0.13 + index) * 70
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(-100, 560 + index * 31),
					Vector2(400 + offset, 520 + index * 35),
					Vector2(1400, 555 + index * 31),
					Vector2(1400, 591 + index * 31),
					Vector2(400 + offset, 553 + index * 35),
					Vector2(-100, 592 + index * 31)
				]
			),
			Color(0.6, 0.75, 0.71, 0.025)
		)


func set_scene(screen: String) -> void:
	shade.color.a = 0.06 if screen == "title" else 0.32


# 新しい道への移動を見せる一回のスクロール演出。
func scroll_map() -> void:
	travel = 26.0
	create_tween().tween_property(self, "travel", 0.0, 0.85).set_trans(Tween.TRANS_CUBIC)
