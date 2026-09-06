extends Control
## 状態は Run が所有し、ここには描画と操作の進行だけを置く。

const UI := preload("res://scripts/ui.gd")
const Actor := preload("res://scripts/actor.gd")
const Effects := preload("res://scripts/effects.gd")
const Backdrop := preload("res://scripts/backdrop.gd")
const Catalog := preload("res://scripts/card_catalog.gd")

var screen: Control
var overlay: Control
var particles: Control
var card_nodes: Array[Button] = []
var enemy_art: Node2D
var hero_art: Node2D
var effects_layer: Control
var backdrop: Control
var displayed_phase: String = ""
var health_label: Label
var health_bar: ProgressBar
var displayed_hp: int = -1
var closing: bool = false
var busy: bool = false
var modal: String = ""
var first_focus: Button
var animation: Tween


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
	particles = Control.new()
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particles)
	card_nodes.clear()
	first_focus = null
	enemy_art = null
	hero_art = null
	if not is_instance_valid(backdrop):
		backdrop = Backdrop.new()
		backdrop.z_index = -10
		add_child(backdrop)
	backdrop.setup("boss" if Run.phase == "battle" and Run.current_kind == "boss" else Run.phase)
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
	_footer()
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
	var keyart: TextureRect = UI.art(screen, "title_keyart", Rect2(360, -70, 1000, 800))
	var fade := ShaderMaterial.new()
	fade.shader = preload("res://assets/shaders/keyart.gdshader")
	keyart.material = fade
	UI.panel(screen, Rect2(48, 69, 586, 566), Color("101c2cf0"), Color("687371"))
	UI.art(screen, "logo_mark", Rect2(86, 91, 68, 68))
	UI.label(screen, "八つの夜を越え、灯を空へ。", Rect2(171, 108, 410, 40), 21, UI.GOLD)
	UI.label(screen, "燈火の巡礼", Rect2(83, 184, 529, 98), 70)
	UI.label(screen, "カードを紡ぐ、ひとりの旅", Rect2(92, 293, 514, 42), 27, UI.GOLD)
	UI.label(screen, "進む道を選び、敵の意図を読み、灯を守る。\n一枚の選択が、夜明けまでの道になる。",
		Rect2(92, 376, 510, 74), 20, UI.MUTED)
	first_focus = UI.button(screen, "巡礼をはじめる　→", Rect2(92, 492, 414, 63), _start, true)
	UI.button(screen, "終了", Rect2(523, 492, 72, 63), _request_quit)
	UI.label(screen, "一幕完結　／　分岐する八階層", Rect2(94, 578, 470, 30), 17, UI.MUTED)


func _hud() -> void:
	UI.panel(screen, Rect2(24, 18, 1232, 64), Color("101c2cf5"), Color("536963"))
	UI.art(screen, "logo_mark", Rect2(36, 25, 43, 43))
	UI.label(screen, "燈火の巡礼", Rect2(87, 29, 178, 40), 23, UI.GOLD)
	health_label = UI.label(screen, "", Rect2(284, 21, 194, 32), 20)
	health_bar = UI.meter(screen, Rect2(284, 61, 177, 5), Run.max_hp, Run.hp, UI.RUST)
	var previous: int = Run.hp if displayed_hp < 0 else displayed_hp
	UI.count(health_label, previous, Run.hp, "体力  %d / " + str(Run.max_hp))
	displayed_hp = Run.hp
	UI.label(screen, "第 %02d / 08 層" % maxi(1, Run.floor_index + 1), Rect2(499, 29, 165, 36), 21)
	UI.button(screen, "デッキ %d [D]" % Run.deck.size(), Rect2(771, 30, 190, 42), _open_deck)
	UI.button(screen, "地図 [M]", Rect2(975, 30, 128, 42), _open_map)
	UI.button(screen, "音 切替", Rect2(1117, 30, 116, 42), _toggle_audio)


func _footer() -> void:
	UI.panel(screen, Rect2(0, 686, 1280, 34), Color("10262df5"), Color.TRANSPARENT)
	UI.label(screen, "矢印 / 十字キー: 選択　 Enter / A: 決定　 Esc / B: 戻る　 D / Y: デッキ　 M / X: 地図",
		Rect2(30, 686, 1020, 32), 15, UI.MUTED)
	UI.label(screen, "F11: 全画面", Rect2(1130, 686, 140, 32), 15, UI.MUTED)


