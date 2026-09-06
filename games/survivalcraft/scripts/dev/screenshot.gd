extends SceneTree
## 通常シーンの画面と、撮影用に固定した夜・完成した家・キャラクターを撮影する。

const Inputs := preload("res://scripts/dev/integration.gd")
const Gallery := preload("res://scripts/dev/animation_gallery.gd")
const Data := preload("res://scripts/voxel_data.gd")
var main: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _capture_scenes()
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	await _capture("title")
	main.start_game()
	await create_timer(0.4).timeout
	await _capture("play")
	Inputs.prepare_tree(main)
	await create_timer(0.2).timeout
	Inputs.mouse(MOUSE_BUTTON_LEFT, true)
	await create_timer(0.16).timeout
	await _capture("mining-start")
	await create_timer(0.20).timeout
	await _capture("mining-middle")
	await create_timer(0.22).timeout
	await _capture("mining-end")
	for frame: int in range(120):
		if int(main.model.inventory.get("wood", 0)) > 0:
			break
		await physics_frame
	Inputs.mouse(MOUSE_BUTTON_LEFT, false)
	await create_timer(0.12).timeout
	await _capture("block-particles")
	main._request("craft_menu", "")
	await create_timer(0.15).timeout
	await _capture("craft")
	main._request("close", "")
	main._request("pause", "")
	await create_timer(0.15).timeout
	await _capture("pause")
	main._request("close", "")
	_settlement_fixture()
	main.model.day_time = 0.77
	await create_timer(1.0).timeout
	await _capture("night")
	main._hurt(18)
	await create_timer(0.08).timeout
	await _capture("damage-flash")
	main.model.hp = 100
	main.model.hunger = 100
	main.model.day = 4
	main.model.day_time = 0.179
	await create_timer(0.7).timeout
	await _capture("clear")
	main.start_game()
	main._request("retire", "")
	await create_timer(0.5).timeout
	await _capture("failed")
	main.stop_audio()
	await create_timer(0.2).timeout
	main.queue_free()
	await process_frame
	var gallery: Node3D = Gallery.new()
	root.add_child(gallery)
	for index: int in range(3):
		gallery.pose([0.0, 0.5, 0.99][index], ["開始", "途中", "終了"][index])
		await _capture("actors-" + ["start", "middle", "end"][index])
	gallery.queue_free()
	await process_frame


func _settlement_fixture() -> void:
	# 代表画面用の家と時刻。通常プレイ・入力録画の進行とは分けて再現する。
	var base: int = 7
	for x: int in range(14, 17):
		for z: int in range(13, 16):
			for y: int in range(4):
				var id: int = Data.PLANK if y in [0, 3] or x != 15 or z != 14 else Data.AIR
				main.model.data.set_block(Vector3i(x, base + y, z), id)
	main.model.data.set_block(Vector3i(15, base + 1, 15), Data.AIR)
	main.model.data.set_block(Vector3i(15, base + 2, 15), Data.AIR)
	main.model.data.set_block(Vector3i(13, 7, 16), Data.TORCH)
	main.model.data.set_block(Vector3i(17, 7, 16), Data.TORCH)
	main.model.tool_level = 2
	main.model.house_built = main.model.check_house()
	main.model.world_changed.emit()
	main.player.setup(Vector3(15.5, 7.05, 20.5))
	Inputs.motion(Vector2(0, 14))


func _capture(name_suffix: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name_suffix
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		failed = true
		push_error("スクリーンショット保存失敗: " + path)
	else:
		print("screenshot: " + path)
