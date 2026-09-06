extends RefCounted
## 低分割の立体を組み合わせる。メッシュの追加は構築時だけの非冪等操作。


static func pivot(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node


static func part(
	parent: Node3D, point: Vector3, size: Vector3, color: Color,
	form: String = "box", glow: bool = false
) -> MeshInstance3D:
	var mesh: PrimitiveMesh
	if form == "sphere":
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	elif form in ["cone", "cylinder"]:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.0 if form == "cone" else 0.5
		cylinder.bottom_radius = 0.5
		cylinder.height = 1.0
		cylinder.radial_segments = 6
		mesh = cylinder
	else:
		mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.emission_enabled = glow
	material.emission = color if glow else Color.BLACK
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = material
	result.position = point
	result.scale = size
	parent.add_child(result)
	return result
