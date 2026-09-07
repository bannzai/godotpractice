class_name ForestBackdrop
extends Node2D
## 背景だけに時間を与え、UI や戦闘状態へ影響を及ぼさない森。

const LAYERS: Array[String] = ["forest_far", "forest_mid", "forest_near"]

var _layers: Array[Sprite2D] = []
var _pollen: CPUParticles2D
var _elapsed := 0.0


func setup(_boss: bool = false, height: float = 720.0) -> void:
	if _layers.is_empty():
		for layer_name: String in LAYERS:
			var layer := Sprite2D.new()
			layer.texture = load("res://assets/pixel/backgrounds/%s.png" % layer_name) as Texture2D
			layer.centered = false
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(layer)
			_layers.append(layer)
		_add_pollen()
	for layer: Sprite2D in _layers:
		layer.scale = Vector2.ONE * 4.0
	_pollen.position = Vector2(640, height / 2.0)
	_pollen.emission_rect_extents = Vector2(640, height * 0.46)
	_update_layers()


func _process(delta: float) -> void:
	# 経過時間による背景の揺れは連続した運動のため冪等ではない。
	_elapsed += delta
	_update_layers()


func _update_layers() -> void:
	for index in range(_layers.size()):
		var sway := roundf(sin(_elapsed * 0.13 + index * 0.7) * (index + 1) * 4.0)
		_layers[index].position = Vector2(-18.0 + sway, 0)


func _add_pollen() -> void:
	_pollen = CPUParticles2D.new()
	_pollen.amount = 22
	_pollen.lifetime = 9.0
	_pollen.preprocess = 9.0
	_pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_pollen.direction = Vector2(-0.35, -1.0)
	_pollen.spread = 26.0
	_pollen.gravity = Vector2.ZERO
	_pollen.initial_velocity_min = 4.0
	_pollen.initial_velocity_max = 10.0
	_pollen.scale_amount_min = 1.0
	_pollen.scale_amount_max = 1.0
	_pollen.color = Color("9bbc0f")
	_pollen.texture = load("res://assets/pixel/world/pollen.png") as Texture2D
	_pollen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_pollen)
