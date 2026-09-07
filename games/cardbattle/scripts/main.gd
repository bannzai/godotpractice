extends "res://scripts/main_ui.gd"
## 入力と表示を担当。ルールと勝敗は Session.duel が所有する。
## 入力コールバックは押下ごとに選択・画面・音を進めるため非冪等。

const Catalog = preload("res://scripts/card_catalog.gd")
const CardView = preload("res://scripts/card_view.gd")
const Effect = preload("res://scripts/duel_effect.gd")
const Backdrop = preload("res://scripts/starfield.gd")
const Audio = preload("res://scripts/duel_audio.gd")
const Actor = preload("res://scripts/card_actor.gd")
const DUEL_THEME = preload("res://scenes/duel_theme.tres")
const GOLD := Color("d6b45f")
const TEAL := Color("8fcaa5")
const WHITE := Color("f2e7c5")
const MUTED := Color("c0b38f")
const INK := Color("173c2a")
const BURGUNDY := Color("712f35")
const PHASE_NAMES := {"draw": "ドロー", "main": "メイン", "battle": "バトル", "end": "エンド"}

var state: RefCounted:
	get:
		return get_node("/root/Session").duel
var screen: String = "title"
var effect: Control
var audio: Node
var backdrop: Control
var transition: ColorRect
var transition_tween: Tween
var shake_tween: Tween
var closing: bool = false
var selected_zone: String = ""
var selected_index: int = -1
var inspected_id: String = ""
var hand_page: int = 0
var audio_stopped: bool = false
var busy: bool = false
var auto_phase: bool = false
var auto_actions_paused: bool = false
var show_help: bool = false
var show_tutorial: bool = false
var tutorial_seen: bool = false
var tutorial_step: int = 0
var selected_deck: int = 0
var tournament_round: int = 0
var cpu_time: float = 0.0
var recent_messages: Array[String] = []
var last_focus: String = ""


func _ready() -> void:
	print("cardbattle boot")
	theme = DUEL_THEME
	get_tree().auto_accept_quit = false
	backdrop = Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	effect = Effect.new()
	effect.theme = theme
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(effect)
	effect.impact.connect(_impact)
	audio = Audio.new()
	add_child(audio)
	transition = ColorRect.new()
	transition.color = Color("07111f")
	transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(transition)
	_render()
	audio.set_scene("title")
	_reveal_screen()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		_shutdown()


func _shutdown() -> void:
	closing = true
	busy = true
	await audio.shutdown()
	get_tree().quit()


func _exit_tree() -> void:
	stop_audio()


func stop_audio() -> void:
	audio_stopped = true
	if is_instance_valid(audio):
		audio.stop_audio()


# 画面遷移ごとに開始する視覚演出なので非冪等。前の遷移は置き換える。
func _reveal_screen() -> void:
	if transition_tween:
		transition_tween.kill()
	transition.modulate.a = 1.0
	content.modulate.a = 0.0
	transition_tween = create_tween().set_parallel(true)
	transition_tween.tween_property(transition, "modulate:a", 0.0, 0.38)
	transition_tween.tween_property(content, "modulate:a", 1.0, 0.48)


# 衝撃のたびに一時的な盤面移動とアニメーションの停止を開始するため非冪等。
func _impact(strength: float, duration: float) -> void:
	if shake_tween:
		shake_tween.kill()
	content.position = Vector2.ZERO
	shake_tween = create_tween()
	for offset: Vector2 in [Vector2(1, -0.5), Vector2(-0.7, 0.3), Vector2(0.4, -0.2), Vector2.ZERO]:
		shake_tween.tween_property(content, "position", offset * strength, duration / 4.0)
	for card: Node in content.get_children():
		if card is CardView and is_instance_valid(card.actor):
			card.actor.hit_stop(0.055)


# 経過時間によるCPU操作と表示補間はフレームごとに進むため非冪等。
func _process(delta: float) -> void:
	if screen != "duel":
		return
	for player: int in range(2):
		display_life[player] = move_toward(
			display_life[player], state.players[player].life, delta * 5000
		)
		var label: Label = content.get_node_or_null("life%d" % player)
		if label:
			label.text = "%04d" % roundi(display_life[player])
		var bar: ProgressBar = content.get_node_or_null("life_bar%d" % player)
		if bar:
			bar.value = display_life[player]
	if busy or show_help or auto_actions_paused or state.winner != -1:
		return
	cpu_time += delta
	if state.turn_player == 1 and cpu_time > 0.8:
		cpu_time = 0
		_perform(state.cpu_step())
	elif auto_phase and state.phase in ["draw", "end"] and cpu_time > 0.8:
		cpu_time = 0
		_perform(state.advance_phase())


