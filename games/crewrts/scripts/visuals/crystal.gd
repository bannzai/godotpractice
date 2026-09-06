extends Node3D
## 運搬物の描画だけを保持し、必要人数はモデルの値をラベルへ反映する。

const Shapes := preload("res://scripts/visuals/shapes.gd")
var label: Label3D
var carried: bool = false


func set_carried(value: bool) -> void:
	carried = value


## 結晶の多面体と台座を構築するため、個体初期化時に一度だけ呼ぶ。
func shard(point: Vector3, height: float, radius: float, tint: Color) -> void:
	var node: Node3D = Shapes.pivot(self, "結晶", point)
	Shapes.cylinder(node, Vector3(0, height * 0.28, 0),
		Vector3(radius, height * 0.28, radius), tint)
	Shapes.cylinder(node, Vector3(0, height * 0.74, 0),
		Vector3(radius, height * 0.18, radius), tint.lightened(0.12), true)
	node.rotation.z = point.x * -0.22


func pedestal(radius: float) -> void:
	Shapes.cylinder(self, Vector3(0, 0.15, 0), Vector3(radius, 0.15, radius), Color("8f795b"))
	Shapes.cylinder(self, Vector3(0, 0.3, 0),
		Vector3(radius * 0.85, 0.03, radius * 0.85), Color("c9af72"))
