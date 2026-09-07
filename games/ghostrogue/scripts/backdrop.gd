extends Node2D
## CC0 写真へポスタリゼーションと網点を重ねる背景専用 Canvas。

const SOURCES: Dictionary = {
	"town": "res://assets/external/streets/street-01.webp",
	"graveyard": "res://assets/external/streets/graveyard-01.webp",
	"river": "res://assets/external/streets/river-01.webp",
	"house": "res://assets/external/streets/house-01.webp",
}

var scene_name: String = ""
var darkness: int = 0
var elapsed: float = 0.0
var district: int = 0
var background: TextureRect
var rust: TextureRect
var fog: Sprite2D
var flashlight: PointLight2D
var tint: CanvasModulate
var shader_material: ShaderMaterial
var focus_target: Vector2 = Vector2(905, 390)
var focus_locked: bool = false


func setup(scene: String) -> void:
	if not is_instance_valid(background):
		_create_layers()
	if scene_name == scene:
		return
	scene_name = scene
	_apply_source()
	set_darkness(darkness)


func set_district(value: int) -> void:
	district = clampi(value, 0, 11)
	if scene_name == "map":
		_apply_source()


func aim_at(point: Vector2, locked: bool = true) -> void:
	focus_target = point
	focus_locked = locked


func _create_layers() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = -20
	add_child(canvas)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/gekiga.gdshader")
	background.material = shader_material
	canvas.add_child(background)
	rust = TextureRect.new()
	rust.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rust.texture = load("res://assets/external/textures/rust.webp")
	rust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rust.stretch_mode = TextureRect.STRETCH_TILE
	rust.modulate = Color("21000036")
	rust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(rust)
	fog = Sprite2D.new()
	fog.centered = false
	fog.texture = load("res://assets/art/fog.svg")
	fog.position = Vector2(-16, -10)
	fog.scale = Vector2(1.03, 1.03)
	canvas.add_child(fog)
	tint = CanvasModulate.new()
	canvas.add_child(tint)
	flashlight = PointLight2D.new()
	flashlight.texture = load("res://assets/art/flashlight.svg")
	flashlight.color = Color("ffe18d")
	flashlight.texture_scale = 2.5
	flashlight.energy = 0.9
	canvas.add_child(flashlight)


func _apply_source() -> void:
	if not is_instance_valid(background):
		return
	var setting: String = "town"
	if scene_name == "map":
		setting = ["town", "river", "house", "graveyard"][district % 4]
	elif scene_name in ["grave", "graveyard", "rest"]:
		setting = "graveyard"
	elif scene_name in ["living", "boss", "house"]:
		setting = "house"
	elif scene_name == "story":
		setting = "river"
	background.texture = load(SOURCES[setting])


func set_darkness(value: int) -> void:
	darkness = clampi(value, 0, 100)
	if not is_instance_valid(tint):
		return
	var amount: float = float(darkness) / 100.0
	tint.color = Color.WHITE.lerp(Color("a83838"), amount * 0.46)
	flashlight.color = Color("ffe18d").lerp(Color("ff3b2d"), amount * 0.68)
	shader_material.set_shader_parameter("darkness", amount)


func _process(delta: float) -> void:
	if not is_instance_valid(background):
		return
	elapsed += delta
	background.position.x = sin(elapsed * 0.12) * 4.0
	background.size.x = 1288.0
	rust.position.x = sin(elapsed * 0.19) * 10.0
	fog.position.x = -16.0 + sin(elapsed * 0.21) * 14.0
	fog.modulate.a = 0.28 + sin(elapsed * 0.42) * 0.10
	if not focus_locked:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		if mouse.length() > 10.0:
			focus_target = mouse
	flashlight.position = flashlight.position.lerp(focus_target, 1.0 - exp(-delta * 3.2))
	flashlight.energy = 0.88 + sin(elapsed * 7.7) * 0.10
