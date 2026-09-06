extends SceneTree
## 本番シーンと実際に進行したアニメーションを撮影し、途中と終了を証拠として残す。

const CHARACTERS: Array[String] = [
	"ember", "tide", "sprout", "moth", "crab", "owl", "player", "captain", "healer", "crab_captain",
]

var main: Control
var game: Node
var failed: bool = false


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 同じツリーで操作を順番に実行するため非冪等。
func _run() -> void:
	var captured: bool = await _capture_scenes()
	await _dispose_main()
	if captured:
		await preload("res://scripts/dev/input_checks.gd").run(_check, self)
	quit(1 if failed or not captured else 0)


func _capture_scenes() -> bool:
	game = root.get_node("Game")
	game.new_game()
	game.mode = "title"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	if not await _capture("title", 0.4):
		return false
	main._show_help()
	if not await _capture("help"):
		return false
	main.start_new()
	if not await _capture("transition-play-mid", 0.10):
		return false
	if not await _capture("town", 0.3):
		return false
	if not await _capture_locations():
		return false
	return await _capture_combat()


func _capture_locations() -> bool:
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
	return true


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
	if not await _capture("battle", 0.4):
		return false
	if not await _capture_first_attack():
		return false
	game.mode = "field"
	await main.begin_battle("crab", 8, true)
	if not await _capture("trainer", 0.4):
		return false
	return await _capture_polish()


func _capture_first_attack() -> bool:
	if not _start_attack("spark"):
		return false
	if not await _capture("attack", 0.25):
		return false
	if not await _capture("attack-fire", 0.19):
		return false
	return await _settle()


func _capture_polish() -> bool:
	if not await _capture_animations():
		return false
	if not await _capture_attributes():
		return false
	if not await _capture_items():
		return false
	if not await _capture_level_and_defeat():
		return false
	return await _capture_results()


func _capture_attributes() -> bool:
	for fixture: Array in [["tide", "ember", "drop", "water"], ["sprout", "tide", "seed", "leaf"]]:
		await _prepare_battle(fixture[0], fixture[1])
		if not _start_attack(fixture[2]):
			return false
		if not await _capture("attack-" + fixture[3], 0.51):
			return false
		if not await _settle():
			return false
	return true


func _capture_items() -> bool:
	for success: bool in [true, false]:
		await _prepare_battle("ember", "tide")
		game.enemy.hp = 1 if success else Catalog.stats(game.enemy).hp
		preload("res://scripts/dev/logic_checks.gd")._seed_capture(game, success)
		main.refresh()
		main.battle_turn("capture", "")
		if not await _capture("capture-success" if success else "capture-failure", 1.16):
			return false
		if not await _settle():
			return false
	await _prepare_battle("ember", "sprout")
	game.party[0].hp = 10
	main.refresh()
	main.battle_turn("potion", "")
	if not await _capture("heal", 0.20):
		return false
	return await _settle()


func _capture_level_and_defeat() -> bool:
	await _prepare_battle("ember", "sprout", 5)
	game.enemy.hp = 1
	main.refresh()
	if not _start_attack("spark"):
		return false
	return await _capture_defeat_and_growth()


func _capture_defeat_and_growth() -> bool:
	if not await _wait_defeat(false):
		return false
	if not await _capture("defeat-mid", 0.17):
		return false
	if not await _wait_defeat(true):
		return false
	if not await _capture("defeat-end", 0.0):
		return false
	return await _capture_growth()


func _capture_growth() -> bool:
	var deadline: int = Time.get_ticks_msec() + 5000
	while is_instance_valid(main.battle_message) and main.busy \
		and not main.battle_message.text.contains("成長") and Time.get_ticks_msec() < deadline:
		await process_frame
	var reached: bool = is_instance_valid(main.battle_message) \
		and main.battle_message.text.contains("成長")
	_check(reached, "レベルアップの演出へ到達する")
	if not reached:
		return false
	if not await _capture("levelup", 0.15):
		return false
	return await _settle()


func _capture_results() -> bool:
	game.mode = "clear"
	main.refresh()
	if not await _capture("transition-result-mid", 0.10):
		return false
	if not await _capture("clear", 0.30):
		return false
	game.mode = "gameover"
	main.refresh()
	if not await _capture("gameover", 0.4):
		return false
	main.retry()
	_check(game.mode == "field" and game.party[0].hp == Catalog.stats(game.party[0]).hp,
		"全滅後に仲間が回復した状態で町から再開する")
	main.to_title()
	if not await _capture("transition-title-mid", 0.10):
		return false
	return await _capture("return-title", 0.30)


func _prepare_battle(lead: String, enemy: String, level: int = 10) -> void:
	game.new_game()
	game.party = [Catalog.create_monster(lead, level)]
	game.zone = "route"
	game.cell = Vector2i(4, 4)
	main.refresh()
	await main.begin_battle(enemy, mini(level, 6), false)
	await create_timer(0.35).timeout


