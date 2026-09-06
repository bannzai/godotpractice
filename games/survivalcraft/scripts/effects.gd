extends Node3D
## 破片と獲得表示は短命ノード、たいまつは座標で一意に管理する。

var _torches: Dictionary[Vector3i, Node3D] = {}


func burst(point: Vector3, color: Color) -> void:
	# 破壊・被弾イベントごとに独立した破片を出すため非冪等。
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = 15
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 100.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 3.8
	particles.gravity = Vector3(0.0, -9.0, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE * 0.12
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	cube.material = material
	particles.mesh = cube
	particles.position = point
	add_child(particles)
	particles.emitting = true
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(particles.queue_free)


func floating_text(point: Vector3, text: String, color: Color) -> void:
	# 獲得イベントをそれぞれ表示するため、呼び出しごとに追加する非冪等な演出。
	var label: Label3D = Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 44
	label.outline_size = 10
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = point
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", point.y + 1.3, 0.9).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)


func torch(point: Vector3) -> void:
	var key: Vector3i = Vector3i(point.floor())
	if _torches.has(key):
		return
	var holder: Node3D = Node3D.new()
	holder.position = point
	add_child(holder)
	_torches[key] = holder
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("ffc16d")
	light.light_energy = 1.4
	light.omni_range = 7.0
	light.position.y = 0.7
	holder.add_child(light)
	var flame: MeshInstance3D = MeshInstance3D.new()
	var prism: PrismMesh = PrismMesh.new()
	prism.size = Vector3(0.22, 0.42, 0.22)
	flame.mesh = prism
	flame.position.y = 0.7
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ffe5a0")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = material
	holder.add_child(flame)
	var tween: Tween = holder.create_tween().set_loops()
	tween.tween_property(flame, "scale", Vector3(0.8, 1.2, 0.8), 0.16)
	tween.tween_property(flame, "scale", Vector3.ONE, 0.21)


func clear_torches() -> void:
	for holder: Node3D in _torches.values():
		holder.queue_free()
	_torches.clear()
