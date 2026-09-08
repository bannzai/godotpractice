extends Control
## 画面はSessionの投影。選択や説明の開閉だけをここで扱う。

const UI = preload("res://scripts/spirit_ui.gd")
const Background = preload("res://scripts/spirit_background.gd")
const BattleView = preload("res://scripts/battle_view.gd")
const Catalog = preload("res://scripts/card_catalog.gd")
const Actor = preload("res://scripts/spirit_actor.gd")
const Effects = preload("res://scripts/spirit_effects.gd")

var session: Node
var page: Control
var background: Control
var effects: Control
var sound: Node
var battle_view: Control
var last_screen: String = ""
var overlay: String = ""
var collection_page: int = 0
var refreshing: bool = false
var exiting: bool = false
var muted: bool = false
var seed_field: LineEdit
var status_text: String = ""
var pending_darkness: int = 0
var pending_gain: String = ""


func _ready() -> void:
	print("spiritboard boot")
	get_tree().auto_accept_quit = false
	session = get_node("/root/Session")
	theme = load("res://scenes/ui/theme.tres")
	background = Background.new()
	add_child(background)
	page = Control.new()
	page.size = Vector2(1280, 720)
	add_child(page)
	effects = Effects.new()
	effects.size = Vector2(1280, 720)
	add_child(effects)
	sound = load("res://scripts/spirit_audio.gd").new()
	add_child(sound)
	session.changed.connect(_schedule_refresh)
	session.event.connect(_session_event)
	refresh()


func _schedule_refresh() -> void:
	if refreshing or (is_instance_valid(battle_view) and battle_view.busy):
		return
	refreshing = true
	refresh.call_deferred()


func refresh() -> void:
	refreshing = false
	var focus_tag: String = ""
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused and page.is_ancestor_of(focused):
		focus_tag = str(focused.get_meta("tag", ""))
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	battle_view = null
	background.set_scene(session.screen)
	if overlay == "help":
		_help()
	elif overlay == "collection":
		_collection()
	else:
		match session.screen:
			"title":
				_title()
			"map":
				_map()
			"event":
				_event_screen()
			"battle":
				_battle()
			"result":
				_result()
	_footer()
	if last_screen != session.screen:
		last_screen = session.screen
		focus_tag = ""
		effects.transition()
		if session.screen == "map":
			background.scroll_map()
		var scene_music: String = session.screen
		if scene_music == "event":
			scene_music = "police" if _node_kind() == "police" else "map"
		elif scene_music == "battle":
			scene_music = {"general": "boss", "police": "police"}.get(
				session.board.enemy_id, "battle"
			)
		sound.play_scene(scene_music)
		sound.play_sfx("transition")
		if session.screen == "battle":
			sound.play_sfx("voice")
		if session.screen == "event" and _node_kind() in ["grave", "police"]:
			effects.entrance(session.event_title())
		elif session.screen == "battle" and session.board.enemy_id in ["general", "police"]:
			effects.entrance(Catalog.enemy(session.board.enemy_id).name)
	if pending_darkness > 0:
		effects.darkness()
		sound.play_sfx("darkness")
	elif pending_darkness < 0:
		effects.burst(Vector2(1100, 63), UI.JADE, "影が薄まる")
		sound.play_sfx("heal")
	if not pending_gain.is_empty():
		effects.burst(Vector2(640, 355), UI.JADE, Catalog.card(pending_gain).name + "と契約")
		sound.play_sfx("acquire")
	pending_darkness = 0
	pending_gain = ""
	if focus_tag.is_empty() and session.screen == "battle" and overlay.is_empty():
		focus_tag = "hand-0"
	_focus_first(focus_tag)


