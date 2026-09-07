extends SceneTree
## 代表画面とモデルの連続フレームを、実レンダラで撮影する。

const Gallery = preload("res://scripts/dev/model_gallery.gd")
var _main: Node
var _state: Node
var _failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	_run.call_deferred()


# 撮影対象の状態を順に構成してフレームを出力する一度限りの処理。
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	await _capture_scenes()
	await _main.prepare_shutdown()
	_main.queue_free()
	await process_frame
	var gallery: Node = Gallery.new()
	root.add_child(gallery)
	if not await gallery.capture_frames():
		_failed = true
	gallery.queue_free()
	await process_frame
	print("screenshot OK" if not _failed else "スクリーンショット検証失敗")
	quit(1 if _failed else 0)


func _capture_scenes() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	_state = root.get_node("RaceState")
	_state.save_enabled = false
	_state._rng.seed = 380038
	await create_timer(0.5).timeout
	await _capture("title")
	_main.select_kart(1)
	await _capture("title-highlight")
	_main.show_garage()
	await _capture("garage")
	_main.show_tutorial()
	await _capture("tutorial-accelerate")
	_main.tutorial_step = 2
	_main.hud.set_tutorial_step(2)
	_main.hud.refresh()
	await _capture("tutorial-drift")
	_main.start_race()
	_main.set_physics_process(false)
	await create_timer(0.45).timeout
	await _capture("countdown")
	_advance(3.1)
	_advance(2.3)
	await _capture("racing")
	# 表示用 fixture。各所持アイテムと発動の見た目を確実に撮影する。
	for item: int in range(1, 4):
		_state.racers[0].item = item
		_main.hud.refresh()
		await _capture("item-%d" % item)
		_state.use_item(0)
		_advance(0.12)
		await _capture("item-effect-%d" % item)
	_state.racers[0].lateral = 0.0
	_state.racers[0].boost = 0.0
	_advance(0.8, 0.4, true)
	await _capture("drift")
	_advance(0.06)
	await _capture("boost")
	_state.racers[0].invulnerable = 0.0
	_state.hit(0)
	_main.hud.refresh()
	await create_timer(0.08).timeout
	await _capture("hit", 0.0)
	_state.racers[0].respawn_timer = 0.55
	_main._update_racers()
	_main.hud.refresh()
	await _capture("respawn")
	_state.racers[0].respawn_timer = 0.0
	# ゴール待機画面のfixtureとして長いブーストを与え、CPUより先に正順で完走する。
	_state.racers[0].boost = 120.0
	_state.racers[0].invulnerable = 120.0
	for _step: int in range(10000):
		if _state.racers[0].finish_time >= 0.0:
			break
		_advance(1.0 / 60.0, _center_steer())
	if _state.phase != "racing" or _state.racers[0].finish_time < 0:
		_failed = true
		push_error("ゴール待機画面の撮影条件に到達しなかった")
	await _capture("goal")
	for _step: int in range(4000):
		if _state.phase == "results":
			break
		_advance(1.0 / 60.0, _center_steer())
	if _state.phase != "results":
		_failed = true
		push_error("撮影用レースが結果画面に到達しなかった")
	for kart: Node3D in _main.karts:
		kart.play_state("celebrate")
	await create_timer(1.0).timeout
	_main.hud.refresh()
	await _capture("results")


func _center_steer() -> float:
	return clampf(-float(_state.racers[0].lateral) * 0.7 - 0.085, -0.7, 0.7)


# 撮影 fixture では音や描画のフレームを増やさず、走行状態だけを積分する。
func _advance(seconds: float, steer: float = 0.0, drift: bool = false) -> void:
	_state.tick(seconds, 1.0, steer, drift, false)
	_main._update_racers()
	_main._update_camera(1.0, true)
	_main._update_weapons()
	_main.hud.refresh()


func _capture(label: String, settle: float = 0.45) -> void:
	if settle > 0.0:
		await create_timer(settle).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		_failed = true
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
	else:
		print("screenshot: " + path)
