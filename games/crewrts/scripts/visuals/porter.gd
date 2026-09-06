extends "res://scripts/visuals/actor.gd"
## 青隊員は長い受信耳と丸い背嚢。運搬時に両腕を上げる。

const BLUE := Color("3a929c")


func _init() -> void:
	species = "porter"
	create_rig(0.81, 0.32, 0.15)
	Shapes.sphere(body, Vector3(0, 0.5, 0), Vector3(0.3, 0.35, 0.27), BLUE)
	Shapes.sphere(body, Vector3(0, 0.52, 0.28), Vector3(0.36, 0.34, 0.25), Color("cfb77c"))
	Shapes.box(body, Vector3(0, 0.61, 0.48), Vector3(0.19, 0.13, 0.04), CREAM)
	Shapes.sphere(head, Vector3.ZERO, Vector3(0.35, 0.3, 0.31), BLUE)
	Shapes.sphere(head, Vector3(0, -0.02, -0.23), Vector3(0.25, 0.16, 0.12), INK)
	for side: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = Shapes.sphere(head, Vector3(side * 0.19, 0.42, 0),
			Vector3(0.085, 0.34, 0.09), BLUE)
		ear.rotation.z = -side * 0.18
		Shapes.sphere(head, Vector3(side * 0.1, 0, -0.34), Vector3.ONE * 0.045, CREAM)
	for arm: Node3D in [left_arm, right_arm]:
		Shapes.sphere(arm, Vector3(0, -0.16, 0), Vector3(0.1, 0.22, 0.1), BLUE)
	for foot: Node3D in [left_foot, right_foot]:
		Shapes.sphere(foot, Vector3(0, -0.1, -0.07), Vector3(0.12, 0.1, 0.18), INK)
