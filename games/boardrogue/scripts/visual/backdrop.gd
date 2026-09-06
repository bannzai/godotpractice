extends Control
## 三層の視差と霧を、操作画面から独立させて連続描画する。

const ATMOSPHERE := preload("res://assets/shaders/atmosphere.gdshader")
const LAYERS: Array[String] = ["bg_sky", "bg_landscape", "bg_foreground"]

var _layers: Array[TextureRect] = []
var _mist: ShaderMaterial
var _elapsed: float = 0.0
var _pointer: Vector2 = Vector2.ZERO
var _scene_key: String = "title"


func setup(scene_key: String) -> void:
	_scene_key = scene_key
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	if _layers.is_empty():
		for filename: String in LAYERS:
			var layer := TextureRect.new()
			layer.texture = load("res://assets/art/%s.svg" % filename)
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_SCALE
			layer.position = Vector2(-32, -18)
			layer.size = Vector2(1344, 756)
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(layer)
			_layers.append(layer)
		var fog := ColorRect.new()
		fog.size = size
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mist = ShaderMaterial.new()
		_mist.shader = ATMOSPHERE
		fog.material = _mist
		add_child(fog)
	var is_boss: bool = scene_key in ["boss", "general", "final"]
	_layers[0].modulate = Color("d8a997") if is_boss else Color.WHITE
	_mist.set_shader_parameter("tint", Color("c19279") if is_boss else Color("c7d1b9"))
	_mist.set_shader_parameter("strength", 0.10 if scene_key == "map" else 0.065)


# 視差は時刻とカーソル位置によって変わる継続演出なので毎フレーム進行する。
func _process(delta: float) -> void:
	if _layers.is_empty():
		return
	_elapsed += delta
	var target: Vector2 = (get_local_mouse_position() - size * 0.5) / (size * 0.5)
	_pointer = _pointer.lerp(target.clamp(Vector2(-1, -1), Vector2.ONE), minf(1.0, delta * 2.4))
	for index: int in range(_layers.size()):
		var depth: float = float(index + 1)
		var scroll: float = sin(_elapsed * 0.08) * 3.0 if _scene_key == "map" else 0.0
		_layers[index].position = Vector2(-32, -18) + Vector2(
			_pointer.x * depth * 4.0 + sin(_elapsed * 0.14) * depth + scroll * depth,
			_pointer.y * depth * 1.8 + cos(_elapsed * 0.18) * depth * 0.7)
	_mist.set_shader_parameter("clock", _elapsed)