func _title() -> void:
	UI.art(page, "title_keyart", Rect2(540, 42, 705, 640))
	UI.art(page, "logo_mark", Rect2(74, 74, 64, 64))
	UI.label(page, "夜 を 渡 る、霊 と 生 き る。", Rect2(76, 158, 500, 35), 20, UI.GOLD)
	UI.label(page, "幽契の夜路", Rect2(70, 195, 600, 108), 76)
	UI.line(page, Vector2(78, 314), Vector2(470, 314))
	UI.label(
		page,
		"失くした名を探して、十の夜路へ。\n霊を集め、札に宿し、将軍の門を越える。\nその力は、あなたを少しずつ闇に変える。",
		Rect2(78, 341, 490, 104),
		22,
		UI.MUTED
	)
	UI.button(page, "新たな夜を歩く", Rect2(78, 471, 355, 55), _start_run, "new")
	var resume_button: Button = UI.button(
		page, "旅の続きを開く", Rect2(78, 539, 355, 48), _resume_run, "resume"
	)
	resume_button.disabled = not session.has_save()
	UI.label(page, "道の種", Rect2(78, 606, 88, 35), 18, UI.MUTED)
	seed_field = LineEdit.new()
	seed_field.position = Vector2(167, 601)
	seed_field.size = Vector2(266, 42)
	seed_field.placeholder_text = "空欄で新しい道"
	seed_field.max_length = 9
	seed_field.set_meta("tag", "seed")
	page.add_child(seed_field)
	if not status_text.is_empty():
		UI.label(page, status_text, Rect2(470, 617, 650, 38), 18, UI.RED)


# 開始は入力一回につき新しい旅を作るため非冪等。
func _start_run() -> void:
	var chosen_seed: int = int(Time.get_unix_time_from_system()) % 1000000000
	if seed_field and not seed_field.text.is_empty():
		if not seed_field.text.is_valid_int():
			status_text = "道の種は数字で入力してください。"
			refresh()
			return
		chosen_seed = int(seed_field.text)
	status_text = ""
	session.new_run(chosen_seed)


func _resume_run() -> void:
	if not session.load_game():
		status_text = "旅の記録を読み取れませんでした。新しい夜を始められます。"
		refresh()


func _header(subtitle: String) -> void:
	UI.label(page, "幽契の夜路", Rect2(34, 21, 310, 48), 30)
	UI.label(page, subtitle, Rect2(270, 27, 550, 38), 21, UI.GOLD)
	UI.line(page, Vector2(34, 80), Vector2(1246, 80), Color("687160"))
	if session.run.is_empty():
		return
	UI.label(
		page,
		"命  %s  ／  銭  %s" % [session.run.health, session.run.gold],
		Rect2(816, 28, 253, 37),
		22
	)
	UI.label(
		page,
		"闇  %s / 100" % session.run.darkness,
		Rect2(1080, 29, 170, 36),
		21,
		UI.RED if session.run.darkness >= 50 else UI.JADE
	)


func _map() -> void:
	_header("十の夜路  ─  %d / 10" % (session.run.depth + 1))
	UI.label(page, "次に結ぶ契りを選ぶ", Rect2(50, 110, 740, 45), 32)
	UI.label(page, "残した命を守るか。力のために闇へ近づくか。", Rect2(51, 159, 800, 36), 20, UI.MUTED)
	UI.panel(page, Rect2(966, 112, 276, 501), Color(0.055, 0.12, 0.14, 0.94))
	_actor(page, "hero", Rect2(994, 131, 219, 231))
	UI.label(page, "名を失くした旅人", Rect2(989, 364, 227, 32), 23, UI.PAPER, true)
	UI.label(
		page, "闇 50：霊の攻撃力 +1\n闇 80：命の上限が減少\n闇 100：あなたも霊になる", Rect2(989, 416, 229, 115), 19, UI.MUTED
	)
	UI.label(
		page,
		"契約した札  %d 枚\n道の種  %d" % [session.run.deck.size(), session.run.seed],
		Rect2(989, 538, 229, 70),
		18,
		UI.GOLD
	)
	UI.label(page, session.last_message, Rect2(51, 200, 895, 36), 20, UI.JADE)
	var rows: Array = session.run.nodes
	var current: int = int(session.run.depth)
	var start: int = maxi(0, current - 1)
	for depth: int in range(start, mini(rows.size(), start + 5)):
		var x: float = 96 + (depth - start) * 170
		var row: Array = rows[depth]
		UI.label(page, "%02d" % (depth + 1), Rect2(x, 236, 125, 32), 19, UI.GOLD, true)
		for branch: int in row.size():
			var node: Dictionary = row[branch]
			var kind: String = str(node.kind)
			var y: float = 298 + branch * 154
			if depth < rows.size() - 1 and depth < start + 4:
				for next_branch: int in (rows[depth + 1] as Array).size():
					UI.line(
						page,
						Vector2(x + 104, y + 42),
						Vector2(x + 175, 340 + next_branch * 154),
						Color("647161")
					)
			var node_button: Button = UI.button(
				page,
				"",
				Rect2(x, y, 115, 106),
				_select_node.bind(branch),
				"route-%d" % branch if depth == current else ""
			)
			node_button.disabled = depth != current
			UI.art(
				node_button, "node_" + ("boss" if kind == "elite" else kind), Rect2(30, 5, 56, 56)
			)
			UI.label(
				node_button,
				str(node.title),
				Rect2(3, 59, 110, 44),
				15,
				UI.GOLD if depth == current else UI.MUTED,
				true
			)
			if depth < current:
				node_button.modulate.a = 0.4
			elif depth > current:
				node_button.modulate.a = 0.68
	UI.label(page, "各列から一つを選んで進む。最後の将軍を倒せば夜明け。", Rect2(55, 594, 900, 40), 20, UI.PAPER)


