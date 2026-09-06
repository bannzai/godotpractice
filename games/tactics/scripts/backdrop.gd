extends Control
## 空・山稜・手前の草を独立して動かす遠景。

const UI := preload("res://scripts/ui.gd")
var layers: Array[TextureRect] = []
var elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.panel(self, Rect2(0, 0, 1280, 720), Color("172d3d"), Color.TRANSPARENT)
	for layer: String in ["sky", "mountains", "foreground"]:
		layers.append(UI.art(self, "backgrounds/%s.svg" % layer, Rect2(-24, -16, 1328, 752)))


# 雲と草の連続的な時間変化を表す。
func _process(delta: float) -> void:
	elapsed += delta
	for index: int in layers.size():
		var depth: float = float(index + 1)
		layers[index].position.x = -24 + sin(elapsed * 0.12) * depth * 5
		layers[index].position.y = -16 + cos(elapsed * 0.17) * depth * 2
