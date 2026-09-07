extends Node2D
## 遠景・丘・前景の速度差で、静かな風を表現する。

var layers: Array[Sprite2D] = []
var elapsed: float = 0.0


func _ready() -> void:
	for id: String in ["far", "mid", "near"]:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/backgrounds/%s.png" % id)
		sprite.centered = false
		sprite.scale = Vector2(1320, 720) / sprite.texture.get_size()
		add_child(sprite)
		layers.append(sprite)


## 視差の時間積分のため非冪等。
func _process(delta: float) -> void:
	elapsed += delta
	for index: int in layers.size():
		layers[index].position.x = -20 + sin(elapsed * 0.14) * (index + 1) * 5
