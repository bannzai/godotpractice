extends Control
## 入力と表示を担当。ルールと勝敗は Session.duel が所有する。

const Catalog = preload("res://scripts/card_catalog.gd")
const CardView = preload("res://scripts/card_view.gd")
const Effect = preload("res://scripts/duel_effect.gd")
const BACKGROUND = preload("res://assets/art/arena.svg")
const FONT = preload("res://assets/fonts/NotoSansJP.ttf")
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
var bgm: AudioStreamPlayer
var sounds: Array[AudioStreamPlayer] = []
var selected_zone: String = ""
var selected_index: int = -1
var inspected_id: String = ""
var hand_page: int = 0
var audio_stopped: bool = false
var busy: bool = false
var auto_phase: bool = false
var show_help: bool = false
var cpu_time: float = 0.0
var recent_messages: Array[String] = []
var last_focus: String = ""
var display_life: Array[float] = [8000.0, 8000.0]


func _ready() -> void:
	print("cardbattle boot")
	theme = Theme.new()
	var font := FontVariation.new()
	font.base_font = FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500}
	theme.default_font = font
	theme.default_font_size = 17
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	effect = Effect.new()
	effect.theme = theme
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(effect)
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -15
	add_child(bgm)
	bgm.finished.connect(bgm.play)
	# 最初のフレームで終了する起動検査で音声バックエンドの解放待ちを残さない。
	get_tree().create_timer(0.1).timeout.connect(_start_music)
	for index: int in range(4):
		var sound := AudioStreamPlayer.new()
		sound.volume_db = -10
		add_child(sound)
		sounds.append(sound)
	_render()


func _start_music() -> void:
	if audio_stopped or DisplayServer.get_name() == "headless":
		return
	bgm.stream = load("res://assets/audio/bgm.wav")
	bgm.play()


func _exit_tree() -> void:
	stop_audio()


func stop_audio() -> void:
	audio_stopped = true
	bgm.stop()
	bgm.stream = null
	for sound: AudioStreamPlayer in sounds:
		sound.stop()
		sound.stream = null


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, size), false)


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
	if busy or show_help or state.winner != -1:
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


func _render() -> void:
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
	var next_focus: Control = content.get_node_or_null(NodePath(last_focus))
	if next_focus is Button and not next_focus.disabled:
		next_focus.grab_focus()
	else:
		for child: Node in content.get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				break


func _title() -> void:
	_label("星を結び、勝利を刻む。", Rect2(82, 77, 800, 35), 22, TEAL)
	_label("星環の決闘", Rect2(75, 130, 730, 110), 76, WHITE)
	_label("四つの属性と、四十枚の可能性。", Rect2(84, 252, 650, 45), 26, GOLD)
	_label("相手のライフを削りきる、あなたの一手を。\n二つのデッキから選んで、星の守り手に挑もう。", Rect2(86, 317, 650, 90), 20, MUTED)
	_art("earth", Rect2(828, 120, 360, 270))
	_art("fire", Rect2(747, 275, 265, 199))
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
	_label("オリジナル図形・合成音源  /  日本語フォント: Noto Sans JP (OFL)", Rect2(85, 690, 1100, 22), 11, MUTED)


func _duel() -> void:
	_panel(Rect2(24, 18, 872, 97))
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
	_label("%s → %s → %s → %s" % ["ドロー", "メイン", "バトル", "エンド"], Rect2(47, 309, 520, 27), 15, MUTED)
	_label("現在: " + PHASE_NAMES[state.phase], Rect2(603, 306, 278, 34), 20, GOLD)
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
	_label("星環の決闘", Rect2(943, 34, 290, 41), 29, GOLD)
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
	var art_name: String = {"炎": "fire", "水": "water", "風": "wind", "土": "earth"}.get(
		card.attribute, "wind"
	)
	_art(art_name, Rect2(948, 177, 280, 139), "detail_art")
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
	if screen == "duel" and not show_help:
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
	_render()
	for event: Dictionary in events:
		var kind: String = event.type
		var player: int = event.get("player", 0)
		var origin := Vector2(460, 414 if player == 0 else 226)
		var destination := Vector2(460, 226 if player == 0 else 414)
		if kind == "draw":
			origin = Vector2(1190, 95)
			destination = Vector2(455, 626 if player == 0 else 137)
		elif kind == "summon":
			destination = origin
		var names: Dictionary = {
			"draw": "ドロー",
			"summon": "召喚",
			"attack": "攻撃",
			"destroy": "破壊",
			"damage": "ライフ減少",
			"trap": "罠 発動",
			"spell": "魔法 発動"
		}
		if names.has(kind):
			var caption: String = names[kind]
			if event.has("id") and not (kind == "draw" and player == 1):
				caption += "  " + Catalog.card(event.id).name
			if event.has("amount"):
				caption += "  %d" % event.amount
			effect.play(kind, caption, origin, destination)
			_play_sound(
				kind if kind in ["draw", "summon", "attack", "destroy", "damage"] else "summon"
			)
			await get_tree().create_timer(0.48).timeout
	busy = false
	cpu_time = 0
	if state.winner != -1:
		screen = "result"
		_play_sound("victory")
	_render()


func _result() -> void:
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
	for sound: AudioStreamPlayer in sounds:
		if not sound.playing:
			sound.stream = load("res://assets/audio/%s.wav" % kind)
			sound.play()
			return


func _panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("102536"), Color("355263")))
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
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("disabled", _style(Color("132b3a"), Color("294451")))
	button.add_theme_stylebox_override("normal", _style(Color("19384a"), Color("537277")))
	button.add_theme_stylebox_override("hover", _style(Color("245061"), TEAL))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("346571"), WHITE))
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
