extends Control
## 三層の視差と霧を、操作画面から独立させて連続描画する。

const ATMOSPHERE := preload("res://assets/shaders/atmosphere.gdshader")
const LAYERS: Array[String] = ["bg_sky", "bg_landscape", "bg_foreground"]

var _layers: Array[TextureRect] = []
var _painted: TextureRect
var _mist: ShaderMaterial
var _canvas_tint: CanvasModulate
var _light: PointLight2D
var _elapsed: float = 0.0
var _pointer: Vector2 = Vector2.ZERO
var _scene_key: String = "title"


func setup(scene_key: String) -> void:
	_scene_key = scene_key
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	if _layers.is_empty():
		_painted = TextureRect.new()
		_painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_painted.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_painted.position = Vector2(-20, -12)
		_painted.size = Vector2(1320, 744)
		_painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_painted)
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
		_canvas_tint = CanvasModulate.new()
		add_child(_canvas_tint)
		_light = PointLight2D.new()
		_light.position = Vector2(640, 330)
		_light.texture = _light_texture()
		_light.texture_scale = 1.55
		add_child(_light)
		var fog := ColorRect.new()
		fog.size = size
		fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mist = ShaderMaterial.new()
		_mist.shader = ATMOSPHERE
		fog.material = _mist
		add_child(fog)
	var art_key: String = _art_key(scene_key)
	_painted.texture = load("res://assets/art/generated/%s.png" % art_key)
	var is_boss: bool = scene_key in ["battle-night-camp", "battle-castle"]
	for layer: TextureRect in _layers:
		layer.modulate = Color(1.0, 0.92, 0.78, 0.13 if scene_key == "map" else 0.05)
	_canvas_tint.color = Color("e5c7aa") if is_boss else Color("f6ead1")
	var lit_stages: Array[String] = ["battle-river", "battle-night-camp", "battle-castle"]
	_light.energy = 0.62 if scene_key in lit_stages else 0.28
	_light.color = Color("e8a34c") if scene_key == "battle-night-camp" else Color("ffe2a4")
	_mist.set_shader_parameter("tint", Color("3e2b22") if is_boss else Color("765b42"))
	_mist.set_shader_parameter("strength", 0.14 if scene_key == "map" else 0.095)


func _art_key(scene_key: String) -> String:
	match scene_key:
		"map", "reward", "shop":
			return "campaign-map"
		"battle-river":
			return "stage-river"
		"battle-snow":
			return "stage-snow"
		"battle-night-camp", "rest":
			return "stage-night-camp"
		"battle-castle":
			return "stage-castle"
		_:
			return "title-key-art"


func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 0.83, 0.55, 0.75), Color(1, 0.74, 0.36, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


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
	if is_instance_valid(_painted):
		var map_scroll: float = sin(_elapsed * 0.06) * 7.0 if _scene_key == "map" else 0.0
		_painted.position = Vector2(-20 + map_scroll + _pointer.x * 2.0, -12 + _pointer.y)
	_mist.set_shader_parameter("clock", _elapsed)
