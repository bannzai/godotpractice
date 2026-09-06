extends Control
## 奥行きの異なる星空。時間・ポインターに応じて層をずらすため描画は非冪等。

const LAYERS: Array[Texture2D] = [
	preload("res://assets/art/far.svg"),
	preload("res://assets/art/mid.svg"),
	preload("res://assets/art/near.svg"),
]

var elapsed: float = 0.0
var duel: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = preload("res://scripts/astral_glow.gdshader")
	glow.material = shader_material
	add_child(glow)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("07111f"))
	var pointer: Vector2 = (get_local_mouse_position() - size * 0.5) / size
	for index: int in LAYERS.size():
		var depth: float = float(index + 1)
		var offset: Vector2 = Vector2(sin(elapsed * 0.09), cos(elapsed * 0.07))
		offset = (offset * 3.0 + pointer * 7.0) * depth
		var tint := Color(1, 1, 1, 0.5 if duel and index > 0 else 1.0)
		draw_texture_rect(
			LAYERS[index], Rect2(offset - Vector2(24, 24), size + Vector2(48, 48)), false, tint
		)
