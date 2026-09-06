extends "res://scripts/visuals/crystal.gd"
## 二人用は一本の細い琥珀柱。


func _init() -> void:
	pedestal(0.66)
	shard(Vector3(0, 0.32, 0), 1.5, 0.38, Color("d99543"))