# 入力イベントは押下ごとに操作を進めるため非冪等。
func _input(event: InputEvent) -> void:
	if closing or (busy and not event.is_action_pressed("duel_fullscreen")):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("duel_confirm"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			focused.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	for direction: String in ["up", "down", "left", "right"]:
		if event.is_action_pressed("duel_" + direction):
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused:
				var sides: Dictionary = {
					"up": SIDE_TOP, "down": SIDE_BOTTOM, "left": SIDE_LEFT, "right": SIDE_RIGHT
				}
				var neighbor: Control = focused.find_valid_focus_neighbor(sides[direction])
				if neighbor:
					neighbor.grab_focus()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("duel_fullscreen"):
		var mode: int = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			(
				DisplayServer.WINDOW_MODE_WINDOWED
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN
			)
		)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("duel_next") and screen == "duel" and not show_help:
		_next_phase()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("duel_cancel"):
		if show_help:
			show_help = false
		elif show_tutorial:
			_close_tutorial()
		elif screen == "tournament":
			screen = "title"
			_render()
		elif screen == "duel":
			selected_zone = ""
			selected_index = -1
			_render()
		get_viewport().set_input_as_handled()
	if screen == "duel" and event.is_action_pressed("duel_previous_hand"):
		_page(-1)
	if screen == "duel" and event.is_action_pressed("duel_next_hand"):
		_page(1)


