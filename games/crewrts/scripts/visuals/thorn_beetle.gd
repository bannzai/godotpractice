extends "res://scripts/visuals/actor.gd"
## トゲ甲虫は平たい盾殻、三本の背棘、左右の鎌で別シルエットにする。


func _init() -> void:
	species = "thorn_beetle"
	create_rig(0.55, 0.9, 0.87)
	Shapes.sphere(body, Vector3(0, 0.68, 0.05), Vector3(1.23, 0.48, 0.84), Color("586b4c"))
	for index: int in range(3):
		Shapes.cylinder(body, Vector3((index - 1) * 0.6, 1.25, 0.05),
			Vector3(0.23, 0.48 if index == 1 else 0.3, 0.23), Color("d5b57d"), true)
	Shapes.box(head, Vector3(0, 0, -0.8), Vector3(0.78, 0.44, 0.52), Color("3c5147"))
	for side: float in [-1.0, 1.0]:
		Shapes.box(head, Vector3(side * 0.22, 0.04, -1.08),
			Vector3(0.17, 0.085, 0.06), Color("efa75d"))
	left_arm.position = Vector3(-0.4, -0.03, -0.89)
	right_arm.position = Vector3(0.4, -0.03, -0.89)
	for arm: Node3D in [left_arm, right_arm]:
		Shapes.sphere(arm, Vector3.ZERO, Vector3.ONE * 0.18, Color("3c5147"))
		var blade: MeshInstance3D = Shapes.cylinder(arm, Vector3(0, 0, -0.52),
			Vector3(0.22, 0.62, 0.17), Color("d5b57d"), true)
		blade.rotation.x = -PI * 0.5
	for foot: Node3D in [left_foot, right_foot]:
		for index: int in range(3):
			var leg: MeshInstance3D = Shapes.box(foot, Vector3(0, 0, index * 0.6 - 0.5),
				Vector3(0.93, 0.14, 0.2), Color("3c5147"))
			leg.rotation.y = (index - 1) * (0.4 if foot == left_foot else -0.4)
