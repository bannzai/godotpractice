extends RefCounted
## 灯精。六角ランタンの籠、浮遊する結晶核、長い二枚の垂れ布で輪郭を分ける。

const Shapes := preload("res://scripts/actors/shapes.gd")


## 一個体の初期構築で部品を追加するため非冪等。
static func build(rig: Node3D) -> void:
	var body: Node3D = rig.get_node("Body")
	var head: Node3D = rig.get_node("Head")
	Shapes.part(body, Vector3(0, 0.85, 0), Vector3(0.5, 0.73, 0.5),
		Color("f6bb62"), "sphere", true)
	Shapes.part(body, Vector3(0, 0.42, 0), Vector3(0.69, 0.18, 0.69),
		Color("547b8d"), "cylinder")
	for index: int in range(6):
		var angle: float = float(index) * TAU / 6.0
		Shapes.part(body, Vector3(cos(angle) * 0.29, 0.86, sin(angle) * 0.29),
			Vector3(0.045, 0.78, 0.045), Color("7494a2"))
	Shapes.part(head, Vector3(0, 0.4, 0), Vector3(0.88, 0.48, 0.88),
		Color("354a77"), "cone")
	Shapes.part(head, Vector3(0, 0.70, 0), Vector3(0.10, 0.24, 0.10),
		Color("efc77e"), "sphere", true)
	for side: float in [-1.0, 1.0]:
		Shapes.part(body, Vector3(side * 0.12, 0.86, -0.25), Vector3(0.065, 0.13, 0.05),
			Color("263657"))
	for label: String in ["LeftArm", "RightArm"]:
		var ribbon: Node3D = rig.get_node(label)
		Shapes.part(ribbon, Vector3(0, -0.3, 0), Vector3(0.12, 0.70, 0.10),
			Color("7eb0ab"))
		Shapes.part(ribbon, Vector3(0, -0.66, 0), Vector3(0.19, 0.23, 0.19),
			Color("fae4a6"), "cone")
	for label: String in ["LeftFoot", "RightFoot"]:
		Shapes.part(rig.get_node(label), Vector3(0, -0.18, 0), Vector3(0.14, 0.34, 0.14),
			Color("facb75"), "cone", true)
