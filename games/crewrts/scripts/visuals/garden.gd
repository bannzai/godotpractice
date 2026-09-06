extends Node3D
## 遊べる床の高さと障害物位置を変えず、地層と遠景で庭の奥行きを作る。

const Shapes := preload("res://scripts/visuals/shapes.gd")


## 地形を構築するため非冪等。一つのワールドにつき一度だけ呼ぶ。
func build(obstacles: Array[Vector3]) -> void:
	Shapes.box(self, Vector3(0, -0.46, 0), Vector3(50, 0.9, 50), Color("73895a"))
	Shapes.box(self, Vector3(0, -1.1, 0), Vector3(50.3, 0.4, 50.3), Color("b49565"))
	Shapes.box(self, Vector3(0, -1.85, 0), Vector3(50.7, 1.1, 50.7), Color("8a674c"))
	Shapes.box(self, Vector3(0, -2.65, 0), Vector3(51.0, 0.5, 51.0), Color("544e3f"))
	Shapes.box(self, Vector3(0, -3.4, 0), Vector3(72, 0.8, 72), Color("4e725c"))
	for index: int in range(26):
		var patch := Vector3(sin(index * 2.39) * 22.0, 0.014, cos(index * 1.73) * 22.0)
		var tint: Color = Color("809263") if index % 2 == 0 else Color("687e52")
		Shapes.cylinder(self, patch, Vector3(2.6, 0.014, 1.8), tint)
	for index: int in range(18):
		var point := Vector3(sin(index * 0.65) * 1.1, 0.03, 19.0 - index * 2.35)
		var stone: MeshInstance3D = Shapes.sphere(self, point, Vector3(0.72, 0.055, 0.54),
			Color("a4a082"))
		stone.rotation.y = index * 1.4
	for obstacle: Vector3 in obstacles:
		_tree(obstacle, 1.0)
	for index: int in range(30):
		var angle: float = index * TAU / 30.0
		var point := Vector3(sin(angle) * 26.8, -0.2, cos(angle) * 26.8)
		_tree(point, 1.2 + sin(index * 1.7) * 0.2)
	for index: int in range(15):
		var point := Vector3(sin(index * 2.4) * 38, -1.6, cos(index * 2.4) * 37)
		var tint: Color = Color("426650") if index % 2 == 0 else Color("4d7459")
		Shapes.sphere(self, point, Vector3(6.0, 4.2 + sin(index) * 2, 5.0), tint)
	_grass()
	_ornaments()


func _tree(point: Vector3, size: float) -> void:
	var tree: Node3D = Shapes.pivot(self, "樹木", point)
	tree.scale = Vector3.ONE * size
	Shapes.cylinder(tree, Vector3(0, 0.95, 0), Vector3(0.34, 0.95, 0.34), Color("765a43"))
	var limb: MeshInstance3D = Shapes.cylinder(tree, Vector3(0.28, 1.65, 0),
		Vector3(0.15, 0.62, 0.15), Color("765a43"))
	limb.rotation.z = -0.6
	Shapes.sphere(tree, Vector3(0, 2.65, 0), Vector3(1.38, 1.18, 1.27), Color("3e7054"))
	Shapes.sphere(tree, Vector3(-0.43, 3.4, -0.12),
		Vector3(1.07, 1.0, 1.05), Color("648747"))
	Shapes.sphere(tree, Vector3(0.85, 2.7, 0.1), Vector3(0.95, 0.83, 0.9), Color("789b56"))
	for index: int in range(4):
		var angle: float = index * TAU / 4.0
		Shapes.sphere(tree, Vector3(sin(angle) * 0.5, 0.13, cos(angle) * 0.5),
			Vector3(0.48, 0.18, 0.43), Color("60744a"))


func _grass() -> void:
	var grass_mesh := PrismMesh.new()
	grass_mesh.size = Vector3(0.16, 0.5, 0.1)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = grass_mesh
	multimesh.instance_count = 380
	for index: int in range(multimesh.instance_count):
		var point := Vector3(sin(index * 5.3) * 23, 0.2, cos(index * 2.7) * 23)
		var basis := Basis.from_euler(Vector3(0.1, index * 1.7, sin(index) * 0.18))
		multimesh.set_instance_transform(index, Transform3D(basis, point))
		multimesh.set_instance_color(index, Color("5c783f") if index % 2 else Color("92a269"))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _ornaments() -> void:
	for index: int in range(28):
		var point := Vector3(sin(index * 3.7) * 22.5, 0.0, cos(index * 1.4) * 22.5)
		Shapes.cylinder(self, point + Vector3(0, 0.21, 0),
			Vector3(0.035, 0.21, 0.035), Color("4f734d"))
		var color: Color = Color("d6bb78") if index % 2 == 0 else Color("c98c80")
		Shapes.sphere(self, point + Vector3(0, 0.47, 0), Vector3(0.24, 0.11, 0.24), color)
		Shapes.sphere(self, point + Vector3(0, 0.52, 0),
			Vector3.ONE * 0.095, Color("a27044"))
	for index: int in range(12):
		var angle: float = index * TAU / 12.0
		var point := Vector3(sin(angle) * 23.8, 0.25, cos(angle) * 23.8)
		Shapes.sphere(self, point, Vector3(1.1, 0.6, 0.72), Color("838c78"))
