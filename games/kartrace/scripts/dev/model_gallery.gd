extends SceneTree
## 各モデルの形状と全部位アニメーションを同じ照明で撮影する。

const MODEL: Script = preload("res://scripts/kart_visual.gd")
var _world: Node3D
var _models: Array[Node3D] = []


func _initialize() -> void:
	call_deferred("_capture")


# 描画フレームを進めて PNG を出力する開発用エントリーポイント。
func _capture() -> void:
	root.size = Vector2i(1280, 720)
	_world = Node3D.new()
	root.add_child(_world)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("132637")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c1d9ef")
	environment.environment.ambient_light_energy = 0.8
	_world.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.5
	_world.add_child(light)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0, 5.2, -9.8)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	_world.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.current = true
	for kind: int in range(3):
		var model: Node3D = MODEL.new()
		_world.add_child(model)
		model.setup(kind)
		model.position.x = float(kind - 1) * 3.2
		model.rotation.y = -0.3
		_models.append(model)
	DirAccess.make_dir_recursive_absolute("res://tmp")
	for state: String in ["idle", "drive", "drift", "boost", "hit", "celebrate"]:
		for frame: int in range(3):
			for model: Node3D in _models:
				model.animation_player.play(state, 0.0)
				model.animation_player.seek(float(frame) * 0.22, true)
				model.animation_player.pause()
				model.sparks.emitting = state == "drift"
				model.boost_trail.emitting = state == "boost"
				model.exhaust.emitting = state == "drive"
			await create_timer(0.12).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				"res://tmp/model-%s-%d.png" % [state, frame])
	_world.queue_free()
	await process_frame
	print("model gallery OK")
	quit()
