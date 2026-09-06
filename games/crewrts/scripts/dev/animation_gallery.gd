extends RefCounted
## 実ゲームで使う同じモデルと AnimationPlayer の開始・途中・終了を一枚に並べる。

const MODELS: Array[String] = ["captain", "striker", "porter", "beetle", "thorn_beetle"]
const NAMES: Array[String] = ["隊長", "朱 / 攻撃役", "青 / 運搬役", "甲虫", "トゲ甲虫"]
const MOTIONS: Dictionary = {
	"idle": "待機", "walk": "移動", "attack": "攻撃", "hit": "被弾", "death": "退場",
}


## 比較用のノードを一時的に生成し、撮影後に全て解放するため一回の撮影処理は非冪等。
func capture(tree: SceneTree, main: Node, save: Callable) -> bool:
	main.visible = false
	main.hud.visible = false
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 0.8
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0, 18, -25)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.make_current()
	var captions := CanvasLayer.new()
	stage.add_child(captions)
	var heading := Label.new()
	heading.position = Vector2(28, 18)
	heading.add_theme_font_override("font", main.UI_FONT)
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("173b37"))
	captions.add_child(heading)
	var actors: Array[Node3D] = []
	for row: int in range(3):
		for column: int in range(MODELS.size()):
			var actor: Node3D = load("res://assets/models/%s.tscn" % MODELS[column]).instantiate()
			actor.position = Vector3((2 - column) * 4.1, 0, (1 - row) * 6.0)
			# 傾いた装備や脚の先端も各行の見出しから離す。
			actor.scale = Vector3.ONE * 0.82
			stage.add_child(actor)
			actors.append(actor)
			var label := Label.new()
			label.add_theme_font_override("font", main.UI_FONT)
			label.add_theme_font_size_override("font_size", 16)
			label.custom_minimum_size.x = 210
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_color_override("font_color", Color("173b37"))
			label.position = camera.unproject_position(actor.position + Vector3(0, 2.5, 0)) \
				- Vector2(105, 0)
			label.text = NAMES[column] + " / " + ["開始", "途中", "終了"][row]
			captions.add_child(label)
	await tree.process_frame
	for motion: String in MOTIONS:
		heading.text = "部位アニメーション  /  %s　　開始 → 途中 → 終了" % MOTIONS[motion]
		for index: int in range(actors.size()):
			var actor: Node3D = actors[index]
			actor.set_process(false)
			var player: AnimationPlayer = actor.animation_player
			if not player.has_animation(motion):
				push_error("アニメーション未定義: %s / %s" % [MODELS[index % 5], motion])
				stage.queue_free()
				return false
			player.play(motion)
			var animation: Animation = player.get_animation(motion)
			player.seek(animation.length * [0.0, 0.48, 0.95][index / 5], true)
			player.pause()
		if not await save.call("tmp/screenshot-animation-%s.png" % motion):
			stage.queue_free()
			return false
	stage.queue_free()
	await tree.process_frame
	if not await _capture_objects(tree, main, save):
		return false
	main.visible = true
	main.hud.visible = true
	main.world.camera.make_current()
	return true


func _capture_objects(tree: SceneTree, main: Node, save: Callable) -> bool:
	var stage := Node3D.new()
	tree.root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.light_energy = 0.7
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0, 12, 22)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.make_current()
	var names: Array[String] = ["2人で運ぶ結晶", "4人で運ぶ結晶", "6人で運ぶ結晶", "回収基地"]
	var scenes: Array[String] = ["crystal_light", "crystal_medium", "crystal_heavy", "base"]
	var captions := CanvasLayer.new()
	stage.add_child(captions)
	for index: int in range(scenes.size()):
		var item: Node3D = load("res://assets/models/%s.tscn" % scenes[index]).instantiate()
		item.position = Vector3((index - 1.5) * 4.8, 0, 0)
		stage.add_child(item)
		var label := Label.new()
		label.add_theme_font_override("font", main.UI_FONT)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("173b37"))
		label.text = names[index]
		label.position = camera.unproject_position(item.position + Vector3(0, 4.8, 0)) \
			- Vector2(120, 0)
		label.custom_minimum_size.x = 240
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		captions.add_child(label)
	var success: bool = await save.call("tmp/screenshot-objects.png")
	stage.queue_free()
	await tree.process_frame
	return success
