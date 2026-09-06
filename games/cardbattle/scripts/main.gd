extends Control
## 入力と表示を担当。ルールと勝敗は Session.duel が所有する。
## 入力コールバックは押下ごとに選択・画面・音を進めるため非冪等。

const Catalog = preload("res://scripts/card_catalog.gd")
const CardView = preload("res://scripts/card_view.gd")
const Effect = preload("res://scripts/duel_effect.gd")
const Backdrop = preload("res://scripts/starfield.gd")
const Audio = preload("res://scripts/duel_audio.gd")
const Actor = preload("res://scripts/card_actor.gd")
const DUEL_THEME = preload("res://scenes/duel_theme.tres")
const GOLD := Color("dfbc72")
const TEAL := Color("58d6c0")
const WHITE := Color("f3ead8")
const MUTED := Color("9ab5c6")
const PHASE_NAMES := {"draw": "ドロー", "main": "メイン", "battle": "バトル", "end": "エンド"}

var state: RefCounted:
	get:
		return get_node("/root/Session").duel
var screen: String = "title"
var content: Control
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
var cpu_time: float = 0.0
var recent_messages: Array[String] = []
var last_focus: String = ""
var display_life: Array[float] = [8000.0, 8000.0]


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
		show_help = false
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
	get_node("/root/Session").start(deck_index, seed_value)
	screen = "duel"
	selected_zone = ""
	selected_index = -1
	inspected_id = ""
	hand_page = 0
	busy = false
	show_help = false
	cpu_time = 0
	recent_messages.clear()
	display_life = [8000.0, 8000.0]
	_render()
	audio.set_scene("duel")
	_play_sound("transition")
	_reveal_screen()


func _render() -> void:
	backdrop.duel = screen == "duel"
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus and content.is_ancestor_of(focus):
		last_focus = str(focus.name)
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match screen:
		"title":
			_title()
		"duel":
			_duel()
		"result":
			_result()
	if show_help:
		_help()
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
	_art("title_keyart", Rect2(692, 20, 578, 578))
	_art("logo", Rect2(82, 60, 64, 64))
	_label("星を結び、勝利を刻む。", Rect2(160, 78, 520, 35), 20, TEAL)
	_label("星環の決闘", Rect2(75, 144, 730, 100), 76, WHITE)
	_label("四つの属性と、四十枚の可能性。", Rect2(84, 252, 650, 45), 26, GOLD)
	_label("相手のライフを削りきる、あなたの一手を。\n二つのデッキから選んで、星の守り手に挑もう。", Rect2(86, 317, 650, 90), 20, MUTED)
	_label("日輪と月影、二つの宿命。", Rect2(832, 575, 398, 32), 20, GOLD)
	_button(
		"deck0",
		Catalog.deck_name(0) + "\n攻撃と強化で押し切る",
		Rect2(85, 443, 335, 98),
		func() -> void: start_duel(0)
	)
	_button(
		"deck1",
		Catalog.deck_name(1) + "\n守備と罠で形勢を変える",
		Rect2(440, 443, 335, 98),
		func() -> void: start_duel(1)
	)
	_button("help", "遊び方", Rect2(85, 563, 190, 49), _toggle_help)
	_button(
		"audio",
		"音: 切" if AudioServer.is_bus_mute(0) else "音: 入",
		Rect2(296, 563, 190, 49),
		_toggle_audio
	)
	_label(
		"矢印 / 十字キー: 選択    Enter / A: 決定    F11 / START: 全画面", Rect2(85, 653, 1100, 28), 15, MUTED
	)
	_label("オリジナルイラスト・音楽  /  日本語フォント: Noto Sans JP (OFL)", Rect2(85, 690, 1100, 22), 11, MUTED)


