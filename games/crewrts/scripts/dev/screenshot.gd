extends SceneTree
## 実際の描画で代表画面を撮影する (headless では描画されないため、Makefile の screenshot target が
## --headless なしで起動する)。撮影した PNG は tmp/screenshot-<名前>.png に保存し、失敗したら quit(1) で終わる。
## ゲーム固有の状態作り (画面遷移・スコアの投入・操作の再現等) は _capture_scenes() に足す。
## autoload は --script 起動でも root から取得できる。


func _initialize() -> void:
	# BGM の autoload やゲーム側の SE が撮影中に鳴らないよう Master バスをミュートする
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 時間経過と物理で画面を進めるため、同じ実行中に重ねて呼び出さない。
func _run() -> void:
	if await _capture_scenes():
		quit(0)


## 撮影する画面の並び。雛形はメインシーン (タイトル) だけを撮る。失敗した撮影は _capture() が
## quit(1) 済みなので、false を受けたらそのまま抜ける。
func _capture_scenes() -> bool:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-title.png"):
		return false
	main.start_day()
	await create_timer(0.5).timeout
	if not await _capture("tmp/screenshot-play.png"):
		return false
	if not await _capture_actions(main):
		return false
	if not await _capture_results(main):
		return false
	main.stop_audio()
	await create_timer(0.15).timeout
	main.queue_free()
	await process_frame
	return true


func _capture_actions(main: Node) -> bool:
	main.set_physics_process(false)
	var model: Node = main.model
	var point: Vector3 = model.cargo[0].position
	model.throw_at(point)
	model.throw_at(point)
	model.step(0.24, Vector3.ZERO)
	main.world.sync(model, 0.24, point)
	main.hud.refresh(model)
	if not await _capture("tmp/screenshot-throw.png"):
		return false
	model.step(1.0, Vector3.ZERO)
	model.whistle()
	main.world.whistle_time = 1.0
	main.world.sync(model, 0.45, point)
	if not await _capture("tmp/screenshot-whistle.png"):
		return false
	model.throw_at(point)
	model.throw_at(point)
	model.step(1.5, Vector3.ZERO)
	main.world.sync(model, 0.2, point)
	main.hud.refresh(model)
	if not await _capture("tmp/screenshot-carry.png"):
		return false
	model.leader = Vector3(-8, 0, -4)
	model.whistle()
	for index: int in range(6):
		model.throw_at(model.enemies[0].position)
	model.step(0.8, Vector3.ZERO)
	main.world.set_camera(model, 0, 0, true)
	main.world.sync(model, 0.2, model.enemies[0].position)
	main.hud.refresh(model)
	if not await _capture("tmp/screenshot-combat.png"):
		return false
	return true


func _capture_results(main: Node) -> bool:
	var model: Node = main.model
	model.collected = model.goal
	model.step(0.01, Vector3.ZERO)
	main.hud.refresh(model)
	if not await _capture("tmp/screenshot-clear.png"):
		return false
	model.start_day()
	model.remaining = 0.01
	model.step(0.02, Vector3.ZERO)
	main.hud.refresh(model)
	if not await _capture("tmp/screenshot-failed.png"):
		return false
	return true


func _capture(path: String) -> bool:
	await process_frame
	await process_frame
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true
