extends RefCounted
## 進行状態を参照して画面を構築する。ゲーム状態は変更しない。

const UI = preload("res://scripts/ui/widgets.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Actor = preload("res://scripts/visual/actor.gd")
const Card = preload("res://scripts/ui/card.gd")
const NODE_NAMES: Dictionary = {
	"battle": "街道の戦",
	"general": "将軍の陣",
	"final": "最後の天守",
	"reward": "札の社",
	"rest": "灯の宿",
	"shop": "旅の商人"
}
const NODE_PREVIEWS: Dictionary = {
	"battle": "街道で札勝負・通常の盤",
	"general": "険路の将軍・強敵と希少札",
	"final": "最後の天守・旅の決着",
	"reward": "札の社・新しい札を一枚",
	"rest": "灯の宿・王を4回復",
	"shop": "旅の商人・購入と札整理"
}
const MAP_POINTS: Array = [
	[Vector2(120, 445), Vector2(148, 548)],
	[Vector2(247, 383), Vector2(278, 516)],
	[Vector2(382, 438), Vector2(408, 315)],
	[Vector2(516, 351), Vector2(548, 492)],
	[Vector2(654, 292), Vector2(684, 430)],
	[Vector2(786, 363), Vector2(819, 513)],
	[Vector2(920, 306), Vector2(948, 446)],
	[Vector2(1041, 241), Vector2(1070, 388)],
	[Vector2(1162, 285)],
]


static func render(main: Control) -> void:
	match main.run.stage:
		"title":
			_title(main)
		"map":
			_map(main)
		"battle":
			_battle(main)
		"reward":
			_reward(main)
		"rest":
			_rest(main)
		"shop":
			_shop(main)
		"result":
			_result(main)
	if main.run.stage != "title":
		_header(main)


static func _title(main: Control) -> void:
	var veil := ColorRect.new()
	veil.color = Color("24170e42")
	veil.size = Vector2(1280, 720)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.content.add_child(veil)
	UI.scroll_panel(main.content, Rect2(52, 54, 514, 604), Color("f2dfb8ee"))
	UI.label(main.content, "墨\n将\n紀", Rect2(91, 86, 75, 228), 55, UI.INK)
	UI.label(main.content, "霧 の 九 峠", Rect2(187, 100, 320, 51), 30, UI.RED)
	UI.paragraph(main.content, "一枚を伏せ、一手を読む。\n王を守り、霧の先に道を描け。", Rect2(190, 177, 320, 86), 24)
	UI.label(main.content, "水墨札棋ローグライク", Rect2(188, 278, 320, 34), 17, UI.MUTED)
	main.seed_input = LineEdit.new()
	main.seed_input.name = "seed"
	main.seed_input.position = Vector2(235, 351)
	main.seed_input.size = Vector2(270, 42)
	main.seed_input.placeholder_text = "空欄なら新しい旅路"
	main.seed_input.max_length = 9
	main.content.add_child(main.seed_input)
	UI.label(main.content, "旅路の種", Rect2(90, 357, 137, 38), 18, UI.MUTED)
	main.first_focus = UI.button(
		main.content, "start", "新しい旅を始める", Rect2(89, 419, 416, 56), main.start_run
	)
	var resume: Button = UI.button(
		main.content, "resume", "旅の続きを再開", Rect2(89, 487, 416, 46), main.resume_run
	)
	resume.disabled = not main.run.has_save()
	UI.button(
		main.content, "book", "札の図鑑", Rect2(89, 550, 198, 43), main._show_overlay.bind("book")
	)
	UI.button(
		main.content, "help", "遊び方", Rect2(307, 550, 198, 43), main._show_overlay.bind("help")
	)
	UI.label(main.content, "道中の手引きは盤上に現れます", Rect2(150, 610, 355, 28), 16, UI.MUTED)


static func _header(main: Control) -> void:
	UI.scroll_panel(main.content, Rect2(20, 15, 1240, 65), Color("f0ddb5ef"))
	UI.label(main.content, "墨将紀", Rect2(43, 22, 158, 49), 31, UI.RED)
	main.hero_actor = _actor(main.content, "hero", Vector2(198, 47), 0.16)
	var hp: int = main.run.king_hp
	if main.run.stage == "battle":
		hp = main.run.battle.hp[0]
	UI.label(main.content, "王  %d / 10" % hp, Rect2(220, 34, 165, 34), 20, UI.PAPER)
	UI.label(main.content, "銭  %d" % main.run.gold, Rect2(392, 34, 130, 34), 20, UI.GOLD)
	UI.label(main.content, "札  %d 枚" % main.run.deck.size(), Rect2(523, 34, 154, 34), 20, UI.MUTED)
	UI.label(main.content, "第 %d / 9 峠" % maxi(1, main.run.depth + 1), Rect2(675, 34, 170, 34), 20)
	UI.button(main.content, "deck", "所持札", Rect2(881, 29, 106, 40), main._show_overlay.bind("deck"))
	UI.button(
		main.content, "help", "遊び方", Rect2(1001, 29, 111, 40), main._show_overlay.bind("help")
	)
	UI.button(
		main.content, "pause", "旅の休止", Rect2(1126, 29, 111, 40), main._show_overlay.bind("pause")
	)


static func _map(main: Control) -> void:
	UI.scroll_panel(main.content, Rect2(21, 91, 1238, 608), Color("f3e2bdae"))
	UI.label(main.content, "街\n道\n絵\n巻", Rect2(45, 105, 48, 180), 28, UI.INK)
	UI.label(main.content, "霧の九峠を越え、右上の天守へ", Rect2(109, 103, 680, 47), 34, UI.INK)
	UI.label(main.content, "朱印が現在地。明るい札が、いま選べる道。", Rect2(112, 150, 700, 31), 19, UI.MUTED)
	var canvas := Control.new()
	canvas.name = "route_scroll"
	canvas.size = Vector2(1280, 720)
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	main.content.add_child(canvas)
	for depth: int in range(9):
		var nodes: Array = main.run.route[depth]
		for lane: int in range(nodes.size()):
			var item: Dictionary = nodes[lane]
			var point: Vector2 = MAP_POINTS[depth][mini(lane, MAP_POINTS[depth].size() - 1)]
			if depth < 8:
				for next_lane: int in range(main.run.route[depth + 1].size()):
					var next_points: Array = MAP_POINTS[depth + 1]
					var next_point: Vector2 = next_points[mini(next_lane, next_points.size() - 1)]
					var line := Line2D.new()
					line.width = 4
					line.default_color = Color(UI.INK, 0.34)
					line.points = PackedVector2Array(
						[point, (point + next_point) / 2 + Vector2(0, 13), next_point]
					)
					canvas.add_child(line)
			var button: Button = UI.button(
				canvas,
				"route_%d_%d" % [depth, lane],
				"",
				Rect2(point - Vector2(38, 34), Vector2(76, 68)),
				main.choose_node.bind(lane)
			)
			button.disabled = depth != main.run.depth + 1
			if depth == main.run.depth + 1 and lane == 0:
				main.first_focus = button
			var icon: String = "merchant" if item.type == "shop" else item.type
			UI.picture(button, "res://assets/art/route_%s.svg" % icon, Rect2(20, 5, 36, 36))
			var title: Label = UI.label(
				button,
				NODE_NAMES[item.type],
				Rect2(-18, 42, 112, 24),
				14,
				UI.RED if item.type in ["general", "final"] else UI.INK
			)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if depth <= main.run.depth:
				button.modulate.a = 0.42
			elif depth == main.run.depth:
				UI.label(canvas, "● 現在", Rect2(point.x - 33, point.y + 39, 80, 22), 14, UI.RED)
			if depth == main.run.depth + 1:
				var preview_y: float = 584.0 + lane * 49.0
				UI.panel(canvas, Rect2(154 + lane * 493, preview_y, 470, 42), Color("f4e4c7ed"))
				UI.label(
					canvas,
					"%s　—　%s" % [NODE_NAMES[item.type], NODE_PREVIEWS[item.type]],
					Rect2(169 + lane * 493, preview_y + 8, 443, 27),
					17,
					UI.INK
				)
	UI.label(main.content, "旅路の種  %d" % main.run.seed_value, Rect2(978, 103, 250, 28), 15, UI.GOLD)


static func _battle(main: Control) -> void:
	var battle: RefCounted = main.run.battle
	UI.scroll_panel(main.content, Rect2(27, 103, 273, 402), Color("f1dfb9ed"))
	UI.scroll_panel(main.content, Rect2(971, 103, 282, 402), Color("e8d2a9ed"))
	UI.scroll_panel(main.content, Rect2(310, 121, 649, 397), Color("ead6a49c"))
	var start_x: float = 640.0 - battle.width * 52.0
	UI.label(main.content, "敵\n陣", Rect2(324, 161, 29, 75), 18, UI.RED)
	UI.label(main.content, "自\n陣", Rect2(324, 365, 29, 75), 18, UI.JADE)
	for y: int in range(4):
		for x: int in range(battle.width):
			var pos := Vector2i(x, y)
			var unit: Dictionary = battle.unit_at(pos)
			var card := Card.new()
			card.name = "cell_%d_%d" % [x, y]
			card.position = Vector2(start_x + x * 104 + 3, 138 + y * 84 + 3)
			card.size = Vector2(98, 78)
			card.board_pos = pos
			card.side = 1 if y < 2 else 0
			if not unit.is_empty():
				card.card_id = unit.card
				card.side = unit.side
				card.unit_uid = unit.uid
				card.face_down = not unit.face
				card.concealed = unit.side == 1 and not unit.face
				card.selected = main.selected_uid == unit.uid
				card.exhausted = unit.moved or unit.attacked
			elif main.selected_hand >= 0 and y >= 2:
				card.legal = true
			card.legal = _legal_target(main, pos, unit)
			card.pressed.connect(main._click_cell.bind(pos))
			card.dragged.connect(main._drag_card)
			main.content.add_child(card)
			main.cell_nodes[pos] = card
			if y == 2 and x == battle.width / 2:
				main.first_focus = card
	var enemy_king: Button = UI.button(
		main.content,
		"enemy_king",
		"敵王  %d" % battle.hp[1],
		Rect2(580, 90, 120, 37),
		main._attack_king
	)
	var selected: Dictionary = battle.unit_by_id(main.selected_uid)
	var king_legal: bool = not selected.is_empty() and battle.can_attack(main.selected_uid)
	enemy_king.disabled = not king_legal
	enemy_king.add_theme_color_override("font_color", UI.RED)
	if king_legal:
		enemy_king.add_theme_stylebox_override("normal", UI.box(Color("f6dfb8"), UI.RED))
	UI.panel(main.content, Rect2(580, 484, 120, 34), Color("ead8a9e8"))
	UI.label(main.content, "王  %d" % battle.hp[0], Rect2(604, 486, 105, 32), 19, UI.JADE)
	UI.label(main.content, "%d 手目" % battle.turn_number, Rect2(727, 489, 160, 25), 16, UI.MUTED)
	_detail(main)
	_opponent(main)
	_hand(main)
	var phase: String = "先\n手\n布\n陣" if battle.phase == "standby" else "先\n手\n攻\nめ"
	if battle.turn == 1:
		phase = "敵\nの\n手\n番"
	UI.panel(main.content, Rect2(922, 142, 31, 139), Color("e0c38eea"))
	UI.label(main.content, phase, Rect2(926, 149, 24, 128), 18, UI.RED)
	UI.scroll_panel(main.content, Rect2(971, 516, 282, 124), Color("f3e1bbed"))
	var instruction: String = _tutorial_text(main) if main.tutorial_active else main.note
	UI.paragraph(main.content, instruction, Rect2(990, 529, 243, 96), 16)
	if main.tutorial_active:
		var skip: Button = UI.button(
			main.content,
			"tutorial_skip",
			"手ほどきを省く",
			Rect2(1085, 604, 142, 27),
			main._skip_tutorial
		)
		skip.add_theme_font_size_override("font_size", 13)
	var next_text: String = "バトルへ  E / Y" if battle.phase == "standby" else "手番を終える  E / Y"
	var next: Button = UI.button(
		main.content, "phase", next_text, Rect2(978, 644, 266, 49), main._advance_phase
	)
	next.disabled = battle.turn == 1
	next.add_theme_color_override("font_color", UI.RED if battle.phase == "standby" else UI.INK)


static func _detail(main: Control) -> void:
	UI.label(main.content, "選択した札", Rect2(44, 115, 240, 29), 18, UI.MUTED)
	if main.detail_id.is_empty():
		UI.picture(main.content, "res://assets/art/logo_mark.svg", Rect2(97, 174, 128, 128))
		UI.paragraph(
			main.content,
			"手札や盤面の札を選ぶと、\nここに能力と操作が出ます。\n\n伏せ札には、伏せ札の強さがある。",
			Rect2(48, 326, 235, 126),
			17
		)
		return
	var data: Dictionary = Catalog.CARDS[main.detail_id]
	UI.label(main.content, data.name, Rect2(44, 150, 243, 37), 27, UI.GOLD)
	_actor(main.content, main.detail_id, Vector2(161, 248), 0.54)
	UI.label(
		main.content,
		"攻撃力 %d　・　%s" % [data.atk, Catalog.RARITY_NAMES[data.rarity]],
		Rect2(49, 316, 231, 29),
		18
	)
	UI.paragraph(main.content, data.text, Rect2(46, 350, 235, 69), 17)
	if main.selected_uid < 0:
		return
	var unit: Dictionary = main.run.battle.unit_by_id(main.selected_uid)
	if unit.is_empty():
		return
	var standby: bool = main.run.battle.phase == "standby" and main.run.battle.turn == 0
	var reveal: Button = UI.button(
		main.content, "reveal", "登場  R / X", Rect2(42, 427, 119, 31), main._reveal_selected
	)
	reveal.disabled = not standby or unit.face
	var move: Button = UI.button(
		main.content, "move", "移動  M", Rect2(169, 427, 115, 31), main._select_mode.bind("move")
	)
	move.disabled = not standby or not unit.face or unit.moved
	var swap: Button = UI.button(
		main.content, "swap", "配置換え S", Rect2(42, 466, 119, 31), main._select_mode.bind("swap")
	)
	swap.disabled = not standby or main.run.battle.swapped
	var effect: Button = UI.button(
		main.content, "effect", "効果  F", Rect2(169, 466, 115, 31), main._effect_selected
	)
	effect.disabled = (
		not standby or not unit.face or unit.effect_used or data.effect not in ["heal", "reveal"]
	)
	for button: Button in [reveal, move, swap, effect]:
		button.add_theme_font_size_override("font_size", 14)


static func _opponent(main: Control) -> void:
	var battle: RefCounted = main.run.battle
	var enemy: Dictionary = Catalog.ENEMIES[battle.enemy_id]
	UI.label(main.content, enemy.title, Rect2(989, 111, 252, 24), 16, UI.MUTED)
	UI.label(main.content, enemy.name, Rect2(986, 141, 255, 42), 27, UI.GOLD)
	var portrait_scale: float = 0.54 if battle.enemy_id == "final" else 0.61
	main.enemy_actor = _actor(main.content, battle.enemy_id, Vector2(1107, 251), portrait_scale)
	UI.panel(main.content, Rect2(983, 334, 257, 97), Color("342f25"))
	main.speech_label = UI.paragraph(main.content, main.speech, Rect2(995, 341, 230, 85), 18)
	UI.label(
		main.content,
		(
			"敵手札 %d　山札 %d　捨て場 %d"
			% [battle.hands[1].size(), battle.decks[1].size(), battle.discards[1].size()]
		),
		Rect2(986, 448, 255, 27),
		15,
		UI.MUTED
	)
	UI.label(main.content, "王へは中央奥のマスから", Rect2(986, 475, 253, 25), 15, UI.MUTED)


static func _hand(main: Control) -> void:
	var battle: RefCounted = main.run.battle
	UI.panel(main.content, Rect2(27, 535, 929, 161), Color("11251fee"))
	UI.label(
		main.content,
		(
			"手札 %d  /  山札 %d  /  捨て場 %d"
			% [battle.hands[0].size(), battle.decks[0].size(), battle.discards[0].size()]
		),
		Rect2(42, 538, 682, 24),
		16,
		UI.MUTED
	)
	var page_count: int = maxi(1, ceili(battle.hands[0].size() / 8.0))
	main.hand_page = mini(main.hand_page, page_count - 1)
	for index: int in range(
		main.hand_page * 8, mini(battle.hands[0].size(), (main.hand_page + 1) * 8)
	):
		var card := Card.new()
		card.name = "hand_%d" % index
		card.position = Vector2(42 + (index % 8) * 109, 568)
		card.size = Vector2(98, 117)
		card.card_id = str(battle.hands[0][index])
		card.hand_index = index
		card.selected = main.selected_hand == index
		card.pressed.connect(main._select_hand.bind(index))
		main.content.add_child(card)
		main.hand_nodes.append(card)
		if index == main.hand_page * 8:
			main.first_focus = card
	if page_count > 1:
		var prev: Button = UI.button(
			main.content, "hand_prev", "＜", Rect2(790, 536, 56, 27), main._change_hand_page.bind(-1)
		)
		prev.disabled = main.hand_page == 0
		var next: Button = UI.button(
			main.content, "hand_next", "＞", Rect2(857, 536, 56, 27), main._change_hand_page.bind(1)
		)
		next.disabled = main.hand_page == page_count - 1


static func _reward(main: Control) -> void:
	UI.label(main.content, "勝ち取った一枚を、次の峠へ", Rect2(85, 108, 1100, 58), 37)
	UI.label(main.content, "並べる札が変われば、同じ盤にも新しい道が生まれる。", Rect2(87, 177, 1090, 40), 22, UI.MUTED)
	for index: int in range(main.run.reward_options.size()):
		var id: String = main.run.reward_options[index]
		var x: float = 165 + index * 325
		_offer(main, id, Rect2(x, 246, 293, 362))
		var take: Button = UI.button(
			main.content,
			"reward_%d" % index,
			"この札を迎える",
			Rect2(x + 17, 549, 259, 43),
			main._take_reward.bind(index)
		)
		if index == 0:
			main.first_focus = take
	UI.label(main.content, "獲得した札は図鑑に残り、この旅のデッキへ加わります。", Rect2(105, 645, 1070, 36), 19, UI.MUTED)


static func _offer(main: Control, id: String, area: Rect2) -> void:
	var card: Dictionary = Catalog.CARDS[id]
	UI.panel(main.content, area, Color("203329ef"))
	UI.label(
		main.content,
		card.name,
		Rect2(area.position.x + 18, area.position.y + 15, 258, 41),
		28,
		UI.GOLD
	)
	_actor(main.content, id, area.position + Vector2(area.size.x / 2, 134), 0.48)
	UI.label(
		main.content,
		"攻撃力 %d   /   %s" % [card.atk, Catalog.RARITY_NAMES[card.rarity]],
		Rect2(area.position.x + 23, area.position.y + 201, 245, 27),
		20
	)
	UI.paragraph(
		main.content, card.text, Rect2(area.position.x + 19, area.position.y + 232, 255, 68), 17
	)


static func _rest(main: Control) -> void:
	_actor(main.content, "rest", Vector2(383, 349), 1.0)
	UI.panel(main.content, Rect2(656, 155, 543, 434), Color("1f3329ec"))
	UI.label(main.content, "灯の消えぬ宿", Rect2(687, 194, 461, 63), 39, UI.GOLD)
	UI.paragraph(main.content, "夜を越えるにも、力がいる。\n火のそばで、次の一手を考えよう。", Rect2(689, 294, 455, 118), 25)
	UI.label(main.content, "王を4回復する（上限10）", Rect2(689, 427, 467, 38), 23, UI.JADE)
	main.first_focus = UI.button(
		main.content, "rest", "休息して道へ", Rect2(689, 508, 460, 54), main._rest
	)


static func _shop(main: Control) -> void:
	UI.label(main.content, "旅の商人", Rect2(49, 103, 450, 52), 37)
	_actor(main.content, "merchant", Vector2(152, 278), 0.67)
	UI.paragraph(
		main.content, "札を揃えるか、\n余分な札を手放すか。\n\n一枚の選択が\n王の運命を変える。", Rect2(49, 404, 221, 144), 20
	)
	for index: int in range(main.run.shop_options.size()):
		var id: String = main.run.shop_options[index]
		if id.is_empty():
			continue
		var x: float = 305 + index * 304
		_offer(main, id, Rect2(x, 126, 287, 372))
		var cost: int = Catalog.PRICES[Catalog.CARDS[id].rarity]
		var buy: Button = UI.button(
			main.content,
			"buy_%d" % index,
			"%d 銭で迎える" % cost,
			Rect2(x + 16, 448, 254, 39),
			main._buy_card.bind(index)
		)
		buy.disabled = main.run.gold < cost
	UI.label(main.content, "札の整理：20銭で一枚手放す（4枚は残す）", Rect2(311, 520, 896, 31), 19, UI.GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(308, 560)
	scroll.size = Vector2(915, 68)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.content.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	scroll.add_child(row)
	for index: int in range(main.run.deck.size()):
		var remove := Button.new()
		remove.name = "remove_%d" % index
		remove.text = Catalog.CARDS[main.run.deck[index]].name
		remove.custom_minimum_size = Vector2(135, 43)
		remove.disabled = main.run.gold < 20 or main.run.deck.size() <= 4
		remove.pressed.connect(main._remove_card.bind(index))
		row.add_child(remove)
	main.first_focus = UI.button(
		main.content, "leave", "買い物を終えて道へ", Rect2(816, 651, 404, 44), main._leave_node
	)


static func _result(main: Control) -> void:
	UI.picture(main.content, "res://assets/art/generated/title-key-art.png", Rect2(543, 74, 670, 670))
	UI.panel(main.content, Rect2(68, 117, 548, 532), Color("152920ed"))
	UI.label(
		main.content,
		"夜明けの先へ" if main.run.won else "旗は、まだ折れぬ",
		Rect2(100, 148, 503, 69),
		40,
		UI.GOLD
	)
	UI.paragraph(
		main.content,
		"最後の城主を倒した。\nこの道の続きを描くのは、あなた。" if main.run.won else "王の灯が消え、旅は幕を閉じた。\n集めた知恵と札の記憶は、次の旅へ。",
		Rect2(101, 241, 458, 92),
		23
	)
	var count: Label = UI.label(main.content, "到達した峠　0", Rect2(100, 352, 450, 43), 27)
	count.create_tween().tween_method(
		func(value: float) -> void:
			if is_instance_valid(count):
				count.text = "到達した峠　%d / 9" % roundi(value),
		0.0,
		float(main.run.depth + 1),
		0.7
	)
	UI.label(main.content, "倒した将軍　%d 人" % main.run.generals.size(), Rect2(100, 408, 450, 38), 23)
	var names: Array[String] = []
	for general: String in main.run.generals:
		names.append(Catalog.ENEMIES[general].name)
	UI.paragraph(main.content, "・".join(names), Rect2(100, 451, 454, 48), 16)
	UI.button(
		main.content,
		"collected",
		"迎えた札 %d 枚を見る" % main.run.collected.size(),
		Rect2(100, 502, 451, 39),
		main._show_overlay.bind("collected")
	)
	main.first_focus = UI.button(
		main.content, "result_title", "タイトルへ", Rect2(100, 554, 451, 56), main._to_title
	)


static func modal(main: Control, kind: String) -> void:
	_disable_focus(main.content)
	var shield := ColorRect.new()
	shield.color = Color("07120ef2")
	shield.size = Vector2(1280, 720)
	main.content.add_child(shield)
	UI.panel(shield, Rect2(50, 43, 1180, 635), Color("192f25"))
	main.first_focus = UI.button(
		shield, "close_modal", "閉じる  Esc / B", Rect2(975, 61, 235, 43), main._close_overlay
	)
	match kind:
		"help":
			_help(shield)
		"pause":
			_pause(main, shield)
		"book", "deck", "collected":
			_book(main, shield, kind)


static func _help(parent: Control) -> void:
	UI.label(parent, "一手を読むための手引き", Rect2(80, 65, 850, 52), 34, UI.GOLD)
	var left: String = (
		"■ 勝利と旅路\n"
		+ "敵王の10ptを削れば勝利。あなたの王のptは旅の間引き継ぎます。9峠目の城主を倒せばクリア。将軍の道は難しく、稀な札を得られます。\n"
		+ "\n"
		+ "■ 準備フェーズ\n"
		+ "潜伏：手札 → 自陣の空きマス。\n"
		+ "登場：伏せ札を選び、登場で表向きに。\n"
		+ "移動：表向きの札を上下左右の空き1マスへ。各札1回、移動した札はその手番に攻撃不可。\n"
		+ "配置換え：隣接する味方一組を入れ替え。1手番に一組だけ。夜渡りは敵札とも交換可能。\n"
		+ "効果：星読みや灯守は各手番に1回発動。"
	)
	var right: String = (
		"■ 攻撃フェーズ\n"
		+ "表向きの札 → 隣接する敵札か敵王で攻撃。各札1回。射手だけ2マス先にも届きます。\n"
		+ "敵の伏せ札は攻撃時に表向きに。攻撃力を比べ、低い札は捨て場へ。同じなら相討ち。勝者は敗者のマスへ移動します。\n"
		+ "敵王は敵陣中央の奥。王へのダメージは攻撃力（負なら0）。\n"
		+ "\n"
		+ "■ 操作\n"
		+ "マウス：クリック、手札・札のドラッグ。\n"
		+ "キーボード：矢印で選択、Enterで決定。\n"
		+ "パッド：十字・左スティック、Aで決定。\n"
		+ "E / Y：攻撃へ・手番終了。R / X：登場。\n"
		+ "Esc / B：選択解除・旅の休止。F11：全画面。\n"
		+ "\n"
		+ "初手3枚、先攻の最初はドローなし。以後は1枚。山札が尽きれば捨て場を混ぜて再利用。"
	)
	UI.paragraph(parent, left, Rect2(84, 139, 530, 483), 19)
	UI.paragraph(parent, right, Rect2(651, 139, 527, 483), 18)


static func _pause(main: Control, parent: Control) -> void:
	UI.label(parent, "旅の休止", Rect2(108, 114, 750, 60), 42, UI.GOLD)
	UI.paragraph(
		parent, "一手ごとに旅を記録しています。\nタイトルの「旅の続きを再開」から、この盤面へ戻れます。", Rect2(112, 217, 1014, 109), 25
	)
	main.first_focus = UI.button(
		parent, "continue", "対局に戻る", Rect2(257, 350, 768, 59), main._close_overlay
	)
	UI.button(parent, "save_title", "旅を保存してタイトルへ", Rect2(257, 430, 768, 59), main._to_title)
	if main.run.stage != "title" and main.run.stage != "result":
		UI.button(parent, "concede", "この旅を終える（降参）", Rect2(257, 531, 768, 51), main._concede)


static func _book(main: Control, parent: Control, kind: String) -> void:
	UI.label(
		parent,
		{"book": "札の図鑑", "deck": "この旅の所持札", "collected": "この旅で迎えた札"}[kind],
		Rect2(81, 60, 850, 55),
		34,
		UI.GOLD
	)
	var collection: Array = main.run.collection if kind == "book" else main.run.deck
	var ids: Array = Catalog.CARDS.keys() if kind == "book" else main.run.deck
	if kind == "collected":
		ids = main.run.collected
		collection = ids
		if ids.is_empty():
			UI.label(parent, "この旅では、まだ新しい札を迎えていません。", Rect2(120, 245, 1030, 50), 25)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(78, 134)
	scroll.size = Vector2(1130, 475)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 17)
	grid.add_theme_constant_override("v_separation", 13)
	scroll.add_child(grid)
	for id: String in ids:
		var cell := Panel.new()
		cell.focus_mode = Control.FOCUS_ALL
		cell.custom_minimum_size = Vector2(357, 166)
		grid.add_child(cell)
		if id not in collection:
			UI.label(cell, "未発見", Rect2(119, 61, 221, 42), 23, UI.MUTED)
			continue
		var card: Dictionary = Catalog.CARDS[id]
		_actor(cell, id, Vector2(53, 79), 0.31)
		UI.label(cell, card.name, Rect2(111, 11, 232, 34), 22, UI.GOLD)
		UI.label(
			cell,
			"攻 %d  /  %s" % [card.atk, Catalog.RARITY_NAMES[card.rarity]],
			Rect2(111, 47, 230, 28),
			16
		)
		UI.paragraph(cell, card.text, Rect2(109, 83, 230, 78), 15)
	UI.label(
		parent,
		"素材：生成水墨画・独自SVG・合成音声。字体：Yuji Syuku / SIL OFL 1.1。",
		Rect2(81, 630, 1120, 29),
		14,
		UI.MUTED
	)


static func _actor(parent: Node, id: String, point: Vector2, factor: float) -> Node2D:
	var actor := Actor.new()
	parent.add_child(actor)
	actor.position = point
	actor.setup(id, factor)
	return actor


static func _disable_focus(node: Node) -> void:
	if node is Control:
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		_disable_focus(child)


static func _legal_target(main: Control, pos: Vector2i, unit: Dictionary) -> bool:
	var battle: RefCounted = main.run.battle
	if battle.turn != 0 or main.busy:
		return false
	if main.selected_hand >= 0:
		return unit.is_empty() and battle.own_zone(0, pos)
	var selected: Dictionary = battle.unit_by_id(main.selected_uid)
	if selected.is_empty():
		return false
	var distance: int = absi(selected.x - pos.x) + absi(selected.y - pos.y)
	if main.mode == "move":
		return unit.is_empty() and distance == 1 and selected.face and not selected.moved
	if main.mode == "swap":
		return (
			not unit.is_empty()
			and distance == 1
			and not battle.swapped
			and (unit.side == 0 or (selected.face and selected.card == "veil"))
		)
	if main.mode == "effect":
		return not unit.is_empty() and unit.side == 1 and not unit.face
	return not unit.is_empty() and battle.can_attack(selected.uid, unit.uid)


static func _tutorial_text(main: Control) -> String:
	var messages: Array[String] = [
		"手ほどき 一｜手札から一枚を選ぶ。名と能力は左の巻物に現れます。",
		"手ほどき 二｜青磁に脈打つ自陣の空きマスを選び、札を伏せて置きます。",
		"手ほどき 三｜置いた伏せ札を選び、左の「登場」で表向きにします。",
		"手ほどき 四｜右下の「バトルへ」で攻めへ。移動した札は攻撃できません。",
		"手ほどき 五｜表向き札を選び、朱に脈打つ隣の敵札を選んで攻撃します。",
	]
	return messages[clampi(main.tutorial_step, 0, messages.size() - 1)]
