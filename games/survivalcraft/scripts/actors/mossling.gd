extends RefCounted
## 石殻獣。幅広い六角甲羅、苔の稜線、分節した脚と牙を持つ独立モデル。

const Shapes := preload("res://scripts/actors/shapes.gd")


## 一個体の初期構築で部品を追加するため非冪等。
static func build(rig: Node3D) -> void:
	var body: Node3D = rig.get_node("Body")
	var head: Node3D = rig.get_node("Head")
	Shapes.part(body, Vector3(0, 0.63, 0.04), Vector3(1.15, 0.75, 1.25),
		Color("526d70"), "sphere")
	for side: float in [-1.0, 1.0]:
		Shapes.part(body, Vector3(side * 0.30, 0.91, 0.04), Vector3(0.5, 0.3, 0.87),
			Color("82a568"), "sphere")
		Shapes.part(head, Vector3(side * 0.2, 0.06, -0.38), Vector3(0.11, 0.10, 0.07),
			Color("ffcf71"), "box", true)
		var tusk: MeshInstance3D = Shapes.part(head, Vector3(side * 0.30, -0.13, -0.44),
			Vector3(0.16, 0.4, 0.16), Color("f0e7c5"), "cone")
		tusk.rotation.x = -0.65
	Shapes.part(head, Vector3(0, 0, -0.08), Vector3(0.67, 0.44, 0.55), Color("354d59"))
	Shapes.part(body, Vector3(0, 1.08, 0.0), Vector3(0.22, 0.25, 0.72),
		Color("beca80"), "cone")
	for label: String in ["LeftArm", "RightArm", "LeftFoot", "RightFoot"]:
		var limb: Node3D = rig.get_node(label)
		Shapes.part(limb, Vector3(0, -0.14, 0), Vector3(0.26, 0.4, 0.29), Color("405a61"))
		Shapes.part(limb, Vector3(0, -0.33, -0.08), Vector3(0.34, 0.16, 0.39),
			Color("d9d5ad"))