func _select_node(branch: int) -> void:
	sound.play_sfx("card")
	session.choose_node(branch)


func _event_screen() -> void:
	var kind: String = _node_kind()
	_header(session.event_title())
	UI.art(page, "node_" + kind, Rect2(72, 152, 252, 252))
	var npc: String = "police" if kind == "police" else "merchant" if kind == "merchant" else "hero"
	_actor(page, npc, Rect2(75, 300, 262, 315))
	var prop: String = (
		"prop_coin" if kind == "merchant" else "prop_grave" if kind == "grave" else "prop_talisman"
	)
	UI.art(page, prop, Rect2(270, 532, 72, 72))
	UI.panel(page, Rect2(379, 115, 861, 514), Color(0.045, 0.10, 0.12, 0.93))
	UI.label(page, session.event_title(), Rect2(415, 139, 790, 55), 36)
	UI.label(page, session.event_description(), Rect2(416, 207, 775, 89), 23, UI.MUTED)
	var choices: Array = session.event_choices()
	for index: int in choices.size():
		var choice: Dictionary = choices[index]
		var spacing: float = minf(71.0, 313.0 / choices.size())
		var y: float = 306 + index * spacing
		var choice_button: Button = UI.button(
			page,
			str(choice.label),
			Rect2(416, y, 316, 53),
			_resolve_event.bind(str(choice.action)),
			"event-%d" % index
		)
		choice_button.disabled = not bool(choice.get("enabled", true))
		UI.label(page, str(choice.get("description", "")), Rect2(752, y + 4, 445, 57), 19, UI.MUTED)


func _resolve_event(action: String) -> void:
	sound.play_sfx("card")
	session.resolve_event(action)


func _battle() -> void:
	_header("霊の盤  ─  第 %d 手" % session.board.turn_number)
	battle_view = BattleView.new()
	page.add_child(battle_view)
	battle_view.setup(session, effects, sound)
	battle_view.render_requested.connect(_schedule_refresh)


func _result() -> void:
	var ending: String = str(session.run.get("result", "defeat"))
	var clear: bool = ending in ["clear", "victory"]
	var fallen: bool = ending in ["darkness", "fallen"]
	UI.art(page, "title_keyart", Rect2(665, 65, 570, 613))
	UI.panel(page, Rect2(66, 83, 700, 533), Color(0.055, 0.105, 0.12, 0.94))
	UI.label(
		page,
		"夜 明 け" if clear else "闇 に 還 る" if fallen else "途 切 れ た 契 り",
		Rect2(109, 117, 603, 77),
		49,
		UI.GOLD if clear else UI.RED
	)
	var narrative: String = "最後の門が開き、霊たちは静かに名を取り戻した。\nあなたの影はまだ、人の形をしている。"
	if fallen:
		narrative = "百の闇が胸に満ち、あなたの名が消えた。\n次の旅人が拾う札には、あなたの声が宿る。"
	elif not clear:
		narrative = "札が散り、夜路はここで途切れた。\nそれでも、結んだ霊の名は図鑑に残る。"
	UI.label(page, narrative, Rect2(111, 213, 598, 96), 23, UI.MUTED)
	UI.line(page, Vector2(111, 327), Vector2(715, 327))
	UI.label(page, "到達した夜路", Rect2(112, 353, 225, 35), 21, UI.MUTED)
	_count_label(mini(10, int(session.run.depth) + 1), Rect2(485, 347, 190, 43), " / 10")
	UI.label(page, "集めた霊", Rect2(112, 405, 225, 35), 21, UI.MUTED)
	_count_label((session.run.collected as Array).size(), Rect2(485, 399, 190, 43), " 体")
	UI.label(page, "最終闇堕ち度", Rect2(112, 457, 250, 35), 21, UI.MUTED)
	_count_label(int(session.run.darkness), Rect2(485, 451, 190, 43), " / 100")
	UI.button(page, "タイトルへ戻る", Rect2(111, 530, 599, 53), session.to_title, "title")
	if not session.run.collected.is_empty():
		UI.panel(page, Rect2(790, 510, 440, 133), Color(0.055, 0.105, 0.12, 0.96))
		UI.label(page, "この夜に結んだ霊", Rect2(810, 518, 400, 42), 23, UI.GOLD)
		var names: PackedStringArray = []
		for id: String in session.run.collected:
			var spirit_name: String = str(Catalog.card(id).name)
			if spirit_name not in names:
				names.append(spirit_name)
		UI.label(page, "・".join(names), Rect2(810, 565, 400, 72), 18, UI.MUTED)