func start_duel(deck_index: int, seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = int(Time.get_ticks_usec())
	selected_deck = deck_index
	get_node("/root/Session").start(deck_index, seed_value)
	screen = "duel"
	selected_zone = ""
	selected_index = -1
	inspected_id = ""
	hand_page = 0
	busy = false
	show_help = false
	show_tutorial = not tutorial_seen
	tutorial_step = 0
	cpu_time = 0
	recent_messages.clear()
	display_life = [8000.0, 8000.0]
	_render()
	audio.set_scene("duel")
	_play_sound("transition")
	_reveal_screen()


func _render() -> void:
	backdrop.duel = screen in ["duel", "tournament"]
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus and content.is_ancestor_of(focus):
		last_focus = str(focus.name)
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match screen:
		"title":
			_title()
		"tournament":
			_tournament()
		"duel":
			_duel()
		"result":
			_result()
	if show_help:
		_help()
	elif show_tutorial and screen == "duel":
		_tutorial()
	if busy:
		for child: Node in content.get_children():
			if child is Button:
				child.disabled = true
	var next_focus: Control = content.get_node_or_null(NodePath(last_focus))
	if next_focus is Button and not next_focus.disabled:
		next_focus.grab_focus()
	else:
		for child: Node in content.get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				break


func _title() -> void:
	_panel(Rect2(49, 43, 650, 630))
	_label("花影杯　招待状", Rect2(82, 69, 540, 31), 19, TEAL)
	_label("綺羅の決闘会", Rect2(78, 121, 590, 91), 65, WHITE)
	_label("金の蔓が結ぶ、三つの対戦席。", Rect2(84, 222, 560, 39), 25, GOLD)
	_label(
		"四十枚の札を選び、温室のトーナメントへ。\nカードに刻まれた強さと効果を読み、相手のライフを0にしよう。",
		Rect2(86, 286, 560, 78),
		18,
		MUTED
	)
	_framed_card_art("m11", Rect2(734, 52, 246, 344), "title_sun")
	_framed_card_art("m23", Rect2(970, 83, 226, 316), "title_moon")
	_label("参加する札束を選ぶ", Rect2(84, 401, 570, 34), 20, WHITE)
	_button(
		"deck0",
		Catalog.deck_name(0) + "\n攻撃と加護で押し切る　→ 大会表へ",
		Rect2(83, 448, 278, 105),
		_open_tournament.bind(0)
	)
	_button(
		"deck1",
		Catalog.deck_name(1) + "\n守備と罠で形勢を変える　→ 大会表へ",
		Rect2(378, 448, 278, 105),
		_open_tournament.bind(1)
	)
	_button("help", "綴じ本を開く", Rect2(83, 580, 184, 48), _toggle_help)
	_button(
		"audio",
		"蓄音機: 切" if AudioServer.is_bus_mute(0) else "蓄音機: 入",
		Rect2(285, 580, 184, 48),
		_toggle_audio
	)
	_label("Zen Antique / 生成イラスト", Rect2(948, 650, 266, 25), 13, MUTED)


func _open_tournament(deck_index: int) -> void:
	selected_deck = deck_index
	screen = "tournament"
	show_help = false
	_render()
	_play_sound("transition")
	_reveal_screen()


func _tournament() -> void:
	_panel(Rect2(55, 36, 1170, 648))
	_label("花影杯　対戦表", Rect2(90, 63, 700, 55), 39, WHITE)
	_label(
		"金色に灯る対戦札を選ぶ。勝つと次の額縁が開く。",
		Rect2(92, 119, 720, 30),
		17,
		TEAL
	)
	_label("使用札束　" + Catalog.deck_name(selected_deck), Rect2(864, 78, 315, 35), 18, GOLD)
	_rule(Rect2(296, 292, 128, 4), GOLD)
	_rule(Rect2(686, 292, 128, 4), GOLD)
	_rule(Rect2(424, 292, 4, 71), GOLD)
	_rule(Rect2(810, 222, 4, 73), GOLD)
	var names: Array[String] = ["温室の管理人", "黄昏の調香師", "百花の館主"]
	var notes: Array[String] = ["初戦　基本の召喚", "準決勝　守備と罠", "決勝　王の一手"]
	var arts: Array[String] = ["m03", "m15", "m23"]
	var xs: Array[float] = [104, 492, 878]
	var ys: Array[float] = [185, 255, 115]
	for round_index: int in range(3):
		_framed_card_art(
			arts[round_index], Rect2(xs[round_index], ys[round_index], 190, 266),
			"tournament_art%d" % round_index
		)
		var label: String = names[round_index] + "\n" + notes[round_index]
		var locked: bool = round_index != tournament_round
		if round_index < tournament_round:
			label += "\n勝利済み"
		elif round_index > tournament_round:
			label += "\n前の対戦で解放"
		else:
			label += "\n対戦する"
		_button(
			"round%d" % round_index,
			label,
			Rect2(xs[round_index] - 8, ys[round_index] + 283, 206, 86),
			_start_tournament_duel.bind(round_index),
			locked
		)
	_button("back", "招待状へ戻る", Rect2(88, 611, 205, 45), _back_title)
	_button("help", "大会の遊び方", Rect2(975, 611, 205, 45), _toggle_help)


func _start_tournament_duel(round_index: int) -> void:
	if round_index != tournament_round:
		return
	start_duel(selected_deck)


func _duel() -> void:
	_panel(Rect2(24, 18, 872, 91))
	_life_bar(1, Rect2(43, 101, 257, 4), GOLD)
	_life_bar(0, Rect2(599, 101, 257, 4), TEAL)
	_label("対戦者  /  CPU", Rect2(43, 29, 330, 25), 16, MUTED)
	_label("あなた  /  " + Catalog.deck_name(selected_deck), Rect2(598, 29, 280, 25), 15, TEAL)
	_label("%04d" % roundi(display_life[1]), Rect2(42, 50, 270, 50), 35, WHITE, "life1")
	_label("%04d" % roundi(display_life[0]), Rect2(596, 50, 270, 50), 35, WHITE, "life0")
	_label("ライフ", Rect2(170, 76, 90, 22), 12, MUTED)
	_label("ライフ", Rect2(725, 76, 90, 22), 12, MUTED)
	_label(
		"第 %d 席\n%s" % [state.turn, "あなたの手番" if state.turn_player == 0 else "相手が思案中"],
		Rect2(333, 39, 245, 60),
		19,
		GOLD
	)
	_zones(1, 167)
	_zones(0, 353)
	_spell_zones(1, 123)
	_spell_zones(0, 493)
	_phase_track()
	_label("手札 %d 枚" % state.players[0].hand.size(), Rect2(38, 540, 200, 26), 14, TEAL)
	_label(
		(
			"CPU  手札 %d  /  山札 %d  /  墓地 %d"
			% [
				state.players[1].hand.size(),
				state.players[1].deck.size(),
				state.players[1].grave.size()
			]
		),
		Rect2(484, 123, 402, 27),
		13,
		MUTED
	)
	_hand()
	_sidebar()


func _zones(player: int, y: float) -> void:
	for index: int in range(5):
		var card := CardView.new()
		card.name = "monster%d_%d" % [player, index]
		card.position = Vector2(38 + index * 170, y)
		card.size = Vector2(157, 133)
		var monsters: Array = state.players[player].monsters
		if index < monsters.size():
			var monster: Dictionary = monsters[index]
			card.card_id = monster.id
			card.defense = monster.defense
			card.exhausted = monster.attacked
			card.bonus = monster.boost
			card.selected = selected_zone == "monster%d" % player and selected_index == index
			if player == 0:
				var reason: String = _monster_unavailable(monster)
				card.available = reason.is_empty()
				card.unavailable_reason = reason
			else:
				card.available = _can_choose_target()
				if card.available:
					card.preview_text = _battle_preview(selected_index, index)
			card.pressed.connect(_select.bind("monster%d" % player, index, monster.id))
			card.focus_entered.connect(_inspect.bind(monster.id))
			card.mouse_entered.connect(_inspect.bind(monster.id))
		else:
			card.disabled = true
			card.focus_mode = Control.FOCUS_NONE
		content.add_child(card)


func _spell_zones(player: int, y: float) -> void:
	_label("伏せ", Rect2(40, y, 40, 26), 12, MUTED)
	for index: int in range(5):
		var present: bool = index < state.players[player].spells.size()
		var label: String = "◆" if present else "·"
		var button: Button = _button(
			"spell%d_%d" % [player, index],
			label,
			Rect2(84 + index * 66, y, 58, 29),
			func() -> void: pass
		)
		button.disabled = not present
		if present and player == 0:
			var id: String = state.players[player].spells[index]
			button.focus_entered.connect(_inspect.bind(id))
			button.mouse_entered.connect(_inspect.bind(id))
			button.pressed.connect(_inspect.bind(id))
		elif present:
			button.focus_entered.connect(_inspect_hidden)
			button.mouse_entered.connect(_inspect_hidden)


func _hand() -> void:
	var hand: Array = state.players[0].hand
	hand_page = clampi(hand_page, 0, maxi(0, (hand.size() - 1) / 7))
	for offset: int in range(7):
		var index: int = hand_page * 7 + offset
		if index >= hand.size():
			break
		var card := CardView.new()
		card.name = "hand%d" % index
		card.position = Vector2(38 + offset * 122, 574)
		card.size = Vector2(113, 134)
		card.card_id = hand[index]
		card.selected = selected_zone == "hand" and selected_index == index
		card.unavailable_reason = _hand_unavailable(hand[index])
		card.available = card.unavailable_reason.is_empty()
		card.pressed.connect(_select.bind("hand", index, hand[index]))
		card.focus_entered.connect(_inspect.bind(hand[index]))
		card.mouse_entered.connect(_inspect.bind(hand[index]))
		content.add_child(card)
	_button("prevhand", "前の手札", Rect2(605, 538, 126, 30), _page.bind(-1))
	_button("nexthand", "次の手札", Rect2(746, 538, 136, 30), _page.bind(1))


func _hand_unavailable(id: String) -> String:
	var reason := ""
	if state.turn_player != 0:
		reason = "相手の手番"
	elif state.phase != "main":
		reason = "メインで使用"
	else:
		var card: Dictionary = Catalog.card(id)
		if card.type == "monster" and state.summoned:
			reason = "召喚は使用済み"
		elif card.type == "monster" and state.players[0].monsters.size() >= 5:
			reason = "場が満員"
		elif card.type == "trap" and state.players[0].spells.size() >= 5:
			reason = "伏せ場が満員"
		elif card.effect == "destroy" and state.players[1].monsters.is_empty():
			reason = "破壊対象なし"
		elif card.effect == "boost" and state.players[0].monsters.is_empty():
			reason = "強化対象なし"
		elif card.effect == "draw" and state.players[0].deck.size() < 2:
			reason = "山札が不足"
	return reason


func _monster_unavailable(monster: Dictionary) -> String:
	var reason := ""
	if state.turn_player != 0:
		reason = "相手の手番"
	elif state.phase == "main":
		if monster.changed:
			reason = "表示変更済み"
		elif monster.attacked:
			reason = "攻撃後は変更不可"
	elif state.phase != "battle":
		reason = "メインかバトルで選ぶ"
	elif state.turn == 1:
		reason = "初手は攻撃不可"
	elif monster.defense:
		reason = "守備中"
	elif monster.attacked:
		reason = "攻撃済み"
	return reason


func _can_choose_target() -> bool:
	return (
		selected_zone == "monster0"
		and selected_index >= 0
		and state.phase == "battle"
		and state.turn_player == 0
	)


func _battle_preview(attacker_index: int, target_index: int) -> String:
	var preview := ""
	if attacker_index < 0 or attacker_index >= state.players[0].monsters.size():
		return preview
	if target_index >= 0 and target_index < state.players[1].monsters.size():
		var attacker: Dictionary = state.players[0].monsters[attacker_index]
		var target: Dictionary = state.players[1].monsters[target_index]
		var attack_power: int = state.power(attacker)
		if target.defense:
			var guard: int = Catalog.card(target.id).defense
			if attack_power > guard:
				preview = "破壊する"
			elif attack_power < guard:
				preview = "反撃 %d" % (guard - attack_power)
			else:
				preview = "互角"
		else:
			var target_power: int = state.power(target)
			if attack_power > target_power:
				preview = "破壊 +%d" % (attack_power - target_power)
			elif attack_power < target_power:
				preview = "自壊 -%d" % (target_power - attack_power)
			else:
				preview = "相打ち"
	return preview


func _sidebar() -> void:
	_paper_panel(Rect2(921, 18, 335, 690))
	_label("卓上の記録", Rect2(944, 34, 250, 41), 27, INK)
	_label(
		"山札 %d   墓地 %d" % [state.players[0].deck.size(), state.players[0].grave.size()],
		Rect2(945, 87, 285, 28),
		16,
		Color("5c5138")
	)
	_button("grave", "墓地を見る", Rect2(1098, 85, 140, 31), _show_grave)
	_detail()
	_actions()
	_button(
		"phase",
		_next_phase_label(),
		Rect2(940, 505, 298, 48),
		_next_phase,
		state.turn_player != 0 or busy
	)
	_button(
		"auto", "封蝋の自動送り: " + ("入" if auto_phase else "切"), Rect2(940, 564, 298, 35), _toggle_auto
	)
	_button("help", "綴じ本", Rect2(940, 610, 142, 35), _toggle_help)
	_button(
		"audio",
		"蓄音機: " + ("切" if AudioServer.is_bus_mute(0) else "入"),
		Rect2(1096, 610, 142, 35),
		_toggle_audio
	)
	_label(state.message, Rect2(942, 657, 289, 42), 12, BURGUNDY)


func _next_phase_label() -> String:
	var next: Dictionary = {
		"draw": "メイン", "main": "バトル", "battle": "エンド", "end": "相手の手番"
	}
	return "封蝋を押す　%sへ  [N / Y]" % next.get(state.phase, "次")


func _detail() -> void:
	for child_name: String in ["detail_name", "detail_art", "detail_stats", "detail_text"]:
		var previous: Node = content.get_node_or_null(NodePath(child_name))
		if previous:
			content.remove_child(previous)
			previous.queue_free()
	if inspected_id.is_empty():
		_label("札に触れて確かめる", Rect2(944, 133, 290, 36), 20, INK, "detail_name")
		_label(
			"金色の縁は、いま選べる札。\n使えない理由は札の上に現れます。\n\n攻撃役を選ぶと、相手の札に\n破壊・反撃・相打ちの予告が出ます。",
			Rect2(944, 185, 289, 200),
			17,
			INK,
			"detail_text"
		)
		return
	var card: Dictionary = Catalog.card(inspected_id)
	_label(card.name, Rect2(944, 130, 290, 36), 24, INK, "detail_name")
	var actor := Actor.new()
	actor.name = "detail_art"
	actor.position = Vector2(948, 172)
	content.add_child(actor)
	actor.setup(inspected_id, Vector2(280, 145))
	var stats: String = "魔法" if card.type == "spell" else "罠・攻撃時に自動発動"
	if card.type == "monster":
		stats = "攻 %d   守 %d   /   ★%d・%s" % [card.attack, card.defense, card.level, card.attribute]
	_label(stats, Rect2(944, 326, 291, 25), 15, BURGUNDY, "detail_stats")
	_label(card.text, Rect2(944, 366, 289, 77), 16, INK, "detail_text")


func _actions() -> void:
	if selected_index < 0 or state.turn_player != 0 or busy:
		return
	if selected_zone == "hand" and selected_index < state.players[0].hand.size():
		var selected_id: String = state.players[0].hand[selected_index]
		var reason: String = _hand_unavailable(selected_id)
		if not reason.is_empty():
			_label("この札はまだ使えない：" + reason, Rect2(944, 450, 290, 43), 15, BURGUNDY)
			return
		var card: Dictionary = Catalog.card(selected_id)
		if card.type == "monster":
			_label(
				"場へ出すと 攻%d / 守%d。今の手番から攻撃可。" % [card.attack, card.defense],
				Rect2(944, 442, 290, 34),
				13,
				INK
			)
			_button("summon", "攻撃向きで召喚", Rect2(940, 477, 143, 27), _summon.bind(false))
			_button("defend", "守備向きで召喚", Rect2(1095, 477, 143, 27), _summon.bind(true))
		elif card.type == "spell":
			_label("発動後：" + card.text, Rect2(944, 442, 290, 34), 13, INK)
			_button("cast", "この魔法を発動", Rect2(940, 477, 298, 27), _cast)
		else:
			_label("伏せると相手の攻撃時に自動発動。", Rect2(944, 442, 290, 34), 13, INK)
			_button("set", "この罠を伏せる", Rect2(940, 477, 298, 27), _set_trap)
	elif selected_zone == "monster0":
		if state.phase == "main":
			_label("表示を変えると今の手番では再変更できない。", Rect2(944, 442, 290, 34), 13, INK)
			_button("position", "攻撃 / 守備を切替", Rect2(940, 477, 298, 27), _change_position)
		elif state.phase == "battle":
			if state.players[1].monsters.is_empty():
				var attacker: Dictionary = state.players[0].monsters[selected_index]
				_label(
					"結果予告：相手へ %d の直接ダメージ" % state.power(attacker),
					Rect2(944, 442, 290, 34),
					13,
					BURGUNDY
				)
				_button("attack", "予告どおり直接攻撃", Rect2(940, 477, 298, 27), _attack.bind(-1))
			else:
				_label(
					"金色に光る相手札を選ぶ。結果は札上に予告。",
					Rect2(944, 450, 290, 43),
					14,
					BURGUNDY
				)


func _select(zone: String, index: int, id: String) -> void:
	if busy:
		return
	if (
		zone == "monster1"
		and selected_zone == "monster0"
		and state.phase == "battle"
		and state.turn_player == 0
	):
		_attack(index)
		return
	selected_zone = zone
	selected_index = index
	inspected_id = id
	_render()


func _inspect(id: String) -> void:
	inspected_id = id
	if screen == "duel" and not show_help and not busy:
		_detail()


func _inspect_hidden() -> void:
	inspected_id = ""
	_detail()
	var label: Label = content.get_node("detail_name")
	label.text = "相手の伏せカード"
	content.get_node("detail_text").text = "攻撃を宣言すると罠が発動する\n可能性があります。内容は非公開です。"


func _next_phase() -> void:
	if screen == "duel" and state.turn_player == 0 and not busy:
		_perform(state.advance_phase())


func _summon(defense: bool) -> void:
	_perform(state.summon(selected_index, defense))


func _cast() -> void:
	_perform(state.play_spell(selected_index))


func _set_trap() -> void:
	_perform(state.set_trap(selected_index))


func _change_position() -> void:
	_perform(state.change_position(selected_index))


func _attack(target: int) -> void:
	if state.turn_player != 0 or busy:
		return
	_perform(state.attack(selected_index, target))


# 成功した操作結果を時間順に再生するため非冪等。busy で重複入力を防ぐ。
func _perform(success: bool) -> void:
	if not success:
		_render()
		return
	busy = true
	selected_zone = ""
	selected_index = -1
	recent_messages.append(state.message)
	if recent_messages.size() > 8:
		recent_messages.pop_front()
	var events: Array = state.events.duplicate(true)
	for child: Node in content.get_children():
		if child is Button:
			child.disabled = true
	for event: Dictionary in events:
		if event.type == "summon":
			_render()
		var actor_duration: float = _animate_card_event(event)
		var kind: String = event.type
		var player: int = event.get("player", 0)
		var origin := Vector2(460, 414 if player == 0 else 226)
		var destination := Vector2(460, 226 if player == 0 else 414)
		if kind == "draw":
			origin = Vector2(1190, 95)
			destination = Vector2(455, 626 if player == 0 else 137)
		elif kind in ["summon", "destroy"]:
			destination = Vector2(116 + event.get("target", 0) * 170, origin.y)
		elif kind == "attack":
			origin.x = 116 + event.get("source", 0) * 170
			destination.x = 116 + event.get("target", 0) * 170
			if event.get("target", -1) == -1:
				destination = Vector2(110 if player == 0 else 665, 80)
		elif kind == "damage":
			destination = Vector2(665 if player == 0 else 110, 80)
		var names: Dictionary = {
			"draw": "ドロー",
			"summon": "召喚",
			"attack": "攻撃",
			"destroy": "破壊",
			"damage": "ライフ減少",
			"trap": "罠 発動",
			"spell": "魔法 発動",
			"set": "罠をセット"
		}
		if names.has(kind):
			var caption: String = names[kind]
			if event.has("id") and not (kind in ["draw", "set"] and player == 1):
				caption += "  " + Catalog.card(event.id).name
			if event.has("amount"):
				caption += "  %d" % event.amount
			var presentation_kind: String = kind
			if kind == "spell" and event.id == "boost":
				presentation_kind = "boost"
				destination = Vector2(116 + state._strongest(player) * 170, origin.y)
			effect.play(presentation_kind, caption, origin, destination)
			_play_sound(presentation_kind if presentation_kind != "spell" else "summon")
			await get_tree().create_timer(maxf(effect.duration(), actor_duration + 0.06)).timeout
	busy = false
	cpu_time = 0
	if state.winner != -1:
		screen = "result"
		audio.set_scene("victory" if state.winner == 0 else "defeat")
		_play_sound("victory" if state.winner == 0 else "damage")
		_reveal_screen()
	_render()


func _result() -> void:
	_framed_card_art("m11" if state.winner == 0 else "m23", Rect2(65, 118, 285, 399))
	_panel(Rect2(319, 94, 886, 536))
	_label("花影杯　対戦結果", Rect2(375, 135, 710, 38), 23, TEAL)
	_label("勝利の花が開いた" if state.winner == 0 else "花影はまだ閉じている", Rect2(373, 207, 755, 90), 48, GOLD)
	_label(state.message, Rect2(383, 321, 700, 60), 21, WHITE)
	_label(
		(
			"第 %d ターン  /  残りライフ %d  /  相手 %d"
			% [state.turn, state.players[0].life, state.players[1].life]
		),
		Rect2(385, 401, 680, 35),
		19,
		MUTED
	)
	var continue_label: String = "同じ対戦札へ戻る"
	if state.winner == 0:
		continue_label = "優勝　大会表を最初から" if tournament_round == 2 else "次の対戦札を開く"
	_button("continue", continue_label, Rect2(379, 489, 325, 62), _advance_tournament)
	_button("retry", "この相手と再戦", Rect2(726, 489, 220, 62), _retry)
	_button("title", "招待状へ", Rect2(967, 489, 190, 62), _back_title)


func _retry() -> void:
	start_duel(selected_deck)


func _advance_tournament() -> void:
	if state.winner == 0:
		tournament_round = 0 if tournament_round >= 2 else tournament_round + 1
	screen = "tournament"
	show_help = false
	show_tutorial = false
	_render()
	audio.set_scene("title")
	_reveal_screen()


func _back_title() -> void:
	screen = "title"
	show_help = false
	show_tutorial = false
	_render()
	audio.set_scene("title")
	_reveal_screen()


func _page(direction: int) -> void:
	hand_page += direction
	_render()


func _toggle_auto() -> void:
	auto_phase = not auto_phase
	_render()


func _toggle_audio() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	_render()


func _toggle_help() -> void:
	show_tutorial = false
	show_help = not show_help
	_render()


func _tutorial() -> void:
	var texts: Array[String] = [
		"最初はドロー。右下の金の封蝋を押すと、札を使えるメインへ進みます。",
		"金色に光る手札はいま使える札。暗い帯には使えない理由が直接出ます。",
		"バトルでは自分の攻撃札、次に相手札を選択。相手札の帯で結果を予告します。",
	]
	var highlight: Panel
	if tutorial_step == 0:
		highlight = _highlight(Rect2(934, 499, 310, 61))
	elif tutorial_step == 1:
		highlight = _highlight(Rect2(29, 566, 862, 146))
	else:
		highlight = _highlight(Rect2(31, 158, 850, 337))
	highlight.z_index = 4
	var guide: Panel = _paper_panel(Rect2(932, 126, 313, 342))
	guide.z_index = 5
	_label(
		"卓上指南　%d / 3" % (tutorial_step + 1), Rect2(953, 149, 270, 37), 23, INK
	).z_index = 6
	_label(texts[tutorial_step], Rect2(953, 207, 270, 118), 17, INK).z_index = 6
	_label("光る場所を盤面で試せます。", Rect2(953, 333, 270, 31), 13, BURGUNDY).z_index = 6
	_button("tutorial_skip", "指南を閉じる", Rect2(951, 397, 126, 42), _close_tutorial).z_index = 6
	var next_button: Button = _button(
		"tutorial_next",
		"指南を終える" if tutorial_step == 2 else "次の説明",
		Rect2(1088, 397, 137, 42),
		_tutorial_next
	)
	next_button.z_index = 6


func _tutorial_next() -> void:
	if tutorial_step >= 2:
		_close_tutorial()
		return
	tutorial_step += 1
	_render()


func _close_tutorial() -> void:
	tutorial_seen = true
	show_tutorial = false
	_render()


func _help() -> void:
	for child: Node in content.get_children():
		if child is Button:
			child.disabled = true
	_paper_panel(Rect2(171, 55, 938, 610))
	_label("花影杯の綴じ本", Rect2(210, 77, 835, 52), 34, INK)
	_label(
		(
			"勝利　相手のライフ8000を0にする、または相手がドローできなくなる。\n\n"
			+ "一　封蝋を押して ドロー → メイン → バトル → エンド と進む。\n"
			+ "二　メインでは金色に光る手札を選ぶ。通常召喚は1回、場と伏せ札は各5枚まで。\n"
			+ "三　魔法は即発動。罠は伏せると相手の攻撃時に自動発動する。\n"
			+ "四　バトルでは自分の攻撃札を選び、次に結果予告の出た相手札を選ぶ。\n\n"
			+ "攻撃同士　低い側を破壊し、差分をライフから引く。同値は相打ち。\n"
			+ "守備へ攻撃　守備を上回れば破壊、下回れば攻撃側が差分を受ける。\n\n"
			+ "選べない理由と次に起きることは、札と封蝋の上へ直接表示される。"
		),
		Rect2(213, 147, 860, 433),
		17,
		INK
	)
	_button("closehelp", "閉じる", Rect2(754, 591, 307, 47), _toggle_help).grab_focus()


func _show_grave() -> void:
	inspected_id = ""
	_detail()
	content.get_node("detail_name").text = "墓地・直近の記録"
	var lines: String = ""
	for player: int in range(2):
		lines += ("あなた" if player == 0 else "CPU") + ":\n"
		var grave: Array = state.players[player].grave
		for index: int in range(maxi(0, grave.size() - 4), grave.size()):
			lines += Catalog.card(grave[index]).name + "\n"
	content.get_node("detail_text").text = lines if not lines.is_empty() else "まだカードがありません。"
	content.get_node("detail_text").position.y = 185
	content.get_node("detail_text").size.y = 250


func _play_sound(kind: String) -> void:
	if not audio_stopped:
		audio.play_effect(kind)


func _phase_track() -> void:
	_rule(Rect2(58, 322, 521, 3), Color("8e713a"))
	for index: int in PHASE_NAMES.size():
		var phase: String = PHASE_NAMES.keys()[index]
		var active: bool = state.phase == phase
		var rect := Rect2(38 + index * 143, 304, 134, 38)
		var panel := Panel.new()
		panel.position = rect.position
		panel.size = rect.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var seal := _style(
			BURGUNDY if active else Color("183c2a"), Color("f1d181") if active else Color("8e713a")
		)
		seal.set_corner_radius_all(19)
		seal.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", seal)
		content.add_child(panel)
		_label(
			"%d　%s" % [index + 1, PHASE_NAMES[phase]],
			Rect2(rect.position + Vector2(8, 7), Vector2(118, 27)),
			14,
			WHITE if active else MUTED
		)
	_label("あなたの手番" if state.turn_player == 0 else "相手が思案中", Rect2(670, 308, 211, 29), 18, TEAL)


# ルールが確定したイベントを表示中のカードに適用するため非冪等。
func _animate_card_event(event: Dictionary) -> float:
	var duration: float = 0.0
	var player: int = event.get("player", 0)
	var index: int = event.get("source", 0) if event.type == "attack" else event.get("target", 0)
	var card: Control = content.get_node_or_null("monster%d_%d" % [player, index])
	var action: String = {"summon": "summon", "attack": "attack", "destroy": "death"}.get(
		event.type, ""
	)
	if card is CardView and not action.is_empty():
		card.play_action(action)
		duration = card.actor.animation_length(action)
	if event.type == "attack" and event.get("target", -1) >= 0:
		var target: Control = content.get_node_or_null("monster%d_%d" % [1 - player, event.target])
		if target is CardView:
			duration = maxf(duration, 0.28 + target.actor.animation_length("hit"))
			get_tree().create_timer(0.28).timeout.connect(
				func() -> void:
					if is_instance_valid(target):
						target.play_action("hit")
			)
	if event.type == "summon" and event.id in ["m11", "m23"]:
		audio.set_scene("boss")
	return duration
