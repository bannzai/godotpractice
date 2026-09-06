extends SceneTree
## 固定した画面・戦闘状態と、本番の演出から描画証拠を作る。
## 入力経路と勝敗の成立はintegration/demo/selfcheckが別途検証する。

const AudioStop = preload("res://scripts/dev/audio_stop.gd")
const Catalog = preload("res://scripts/card_catalog.gd")
const Gallery = preload("res://scripts/dev/gallery.gd")

var main: Control
var session: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 撮影一式を一度だけ順番に進める。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	session = root.get_node("Session")
	session.save_enabled = false
	session.save_path = "res://tmp/screenshots-save.json"
	session.collection_path = "res://tmp/screenshots-collection.json"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _capture_scenes()
	AudioStop.stop(root)
	await create_timer(0.25).timeout
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await _settle()
	await _capture("title")
	session.new_run(222223)
	await _settle()
	await _capture("map")
	main.overlay = "help"
	main.refresh()
	await _capture("help")
	main.overlay = "collection"
	session.discovered.assign(Catalog.CARDS.keys())
	for page: int in range(2):
		main.collection_page = page
		main.refresh()
		await _capture("collection-%d" % (page + 1))
	main.overlay = ""
	for kind: String in ["grave", "hunt", "police", "rest", "merchant"]:
		_enter_kind(kind)
		await _settle()
		await _capture("event-" + kind)
	_enter_kind("police")
	session.resolve_event("fight")
	await _settle()
	await _capture("police-battle")
	_enter_kind("boss")
	await _settle()
	await _capture("boss-battle")
	_battle_fixture(3)
	await _settle()
	await _capture("battle-small")
	_battle_fixture(5)
	await _settle()
	await _capture("battle-wide")
	await _capture_effects()
	await _capture_results()
	await _capture_characters()


func _enter_kind(kind: String) -> void:
	session.new_run(222223)
	for depth: int in range(10):
		for branch: int in range(2):
			if str(session.run.nodes[depth][branch].kind) == kind:
				session.run.depth = depth
				session.choose_node(branch)
				return
	push_error("撮影対象のノードがありません: " + kind)
	failed = true


func _battle_fixture(width: int) -> void:
	_enter_kind("battle")
	session.run.depth = 4 if width == 5 else 0
	session.board.setup(session.run.deck, width, 222223, 8, 54, "ghost")
	session.run.health = 8
	session.run.darkness = 54
	var middle: int = width / 2
	session.board.units.assign(
		[
			_unit(1, "lantern", 0, width * 2 + middle),
			_unit(2, "fox", 0, width * 2 + middle + 1, false),
			_unit(3, "bell", 0, width * 3 + middle),
			_unit(4, "willow", 1, width + middle, false),
			_unit(5, "mask", 1, middle + 1),
			_unit(6, "crow", 1, width + middle - 1)
		]
	)
	session.board.next_uid = 7
	session.board.hands[0] = ["crow", "monk", "spider", "hound"]
	session.board.deployed = false
	main.refresh()


func _unit(uid: int, card: String, side: int, pos: int, face: bool = true) -> Dictionary:
	return {
		"uid": uid,
		"card": card,
		"side": side,
		"pos": pos,
		"face": face,
		"moved": false,
		"attacked": false,
		"flipped": false
	}


func _capture_effects() -> void:
	_battle_fixture(3)
	await _settle()
	main.battle_view._execute("deploy", 0, 6)
	await _sequence("placement")
	_battle_fixture(3)
	await _settle()
	main.battle_view._execute("flip", 8)
	await _sequence("flip")
	_battle_fixture(3)
	await _settle()
	main.battle_view._execute("move", 7, 6)
	await _sequence("move")
	_battle_fixture(3)
	session.board.phase = "battle"
	main.refresh()
	await _settle()
	main.battle_view._execute("attack", 7, 4)
	await _sequence("attack-and-vanish")
	_battle_fixture(3)
	session.board.at(7).pos = 1
	session.board.phase = "battle"
	main.refresh()
	await _settle()
	main.battle_view._execute("attack", 1, -2)
	await _sequence("king-hit")
	session.to_title()
	await _settle()
	main.effects.darkness()
	await create_timer(0.12).timeout
	await _capture("effect-darkness")
	await _settle()
	main.effects.burst(Vector2(640, 350), Color("8bcebb"), "新しい契り +1")
	await create_timer(0.2).timeout
	await _capture("effect-acquire")
	for kind: String in ["grave", "police", "boss"]:
		_enter_kind(kind)
		await create_timer(0.24).timeout
		await _capture("entrance-" + kind)
		await _settle()
	session.new_run(222223)
	await create_timer(0.1).timeout
	await _capture("effect-map-scroll")
	await _settle()
	main.effects.transition()
	await create_timer(0.1).timeout
	await _capture("effect-transition")


func _sequence(name: String) -> void:
	await create_timer(0.045).timeout
	await _capture("effect-%s-start" % name)
	await create_timer(0.22).timeout
	await _capture("effect-%s-middle" % name)
	await create_timer(0.64).timeout
	await _capture("effect-%s-end" % name)
	await _settle()


func _capture_results() -> void:
	for ending: String in ["defeat", "clear", "darkness"]:
		session.new_run(222223)
		session.run.depth = 10 if ending == "clear" else 6
		session.run.darkness = 100 if ending == "darkness" else 54
		session.run.collected = ["mask", "hound", "dragon", "empress"]
		session.run.result = ending
		session.screen = "result"
		main.refresh()
		await _settle()
		await _capture("result-" + ending)
	session.to_title()
	await _settle()
	await _capture("return-title")


func _capture_characters() -> void:
	main.hide()
	var gallery: Control = Gallery.new()
	root.add_child(gallery)
	var characters: Array = ["hero", "ghost", "general", "police", "merchant"]
	characters.append_array(Catalog.CARDS.keys())
	for id: String in characters:
		gallery.setup(id)
		await _capture("character-" + id)
	gallery.queue_free()
	main.show()
	await process_frame


func _settle() -> void:
	await create_timer(1.3).timeout


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("撮影に失敗: %s" % name)
		failed = true
	else:
		print("screenshot: " + path)
