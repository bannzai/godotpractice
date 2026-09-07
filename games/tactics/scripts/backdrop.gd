extends Control
## 大和絵に屏風の折り目・和紙・金雲を重ねた遠景。

const UI := preload("res://scripts/ui.gd")
const GOLD_CLOUDS := preload("res://assets/shaders/gold_clouds.gdshader")

var landscape: TextureRect
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	clip_contents = true
	landscape = UI.art_cover(
		self, "generated/yamato-landscape.png", Rect2(-14, -8, 1308, 736)
	)
	var material := ShaderMaterial.new()
	material.shader = GOLD_CLOUDS
	landscape.material = material


# 原画を見失わない範囲で、屏風絵がわずかに息づくように動かす。
func _process(delta: float) -> void:
	elapsed += delta
	landscape.position.x = -14.0 + sin(elapsed * 0.09) * 2.5
	landscape.position.y = -8.0 + cos(elapsed * 0.07) * 1.5
