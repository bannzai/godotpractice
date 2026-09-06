extends "res://scripts/visuals/actor.gd"
## 隊長は丸い探検帽、片側の通信機、短いマントを持つ。


func _init() -> void:
	species = "captain"
	create_rig(1.08, 0.38, 0.2)
	Shapes.cylinder(body, Vector3(0, 0.7, 0), Vector3(0.34, 0.36, 0.3), CREAM)
	Shapes.box(body, Vector3(0, 0.72, -0.3), Vector3(0.28, 0.29, 0.08), Color("447d75"))
	Shapes.box(body, Vector3(0, 0.65, 0.32), Vector3(0.61, 0.65, 0.08), Color("bf6649"))
	Shapes.sphere(head, Vector3.ZERO, Vector3(0.43, 0.34, 0.36), CREAM)
	Shapes.sphere(head, Vector3(0, -0.03, -0.29), Vector3(0.34, 0.19, 0.14), INK)
	Shapes.box(head, Vector3(0, 0.05, -0.43), Vector3(0.34, 0.045, 0.035), GOLD)
	Shapes.cylinder(head, Vector3(0, 0.29, 0), Vector3(0.49, 0.045, 0.42), Color("c8ad72"))
	Shapes.sphere(head, Vector3(0, 0.35, 0), Vector3(0.34, 0.2, 0.31), CREAM)
	Shapes.cylinder(head, Vector3(0.4, 0.32, 0), Vector3(0.025, 0.3, 0.025), INK)
	Shapes.sphere(head, Vector3(0.4, 0.61, 0), Vector3.ONE * 0.08, Color("e8ae55"))
	for arm: Node3D in [left_arm, right_arm]:
		Shapes.sphere(arm, Vector3(0, -0.15, 0), Vector3(0.11, 0.23, 0.12), CREAM)
		Shapes.sphere(arm, Vector3(0, -0.33, 0), Vector3.ONE * 0.12, Color("bf6649"))
	for foot: Node3D in [left_foot, right_foot]:
		Shapes.box(foot, Vector3(0, -0.1, -0.07), Vector3(0.24, 0.22, 0.37), INK)
	scale = Vector3.ONE * 1.18