func _duel() -> void:
	_panel(Rect2(24, 18, 872, 97))
	_life_bar(1, Rect2(43, 101, 257, 4), GOLD)
	_life_bar(0, Rect2(599, 101, 257, 4), TEAL)
	_label("星の守り手  /  CPU", Rect2(43, 29, 330, 25), 17, MUTED)
	_label("あなた", Rect2(598, 29, 260, 25), 17, TEAL)
	_label("%04d" % roundi(display_life[1]), Rect2(42, 50, 270, 50), 35, WHITE, "life1")
	_label("%04d" % roundi(display_life[0]), Rect2(596, 50, 270, 50), 35, WHITE, "life0")
	_label("ライフ", Rect2(170, 76, 90, 22), 12, MUTED)
	_label("ライフ", Rect2(725, 76, 90, 22), 12, MUTED)
	_label(
		"第 %d ターン\n%s" % [state.turn, "あなたの番" if state.turn_player == 0 else "CPU 思考中"],
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
		card.pressed.connect(_select.bind("hand", index, hand[index]))
		card.focus_entered.connect(_inspect.bind(hand[index]))
		card.mouse_entered.connect(_inspect.bind(hand[index]))
		content.add_child(card)
	_button("prevhand", "‹ Q / LB", Rect2(605, 538, 126, 30), _page.bind(-1))
	_button("nexthand", "E / RB ›", Rect2(746, 538, 136, 30), _page.bind(1))


func _sidebar() -> void:
	_panel(Rect2(921, 18, 335, 690))
	_art("logo", Rect2(942, 34, 37, 37))
	_label("星環の決闘", Rect2(990, 34, 250, 41), 28, GOLD)
	_label(
		"山札 %d   墓地 %d" % [state.players[0].deck.size(), state.players[0].grave.size()],
		Rect2(945, 87, 285, 28),
		16,
		MUTED
	)
	_button("grave", "墓地を見る", Rect2(1098, 85, 140, 31), _show_grave)
	_detail()
	_actions()
	_button(
		"phase",
		"次のフェイズ  N / Y",
		Rect2(940, 506, 298, 43),
		_next_phase,
		state.turn_player != 0 or busy
	)
	_button(
		"auto", "ドロー・エンド自動: " + ("入" if auto_phase else "切"), Rect2(940, 559, 298, 35), _toggle_auto
	)
	_button("help", "遊び方", Rect2(940, 604, 142, 35), _toggle_help)
	_button(
		"audio",
		"音: " + ("切" if AudioServer.is_bus_mute(0) else "入"),
		Rect2(1096, 604, 142, 35),
		_toggle_audio
	)
	_label(state.message, Rect2(942, 652, 289, 46), 12, TEAL)


func _detail() -> void:
	for child_name: String in ["detail_name", "detail_art", "detail_stats", "detail_text"]:
		var previous: Node = content.get_node_or_null(NodePath(child_name))
		if previous:
			content.remove_child(previous)
			previous.queue_free()
	if inspected_id.is_empty():
		_label("カードを選択", Rect2(944, 133, 290, 36), 21, WHITE, "detail_name")
		_label(
			"手札や場のカードに触れると\nここに効果が表示されます。\n\n手札を決定して召喚・魔法・罠。\nバトルでは自分の攻撃役を選び、\n相手のカードを決定して攻撃。",
			Rect2(944, 185, 289, 200),
			17,
			MUTED,
			"detail_text"
		)
		return
	var card: Dictionary = Catalog.card(inspected_id)
	_label(card.name, Rect2(944, 130, 290, 36), 24, WHITE, "detail_name")
	var actor := Actor.new()
	actor.name = "detail_art"
	actor.position = Vector2(948, 172)
	content.add_child(actor)
	actor.setup(inspected_id, Vector2(280, 145))
	var stats: String = "魔法" if card.type == "spell" else "罠・攻撃時に自動発動"
	if card.type == "monster":
		stats = "攻 %d   守 %d   /   ★%d・%s" % [card.attack, card.defense, card.level, card.attribute]
	_label(stats, Rect2(944, 326, 291, 25), 15, GOLD, "detail_stats")
	_label(card.text, Rect2(944, 366, 289, 77), 16, WHITE, "detail_text")


func _actions() -> void:
	if selected_index < 0 or state.turn_player != 0 or busy:
		return
	if selected_zone == "hand" and selected_index < state.players[0].hand.size():
		if state.phase != "main":
			_label("メインフェイズで使用できます", Rect2(944, 450, 290, 43), 16, TEAL)
			return
		var card: Dictionary = Catalog.card(state.players[0].hand[selected_index])
		if card.type == "monster":
			if state.summoned or state.players[0].monsters.size() >= 5:
				_label("召喚済み、または場が満員です", Rect2(944, 450, 290, 43), 16, TEAL)
				return
			_button("summon", "攻撃召喚", Rect2(940, 451, 143, 43), _summon.bind(false))
			_button("defend", "守備召喚", Rect2(1095, 451, 143, 43), _summon.bind(true))
		elif card.type == "spell":
			_button("cast", "魔法を発動", Rect2(940, 451, 298, 43), _cast)
		else:
			_button("set", "罠を伏せる", Rect2(940, 451, 298, 43), _set_trap)
	elif selected_zone == "monster0":
		if state.phase == "main":
			_button("position", "攻撃 / 守備を切替", Rect2(940, 451, 298, 43), _change_position)
		elif state.phase == "battle":
			if state.players[1].monsters.is_empty():
				_button("attack", "直接攻撃", Rect2(940, 451, 298, 43), _attack.bind(-1))
			else:
				_label("相手のモンスターを選んで攻撃", Rect2(944, 450, 290, 43), 16, TEAL)


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
	_art("cards/m11" if state.winner == 0 else "cards/m23", Rect2(-55, 155, 435, 435))
	_art("logo", Rect2(1035, 225, 200, 200))
	_panel(Rect2(268, 105, 744, 505))
	_label("決闘終了", Rect2(320, 140, 640, 38), 23, TEAL)
	_label("あなたの勝利" if state.winner == 0 else "あなたの敗北", Rect2(319, 208, 646, 90), 55, GOLD)
	_label(state.message, Rect2(329, 321, 620, 60), 21, WHITE)
	_label(
		(
			"第 %d ターン  /  残りライフ %d  /  相手 %d"
			% [state.turn, state.players[0].life, state.players[1].life]
		),
		Rect2(331, 401, 620, 35),
		19,
		MUTED
	)
	_button("retry", "同じデッキで再戦", Rect2(326, 492, 305, 63), _retry)
	_button("title", "タイトルへ", Rect2(650, 492, 305, 63), _back_title)


func _retry() -> void:
	start_duel(get_node("/root/Session").selected_deck)


func _back_title() -> void:
	screen = "title"
	show_help = false
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
	show_help = not show_help
	_render()


func _help() -> void:
	for child: Node in content.get_children():
		if child is Button:
			child.disabled = true
	_panel(Rect2(171, 55, 938, 610))
	_label("遊び方", Rect2(210, 77, 835, 52), 34, GOLD)
	_label(
		(
			"勝利条件  相手のライフ8000を0にする、または相手がドローできなくなる。\n\n"
			+ "ドロー → メイン → バトル → エンド。N / Yで進行。自動はドローとエンドのみ。\n"
			+ "メイン: 手札を選んで通常召喚を1回。場は5体、罠は5枚まで。生け贄は不要。\n"
			+ "攻撃表示で召喚すればそのターンから攻撃可。ただし最初のターンは攻撃不可。\n"
			+ "魔法は即発動。破壊は最も強い相手、強化は最も強い味方が自動で対象になる。\n"
			+ "罠は伏せると相手の攻撃時に自動発動。攻守の切替はメイン中に1体1回。\n\n"
			+ "バトル: 攻撃役を決定 → 相手を決定。相手がいなければ「直接攻撃」。\n"
			+ "攻撃同士: 低い側を破壊し差分ダメージ。同値は両方破壊。\n"
			+ "守備への攻撃: 上回れば破壊、下回れば攻撃側に差分ダメージ。同値は変化なし。\n\n"
			+ "矢印 / 十字キー: 移動　Enter / A: 決定　Esc / B: 解除・閉じる\n"
			+ "Q・E / LB・RB: 手札ページ　F11 / START: 全画面　マウスにも対応"
		),
		Rect2(213, 147, 860, 433),
		17,
		WHITE
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


func _panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", _style(Color(0.04, 0.09, 0.14, 0.95), Color("355263"))
	)
	content.add_child(panel)


func _label(value: String, rect: Rect2, pixels: int, color: Color, node_name: String = "") -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = value
	label.position = rect.position
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	label.size = rect.size
	label.set_deferred("size", rect.size)
	return label


func _art(art_name: String, rect: Rect2, node_name: String = "") -> void:
	var art := TextureRect.new()
	if not node_name.is_empty():
		art.name = node_name
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture = load("res://assets/art/%s.svg" % art_name)
	art.position = rect.position
	art.size = rect.size
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)


