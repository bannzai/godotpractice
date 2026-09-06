extends RefCounted
## 種類ごとのモデルで使う低分割メッシュと材質。描画資源だけを共有する。

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var surface := StandardMaterial3D.new()
		surface.albedo_color = color
		surface.roughness = 0.82
		_materials[color] = surface
	return _materials[color]


## ノードを追加する生成処理。同じ個体には初期構築時に一度だけ呼ぶ。
static func pivot(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node)
	return node


static func sphere(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		_meshes["sphere"] = mesh
	return place(parent, point, size, _meshes.sphere, color)


static func box(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not _meshes.has("box"):
		_meshes["box"] = BoxMesh.new()
	return place(parent, point, size, _meshes.box, color)


static func cylinder(
	parent: Node3D, point: Vector3, size: Vector3, color: Color, tapered: bool = false
) -> MeshInstance3D:
	var key: String = "cone" if tapered else "cylinder"
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0 if tapered else 1.0
		mesh.bottom_radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 10
		_meshes[key] = mesh
	return place(parent, point, size, _meshes[key], color)


## 個別ノードを生成するため非冪等。メッシュと材質は同じ入力から再利用する。
static func place(
	parent: Node3D, point: Vector3, size: Vector3, mesh: Mesh, color: Color
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = point
	instance.scale = size
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance
