extends "res://scripts/visuals/crystal.gd"
## 四人用は中央結晶と左右の小結晶。


func _init() -> void:
	pedestal(0.94)
	shard(Vector3(0, 0.32, 0), 1.8, 0.46, Color("d9a74e"))
	shard(Vector3(-0.5, 0.3, 0.12), 1.1, 0.28, Color("b4793c"))
	shard(Vector3(0.5, 0.3, 0.12), 1.3, 0.27, Color("e2be6f"))