func _map() -> void:
	UI.label(screen, "巡礼路", Rect2(58, 112, 660, 60), 42)
	UI.label(screen, "次の灯を選ぶ。傷を癒すか、強敵から遺物を得るか。", Rect2(60, 174, 1040, 38), 21, UI.MUTED)
	var message_label: Label = UI.label(screen, Run.message,
		Rect2(650, 120, 570, 74), 17, UI.GOLD)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_draw_route(screen, true)
	UI.panel(screen, Rect2(58, 524, 1164, 140), Color("16363deb"), Color("64716a"))
	UI.label(screen, "携えた遺物", Rect2(80, 539, 300, 36), 24, UI.GOLD)
	UI.label(screen, _relic_text(), Rect2(80, 581, 968, 72), 18)
	for index: int in range(Run.relics.size()):
		UI.art(screen, "relic_" + Run.relics[index], Rect2(1060 + index * 49, 543, 46, 46))


func _draw_route(parent: Control, interactive: bool) -> void:
	for row_index: int in range(Run.map_rows.size()):
		var x: float = 74 + row_index * 145
		var row: Array = Run.map_rows[row_index]
		UI.label(parent, "%02d" % (row_index + 1), Rect2(x, 233, 120, 35), 24, UI.GOLD)
		for choice: int in range(row.size()):
			var node: Dictionary = row[choice]
			var y: float = 286 + choice * 78
			var active: bool = row_index == Run.floor_index + 1 and interactive
			if row_index == 7:
				y = 340
			var caption: String = "最上階\nボス" if node.kind == "boss" else str(node.label)
			if row_index < Run.route.size() and Run.route[row_index] == choice:
				caption = "✓ " + caption
			var button: Button = UI.button(parent, caption, Rect2(x, y, 126, 64),
				_choose_node.bind(choice), active)
			button.icon = load("res://assets/art/route_" + str(node.kind) + ".svg")
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 25)
			button.add_theme_font_size_override("font_size", 16)
			button.disabled = not active
			if row_index <= Run.floor_index:
				button.modulate = Color(0.65, 0.75, 0.7, 0.65)
			if active and first_focus == null:
				first_focus = button
		if row_index < 7:
			UI.label(parent, "›", Rect2(x + 128, 347, 22, 30), 24, UI.GOLD)


