extends Node3D
## 回収基地は木の発着台、三脚の観測ポッド、回転する回収リング。

const Shapes := preload("res://scripts/visuals/shapes.gd")
var beacon: Node3D


func _init() -> void:
	Shapes.cylinder(self, Vector3(0, 0.12, 0), Vector3(2.65, 0.12, 2.65), Color("a88f68"))
	Shapes.cylinder(self, Vector3(0, 0.25, 0), Vector3(2.34, 0.035, 2.34), Color("ceb987"))
	Shapes.cylinder(self, Vector3(0, 0.31, 0), Vector3(1.9, 0.025, 1.9), Color("3f7773"))
	for index: int in range(3):
		var angle: float = index * TAU / 3.0
		var foot := Vector3(sin(angle), 0, cos(angle))
		var strut: MeshInstance3D = Shapes.box(self, foot * 0.95 + Vector3(0, 0.95, 0),
			Vector3(0.25, 1.4, 0.25), Color("3c5957"))
		strut.rotation = Vector3(foot.z * 0.35, 0, -foot.x * 0.35)
	Shapes.sphere(self, Vector3(0, 1.9, 0), Vector3(1.07, 1.13, 1.07), Color("e7d7aa"))
	Shapes.sphere(self, Vector3(0, 2.06, 0.82), Vector3(0.68, 0.48, 0.32), Color("326a72"))
	Shapes.box(self, Vector3(0, 2.05, 1.12), Vector3(0.58, 0.065, 0.06), Color("7cc3b7"))
	Shapes.cylinder(self, Vector3(0, 3.1, 0), Vector3(0.45, 0.13, 0.45), Color("ba664e"))
	Shapes.cylinder(self, Vector3(0, 3.48, 0), Vector3(0.05, 0.28, 0.05), Color("3c5957"))
	beacon = Shapes.pivot(self, "Beacon", Vector3(0, 3.67, 0))
	Shapes.box(beacon, Vector3(0.28, 0, 0), Vector3(0.58, 0.3, 0.05), Color("dc9254"))
	for side: float in [-1.0, 1.0]:
		Shapes.box(self, Vector3(side * 1.7, 0.65, 0.9),
			Vector3(0.45, 0.65, 0.45), Color("4a7066"))
		Shapes.sphere(self, Vector3(side * 1.7, 1.08, 0.9),
			Vector3.ONE * 0.18, Color("d4c984"))
