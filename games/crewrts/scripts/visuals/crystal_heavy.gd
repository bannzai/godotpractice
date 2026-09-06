extends "res://scripts/visuals/crystal.gd"
## 六人用は横幅のある王冠状の結晶群。


func _init() -> void:
	pedestal(1.23)
	shard(Vector3(0, 0.32, 0), 2.3, 0.53, Color("daac60"))
	shard(Vector3(-0.68, 0.32, 0), 1.7, 0.4, Color("b98243"))
	shard(Vector3(0.68, 0.32, 0), 1.55, 0.4, Color("edc879"))
	shard(Vector3(-0.2, 0.32, 0.62), 1.25, 0.35, Color("c7944e"))
	shard(Vector3(0.4, 0.32, -0.56), 1.35, 0.3, Color("e1b363"))
