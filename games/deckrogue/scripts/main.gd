extends Control
## 状態は Run が所有し、ここには描画と操作の進行だけを置く。

const UI := preload("res://scripts/ui.gd")
const Actor := preload("res://scripts/actor.gd")
const Effects := preload("res://scripts/effects.gd")
const Catalog := preload("res://scripts/card_catalog.gd")
const NODE_PREVIEWS: Dictionary = {
	"battle": "戦闘。勝てば三枚の記憶から一枚を選びます。",
	"elite": "強敵。危険ですが、勝利すると遺物も得ます。",
	"rest": "休息。体力を回復して次の頁へ進みます。",
	"card": "書庫。戦わず、新しいカードを一枚選べます。",
	"event": "祠。旅のあいだ働く遺物を受け取ります。",
	"boss": "最上階。竜の王を倒せば写本が完成します。",
}

var screen: Control
var overlay: Control
var particles: Control
var card_nodes: Array[Button] = []
var enemy_art: Node2D
var hero_art: Node2D
var effects_layer: Control
var displayed_phase: String = ""
var health_label: Label
var health_bar: ProgressBar
var map_preview_label: Label
var displayed_hp: int = -1
var closing: bool = false
var busy: bool = false
var modal: String = ""
var first_focus: Button
var animation: Tween
var tutorial_step: int = -1
var tutorial_seen: bool = false


func _ready() -> void:
	print("deckrogue boot")
	theme = preload("res://assets/ui/pilgrimage.tres")
	get_tree().auto_accept_quit = false
	Run.changed.connect(_on_changed)
	Run.effect.connect(_effect)
	_render()


func _on_changed() -> void:
	if not busy:
		_render()


func _render(draw_cards: bool = true) -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	if is_instance_valid(particles):
		remove_child(particles)
		particles.queue_free()
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	UI.book(screen)
	particles = Control.new()
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particles)
	card_nodes.clear()
	first_focus = null
	enemy_art = null
	hero_art = null
	if not is_instance_valid(effects_layer):
		effects_layer = Effects.new()
		effects_layer.z_index = 20
		add_child(effects_layer)
	elif displayed_phase != Run.phase:
		for effect: Node in effects_layer.get_children():
			effects_layer.remove_child(effect)
			effect.queue_free()
	match Run.phase:
		"title": _title()
		"map": _map()
		"battle": _battle(draw_cards)
		"reward": _reward()
		"rest": _rest()
		"event": _event()
		"result": _result()
	if Run.phase != "title":
		_hud()
	if tutorial_step >= 0:
		_tutorial()
	if first_focus != null and modal.is_empty():
		first_focus.grab_focus()
	if Run.phase == "battle":
		Sound.track("boss" if Run.current_kind == "boss" else "battle")
	else:
		var track_name: String = "map"
		if Run.phase == "title":
			track_name = "title"
		elif Run.phase == "result":
			track_name = "victory" if Run.won else "result"
		Sound.track(track_name)
	if displayed_phase != Run.phase:
		_transition()
	displayed_phase = Run.phase


func _title() -> void:
	UI.illuminated_heading(screen, "燈", "火の巡礼", Rect2(78, 91, 500, 76), 48)
	UI.label(screen, "八つの葉をめくり、灯を夜明けへ。", Rect2(83, 184, 495, 40), 23, UI.RUST)
	UI.rule(screen, PackedVector2Array([Vector2(82, 231), Vector2(583, 231)]), UI.RUST, 2.0)
	UI.label(screen, "敵の次の一手を読み、手札から一枚を選ぶ。\n道を選ぶたび、この写本に旅の線が残る。",
		Rect2(84, 253, 493, 86), 20, UI.INK)
	UI.note(screen, "最初の一頁", "朱色の栞を開くと短い読み方が始まります。\n案内はいつでも読み飛ばせます。",
		Rect2(82, 356, 500, 114), UI.LAPIS)
	first_focus = UI.button(screen, "朱色の栞を開く　[Enter / A]",
		Rect2(83, 496, 395, 61), _start, true)
	UI.button(screen, "本を閉じる", Rect2(492, 496, 91, 61), _request_quit)
	UI.label(screen, "一幕完結　・　分岐する八階層", Rect2(86, 594, 460, 30), 17, UI.MUTED)
	UI.art(screen, "title_keyart", Rect2(697, 72, 480, 560))
	UI.art(screen, "ornament_initial", Rect2(1060, 527, 136, 118))