func _battle(draw_cards: bool) -> void:
	UI.label(screen, "第 %d ターン" % Run.turn, Rect2(54, 100, 300, 38), 26, UI.GOLD)
	UI.label(screen, "弱体：与ダメージ−25%　脆弱：被ダメージ＋50%", Rect2(54, 145, 640, 32), 17, UI.MUTED)
	hero_art = _actor("hero", Rect2(103, 155, 254, 264))
	UI.label(screen, "灯守", Rect2(146, 400, 200, 34), 24)
	UI.label(screen, "防御 %d  /  力 %d" % [Run.block, Run.strength],
		Rect2(84, 446, 340, 28), 19, UI.GOLD)
	UI.label(screen, _status_text(Run.weak, Run.vulnerable),
		Rect2(64, 188, 350, 32), 17, UI.RUST)
	UI.panel(screen, Rect2(749, 100, 438, 62), Color("402f32"), UI.RUST)
	UI.label(screen, "次の行動　" + Run.intent_text(), Rect2(771, 110, 395, 44), 23)
	enemy_art = _actor(_enemy_asset(), Rect2(808, 145, 282, 278))
	UI.label(screen, str(Run.enemy.name), Rect2(820, 394, 380, 38), 25)
	UI.label(screen, "体力 %d / %d   防御 %d" % [Run.enemy.hp, Run.enemy.max_hp, Run.enemy.block],
		Rect2(786, 446, 422, 28), 20, UI.GOLD)
	UI.meter(screen, Rect2(805, 439, 265, 5), Run.enemy.max_hp, Run.enemy.hp, UI.RUST)
	UI.label(screen, _status_text(Run.enemy.weak, Run.enemy.vulnerable),
		Rect2(804, 173, 410, 32), 17, UI.RUST)
	UI.art(screen, "icon_energy", Rect2(563, 202, 86, 86))
	UI.label(screen, "エネルギー　%d / 3" % Run.energy, Rect2(498, 280, 228, 40), 24, UI.GOLD)
	UI.label(screen, "山札 %d  捨て札 %d  廃棄 %d" % [Run.draw_pile.size(),
		Run.discard_pile.size(), Run.exhaust_pile.size()], Rect2(496, 327, 235, 30), 17)
	var message_label: Label = UI.label(screen, Run.message,
		Rect2(407, 380, 380, 72), 18, UI.MUTED)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hand_scroll := ScrollContainer.new()
	hand_scroll.position = Vector2(48, 478)
	hand_scroll.size = Vector2(1010, 202)
	hand_scroll.follow_focus = true
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(hand_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hand_scroll.add_child(row)
	for index: int in range(Run.hand.size()):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(174, 184)
		row.add_child(slot)
		var button: Button = _card(slot, Run.hand[index],
			Rect2(0, 0, 174, 184), _play_card.bind(index))
		button.disabled = int(Catalog.CARDS[Run.hand[index]].cost) > Run.energy
		card_nodes.append(button)
		if not button.disabled and first_focus == null:
			first_focus = button
		if draw_cards:
			_draw_card_animation(button, index)
	var end: Button = UI.button(screen, "ターン終了\n[E / RB]", Rect2(1080, 507, 159, 97), _end_turn, true)
	if first_focus == null:
		first_focus = end
	UI.label(screen, "手札を捨てて\n敵の行動へ", Rect2(1090, 616, 158, 53), 17, UI.MUTED)


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
	return button


func _reward() -> void:
	UI.label(screen, "戦いの記憶を、一枚。", Rect2(100, 125, 1080, 60), 42)
	UI.label(screen, "デッキに加えるカードを選ぶ。見送って、今の構成を保つこともできる。",
		Rect2(104, 194, 1090, 42), 21, UI.MUTED)
	for index: int in range(Run.reward_cards.size()):
		var button: Button = _card(screen, Run.reward_cards[index],
			Rect2(185 + 312 * index, 270, 272, 283), _choose_reward.bind(index))
		if index == 0:
			first_focus = button
	UI.button(screen, "見送って先へ", Rect2(476, 595, 328, 58), _choose_reward.bind(-1))
	UI.label(screen, Run.message, Rect2(100, 235, 1080, 32), 19, UI.GOLD)


func _rest() -> void:
	UI.label(screen, "消えない焚火", Rect2(98, 154, 720, 70), 46)
	UI.label(screen, "火に手をかざす。長い夜にも、休息はある。\n体力を回復して、次の道へ進もう。",
		Rect2(104, 267, 680, 90), 25)
	hero_art = _actor("hero", Rect2(873, 173, 260, 320))
	effects_layer.burst("heal", Vector2(994, 380), 0)
	first_focus = UI.button(screen, "休息して回復する", Rect2(104, 472, 458, 68), _rest_action, true)


func _event() -> void:
	UI.label(screen, "道端の小さな祠", Rect2(98, 154, 760, 70), 46)
	UI.label(screen, "古い巡礼者が残した贈り物。\n遺物は、この旅が終わるまで力を貸してくれる。",
		Rect2(104, 267, 740, 90), 24)
	hero_art = _actor("npc_keeper", Rect2(870, 166, 280, 350))
	first_focus = UI.button(screen, "贈り物を受け取る", Rect2(104, 472, 458, 68), _event_action, true)


func _result() -> void:
	UI.panel(screen, Rect2(190, 146, 900, 470), Color("193a40f0"), UI.GOLD)
	UI.label(screen, "夜明けに、灯は届いた。" if Run.won else "灯は、また誰かの手へ。",
		Rect2(239, 194, 840, 74), 42, UI.GOLD)
	UI.label(screen, "巡礼達成" if Run.won else "巡礼の終わり", Rect2(242, 300, 750, 46), 30)
	UI.art(screen, "logo_mark", Rect2(945, 272, 94, 94))
	var metrics: Array[int] = [Run.floor_index + 1, Run.deck.size(), Run.relics.size()]
	var captions: Array[String] = ["到達した階層", "携えたカード", "集めた遺物"]
	for index: int in range(metrics.size()):
		var x: float = 245 + index * 251
		var number: Label = UI.label(screen, "0", Rect2(x, 363, 100, 57), 38, UI.GOLD)
		UI.count(number, 0, metrics[index], "%02d")
		UI.label(screen, captions[index], Rect2(x, 423, 223, 30), 17, UI.MUTED)
	first_focus = UI.button(screen, "もう一度 巡礼する", Rect2(243, 486, 367, 65), _start, true)
	UI.button(screen, "タイトルへ", Rect2(650, 486, 355, 65), _return_title)


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
	Run.start_run()


func _return_title() -> void:
	_close_modal()
	Run.return_title()


func _choose_node(index: int) -> void:
	if not busy:
		Run.choose_node(index)


func _choose_reward(index: int) -> void:
	Run.choose_reward(index)


func _rest_action() -> void:
	if busy:
		return
	busy = true
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
	UI.art(overlay, "background", Rect2(0, 0, 1280, 720))
	UI.panel(overlay, Rect2(24, 50, 1232, 622), Color("122e36"), UI.GOLD)


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
