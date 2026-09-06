extends "res://scripts/visuals/actor.gd"
## 丸い甲殻と横に張り出す六脚、前方の大顎を持つ甲虫。


func _init() -> void:
	species = "beetle"
	create_rig(0.55, 0.55, 0.76)
	Shapes.sphere(body, Vector3(0, 0.65, 0.23), Vector3(1.0, 0.62, 1.0), Color("765371"))
	Shapes.box(body, Vector3(0, 1.23, 0.22), Vector3(0.07, 0.035, 1.1), Color("bc87a0"))
	Shapes.sphere(head, Vector3(0, 0, -0.8), Vector3(0.63, 0.42, 0.48), Color("493d55"))
	for side: float in [-1.0, 1.0]:
		Shapes.sphere(head, Vector3(side * 0.32, 0.12, -1.16), Vector3.ONE * 0.16, GOLD)
		Shapes.sphere(head, Vector3(side * 0.32, 0.12, -1.3), Vector3.ONE * 0.075, INK)
	left_arm.position = Vector3(-0.44, -0.17, -0.98)
	right_arm.position = Vector3(0.44, -0.17, -0.98)
	for arm: Node3D in [left_arm, right_arm]:
		Shapes.sphere(arm, Vector3.ZERO, Vector3.ONE * 0.15, Color("493d55"))
		var jaw: MeshInstance3D = Shapes.box(arm, Vector3(0, 0, -0.28),
			Vector3(0.24, 0.18, 0.72), Color("c79588"))
		jaw.rotation.y = -0.25 if arm == left_arm else 0.25
	for foot: Node3D in [left_foot, right_foot]:
		for index: int in range(3):
			var leg: MeshInstance3D = Shapes.box(foot, Vector3(0, 0, index * 0.62 - 0.52),
				Vector3(0.78, 0.13, 0.16), Color("493d55"))
			leg.rotation.z = -0.3 if foot == left_foot else 0.3