func _hud() -> void:
	UI.label(screen, "燈火の巡礼", Rect2(75, 57, 174, 34), 21, UI.RUST)
	health_label = UI.label(screen, "", Rect2(270, 57, 190, 31), 18, UI.INK)
	health_bar = UI.meter(screen, Rect2(270, 88, 174, 6), Run.max_hp, Run.hp, UI.RUST)
	var previous: int = Run.hp if displayed_hp < 0 else displayed_hp
	UI.count(health_label, previous, Run.hp, "体力  %d / " + str(Run.max_hp))
	displayed_hp = Run.hp
	UI.label(screen, "第 %02d / 08 葉" % maxi(1, Run.floor_index + 1), Rect2(474, 57, 140, 31), 18)
	UI.label(screen, "旅の余白", Rect2(675, 57, 108, 31), 18, UI.RUST)
	UI.button(screen, "カード帳 %d [D]" % Run.deck.size(), Rect2(791, 53, 178, 42), _open_deck)
	UI.button(screen, "絵地図 [M]", Rect2(980, 53, 126, 42), _open_map)
	UI.button(screen, "音", Rect2(1118, 53, 88, 42), _toggle_audio)
	UI.rule(screen, PackedVector2Array([Vector2(73, 102), Vector2(608, 102)]), UI.GOLD, 1.5)
	UI.rule(screen, PackedVector2Array([Vector2(672, 102), Vector2(1207, 102)]), UI.GOLD, 1.5)


func _map() -> void:
	UI.illuminated_heading(screen, "巡", "礼路の絵地図", Rect2(76, 118, 550, 58), 34)
	UI.label(screen, "金の縁は、いま選べる次の頁。", Rect2(82, 180, 520, 30), 18, UI.MUTED)
	UI.panel(screen, Rect2(672, 116, 533, 96), UI.LIGHT_PAPER, UI.LAPIS, 3, 1)
	UI.label(screen, "選んだ先の予告", Rect2(691, 124, 210, 26), 18, UI.LAPIS)
	map_preview_label = UI.label(screen, "", Rect2(691, 151, 493, 52), 16, UI.INK)
	map_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var engraving: TextureRect = UI.art(screen, "map_engraving", Rect2(74, 218, 1132, 424))
	engraving.modulate = Color(1.0, 1.0, 1.0, 0.57)
	_draw_route(screen, true)
	UI.label(screen, Run.message, Rect2(84, 640, 1115, 26), 15, UI.RUST)


func _draw_route(parent: Control, interactive: bool) -> void:
	var centers := PackedVector2Array()
	for row_index: int in range(Run.map_rows.size()):
		centers.append(_route_position(row_index, 0) + Vector2(55, 28))
	UI.rule(parent, centers, Color("7d6549a8"), 5.0)
	if not Run.route.is_empty():
		var completed := PackedVector2Array()
		for row_index: int in range(Run.route.size()):
			completed.append(_route_position(row_index, Run.route[row_index]) + Vector2(55, 28))
		UI.rule(parent, completed, UI.RUST, 6.0)
		if interactive and Run.floor_index + 1 < Run.map_rows.size():
			var origin: Vector2 = completed[completed.size() - 1]
			for choice: int in range(Run.map_rows[Run.floor_index + 1].size()):
				UI.rule(parent, PackedVector2Array([origin,
					_route_position(Run.floor_index + 1, choice) + Vector2(55, 28)]), UI.GOLD, 3.0)
	for row_index: int in range(Run.map_rows.size()):
		var row: Array = Run.map_rows[row_index]
		for choice: int in range(row.size()):
			var node: Dictionary = row[choice]
			var active: bool = row_index == Run.floor_index + 1 and interactive
			var position: Vector2 = _route_position(row_index, choice)
			var caption: String = "第八葉\n竜の王" if node.kind == "boss" else str(node.label)
			if row_index < Run.route.size() and Run.route[row_index] == choice:
				caption = "✓ " + caption
			elif active:
				caption += "\n頁を開く"
			var button: Button = UI.button(parent, caption, Rect2(position, Vector2(110, 56)),
				_choose_node.bind(choice), active)
			button.icon = load("res://assets/art/route_" + str(node.kind) + ".png")
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 27)
			button.add_theme_font_size_override("font_size", 14)
			button.disabled = not active
			button.tooltip_text = _node_preview(node)
			button.focus_entered.connect(_set_map_preview.bind(node))
			button.mouse_entered.connect(_set_map_preview.bind(node))
			if row_index <= Run.floor_index:
				button.modulate = Color(0.67, 0.57, 0.43, 0.72)
			if active and first_focus == null:
				first_focus = button
	if first_focus != null and interactive:
		var row: Array = Run.map_rows[Run.floor_index + 1]
		_set_map_preview(row[0])