# 結果の値は画面を開くたびに数え上げる。
func _count_label(value: int, rect: Rect2, suffix: String) -> void:
	var number: Label = UI.label(page, "0" + suffix, rect, 29, UI.GOLD)
	var tween: Tween = number.create_tween()
	tween.tween_method(
		func(current: float) -> void: number.text = str(roundi(current)) + suffix,
		0.0,
		float(value),
		0.5
	)


func _footer() -> void:
	UI.line(page, Vector2(34, 661), Vector2(1246, 661), Color("687160"))
	UI.label(page, "矢印 / 十字キー：選択　決定：Enter / A　戻る：Esc / B", Rect2(34, 676, 720, 30), 16, UI.MUTED)
	UI.button(page, "遊び方", Rect2(781, 674, 104, 33), _toggle_overlay.bind("help"), "help")
	UI.button(
		page, "霊の図鑑", Rect2(895, 674, 123, 33), _toggle_overlay.bind("collection"), "collection"
	)
	UI.button(page, "音：切" if muted else "音：入", Rect2(1028, 674, 96, 33), _toggle_sound, "sound")
	if session.screen != "title":
		UI.button(page, "中断・保存", Rect2(1134, 674, 112, 33), _save_title, "save")
	else:
		UI.button(page, "終了", Rect2(1134, 674, 112, 33), _quit_game, "quit")


func _toggle_overlay(which: String) -> void:
	if is_instance_valid(battle_view) and battle_view.busy:
		return
	overlay = "" if overlay == which else which
	collection_page = 0
	refresh()


func _help() -> void:
	_header("旅の手引き")
	UI.panel(page, Rect2(40, 111, 1200, 528), Color(0.035, 0.085, 0.10, 0.97))
	UI.label(page, "札を結び、盤を渡り、王を討つ", Rect2(72, 128, 1100, 52), 34)
	UI.label(page, "一　準備", Rect2(72, 205, 350, 39), 26, UI.GOLD)
	UI.label(
		page,
		"手札を選び、自陣の空きマスへ置く。\n「裏向きで置く」で潜伏できる。\n味方を選び、空きマスへ移動。\n隣の味方を選べば配置換え。\n動いた札は、この手では攻撃できない。",
		Rect2(72, 253, 350, 230),
		21
	)
	UI.label(page, "二　戦闘", Rect2(458, 205, 350, 39), 26, UI.GOLD)
	UI.label(
		page,
		"「戦闘へ」で攻撃の段階に進む。\n表向きの札から隣接する敵を選ぶ。\n攻撃力を比べ、勝った札が敵のマスへ。\n同値なら互いに消滅する。\n最奥中央から相手の王を直接攻撃。",
		Rect2(458, 253, 351, 230),
		21
	)
	UI.label(page, "三　夜路", Rect2(849, 205, 350, 39), 26, UI.GOLD)
	(
		UI
		. label(
			page,
			"墓場・命との契りで霊を集める。\n闇50で攻撃力が増し、80で命が減る。\n100になる前に休息や逃走を選ぶ。\n最後の将軍を倒すと夜明け。\n各操作のあと、旅は自動で保存される。",
			Rect2(849, 253, 350, 230),
			21
		)
	)
	UI.label(
		page, "戦闘へ：B / X　手を終える：E / Y　登場・潜伏：R / RB　全画面：F11", Rect2(72, 518, 1120, 43), 21, UI.JADE
	)
	UI.button(page, "旅へ戻る", Rect2(458, 575, 350, 45), _toggle_overlay.bind("help"), "close")


