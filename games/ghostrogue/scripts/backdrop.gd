extends Node2D
## 背景専用の Canvas に光を置き、文字のコントラストを保つ。

var scene_name: String = ""
var darkness: int = 0
var elapsed: float = 0.0
var far_layer: Sprite2D
var near_layer: Sprite2D
var fog: Sprite2D
var flashlight: PointLight2D
var tint: CanvasModulate


func setup(scene: String) -> void:
	if not is_instance_valid(far_layer):
		var canvas := CanvasLayer.new()
		canvas.layer = -20
		add_child(canvas)
		_make_layer(canvas, "night_sky")
		far_layer = _make_layer(canvas, "town_far")
		near_layer = _make_layer(canvas, "town_near")
		fog = _make_layer(canvas, "fog")
		tint = CanvasModulate.new()
		canvas.add_child(tint)
		flashlight = PointLight2D.new()
		flashlight.texture = load("res://assets/art/flashlight.svg")
		flashlight.color = Color(0.93, 0.91, 0.74)
		flashlight.texture_scale = 1.9
		flashlight.energy = 0.65
		canvas.add_child(flashlight)
	if scene_name == scene:
		return
	scene_name = scene
	var setting: String = "town"
	if scene in ["grave", "graveyard", "rest"]:
		setting = "graveyard"
	elif scene in ["living", "story", "boss", "house"]:
		setting = "house"
	far_layer.texture = load("res://assets/art/%s_far.svg" % setting)
	near_layer.texture = load("res://assets/art/%s_near.svg" % setting)
	set_darkness(darkness)


func _make_layer(parent: Node, image: String) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.centered = false
	layer.texture = load("res://assets/art/%s.svg" % image)
	layer.position = Vector2(-16, -10)
	layer.scale = Vector2(1.03, 1.03)
	parent.add_child(layer)
	return layer


func set_darkness(value: int) -> void:
	darkness = clampi(value, 0, 100)
	if not is_instance_valid(tint):
		return
	var amount: float = float(darkness) / 100.0
	tint.color = Color(0.91, 0.96, 0.99).lerp(Color(0.92, 0.54, 0.56), amount * 0.65)
	flashlight.color = Color(0.93, 0.91, 0.74).lerp(Color(1.0, 0.58, 0.4), amount * 0.5)


# 視差と光の揺れは経過時間によって進む演出なので、フレームごとに変化する。
func _process(delta: float) -> void:
	if not is_instance_valid(far_layer):
		return
	elapsed += delta
	far_layer.position.x = -16.0 + sin(elapsed * 0.13) * 5.0
	near_layer.position.x = -16.0 + sin(elapsed * 0.13) * 11.0
	fog.position.x = -16.0 + sin(elapsed * 0.21) * 14.0
	fog.modulate.a = 0.64 + sin(elapsed * 0.42) * 0.18
	var target: Vector2 = get_viewport().get_mouse_position()
	if target.length() < 10.0:
		target = Vector2(905, 390)
	flashlight.position = flashlight.position.lerp(target, 1.0 - exp(-delta * 1.4))
	flashlight.energy = 0.65 + sin(elapsed * 2.1) * 0.055
