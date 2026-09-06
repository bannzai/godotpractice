extends Control
## 背景だけに視差と薄い霧を重ね、文字やカードの明度は変えない。

const ATMOSPHERE := preload("res://assets/shaders/atmosphere.gdshader")
const LAYERS: Array[String] = ["bg_sky", "bg_ruins", "bg_foreground"]

var _layers: Array[TextureRect] = []
var _atmosphere: ShaderMaterial
var _elapsed: float = 0.0
var _pointer: Vector2 = Vector2.ZERO


func setup(phase: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	if _layers.is_empty():
		for filename: String in LAYERS:
			var layer := TextureRect.new()
			layer.texture = load("res://assets/art/%s.svg" % filename)
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_SCALE
			layer.size = Vector2(1344, 756)
			layer.position = Vector2(-32, -18)
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(layer)
			_layers.append(layer)
		_add_atmosphere()
	_atmosphere.set_shader_parameter("mist_tint",
		Color("d9ad92") if phase == "boss" else Color("9bcfc5"))
	_atmosphere.set_shader_parameter("intensity", 0.13 if phase == "title" else 0.085)
	_layers[0].modulate = Color("ecd8d2") if phase == "boss" else Color.WHITE


func _add_atmosphere() -> void:
	var fog := ColorRect.new()
	fog.size = size
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atmosphere = ShaderMaterial.new()
	_atmosphere.shader = ATMOSPHERE
	fog.material = _atmosphere
	add_child(fog)


# 経過時間とポインタの移動による連続演出なので、毎フレーム状態を進める。
func _process(delta: float) -> void:
	if _layers.is_empty():
		return
	_elapsed += delta
	var target: Vector2 = (get_local_mouse_position() - size * 0.5) / (size * 0.5)
	target = target.clamp(Vector2(-1, -1), Vector2.ONE)
	_pointer = _pointer.lerp(target, minf(1.0, delta * 2.5))
	for index: int in range(_layers.size()):
		var depth: float = float(index + 1)
		_layers[index].position = Vector2(-32, -18) + Vector2(
			_pointer.x * depth * 4.0 + sin(_elapsed * 0.16) * depth * 1.2,
			_pointer.y * depth * 1.6 + cos(_elapsed * 0.2) * depth * 0.5)
	_atmosphere.set_shader_parameter("clock", _elapsed)
