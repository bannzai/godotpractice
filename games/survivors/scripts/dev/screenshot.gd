extends SceneTree
## 代表画面を同じ乱数種と状態から再現し、実際のレンダラで撮影する。

var main: Node
var state: Node


func _initialize() -> void:
	_run.call_deferred()


# 時間を進めながら順番に撮影する検証イベントなので再入しない。
func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	if await _capture_scenes():
		quit(0)


func _capture_scenes() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("RunState")
	await create_timer(0.5).timeout
	if not await _capture("title"):
		return false
	state.start_run(77)
	state.weapons = {"bolt": 3, "orbit": 3, "pulse": 3}
	state.elapsed = 315.0
	state.level = 18
	state.kills = 426
	state.hp = 74.0
	for i: int in range(56):
		var at: Vector2 = Vector2.from_angle(i * 2.399) * (150 + i * 6)
		state.spawn_enemy(i % 3, at)
	for i: int in range(24):
		state.gems.append({"pos": Vector2.from_angle(i * 2.399) * (100 + i * 9), "value": 2})
	state.items.append({"pos": Vector2(150, 50), "kind": "heal"})
	state.items.append({"pos": Vector2(-170, 70), "kind": "magnet"})
	await create_timer(0.3).timeout
	main.set_process(false)
	if not await _capture("play"):
		return false
	state.effects.append({"pos": state.player_pos, "age": 0.3, "kind": "pulse", "text": ""})
	state.effects.append({"pos": Vector2(130, -70), "age": 0.25, "kind": "death", "text": "42"})
	main.queue_redraw()
	if not await _capture("effects"):
		return false
	state.gain_xp(100)
	main.call("_refresh_screen")
	main.queue_redraw()
	if not await _capture("upgrade"):
		return false
	state.finish_run(false)
	main.call("_refresh_screen")
	main.queue_redraw()
	if not await _capture("defeat"):
		return false
	state.start_run(77)
	state.elapsed = 600.0
	state.kills = 1306
	state.level = 32
	state.finish_run(true)
	main.call("_refresh_screen")
	main.queue_redraw()
	var captured: bool = await _capture("clear")
	main.queue_free()
	await process_frame
	return captured


func _capture(label: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true
