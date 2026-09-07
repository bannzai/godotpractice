class_name ClaySurface
extends RefCounted
## プリミティブの形を保ったまま、頂点色と共有ノイズ法線で粘土の表面を作る。

static var _clay_material: StandardMaterial3D
static var _color_noise: FastNoiseLite
static var _styled_meshes: Dictionary = {}


static func style_tree(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		style_mesh(node as MeshInstance3D)


static func style_mesh(instance: MeshInstance3D, fallback_color: Color = Color.WHITE) -> void:
	if instance.mesh == null or instance.mesh.get_surface_count() == 0:
		return
	var color: Color = fallback_color
	var active_material: Material = instance.get_active_material(0)
	if active_material is StandardMaterial3D:
		color = (active_material as StandardMaterial3D).albedo_color
	var cache_key: String = "%d:%s" % [instance.mesh.get_instance_id(), color.to_html()]
	if not _styled_meshes.has(cache_key):
		_styled_meshes[cache_key] = _with_vertex_color(instance.mesh, color)
	instance.mesh = _styled_meshes[cache_key]
	instance.material_override = _material()
	instance.set_meta("clay_vertex_color", true)
	instance.set_meta("clay_normal_noise", true)


static func _with_vertex_color(source: Mesh, base_color: Color) -> ArrayMesh:
	var result: ArrayMesh = ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = PackedColorArray()
		colors.resize(vertices.size())
		for index: int in range(vertices.size()):
			var point: Vector3 = vertices[index]
			var mottling: float = _noise().get_noise_3d(point.x * 3.2, point.y * 3.2,
				point.z * 3.2)
			var fingerprint: float = sin((point.x + point.y * 0.7 + point.z * 0.35) * 41.0)
			var value: float = clampf(1.0 + mottling * 0.055 + fingerprint * 0.018, 0.88, 1.1)
			colors[index] = Color(
				clampf(base_color.r * value, 0.0, 1.0),
				clampf(base_color.g * value, 0.0, 1.0),
				clampf(base_color.b * value, 0.0, 1.0),
				base_color.a
			)
		arrays[Mesh.ARRAY_COLOR] = colors
		var primitive: Mesh.PrimitiveType = Mesh.PRIMITIVE_TRIANGLES
		if source is ArrayMesh:
			primitive = (source as ArrayMesh).surface_get_primitive_type(surface)
		result.add_surface_from_arrays(primitive, arrays)
	return result


static func _material() -> StandardMaterial3D:
	if _clay_material == null:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = 2087
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.065
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		var normal_map: NoiseTexture2D = NoiseTexture2D.new()
		normal_map.width = 192
		normal_map.height = 192
		normal_map.seamless = true
		normal_map.as_normal_map = true
		normal_map.bump_strength = 2.1
		normal_map.noise = noise
		_clay_material = StandardMaterial3D.new()
		_clay_material.albedo_color = Color.WHITE
		_clay_material.roughness = 0.94
		_clay_material.vertex_color_use_as_albedo = true
		_clay_material.normal_enabled = true
		_clay_material.normal_scale = 0.34
		_clay_material.normal_texture = normal_map
	return _clay_material


static func _noise() -> FastNoiseLite:
	if _color_noise == null:
		_color_noise = FastNoiseLite.new()
		_color_noise.seed = 1489
		_color_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_color_noise.frequency = 0.72
		_color_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_color_noise.fractal_octaves = 3
	return _color_noise
