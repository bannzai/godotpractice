extends SceneTree
## 本番シーンを使って探索・攻撃途中・結果・保存再開を撮影する。

var main: Control
var game: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 同じツリーで操作を順番に実行するため非冪等。
func _run() -> void:
	if await _capture_scenes():
		await preload("res://scripts/dev/input_checks.gd").run(_check, self)
		quit(1 if failed else 0)


func _capture_scenes() -> bool:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await create_timer(0.3).timeout
	if not await _capture("title"):
		return false
	main._show_help()
	if not await _capture("help"):
		return false
	main.start_new()
	await create_timer(0.1).timeout
	if not await _capture("town"):
		return false
	game.zone = "route"
	game.cell = Vector2i(4, 4)
	main.notice = "草むらで足音がする。新しい仲間がいるかもしれない。"
	main.refresh()
	if not await _capture("route"):
		return false
	for zone: String in ["home", "clinic"]:
		game.zone = zone
		game.cell = Vector2i(11, 11)
		main.notice = "回復と補充は何度でも無料。旅の仲間を大切に。"
		main.refresh()
		if not await _capture(zone):
			return false
	return await _capture_combat()


func _capture_combat() -> bool:
	for id: String in ["tide", "sprout", "moth", "crab", "owl"]:
		game.party.append(Catalog.create_monster(id, 6))
	game.storage.append(Catalog.create_monster("owl", 4))
	main.open_menu()
	if not await _capture("party"):
		return false
	main._show_storage()
	if not await _capture("storage"):
		return false
	main.close_menu()
	await main.begin_battle("sprout", 5, false)
	if not await _capture("battle"):
		return false
	main.battle_turn("attack", Catalog.moves(game.party[0])[0])
	await create_timer(0.25).timeout
	if not await _capture("attack"):
		return false
	while main.busy:
		await process_frame
	game.mode = "field"
	await main.begin_battle("crab", 8, true)
	if not await _capture("trainer"):
		return false
	return await _capture_results()


func _capture_results() -> bool:
	game.mode = "clear"
	main.refresh()
	if not await _capture("clear"):
		return false
	game.mode = "gameover"
	main.refresh()
	if not await _capture("gameover"):
		return false
	main.retry()
	if game.mode != "field" or game.party[0].hp != Catalog.stats(game.party[0]).hp:
		push_error("全滅後の回復再開が成立しない")
		quit(1)
		return false
	main.to_title()
	if not await _capture("return-title"):
		return false
	main.music.stop()
	main.sound.stop()
	await create_timer(0.15).timeout
	main.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	return true


func _capture(screen: String) -> bool:
	await process_frame
	await process_frame
	var path: String = "tmp/screenshot-%s.png" % screen
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		quit(1)
		return false
	print("screenshot: " + path)
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("入力検証: " + message)