## 実際のターンでダメージを与えてから、攻撃の途中を撮るため非冪等。
func _start_attack(move_id: String) -> bool:
	var hp_before: int = game.enemy.hp
	main.battle_turn("attack", move_id)
	var started: bool = main.busy and game.enemy.hp < hp_before \
		and main.battle_message.text.contains(Catalog.MOVES[move_id].name)
	_check(started, "選択した技が成立して、攻撃演出が始まる: " + Catalog.MOVES[move_id].name)
	return started


func _wait_defeat(finished: bool) -> bool:
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if not is_instance_valid(main.enemy_picture) or not main.busy:
			break
		if main.enemy_picture.sprite.animation == "defeat":
			if not finished or not main.enemy_picture.sprite.is_playing():
				return true
		await process_frame
	_check(false, "倒れるアニメーションの%sを確認できる" % ("終了" if finished else "開始"))
	return false


func _settle() -> bool:
	var deadline: int = Time.get_ticks_msec() + 10000
	while main.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not main.busy, "戦闘演出が制限時間内に終了する")
	return not main.busy


func _capture_animations() -> bool:
	main.visible = false
	for id: String in CHARACTERS:
		if not await _capture_character(id):
			main.visible = true
			return false
	main.visible = true
	return true


func _capture_character(id: String) -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 1180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Control.new()
	board.size = Vector2(1280, 1180)
	board.theme = main.theme
	viewport.add_child(board)
	var paper := ColorRect.new()
	paper.color = Color("edf0df")
	paper.size = board.size
	board.add_child(paper)
	_board_label(board, _character_name(id) + " / 実時間のアニメーション", Vector2(42, 26), 36)
	_board_label(board, "実際に再生したフレームを捕捉。画像やフレーム番号の手動切り替えは不使用。",
		Vector2(42, 80), 21)
	var actors: Array[QuestActor] = _populate_board(board, id)
	var deadline: int = Time.get_ticks_msec() + 4000
	while actors.any(func(actor: QuestActor) -> bool: return actor.sprite.is_playing()) \
		and Time.get_ticks_msec() < deadline:
		await process_frame
	var complete: bool = true
	for index: int in actors.size():
		var target: int = [0, 2, 5][index % 3]
		if actors[index].sprite.frame != target or actors[index].sprite.is_playing():
			complete = false
	_check(complete, "全動作が開始・途中・終盤へ実際に進行: " + id)
	await RenderingServer.frame_post_draw
	var status: Error = viewport.get_texture().get_image().save_png(
		"tmp/screenshot-animations-%s.png" % id
	)
	_check(status == OK, "連続フレームを保存: " + id)
	print("screenshot: tmp/screenshot-animations-%s.png / 全 5 動作・実再生 frame 0, 2, 5" % id)
	viewport.queue_free()
	await process_frame
	await process_frame
	return complete and status == OK


func _populate_board(board: Control, id: String) -> Array[QuestActor]:
	var actors: Array[QuestActor] = []
	for column: int in 3:
		_board_label(board, ["開始 / フレーム 0", "途中 / フレーム 2", "終盤 / フレーム 5"][column],
			Vector2(342 + column * 294, 124), 24)
	for row: int in QuestActor.ACTIONS.size():
		var card := ColorRect.new()
		card.position = Vector2(28, 174 + row * 196)
		card.size = Vector2(1224, 186)
		card.color = Color("ffffff") if row % 2 == 0 else Color("f8f5e7")
		board.add_child(card)
		_board_label(board, ["待機", "移動", "攻撃", "被弾", "倒れる"][row],
			Vector2(66, 226 + row * 196), 30)
		for column: int in 3:
			var actor := QuestActor.new()
			board.add_child(actor)
			actor.setup(id, Rect2(354 + column * 294, 168 + row * 196, 192, 192))
			actor.set_action(QuestActor.ACTIONS[row])
			var frame: int = [0, 2, 5][column]
			if frame == 0:
				actor.sprite.pause()
			else:
				actor.sprite.frame_changed.connect(_pause_at_frame.bind(actor.sprite, frame))
			actors.append(actor)
	return actors


func _pause_at_frame(sprite: AnimatedSprite2D, frame: int) -> void:
	if sprite.frame == frame:
		sprite.pause()


func _board_label(board: Control, text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("24483f"))
	board.add_child(label)


func _character_name(id: String) -> String:
	if Catalog.SPECIES.has(id):
		return Catalog.SPECIES[id].name
	return {"player": "調査隊員", "captain": "隊長 ヒナギク", "healer": "回復の家の案内人",
		"crab_captain": "隊長のアワガニ"}[id]


func _capture(screen: String, delay: float = 0.08) -> bool:
	if delay > 0.0:
		await create_timer(delay).timeout
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "tmp/screenshot-%s.png" % screen
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	_check(status == OK, "スクリーンショット保存: %s (%s)" % [path, error_string(status)])
	if status == OK:
		print("screenshot: " + path)
	return status == OK


func _dispose_main() -> void:
	if not is_instance_valid(main):
		return
	main.stop_audio()
	for frame: int in 12:
		await process_frame
	main.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("撮影検証: " + message)
