extends Node3D
## 演出はイベントごとに生成し、寿命の終了またはラウンドのリセットで解放する。


func burst(point: Vector3, diameter: float, kind: String) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = "Burst"
	particles.emitting = false
	particles.amount = 32 if kind in ["growth", "win"] else 12
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 1.2 if kind == "win" else 0.65
	particles.direction = Vector3.UP
	particles.spread = 80.0
	particles.gravity = Vector3(0, -3.0, 0)
	particles.initial_velocity_min = 1.5 * diameter
	particles.initial_velocity_max = 3.0 * diameter
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = diameter * 0.25
	particles.use_fixed_seed = true
	particles.seed = 41
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.09, 0.05, 0.13) * minf(diameter, 2.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([
		Color("e78763") if kind == "bump" else Color("f6c653"),
		Color("fff2d3"), Color("52b8a5")
	])
	particles.color_initial_ramp = gradient
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(0.6, 0.8))
	shrink.add_point(Vector2(1, 0))
	particles.scale_amount_curve = shrink
	add_child(particles)
	particles.position = point
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	_ring(point, diameter, Color("ef8d70") if kind == "bump" else Color("f8d570"))


func clear() -> void:
	for child: Node in get_children():
		child.free()


func _ring(point: Vector3, diameter: float, color: Color) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = 0.46
	mesh.outer_radius = 0.50
	mesh.rings = 32
	mesh.ring_segments = 6
	ring.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	ring.material_override = material
	add_child(ring)
	ring.position = Vector3(point.x, 0.09, point.z)
	ring.scale = Vector3.ONE * diameter
	var tween: Tween = ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * diameter * 2.3, 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)