func _button(
	node_name: String, value: String, rect: Rect2, action: Callable, unavailable: bool = false
) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.disabled = unavailable
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = rect.size * 0.5
	button.mouse_entered.connect(_button_motion.bind(button, Vector2.ONE * 1.025))
	button.mouse_exited.connect(_button_motion.bind(button, Vector2.ONE))
	button.button_down.connect(_button_motion.bind(button, Vector2.ONE * 0.975))
	button.button_up.connect(_button_motion.bind(button, Vector2.ONE))
	button.pressed.connect(action)
	content.add_child(button)
	return button


func _style(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box


func _life_bar(player: int, rect: Rect2, color: Color) -> void:
	var bar := ProgressBar.new()
	bar.name = "life_bar%d" % player
	bar.position = rect.position
	bar.size = rect.size
	bar.max_value = 8000.0
	bar.value = display_life[player]
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("1b2b39"), Color.TRANSPARENT))
	bar.add_theme_stylebox_override("fill", _style(color, Color.TRANSPARENT))
	content.add_child(bar)
	bar.size = rect.size
	bar.set_deferred("size", rect.size)


func _phase_track() -> void:
	for index: int in PHASE_NAMES.size():
		var phase: String = PHASE_NAMES.keys()[index]
		var active: bool = state.phase == phase
		var rect := Rect2(38 + index * 143, 308, 134, 30)
		var panel := Panel.new()
		panel.position = rect.position
		panel.size = rect.size
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(
			"panel",
			_style(
				Color("244747") if active else Color("0d1c2a"), GOLD if active else Color("293d48")
			)
		)
		content.add_child(panel)
		_label(
			PHASE_NAMES[phase],
			Rect2(rect.position + Vector2(25, 3), Vector2(105, 26)),
			15,
			GOLD if active else MUTED
		)
	_label("あなたの番" if state.turn_player == 0 else "相手の番", Rect2(670, 308, 211, 29), 18, TEAL)


# 押下ごとの視覚フィードバックであり、現在の Tween を置き換えて重複を防ぐ。
func _button_motion(button: Button, target: Vector2) -> void:
	if button.has_meta("motion"):
		var previous: Tween = button.get_meta("motion")
		previous.kill()
	var motion: Tween = button.create_tween()
	motion.tween_property(button, "scale", target, 0.12).set_trans(Tween.TRANS_QUAD)
	button.set_meta("motion", motion)


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