func _collection() -> void:
	_header("一度結んだ霊たち")
	var ids: Array = Catalog.CARDS.keys()
	var owned: Array = session.collection()
	var from: int = collection_page * 6
	for index: int in range(from, mini(from + 6, ids.size())):
		var id: String = str(ids[index])
		var card: Dictionary = Catalog.card(id)
		var x: float = 50 + (index - from) * 198
		var known: bool = id in owned
		UI.panel(page, Rect2(x, 134, 186, 440), Color("142a30"))
		UI.art(page, id if known else "card_back", Rect2(x + 8, 148, 170, 232))
		UI.label(
			page, str(card.name) if known else "未契約", Rect2(x + 10, 390, 166, 39), 25, UI.GOLD, true
		)
		UI.label(
			page,
			"攻撃 %s  ・  %s" % [card.atk, _rarity(int(card.rarity))] if known else "？？？",
			Rect2(x + 11, 435, 164, 30),
			17,
			UI.JADE,
			true
		)
		UI.label(
			page,
			str(card.description) if known else "夜路のどこかで\nあなたを待っている。",
			Rect2(x + 14, 479, 158, 87),
			18,
			UI.MUTED
		)
	UI.button(page, "前の頁", Rect2(50, 600, 180, 42), _turn_collection.bind(-1), "previous")
	UI.label(
		page,
		(
			"%d / %d　契約済み %d / %d"
			% [collection_page + 1, ceili(ids.size() / 6.0), owned.size(), ids.size()]
		),
		Rect2(385, 606, 509, 33),
		20,
		UI.GOLD,
		true
	)
	UI.button(page, "次の頁", Rect2(1045, 600, 185, 42), _turn_collection.bind(1), "next")


func _turn_collection(direction: int) -> void:
	collection_page = posmod(collection_page + direction, ceili(Catalog.CARDS.size() / 6.0))
	refresh()


func _rarity(value: int) -> String:
	return Catalog.RARITIES[clampi(value, 0, 2)]


func _actor(parent: Node, id: String, rect: Rect2) -> Control:
	var actor: Control = Actor.new()
	parent.add_child(actor)
	actor.position = rect.position
	actor.setup(id, rect.size)
	return actor


func _node_kind() -> String:
	var node: Dictionary = session.run.get("current_node", {})
	return str(node.get("kind", "battle"))


func _session_event(data: Dictionary) -> void:
	if str(data.get("type", "")) == "darkness":
		pending_darkness += int(data.get("amount", 0))
	elif str(data.get("type", "")) == "gain":
		pending_gain = str(data.card)


func _save_title() -> void:
	if is_instance_valid(battle_view) and battle_view.busy:
		return
	overlay = ""
	session.save_game()
	session.to_title()


func _toggle_sound() -> void:
	if is_instance_valid(battle_view) and battle_view.busy:
		return
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	refresh()


func _focus_first(tag: String) -> void:
	var buttons: Array[Button] = []
	_find_buttons(page, buttons)
	if buttons.is_empty():
		return
	for button: Button in buttons:
		if not tag.is_empty() and str(button.get_meta("tag", "")) == tag:
			button.grab_focus()
			return
	buttons[0].grab_focus()


func _find_buttons(parent: Node, found: Array[Button]) -> void:
	for child: Node in parent.get_children():
		if child is Button and not child.disabled:
			found.append(child)
		_find_buttons(child, found)


func _unhandled_input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed("fullscreen"):
		var fullscreen: bool = (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if fullscreen
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
		get_viewport().set_input_as_handled()
	elif input_event.is_action_pressed("ui_cancel"):
		if not overlay.is_empty():
			overlay = ""
			refresh()
		elif battle_view:
			battle_view.cancel_selection()
		else:
			_toggle_overlay("help")
		get_viewport().set_input_as_handled()


func stop_audio() -> void:
	if is_instance_valid(sound):
		sound.stop_audio()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if exiting:
		return
	exiting = true
	if session and not session.run.is_empty():
		session.save_game()
	await sound.shutdown()
	get_tree().quit(0)
