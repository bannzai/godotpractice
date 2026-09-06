extends "res://scripts/visuals/actor.gd"
## 朱隊員は角形ヘルメット、肩装甲、右手のハンマーで攻撃役を示す。

const RED := Color("d76744")


func _init() -> void:
	species = "striker"
	create_rig(0.86, 0.35, 0.18)
	Shapes.box(body, Vector3(0, 0.52, 0), Vector3(0.56, 0.49, 0.44), RED)
	Shapes.box(body, Vector3(0, 0.5, -0.24), Vector3(0.23, 0.15, 0.04), GOLD)
	Shapes.box(head, Vector3.ZERO, Vector3(0.65, 0.45, 0.52), RED)
	Shapes.box(head, Vector3(0, -0.02, -0.28), Vector3(0.48, 0.19, 0.05), INK)
	Shapes.box(head, Vector3(0, -0.015, -0.31), Vector3(0.32, 0.045, 0.02), CREAM)
	Shapes.box(head, Vector3(0, 0.28, 0), Vector3(0.15, 0.13, 0.39), Color("a84136"))
	for arm: Node3D in [left_arm, right_arm]:
		Shapes.box(arm, Vector3(0, 0, 0), Vector3(0.22, 0.23, 0.29), Color("a84136"))
		Shapes.box(arm, Vector3(0, -0.24, 0), Vector3(0.14, 0.26, 0.16), RED)
	Shapes.cylinder(right_arm, Vector3(0, -0.32, -0.16), Vector3(0.045, 0.25, 0.045), INK)
	Shapes.box(right_arm, Vector3(0, -0.55, -0.16), Vector3(0.38, 0.19, 0.24), GOLD)
	for foot: Node3D in [left_foot, right_foot]:
		Shapes.box(foot, Vector3(0, -0.1, -0.08), Vector3(0.23, 0.2, 0.32), INK)
