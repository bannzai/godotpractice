extends RefCounted
## 灯守の手袋と真鍮を継いだつるはし。一人称カメラに取り付ける独立モデル。

const Shapes := preload("res://scripts/actors/shapes.gd")


## 一個体の初期構築で部品を追加するため非冪等。
static func build(rig: Node3D) -> void:
	for label: String in ["LeftArm", "RightArm"]:
		var hand: Node3D = rig.get_node(label)
		Shapes.part(hand, Vector3(0, -0.10, 0), Vector3(0.18, 0.42, 0.2),
			Color("426f76"))
		Shapes.part(hand, Vector3(0, 0.14, -0.10), Vector3(0.21, 0.19, 0.25),
			Color("dab485"))
		Shapes.part(hand, Vector3(0, 0.02, -0.01), Vector3(0.2, 0.08, 0.22),
			Color("e6c681"))
	var tool: Node3D = Shapes.pivot(rig.get_node("RightArm"), "Tool", Vector3.ZERO)
	Shapes.part(tool, Vector3(0, 0.32, -0.2), Vector3(0.065, 0.78, 0.07),
		Color("985e3f"))
	Shapes.part(tool, Vector3(0, 0.66, -0.2), Vector3(0.18, 0.18, 0.17),
		Color("d8b66b"))
	var blade: MeshInstance3D = Shapes.part(tool, Vector3(-0.18, 0.67, -0.2),
		Vector3(0.65, 0.12, 0.13), Color("b5d5d7"))
	blade.name = "Blade"
	blade.rotation.z = -0.16
	var tip: MeshInstance3D = Shapes.part(tool, Vector3(-0.51, 0.59, -0.2),
		Vector3(0.13, 0.26, 0.13), Color("b5d5d7"), "cone")
	tip.name = "Tip"
	tip.rotation.z = PI + 0.2
