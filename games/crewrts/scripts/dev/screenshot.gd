extends SceneTree
## 実際の描画で代表画面を撮影する (headless では描画されないため、Makefile の screenshot target が
## --headless なしで起動する)。撮影した PNG は tmp/screenshot-<名前>.png に保存し、失敗したら quit(1) で終わる。
## ゲーム固有の状態作り (画面遷移・スコアの投入・操作の再現等) は _capture_scenes() に足す。
## autoload は --script 起動でも root から取得できる。

const Gallery = preload("res://scripts/dev/animation_gallery.gd")
## 音声の解放は通常 0.1 秒以内に終わる。CI (llvmpipe) で音声スレッドが遅れても足りる余裕を取る
const AUDIO_RELEASE_TIMEOUT_MSEC := 10000

func _initialize() -> void:
	# BGM の autoload やゲーム側の SE が撮影中に鳴らないよう Master バスをミュートする
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 時間経過と物理で画面を進めるため、同じ実行中に重ねて呼び出さない。
func _run() -> void:
	quit(0 if await _capture_scenes() else 1)


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
	for capture: Callable in [_capture_actions, _capture_results, _capture_effects]:
		if not await capture.call(main):
			return false
	var gallery: RefCounted = Gallery.new()
	if not await gallery.capture(self, main, _capture):
		return false
	main.stop_audio()
	if not await _wait_audio_release(main):
		return false
	main.queue_free()
	await process_frame
	return true


## 停止した再生を音声スレッドが手放し WAV が解放されるまで待つ。秒数 (0.15 秒) やフレーム数で待つと、
## 音声スレッドが遅れる CI の回や高リフレッシュレートの画面で解放前に終了し、リーク WARNING で失敗する。
func _wait_audio_release(main: Node) -> bool:
	var deadline: int = Time.get_ticks_msec() + AUDIO_RELEASE_TIMEOUT_MSEC
	while not main.audio.is_released():
		if Time.get_ticks_msec() > deadline:
			push_error("音声の解放が %d ms 以内に終わらない" % AUDIO_RELEASE_TIMEOUT_MSEC)
			quit(1)
			return false
		await process_frame
	return true


func _capture_actions(main: Node) -> bool:
	main.set_physics_process(false)
	var model: Node = main.model
	var point: Vector3 = model.cargo[0].position
	model.throw_at(point)
	model.throw_at(point)
	main._consume_events()
	main.world.sync(model, 0.0, point)
	for frame: Dictionary in [
		{"delta": 0.0, "file": "throw-start"}, {"delta": 0.24, "file": "throw"},
		{"delta": 0.32, "file": "throw-end"},
	]:
		model.step(frame.delta, Vector3.ZERO)
		main.world.sync(model, frame.delta, point)
		main.hud.refresh(model)
		if not await _capture("tmp/screenshot-%s.png" % frame.file):
			return false
	model.step(1.0, Vector3.ZERO)
	model.whistle()
	main._consume_events()
	main.world.whistle_time = 1.0
	main.world.sync(model, 0.45, point)
	await create_timer(0.2).timeout
	if not await _capture("tmp/screenshot-whistle.png"):
		return false
	await create_timer(0.7).timeout
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
	main._consume_events()
	main.world.set_camera(model, 0, 0, true)
	main.world.sync(model, 0.2, model.enemies[0].position)
	main.effects.sync(model, 0.3, main.world.camera)
	main.hud.refresh(model)
	await create_timer(0.2).timeout
	if not await _capture("tmp/screenshot-combat.png"):
		return false
	return true


func _capture_results(main: Node) -> bool:
	var model: Node = main.model
	model.collected = model.goal
	model.step(0.01, Vector3.ZERO)
	main.hud.refresh(model)
	await create_timer(0.75).timeout
	if not await _capture("tmp/screenshot-clear.png"):
		return false
	main.start_day()
	model.remaining = 0.01
	model.step(0.02, Vector3.ZERO)
	main.world.sync(model, 0.02, model.leader)
	main.hud.refresh(model)
	await create_timer(0.75).timeout
	if not await _capture("tmp/screenshot-failed.png"):
		return false
	return true


func _capture_effects(main: Node) -> bool:
	main.start_day()
	var model: Node = main.model
	model.leader = Vector3(-8, 0, -4)
	main.world.set_camera(model, 0, 0, true)
	main.world.sync(model, 0.0, model.enemies[0].position)
	main.hud.refresh(model)
	await create_timer(0.7).timeout
	for index: int in range(8):
		model.throw_at(model.enemies[0].position)
	model.step(2.0, Vector3.ZERO)
	main._consume_events()
	main.world.sync(model, 0.2, model.enemies[0].position)
	main.effects.sync(model, 0.3, main.world.camera)
	main.hud.refresh(model)
	await create_timer(0.24).timeout
	if not await _capture("tmp/screenshot-defeat.png"):
		return false
	main.start_day()
	model.leader = Vector3(-8, 0, -4)
	model.crew[0].state = "idle"
	model.crew[0].position = model.enemies[0].position
	main.effects.reset(model)
	main.world.sync(model, 0.0, model.enemies[0].position)
	main.world.set_camera(model, 0, 0, true)
	model.step(1.45, Vector3.ZERO)
	main._consume_events()
	main.world.sync(model, 0.1, model.enemies[0].position)
	main.effects.sync(model, 0.3, main.world.camera)
	main.hud.refresh(model)
	await create_timer(0.2).timeout
	if not await _capture("tmp/screenshot-lost.png"):
		return false
	main.start_day()
	model.throw_at(model.cargo[0].position)
	model.throw_at(model.cargo[0].position)
	model.step(12.0, Vector3.ZERO)
	main._consume_events()
	main.world.sync(model, 0.2, model.base_position)
	main.effects.sync(model, 0.3, main.world.camera)
	main.hud.refresh(model)
	await create_timer(0.3).timeout
	return await _capture("tmp/screenshot-delivery.png")


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