func _route_position(row_index: int, choice: int) -> Vector2:
	var positions: Array[Vector2] = [
		Vector2(100, 548), Vector2(220, 443), Vector2(112, 342), Vector2(294, 253),
		Vector2(690, 548), Vector2(808, 445), Vector2(711, 333), Vector2(1000, 242),
	]
	var base: Vector2 = positions[row_index]
	if choice == 0:
		return base
	return base + Vector2(126, -28 if row_index % 2 == 0 else 34)


func _node_preview(node: Dictionary) -> String:
	return NODE_PREVIEWS.get(str(node.kind), "まだ書かれていない頁です。")


func _set_map_preview(node: Dictionary) -> void:
	if is_instance_valid(map_preview_label):
		map_preview_label.text = _node_preview(node) + "　[Enter / A で決定]"


func _battle(draw_cards: bool) -> void:
	var forest: TextureRect = UI.art(screen, "battle_forest", Rect2(61, 109, 1158, 354))
	forest.modulate = Color(1.0, 1.0, 1.0, 0.23)
	UI.illuminated_heading(screen, "第", "%d 葉の戦い" % Run.turn,
		Rect2(72, 113, 420, 48), 27)
	UI.label(screen, "弱体：攻撃が減る　／　脆弱：受ける傷が増える",
		Rect2(76, 166, 520, 25), 15, UI.MUTED)
	hero_art = _actor("hero", Rect2(90, 184, 236, 248))
	UI.label(screen, "灯守", Rect2(145, 409, 160, 30), 21, UI.RUST)
	UI.label(screen, "防御 %d　力 %d" % [Run.block, Run.strength], Rect2(93, 442, 270, 26), 17)
	UI.label(screen, _status_text(Run.weak, Run.vulnerable), Rect2(89, 199, 290, 26), 15, UI.RUST)
	UI.panel(screen, Rect2(718, 111, 485, 77), UI.LIGHT_PAPER, UI.RUST, 3, 1)
	UI.label(screen, "敵が次に書く一手", Rect2(737, 117, 210, 25), 17, UI.RUST)
	UI.label(screen, Run.intent_text() + "　― ターンを閉じると実行",
		Rect2(737, 143, 445, 34), 19, UI.INK)
	enemy_art = _actor(_enemy_asset(), Rect2(873, 187, 244, 246))
	UI.label(screen, str(Run.enemy.name), Rect2(857, 408, 330, 32), 22, UI.RUST)
	UI.label(screen, "体力 %d / %d　防御 %d" % [Run.enemy.hp, Run.enemy.max_hp, Run.enemy.block],
		Rect2(832, 441, 370, 25), 17)
	UI.meter(screen, Rect2(857, 435, 258, 5), Run.enemy.max_hp, Run.enemy.hp, UI.RUST)
	UI.label(screen, _status_text(Run.enemy.weak, Run.enemy.vulnerable),
		Rect2(847, 197, 330, 25), 15, UI.RUST)
	UI.art(screen, "icon_energy", Rect2(559, 207, 76, 76))
	UI.label(screen, "使える墨　%d / 3" % Run.energy, Rect2(495, 283, 240, 35), 22, UI.LAPIS)
	UI.label(screen, "山札 %d　捨札 %d　廃棄 %d" % [Run.draw_pile.size(),
		Run.discard_pile.size(), Run.exhaust_pile.size()], Rect2(478, 320, 300, 26), 16)
	var message_label: Label = UI.label(screen, Run.message, Rect2(407, 359, 382, 50), 16, UI.MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(screen, "金縁のカードを選ぶ　[Enter / A またはクリック]",
		Rect2(64, 469, 720, 27), 16, UI.LAPIS)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.position = Vector2(59, 498)
	hand_scroll.size = Vector2(1000, 172)
	hand_scroll.follow_focus = true
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(hand_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(row)
	for index: int in range(Run.hand.size()):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(174, 166)
		row.add_child(slot)
		var button: Button = _card(slot, Run.hand[index],
			Rect2(0, 0, 174, 166), _play_card.bind(index))
		var cost: int = int(Catalog.CARDS[Run.hand[index]].cost)
		button.disabled = cost > Run.energy
		if button.disabled:
			UI.panel(button, Rect2(7, 74, 160, 29), UI.LIGHT_PAPER, UI.RUST, 2, 1)
			UI.label(button, "墨が %d 足りない" % (cost - Run.energy),
				Rect2(14, 76, 148, 24), 14, UI.RUST)
			button.tooltip_text = "使えません。必要な墨 %d、残り %d。" % [cost, Run.energy]
		card_nodes.append(button)
		if not button.disabled and first_focus == null:
			first_focus = button
		if draw_cards:
			_draw_card_animation(button, index)
	var end: Button = UI.button(screen, "この葉を閉じる\n敵の行動へ [E / RB]",
		Rect2(1081, 512, 139, 96), _end_turn, true)
	end.add_theme_font_size_override("font_size", 16)
	if first_focus == null:
		first_focus = end
	UI.label(screen, "手札はすべて捨札へ", Rect2(1083, 620, 136, 26), 14, UI.MUTED)


func _card(parent: Node, id: String, rect: Rect2, callback: Callable) -> Button:
	var data: Dictionary = Catalog.CARDS[id]
	var button: Button = UI.button(parent, "", rect, callback)
	var is_attack: bool = data.type == "attack"
	var is_power: bool = data.type == "power"
	var tint: Color = UI.RUST if is_attack else (UI.GOLD if is_power else Color("75b6b1"))
	button.add_theme_stylebox_override("normal", UI.box(Color("eee2c9"), tint))
	button.add_theme_stylebox_override("hover", UI.box(Color("fff2d5"), tint))
	button.add_theme_stylebox_override("pressed", UI.box(Color("dfd2b6"), tint))
	button.add_theme_stylebox_override("disabled", UI.box(Color("aca899"), Color("687b76")))
	UI.label(button, str(data.cost), Rect2(12, 3, 32, 34), 27, UI.INK)
	UI.label(button, str(data.name), Rect2(45, 6, rect.size.x - 52, 34), 17, UI.INK)
	UI.art(button, "card_" + id, Rect2(10, 40, rect.size.x - 20, 49))
	var description: Label = UI.label(button, Catalog.card_text(id),
		Rect2(12, 93, rect.size.x - 24, rect.size.y - 120), 14, UI.INK)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var category: String = Catalog.TYPES[data.type]
	UI.label(button, category + " · " + str(data.rarity),
		Rect2(12, rect.size.y - 26, rect.size.x - 20, 22), 13, UI.INK)
	button.pivot_offset = rect.size / 2
	if not callback.is_valid():
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _reward() -> void:
	UI.illuminated_heading(screen, "戦", "いの記憶を一枚", Rect2(79, 126, 720, 58), 34)
	UI.label(screen, "選んだ一枚は、この旅が終わるまでカード帳に加わります。",
		Rect2(84, 190, 780, 34), 19, UI.MUTED)
	UI.note(screen, "いま出来ること", "三枚から一枚を選ぶか、見送って現在の構成を保ちます。",
		Rect2(820, 122, 382, 101), UI.LAPIS)
	for index: int in range(Run.reward_cards.size()):
		var button: Button = _card(screen, Run.reward_cards[index],
			Rect2(149 + 338 * index, 260, 272, 283), _choose_reward.bind(index))
		button.tooltip_text = "このカードをカード帳へ加えて、絵地図へ戻ります。"
		if index == 0:
			first_focus = button
	UI.button(screen, "一枚も加えず、絵地図へ戻る", Rect2(443, 586, 393, 55),
		_choose_reward.bind(-1))
	UI.label(screen, Run.message, Rect2(83, 227, 790, 28), 17, UI.RUST)


func _rest() -> void:
	UI.illuminated_heading(screen, "消", "えない焚火", Rect2(82, 145, 500, 66), 39)
	UI.label(screen, "火に手をかざす。長い夜にも、休息はある。\n体力を回復すると、自動で絵地図へ戻ります。",
		Rect2(88, 260, 492, 94), 23)
	UI.note(screen, "頁を進める", "回復する　[Enter / A またはクリック]",
		Rect2(85, 382, 490, 88), UI.VERDIGRIS)
	UI.art(screen, "bestiary_dragon", Rect2(716, 144, 454, 370))
	hero_art = _actor("hero", Rect2(888, 334, 205, 236))
	effects_layer.burst("heal", Vector2(994, 380), 0)
	first_focus = UI.button(screen, "焚火の頁を開き、体力を回復する",
		Rect2(86, 506, 490, 65), _rest_action, true)


func _event() -> void:
	UI.illuminated_heading(screen, "道", "端の小さな祠", Rect2(82, 145, 520, 66), 38)
	UI.label(screen, "古い巡礼者が残した贈り物。\n遺物は、この旅が終わるまで力を貸します。",
		Rect2(88, 259, 493, 92), 23)
	UI.note(screen, "頁を進める", "受け取る　[Enter / A またはクリック]",
		Rect2(85, 382, 490, 88), UI.LAPIS)
	UI.art(screen, "ornament_initial", Rect2(721, 137, 430, 372))
	hero_art = _actor("npc_keeper", Rect2(894, 327, 200, 242))
	first_focus = UI.button(screen, "余白の贈り物を受け取る",
		Rect2(86, 506, 490, 65), _event_action, true)


func _result() -> void:
	UI.illuminated_heading(screen, "夜" if Run.won else "灯",
		"明けに、灯は届いた。" if Run.won else "は、また誰かの手へ。",
		Rect2(86, 140, 1065, 70), 38)
	UI.label(screen, "巡礼達成" if Run.won else "巡礼の終わり", Rect2(90, 245, 470, 44), 28, UI.RUST)
	UI.art(screen, "ornament_initial", Rect2(773, 131, 390, 338))
	var metrics: Array[int] = [Run.floor_index + 1, Run.deck.size(), Run.relics.size()]
	var captions: Array[String] = ["到達した階層", "携えたカード", "集めた遺物"]
	for index: int in range(metrics.size()):
		var x: float = 92 + index * 170
		var number: Label = UI.label(screen, "0", Rect2(x, 325, 100, 57), 38, UI.RUST)
		UI.count(number, 0, metrics[index], "%02d")
		UI.label(screen, captions[index], Rect2(x, 384, 165, 30), 15, UI.MUTED)
	UI.note(screen, "次にできること", "新しい写本を始めるか、表紙へ戻ります。",
		Rect2(84, 444, 500, 92), UI.LAPIS)
	first_focus = UI.button(screen, "もう一度、第一葉から", Rect2(84, 563, 300, 58), _start, true)
	UI.button(screen, "表紙へ戻る", Rect2(398, 563, 186, 58), _return_title)


func _relic_text() -> String:
	if Run.relics.is_empty():
		return "まだ遺物はない。強敵や祠に、その手がかりが眠っている。"
	var lines: PackedStringArray = []
	for id: String in Run.relics:
		var relic: Dictionary = Catalog.RELICS[id]
		lines.append(str(relic.name) + "：" + str(relic.text))
	return "\n".join(lines)


func _status_text(weak: int, vulnerable: int) -> String:
	var parts: PackedStringArray = []
	if weak > 0:
		parts.append("弱体 %d" % weak)
	if vulnerable > 0:
		parts.append("脆弱 %d" % vulnerable)
	return "  ".join(parts)


func _enemy_asset() -> String:
	if Run.current_kind == "boss":
		return "boss"
	var ids: Array = Catalog.ENEMIES.keys()
	var index: int = ids.find(Run.enemy.id)
	return ["enemy_moth", "enemy_sentinel", "enemy_brute"][maxi(0, index) % 3]


# ボタン入力はゲームを一歩進めるため、イベントにつき一度だけ実行する。
func _start() -> void:
	_close_modal()
	if not tutorial_seen:
		tutorial_seen = true
		tutorial_step = 0
	Run.start_run()


func _return_title() -> void:
	_close_modal()
	Run.return_title()


func _choose_node(index: int) -> void:
	if not busy:
		Sound.play("quill")
		Run.choose_node(index)


func _choose_reward(index: int) -> void:
	Sound.play("quill")
	Run.choose_reward(index)


func _rest_action() -> void:
	if busy:
		return
	busy = true
	Sound.play("quill")
	var previous: int = Run.hp
	Run.rest()
	effects_layer.burst("heal", Vector2(987, 340), Run.hp - previous)
	Sound.play("heal")
	await get_tree().create_timer(0.8).timeout
	busy = false
	_render()


func _event_action() -> void:
	if busy:
		return
	busy = true
	Sound.play("quill")
	hero_art.play_action("move")
	effects_layer.burst("power", Vector2(999, 331), 0)
	Sound.play("power")
	await get_tree().create_timer(0.8).timeout
	busy = false
	Run.resolve_event()


func _toggle_audio() -> void:
	Sound.set_muted(not Sound.muted)


# 入力一回の演出であり、Tween の反復生成は別の操作になる。
func _draw_card_animation(button: Button, index: int) -> void:
	var destination: Vector2 = button.position
	button.position = Vector2(100, 100)
	button.scale = Vector2(0.25, 0.25)
	button.modulate.a = 0.0
	var tween: Tween = button.create_tween().set_parallel(true)
	tween.tween_property(button, "position", destination, 0.25).set_delay(index * 0.04)
	tween.tween_property(button, "scale", Vector2.ONE, 0.25).set_delay(index * 0.04)
	tween.tween_property(button, "modulate:a", 1.0, 0.20).set_delay(index * 0.04)


func _play_card(index: int) -> void:
	if busy or not modal.is_empty() or Run.phase != "battle":
		return
	if index >= Run.hand.size() or int(Catalog.CARDS[Run.hand[index]].cost) > Run.energy:
		return
	busy = true
	var id: String = Run.hand[index]
	var source: Vector2 = card_nodes[index].global_position
	Sound.play("card")
	hero_art.play_action("attack" if Catalog.CARDS[id].type == "attack" else "move")
	var flight: Button = _card(particles, id, Rect2(source, Vector2(174, 184)), Callable())
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation = create_tween().set_parallel(true)
	animation.tween_property(flight, "position", Vector2(665, 210), 0.20)
	animation.tween_property(flight, "scale", Vector2(0.7, 0.7), 0.20)
	await animation.finished
	Run.play_card(index)
	if Run.enemy.hp <= 0:
		enemy_art.play_action("death")
		effects_layer.burst("death", Vector2(947, 302))
		Sound.play("death")
	await get_tree().create_timer(1.16 if Run.enemy.hp <= 0 else 0.6).timeout
	busy = false
	_render(int(Catalog.CARDS[id].effects.get("draw", 0)) > 0)


func _end_turn() -> void:
	if busy or not modal.is_empty() or Run.phase != "battle":
		return
	busy = true
	Sound.play("card")
	animation = create_tween().set_parallel(true)
	for index: int in range(card_nodes.size()):
		var source: Button = card_nodes[index]
		var card: Button = _card(particles, Run.hand[index],
			Rect2(source.global_position, Vector2(174, 184)), Callable())
		source.hide()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		animation.tween_property(card, "position", Vector2(660, 330), 0.2)
		animation.tween_property(card, "scale", Vector2(0.1, 0.1), 0.2)
		animation.tween_property(card, "modulate:a", 0.0, 0.2)
	if not card_nodes.is_empty():
		await animation.finished
	enemy_art.play_action("attack" if Run.enemy.intent.kind == "attack" else "move")
	await get_tree().create_timer(0.15).timeout
	Run.end_turn()
	if Run.hp <= 0:
		hero_art.play_action("death")
		effects_layer.burst("death", Vector2(248, 302))
		Sound.play("death")
	await get_tree().create_timer(1.16 if Run.hp <= 0 else 0.6).timeout
	busy = false
	_render()


# 効果シグナル一回につき、一つの視聴覚演出を発火する。
func _effect(kind: String, amount: int) -> void:
	if not is_instance_valid(effects_layer) or not busy:
		return
	if kind not in ["attack", "hurt", "block", "heal", "power"]:
		return
	Sound.play("attack" if kind == "hurt" else kind)
	var point := Vector2(947, 298) if kind == "attack" else Vector2(250, 298)
	effects_layer.burst(kind, point, amount)
	if kind == "attack" and is_instance_valid(enemy_art):
		enemy_art.play_action("hurt")
	elif kind == "hurt" and is_instance_valid(hero_art):
		hero_art.play_action("hurt")
	if kind in ["attack", "hurt"]:
		var shake: Tween = screen.create_tween()
		shake.tween_property(screen, "position", Vector2(5, -2), 0.045)
		shake.tween_property(screen, "position", Vector2(-4, 1), 0.045)
		shake.tween_property(screen, "position", Vector2.ZERO, 0.07)
	if is_instance_valid(health_label):
		UI.count(health_label, displayed_hp, Run.hp, "体力  %d / " + str(Run.max_hp))
		health_bar.value = Run.hp
		displayed_hp = Run.hp


func _actor(id: String, rect: Rect2) -> Node2D:
	var actor := Actor.new()
	screen.add_child(actor)
	actor.setup(id, rect)
	return actor


# 画面遷移の表示一回分。Tween は表示ノードに所有させ、作り直し時に破棄する。
func _transition() -> void:
	if not displayed_phase.is_empty():
		Sound.play("transition")
		Sound.play("page")
	screen.modulate.a = 0.0
	screen.position.y = 14
	var tween: Tween = screen.create_tween().set_parallel(true)
	tween.tween_property(screen, "modulate:a", 1.0, 0.32)
	tween.tween_property(screen, "position:y", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC)
	if Run.phase == "reward":
		effects_layer.burst("reward", Vector2(640, 342))
	elif Run.phase == "result" and Run.won:
		effects_layer.burst("victory", Vector2(640, 280))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()


func _request_quit() -> void:
	if closing:
		return
	closing = true
	busy = true
	await Sound.shutdown()
	get_tree().quit()


func _open_deck() -> void:
	if busy or Run.phase == "title":
		return
	_open_modal("deck")
	UI.label(overlay, "携えたカード　%d 枚" % Run.deck.size(), Rect2(65, 83, 990, 55), 36, UI.GOLD)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(66, 164)
	scroll.size = Vector2(1135, 422)
	scroll.follow_focus = true
	overlay.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)
	for id: String in Run.deck:
		var card: Button = _card(grid, id, Rect2(0, 0, 201, 210), Callable())
		card.custom_minimum_size = Vector2(201, 210)
	UI.button(overlay, "閉じる [Esc / B]", Rect2(475, 611, 330, 48), _close_modal).grab_focus()


func _open_map() -> void:
	if busy or Run.phase == "title":
		return
	_open_modal("map")
	UI.label(overlay, "巡礼路　― 現在 第 %d 層" % maxi(1, Run.floor_index + 1),
		Rect2(67, 103, 1060, 60), 37, UI.GOLD)
	_draw_route(overlay, false)
	UI.label(overlay, _relic_text(), Rect2(80, 528, 1110, 68), 18)
	UI.button(overlay, "閉じる [Esc / B]", Rect2(475, 611, 330, 48), _close_modal).grab_focus()


func _open_modal(kind: String) -> void:
	_close_modal()
	modal = kind
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	screen.hide()
	effects_layer.hide()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	UI.book(overlay)
	UI.label(overlay, "余白に挟んだ別の頁", Rect2(76, 58, 460, 31), 17, UI.RUST)


func _close_modal() -> void:
	modal = ""
	if is_instance_valid(screen):
		screen.process_mode = Node.PROCESS_MODE_INHERIT
		screen.show()
	if is_instance_valid(effects_layer):
		effects_layer.show()
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	if is_instance_valid(first_focus):
		first_focus.grab_focus()


func _tutorial() -> void:
	var belongs_to_map: bool = tutorial_step in [0, 1] and Run.phase == "map"
	var belongs_to_battle: bool = tutorial_step in [2, 3] and Run.phase == "battle"
	if not belongs_to_map and not belongs_to_battle:
		return
	var veil := ColorRect.new()
	veil.color = Color("24170daf")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 30
	screen.add_child(veil)
	var page: Panel = UI.panel(veil, Rect2(253, 152, 774, 416), UI.LIGHT_PAPER, UI.GOLD, 5, 1)
	UI.art(page, "ornament_initial", Rect2(552, 44, 165, 150)).modulate = Color(1, 1, 1, 0.48)
	var heading: String
	var body: String
	match tutorial_step:
		0:
			heading = "第一の欄外注　―　旅路を読む"
			body = "金色の線で結ばれた札が、いま選べる行き先です。\n札に触れると右上の予告が変わり、戦い・休息・書庫など\n次の頁で起こることを選ぶ前に読めます。"
		1:
			heading = "第二の欄外注　―　頁を選ぶ"
			body = "方向キー／左スティックで札を移り、Enter／Aで決定します。\nマウスなら札を直接クリックできます。\n案内を閉じたら、金縁の行き先から一つ選んでください。"
		2:
			heading = "第三の欄外注　―　敵の筆を読む"
			body = "右頁の『敵が次に書く一手』は、葉を閉じた後の行動です。\n攻撃が来るなら防御を、隙があれば攻撃を選びます。\n中央の青い印が、カードに使える墨の残りです。"
		_:
			heading = "最後の欄外注　―　一枚を使う"
			body = "金縁のカードを選び、Enter／Aまたはクリックで使います。\n灰色のカードには使えない理由が書かれます。\n使う札がなくなったら『この葉を閉じる』か E／RB で敵の番です。"
	UI.illuminated_heading(page, "注", heading, Rect2(42, 39, 665, 53), 27)
	var copy: Label = UI.label(page, body, Rect2(49, 124, 662, 132), 20, UI.INK)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(page, "%d / 4" % (tutorial_step + 1), Rect2(50, 279, 85, 31), 17, UI.MUTED)
	var next_text: String = "次の注を読む"
	if tutorial_step == 1:
		next_text = "案内を閉じて、行き先を選ぶ"
	elif tutorial_step == 3:
		next_text = "案内を閉じて、カードを選ぶ"
	first_focus = UI.button(page, next_text, Rect2(46, 323, 452, 54), _tutorial_next, true)
	UI.button(page, "案内を読み飛ばす", Rect2(514, 323, 210, 54), _tutorial_skip)


func _tutorial_next() -> void:
	Sound.play("page")
	if tutorial_step in [1, 3]:
		tutorial_step += 1
		if tutorial_step >= 4:
			tutorial_step = -1
	else:
		tutorial_step += 1
	_render(false)


func _tutorial_skip() -> void:
	Sound.play("page")
	tutorial_step = -1
	_render(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("ui_cancel"):
		_close_modal()
	elif event.is_action_pressed("deck"):
		_open_deck()
	elif event.is_action_pressed("map"):
		_open_map()
	elif event.is_action_pressed("end_turn"):
		_end_turn()
