extends Control
## 進行は GameState に集約する。ここに持つのは表示・技選択・演出の一時状態だけ。
## ボタン操作とアニメーションはユーザーの一回の行動を表すため非冪等。

const UI := preload("res://scripts/ui.gd")
const Catalog := preload("res://scripts/catalog.gd")
const Story := preload("res://scripts/story.gd")
const Actor := preload("res://scripts/actor.gd")
const Backdrop := preload("res://scripts/backdrop.gd")
const Effects := preload("res://scripts/effects.gd")
const Sound := preload("res://scripts/sound.gd")
const RouteView := preload("res://scripts/route_view.gd")
const TYPE_COLORS: Dictionary = {
	"grudge": Color("cd938c"), "sorrow": Color("83bfca"), "rage": Color("d6b276")
}

var run: Node
var screen: Control
var first_focus: Button
var busy: bool = false
var sound: Node
var backdrop: Node2D
var effects: Node
var actor_nodes: Array[Node2D] = []
var enemy_nodes: Array[Node2D] = []
var seed_input: LineEdit
var moves: Array[int] = [0, 0, 0]
var target_index: int = 0
var overlay: String = ""
var codex_page: int = 0
var swap_front: int = 0
var _previous_mode: String = ""
var _previous_darkness: int = 0
var _closing: bool = false
var _feedback: Label
var _health_bars: Dictionary = {}
var _health_labels: Dictionary = {}
var _health_names: Dictionary = {}
var _empty_slots: Array[Dictionary] = []


func _ready() -> void:
	print("ghostrogue boot")
	run = get_tree().root.get_node("GameState")
	theme = load("res://assets/ui/night.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop = Backdrop.new()
	add_child(backdrop)
	sound = Sound.new()
	add_child(sound)
	effects = Effects.new()
	add_child(effects)
	run.changed.connect(_on_changed)
	get_tree().auto_accept_quit = false
	render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()


func request_quit() -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(run) and run.mode != "title":
		run.save_game()
	stop_audio()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0)


func stop_audio() -> void:
	if is_instance_valid(sound):
		sound.stop_audio()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not busy:
		if overlay != "":
			_close_overlay()
		elif run.mode != "title":
			_open_overlay("pause")
		get_viewport().set_input_as_handled()


func _on_changed() -> void:
	if not busy:
		render()


func render() -> void:
	if not is_instance_valid(run):
		return
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	screen = Control.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	move_child(effects, -1)
	actor_nodes.clear()
	enemy_nodes.clear()
	_health_bars.clear()
	_health_labels.clear()
	_health_names.clear()
	_empty_slots.clear()
	first_focus = null
	var scene_kind: String = str(run.mode)
	if run.mode == "event":
		scene_kind = str(run.current_node.get("kind", "story"))
	elif run.mode == "battle":
		scene_kind = str(run.battle_kind)
	backdrop.setup(scene_kind)
	backdrop.set_darkness(run.darkness)
	if run.darkness > _previous_darkness:
		effects.darkness_pulse()
		sound.play_sfx("heartbeat")
	_previous_darkness = run.darkness
	if scene_kind != _previous_mode:
		effects.transition()
		sound.play_bgm(_music_for(scene_kind))
		if scene_kind == "police":
			sound.play_sfx("siren")
			effects.flash(Color("af384858"))
			effects.shake()
		elif scene_kind in ["grave", "living"]:
			sound.play_sfx("spirit")
			effects.flash(Color("aacfc844"))
		_previous_mode = scene_kind
	if overlay != "":
		_draw_overlay()
	else:
		match run.mode:
			"title":
				_draw_title()
			"intro":
				_draw_intro()
			"map":
				_draw_map()
			"event":
				_draw_event()
			"battle":
				_draw_battle()
			"result":
				_draw_result()
	_footer()
	if is_instance_valid(first_focus):
		_focus_safely.call_deferred(first_focus)


func _focus_safely(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()


func _music_for(kind: String) -> String:
	if kind in ["title", "battle", "police", "boss", "result"]:
		return kind
	return "map"


func _button(
	id: String, text: String, rect: Rect2, callback: Callable, hint: String = ""
) -> Button:
	var button: Button = UI.button(screen, id, text, rect, callback, hint)
	button.pressed.connect(_click_sound)
	if first_focus == null:
		first_focus = button
	return button


func _click_sound() -> void:
	sound.play_sfx("select")


func _footer() -> void:
	UI.label(
		screen,
		"移動  方向キー / 左スティック　 決定  Enter / A　 戻る  Esc / B　 全画面  F11",
		Rect2(44, 684, 1140, 25),
		14,
		UI.MUTED
	)
	UI.label(screen, "夜を継ぐ者", Rect2(1110, 682, 135, 26), 16, UI.GOLD)


func _draw_title() -> void:
	UI.panel(screen, Rect2(42, 55, 618, 599), Color("10212be8"))
	UI.label(screen, "幽霊収集ローグライク", Rect2(82, 88, 430, 30), 20, UI.GOLD)
	UI.texture(screen, "res://assets/art/logo.svg", Rect2(71, 131, 569, 128))
	UI.label(screen, "妹を救うために、どこまで奪えるか。", Rect2(82, 260, 520, 44), 25)
	UI.label(screen, "十二の辻。従える魂は三つ。\n力を集めるたび、あなたの影は濃くなる。", Rect2(82, 326, 520, 70), 23, UI.MUTED)
	_button("StartRun", "新しい夜へ", Rect2(82, 428, 270, 56), _start_run)
	var resume: Button = _button("ResumeRun", "夜の続きから", Rect2(365, 428, 242, 56), _resume)
	resume.disabled = not run.has_save()
	_button("OpenCodex", "霊の手帳", Rect2(82, 500, 254, 52), _open_overlay.bind("codex"))
	_button("Help", "旅の手引き", Rect2(350, 500, 257, 52), _open_overlay.bind("help"))
	UI.label(screen, "夜の種", Rect2(84, 580, 100, 30), 19, UI.MUTED)
	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "空欄で新しい道"
	seed_input.add_theme_font_size_override("font_size", 18)
	screen.add_child(seed_input)
	seed_input.position = Vector2(191, 577)
	seed_input.size = Vector2(250, 38)
	UI.label(screen, "同じ数字で道を再現", Rect2(454, 584, 170, 24), 14, UI.MUTED)
	UI.texture(screen, "res://assets/art/keyart.svg", Rect2(624, 107, 623, 567))


func _start_run() -> void:
	var seed_value: int = int(seed_input.text) if is_instance_valid(seed_input) else 0
	overlay = ""
	moves.assign([0, 0, 0])
	target_index = 0
	run.new_run(seed_value)


func _resume() -> void:
	overlay = ""
	if not run.load_game():
		render()
		UI.label(screen, "保存を読み込めませんでした。新しい夜を始められます。", Rect2(82, 622, 550, 25), 16, UI.RED)


func _draw_intro() -> void:
	_actor("hero_0", Vector2(274, 360), 1.3)
	UI.label(screen, "序章　消えた声", Rect2(95, 118, 390, 50), 32, UI.GOLD)
	UI.panel(screen, Rect2(484, 80, 748, 573))
	UI.label(screen, Story.INTRO.title, Rect2(520, 112, 672, 60), 32)
	UI.label(screen, Story.INTRO.text, Rect2(520, 200, 672, 340), 23)
	_button("BeginJourney", "灯を掲げ、町へ入る", Rect2(729, 568, 458, 57), run.begin_journey)


func _header(title: String, subtitle: String = "") -> void:
	UI.panel(screen, Rect2(24, 20, 1232, 87), Color("10222eeb"))
	UI.label(screen, title, Rect2(46, 34, 355, 40), 30)
	UI.label(screen, subtitle, Rect2(47, 76, 355, 23), 14, UI.MUTED)
	_actor("hero_%d" % run.darkness_stage(), Vector2(440, 58), 0.25)
	UI.label(screen, "辻 %02d / 12" % run.depth, Rect2(489, 37, 120, 32), 22)
	UI.texture(screen, "res://assets/art/icon_spirit.svg", Rect2(609, 40, 26, 26))
	UI.texture(screen, "res://assets/art/icon_item.svg", Rect2(740, 41, 26, 26))
	UI.texture(screen, "res://assets/art/icon_darkness.svg", Rect2(867, 31, 29, 29))
	UI.label(screen, "霊気 %d" % run.ether, Rect2(641, 38, 100, 30), 22, Color("9ccacc"))
	UI.label(screen, "お守り %d" % run.relics, Rect2(769, 39, 104, 30), 20, UI.GOLD)
	UI.label(screen, "闇 %d / 100" % run.darkness, Rect2(902, 29, 238, 32), 23, UI.RED)
	UI.bar(screen, Rect2(902, 68, 224, 10), run.darkness, 100, UI.RED)
	var stage: String = "人の心"
	if run.darkness >= 80:
		stage = "極刑対象 / 暴走"
	elif run.darkness >= 60:
		stage = "暴走する魂"
	elif run.darkness >= 30:
		stage = "霊の攻撃 +25%"
	UI.label(screen, stage, Rect2(902, 80, 239, 22), 13, UI.MUTED)
	_button("Pause", "休止", Rect2(1160, 38, 72, 43), _open_overlay.bind("pause"))
	# 主操作へ最初のフォーカスを渡す。
	first_focus = null


func _draw_map() -> void:
	_header("夜の町を歩く", "夜の種 %d　/　次の辻を選ぶ" % run.run_seed)
	UI.panel(screen, Rect2(34, 132, 914, 389), Color("142735ca"))
	UI.label(screen, "夜葬の門へ", Rect2(61, 149, 650, 38), 24, UI.GOLD)
	UI.label(screen, "戦：戦闘　墓：墓場　命：依代　警：警察　灯：休息　語：物語", Rect2(61, 192, 844, 28), 16, UI.MUTED)
	UI.label(screen, run.last_message, Rect2(61, 227, 844, 35), 16, UI.PAPER)
	var route_view := RouteView.new()
	route_view.run = run
	route_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(route_view)
	route_view.position = Vector2(63, 219)
	route_view.size = Vector2(859, 300)
	var branches: Array = run.route[mini(run.depth, run.route.size() - 1)]
	for index: int in range(branches.size()):
		var info: Dictionary = branches[index]
		var kind: String = str(info.kind)
		var title: String = Catalog.NODE_LABELS.get(kind, kind)
		var hint: String = _node_hint(info)
		_button(
			"Branch%d" % index,
			title + "\n" + hint,
			Rect2(42 + index * 460, 541, 446, 109),
			_enter_node.bind(index)
		)
	_draw_party_sidebar()


func _node_hint(info: Dictionary) -> String:
	var hints: Dictionary = {
		"grave": "霊を得る / 闇が少し増える　祈って去ることもできる",
		"living": "狙った大霊を得る / 命と引き換えに闇が大きく増える",
		"police": "闇が濃いほど重い罰。逃走か戦闘かを選ぶ",
		"rest": "闇を鎮め、魂と霊気を回復する",
		"story": "町の記憶に耳を傾け、言葉を選ぶ",
		"boss": "夜を終わらせる最後の戦い",
	}
	return hints.get(str(info.get("kind", "")), "霊を指揮して戦う / 倒れた仲間は戻らない")


func _enter_node(index: int) -> void:
	moves.assign([0, 0, 0])
	target_index = 0
	sound.play_sfx("step")
	run.enter_node(index)


func _draw_party_sidebar() -> void:
	UI.panel(screen, Rect2(968, 132, 278, 518))
	UI.label(screen, "灯に従う魂", Rect2(988, 149, 230, 38), 25, UI.GOLD)
	for index: int in range(mini(3, run.party.size())):
		var member: Dictionary = run.party[index]
		var definition: Dictionary = Catalog.spirit(member.species)
		_actor(member.species, Vector2(1018, 254 + index * 106), 0.34)
		UI.label(screen, definition.name, Rect2(1062, 218 + index * 106, 164, 33), 21)
		UI.label(
			screen,
			"%s / HP %d" % [Catalog.TYPES[definition.type], member.hp],
			Rect2(1062, 252 + index * 106, 160, 24),
			16,
			UI.MUTED
		)
		UI.bar(
			screen,
			Rect2(1062, 282 + index * 106, 153, 5),
			member.hp,
			definition.hp,
			TYPE_COLORS[definition.type]
		)
	_button(
		"OpenParty",
		"編成・控え %d" % maxi(0, run.party.size() - 3),
		Rect2(988, 546, 239, 44),
		_open_overlay.bind("party")
	)
	_button("OpenCodex", "霊の手帳", Rect2(988, 598, 239, 36), _open_overlay.bind("codex"))


func _draw_event() -> void:
	var kind: String = str(run.current_node.kind)
	_header(Catalog.NODE_LABELS.get(kind, "夜の記憶"), "選択の代償は、灯を掲げる前に見える。")
	var title: String = ""
	var body: String = ""
	var actor_id: String = "hero_%d" % run.darkness_stage()
	match kind:
		"story":
			var entry: Dictionary = Story.EVENTS[int(run.current_node.get("story", 0))]
			title = entry.title
			body = entry.text
			actor_id = "child" if int(run.current_node.get("story", 0)) == 0 else "hero_0"
		"grave":
			title = "土の下から、声がする。"
			body = "崩れた墓標の下に、帰れない魂が眠っている。\n\n"
			body += "墓を暴けば力になる。\nけれど、安らぎを奪った事実は消えない。"
			actor_id = str(run.current_node.get("spirit", "doll"))
		"living":
			title = "その力には、まだ命が繋がっている。"
			actor_id = str(run.current_node.get("spirit", "beast"))
			body = "ここには「%s」を宿す生きた依代がいる。\n\n" % Catalog.spirit(actor_id).name
			body += "命を断てば、この大霊は確実に手に入る。\n妹を救う力のために、別の命を奪うのか。"
		"police":
			title = "「その灯を、下ろしなさい」"
			body = "赤い光が路地を塞ぐ。封魂警官はあなたの影を見ている。\n\n"
			body += "逃走には前衛の速さが役立つ。\n闇が濃いほど、失敗した時に失うものは増える。"
			actor_id = "police"
		"rest":
			title = "まだ消えていない、小さな灯。"
			body = "荒れた祠に、誰かが残した蝋燭がある。\n\n"
			body += "立ち止まって、人だった頃の名を呼ぶ。\n霊たちは傷を癒し、あなたの影も少し薄くなる。"
	_actor(actor_id, Vector2(250, 354), 1.23)
	UI.label(screen, Catalog.NODE_LABELS.get(kind, ""), Rect2(78, 568, 355, 42), 28, UI.GOLD)
	UI.panel(screen, Rect2(465, 136, 778, 350))
	UI.label(screen, title, Rect2(496, 169, 715, 93), 29)
	UI.label(screen, body, Rect2(496, 275, 709, 199), 22)
	var options: Array = run.event_choices()
	for index: int in range(options.size()):
		var choice: Dictionary = options[index]
		_button(
			"EventChoice%d" % index,
			"%s\n%s" % [choice.text, choice.get("hint", "")],
			Rect2(471 + (index % 2) * 392, 493 + (index / 2) * 82, 376, 76),
			_choose_event.bind(index)
		)


func _choose_event(index: int) -> void:
	var before: int = run.party.size()
	run.choose_event(index)
	if run.party.size() > before:
		sound.play_sfx("acquire")
		effects.burst(Vector2(640, 360), UI.GOLD)
		var pop: Label = UI.label(screen, "魂が灯に加わった", Rect2(469, 116, 487, 38), 28, UI.GOLD)
		var tween: Tween = pop.create_tween()
		tween.tween_property(pop, "position:y", 99.0, 0.9)
		tween.parallel().tween_property(pop, "modulate:a", 0.0, 1.4)


func _draw_battle() -> void:
	_header(
		"夜の霊戦" if run.battle_kind == "battle" else Catalog.NODE_LABELS[run.battle_kind],
		"怨 → 哀 → 怒 → 怨 は2倍 / 逆は半分 / 速さ順"
	)
	UI.label(screen, "前衛の技と狙う相手を選ぶ", Rect2(45, 128, 600, 32), 21, UI.GOLD)
	UI.label(screen, "第 %d 手　/　霊が倒れると永久に失う" % run.turn, Rect2(741, 128, 495, 32), 20, UI.RED)
	_feedback = UI.label(screen, run.last_message, Rect2(94, 168, 1110, 54), 22, UI.PAPER)
	for index: int in range(mini(3, run.party.size())):
		var member: Dictionary = run.party[index]
		var node: Node2D = _actor(member.species, Vector2(153 + index * 224, 333), 0.73)
		node.set_meta("uid", member.uid)
		actor_nodes.append(node)
		_draw_combat_card(member, index)
	target_index = clampi(target_index, 0, maxi(0, run.enemies.size() - 1))
	for index: int in range(run.enemies.size()):
		var enemy: Dictionary = run.enemies[index]
		var definition: Dictionary = Catalog.spirit(enemy.species)
		var x: float = 858 + index * 195
		var node: Node2D = _actor(
			enemy.species, Vector2(x + 38, 329), 1.10 if enemy.species == "boss" else 0.84
		)
		node.set_meta("uid", enemy.uid)
		node.scale.x = -absf(node.scale.x)
		enemy_nodes.append(node)
		var selected: String = "狙う ● " if target_index == index else "狙う　"
		_button(
			"Target%d" % index,
			selected + str(definition.name),
			Rect2(x - 59, 423, 218, 43),
			_target.bind(index)
		)
		_health_labels[enemy.uid] = UI.label(
			screen,
			"%s / 速 %d / HP %d" % [Catalog.TYPES[definition.type], definition.speed, enemy.hp],
			Rect2(x - 55, 474, 228, 28),
			17,
			TYPE_COLORS[definition.type]
		)
		_health_labels[enemy.uid].set_meta("species", enemy.species)
		_health_bars[enemy.uid] = UI.bar(
			screen, Rect2(x - 52, 509, 202, 8), enemy.hp, definition.hp, UI.RED
		)
		UI.label(
			screen,
			"予告：%s" % Catalog.MOVES[definition.moves[int(run.turn % 3 == 0)]].name,
			Rect2(x - 55, 531, 230, 30),
			16,
			UI.MUTED
		)
	_button("ResolveTurn", "命令を送る", Rect2(812, 579, 399, 63), _resolve)
	UI.label(screen, "固有技の括弧は霊気消費 / 霊気は共有 / 通常技は消費なし", Rect2(58, 649, 700, 25), 16, UI.MUTED)
	# 技ではなく送信が最初の決定対象なので、通常技だけならEnterで進められる。
	first_focus = screen.get_node("ResolveTurn")


func _draw_combat_card(member: Dictionary, index: int) -> void:
	var definition: Dictionary = Catalog.spirit(member.species)
	var x: float = 43 + index * 225
	UI.panel(screen, Rect2(x, 411, 214, 230))
	_health_names[member.uid] = UI.label(screen, definition.name, Rect2(x + 12, 421, 196, 34), 23)
	_health_labels[member.uid] = UI.label(
		screen,
		"%s / 速 %d / HP %d" % [Catalog.TYPES[definition.type], definition.speed, member.hp],
		Rect2(x + 12, 461, 199, 28),
		16,
		TYPE_COLORS[definition.type]
	)
	_health_labels[member.uid].set_meta("species", member.species)
	_health_bars[member.uid] = UI.bar(
		screen, Rect2(x + 12, 496, 190, 6), member.hp, definition.hp, TYPE_COLORS[definition.type]
	)
	for choice: int in range(2):
		var move: Dictionary = Catalog.MOVES[definition.moves[choice]]
		var prefix: String = "● " if moves[index] == choice else ""
		var choice_button: Button = _button(
			"Move%d_%d" % [index, choice],
			"%s%s%s" % [prefix, move.name, " (%d)" % move.cost if move.cost > 0 else ""],
			Rect2(x + 8, 516 + choice * 57, 198, 49),
			_select_move.bind(index, choice),
			"威力 %.1f倍 / 霊気 %d" % [move.power, move.cost]
		)
		choice_button.add_theme_font_size_override("font_size", 16)


func _select_move(member_index: int, choice: int) -> void:
	moves[member_index] = choice
	render()
	var button: Button = screen.get_node("Move%d_%d" % [member_index, choice])
	_focus_safely.call_deferred(button)


func _target(index: int) -> void:
	target_index = index
	render()


func _resolve() -> void:
	if busy:
		return
	busy = true
	for button: Node in screen.find_children("*", "Button", true, false):
		button.disabled = true
	var actions: Array = run.resolve_turn(moves.slice(0, mini(3, run.party.size())), target_index)
	for event: Dictionary in actions:
		if is_instance_valid(_feedback):
			_feedback.text = event.get("text", "")
		var attacker: Node2D = _combat_actor(
			event.get("actor_side", ""), int(event.get("actor_uid", 0))
		)
		var victim: Node2D = _combat_actor(
			event.get("target_side", ""), int(event.get("target_uid", 0))
		)
		if event.kind == "attack":
			if is_instance_valid(attacker):
				attacker.play_motion("attack")
			await get_tree().create_timer(0.12).timeout
			if is_instance_valid(victim):
				victim.play_motion("hurt")
				effects.burst(victim.position, UI.RED)
				_damage_pop(victim.position, int(event.damage))
				_update_health(int(event.target_uid), int(event.hp))
				effects.shake()
				effects.hit_stop()
				sound.play_sfx("hurt")
			await get_tree().create_timer(0.17).timeout
		elif event.kind == "lost":
			if is_instance_valid(victim):
				victim.play_motion("dissolve")
				sound.play_sfx("dissolve")
				if event.target_side == "party":
					_empty_slots.append({"point": victim.position, "uid": int(event.target_uid)})
			await get_tree().create_timer(0.4).timeout
		elif event.kind == "promoted":
			_promote_actor(event.unit)
			await get_tree().create_timer(0.24).timeout
		elif event.kind == "wild":
			effects.flash(Color("d73c4940"))
			await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.16).timeout
	busy = false
	render()


func _promote_actor(unit: Dictionary) -> void:
	if _empty_slots.is_empty():
		return
	var slot: Dictionary = _empty_slots.pop_front()
	var node: Node2D = _actor(unit.species, slot.point, 0.73)
	node.set_meta("uid", unit.uid)
	actor_nodes.append(node)
	node.play_motion("move")
	for widgets: Dictionary in [_health_bars, _health_labels, _health_names]:
		widgets[unit.uid] = widgets[slot.uid]
		widgets.erase(slot.uid)
	var definition: Dictionary = Catalog.spirit(unit.species)
	_health_names[unit.uid].text = definition.name
	_health_labels[unit.uid].set_meta("species", unit.species)
	_health_bars[unit.uid].max_value = definition.hp
	_update_health(unit.uid, unit.hp)


func _combat_actor(side: String, uid: int) -> Node2D:
	var nodes: Array[Node2D] = actor_nodes if side == "party" else enemy_nodes
	for node: Node2D in nodes:
		if is_instance_valid(node) and int(node.get_meta("uid", 0)) == uid:
			return node
	return null


func _update_health(uid: int, hp: int) -> void:
	if not _health_bars.has(uid):
		return
	var meter: ProgressBar = _health_bars[uid]
	var caption: Label = _health_labels[uid]
	var definition: Dictionary = Catalog.spirit(caption.get_meta("species"))
	caption.text = "%s / 速 %d / HP %d" % [Catalog.TYPES[definition.type], definition.speed, hp]
	meter.create_tween().tween_property(meter, "value", hp, 0.18)


func _damage_pop(point: Vector2, value: int) -> void:
	var number: Label = UI.label(
		screen, "−%d" % value, Rect2(point.x - 34, point.y - 40, 140, 70), 40, UI.RED
	)
	number.add_theme_constant_override("outline_size", 6)
	number.add_theme_color_override("font_outline_color", Color("081a24"))
	var tween: Tween = number.create_tween()
	tween.tween_property(number, "position:y", point.y - 101, 0.5).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(number, "modulate:a", 0.0, 0.6)


func _draw_result() -> void:
	var end: Dictionary = Story.ENDINGS.get(run.ending, Story.ENDINGS.lost)
	UI.panel(screen, Rect2(433, 69, 810, 581), Color("10242fee"))
	var saved: bool = run.ending in ["saved", "scarred"]
	UI.label(screen, "夜明け" if saved else "夜は、まだ終わらない", Rect2(76, 111, 350, 56), 33, UI.GOLD)
	_actor("hero_%d" % run.darkness_stage(), Vector2(232, 364), 1.4)
	UI.label(screen, end.title, Rect2(469, 101, 734, 73), 40)
	UI.label(screen, end.text, Rect2(469, 201, 733, 123), 24, UI.MUTED)
	var totals: Label = UI.label(
		screen,
		(
			"辿った辻　%d / 12　　集めた霊　%d　　最後の闇　%d"
			% [run.route_choices.size(), run.collected.size(), run.darkness]
		),
		Rect2(469, 358, 730, 42),
		22,
		UI.GOLD
	)
	var counting: Tween = totals.create_tween()
	counting.tween_method(_count_totals.bind(totals), 0.0, 1.0, 0.38)
	UI.label(screen, "共に夜を歩いた魂", Rect2(469, 421, 724, 35), 21, UI.MUTED)
	var names: PackedStringArray = []
	for id: String in run.collected:
		names.append(Catalog.spirit(id).name)
	UI.label(screen, " / ".join(names), Rect2(469, 467, 719, 83), 20)
	_button("ReturnTitle", "タイトルへ戻る", Rect2(820, 571, 372, 56), run.to_title)


func _count_totals(amount: float, caption: Label) -> void:
	caption.text = (
		"辿った辻　%d / 12　　集めた霊　%d　　最後の闇　%d"
		% [
			roundi(run.route_choices.size() * amount),
			roundi(run.collected.size() * amount),
			roundi(run.darkness * amount)
		]
	)


func _actor(id: String, point: Vector2, factor: float = 1.0) -> Node2D:
	var node := Actor.new()
	screen.add_child(node)
	node.position = point
	node.scale = Vector2.ONE * factor
	node.setup(id)
	return node


func _open_overlay(kind: String) -> void:
	if busy:
		return
	overlay = kind
	codex_page = 0
	render()


func _close_overlay() -> void:
	overlay = ""
	render()


func _draw_overlay() -> void:
	UI.panel(screen, Rect2(28, 25, 1224, 631), Color("10232ff5"))
	match overlay:
		"codex":
			_draw_codex()
		"party":
			_draw_party()
		"help":
			_draw_help()
		"pause":
			_draw_pause()
	_button("CloseOverlay", "戻る", Rect2(1091, 46, 131, 46), _close_overlay)


func _draw_codex() -> void:
	UI.label(screen, "霊の手帳", Rect2(63, 48, 700, 51), 37)
	UI.label(
		screen,
		"見つけた霊 %d / 12　/　大霊は生きた依代からのみ取得" % run.discovered.size(),
		Rect2(63, 109, 1040, 33),
		20,
		UI.MUTED
	)
	var ids: Array = Catalog.SPIRITS.keys()
	for index: int in range(4):
		var id: String = ids[codex_page * 4 + index]
		var definition: Dictionary = Catalog.spirit(id)
		var x: float = 49 + index * 298
		UI.panel(screen, Rect2(x, 164, 286, 410), Color("1f3644e8"))
		_actor(id, Vector2(x + 141, 272), 0.66)
		UI.label(screen, definition.name, Rect2(x + 16, 367, 259, 41), 27)
		UI.label(
			screen,
			(
				"%s / %s / %s"
				% [
					Catalog.TYPES[definition.type],
					Catalog.RARITIES[definition.rarity],
					"発見済" if id in run.discovered else "未発見"
				]
			),
			Rect2(x + 16, 410, 258, 26),
			16,
			TYPE_COLORS[definition.type]
		)
		UI.label(
			screen,
			"体力 %d　攻撃 %d　速さ %d" % [definition.hp, definition.attack, definition.speed],
			Rect2(x + 16, 447, 256, 29),
			16
		)
		UI.label(screen, definition.lore, Rect2(x + 16, 491, 255, 74), 18, UI.MUTED)
	_button("CodexPrevious", "前の頁", Rect2(389, 595, 170, 40), _codex_move.bind(-1))
	UI.label(screen, "%d / 3" % (codex_page + 1), Rect2(608, 601, 125, 30), 21, UI.GOLD)
	_button("CodexNext", "次の頁", Rect2(727, 595, 170, 40), _codex_move.bind(1))


func _codex_move(direction: int) -> void:
	codex_page = posmod(codex_page + direction, 3)
	render()


func _draw_party() -> void:
	UI.label(screen, "灯に従う魂の編成", Rect2(63, 48, 900, 52), 36)
	UI.label(
		screen, "前衛を選び、控えと入れ替える。傷はそのまま残る。戦闘中の入れ替えはできない。", Rect2(63, 116, 1100, 40), 21, UI.MUTED
	)
	for index: int in range(mini(3, run.party.size())):
		var member: Dictionary = run.party[index]
		var definition: Dictionary = Catalog.spirit(member.species)
		_actor(member.species, Vector2(186 + index * 401, 275), 0.67)
		_button(
			"Front%d" % index,
			"%s%s　HP %d" % ["● " if swap_front == index else "", definition.name, member.hp],
			Rect2(69 + index * 401, 370, 334, 54),
			_select_front.bind(index)
		)
	UI.label(screen, "控え", Rect2(64, 447, 1080, 38), 24, UI.GOLD)
	if run.party.size() <= 3:
		UI.label(screen, "控えの霊はまだいない。墓場や依代から新たな魂を集められる。", Rect2(64, 503, 1115, 76), 23, UI.MUTED)
	for index: int in range(3, run.party.size()):
		var member: Dictionary = run.party[index]
		_button(
			"Reserve%d" % index,
			"%s　HP %d" % [Catalog.spirit(member.species).name, member.hp],
			Rect2(62 + ((index - 3) % 4) * 294, 505 + ((index - 3) / 4) * 60, 280, 51),
			_swap.bind(index)
		)


func _select_front(index: int) -> void:
	swap_front = index
	render()


func _swap(index: int) -> void:
	run.swap_party(swap_front, index)


func _draw_help() -> void:
	UI.label(screen, "旅の手引き", Rect2(65, 55, 900, 60), 40)
	UI.label(screen, "力を得ることと、人でいること。", Rect2(65, 146, 1110, 55), 31, UI.GOLD)
	UI.label(
		screen,
		(
			"十二の辻から道を選び、夜葬の主を倒して妹の声を取り戻す。\n"
			+ "前衛は三体。通常技か霊気を使う固有技を選び、敵を指定して命令する。\n"
			+ "速さ順に行動し、怨→哀→怒→怨は2倍、逆は半分。倒れた霊は永久に失う。\n\n"
			+ "墓を荒らすと闇が増える。生きた依代を殺めれば、さらに強い大霊が手に入る。\n"
			+ "闇30で攻撃が上がり、60で命令を無視する暴走、80で警察の罰が最大になる。\n"
			+ "闇100であなた自身が夜に呑まれる。休息や善良な選択で闇を鎮めよう。\n\n"
			+ "警察からは逃げるか戦う。速い前衛は逃走に有利。戦って勝つと闇が大きく増える。\n"
			+ "選択の後に自動保存。休止からタイトルへ戻り、次回は「夜の続きから」で再開。"
		),
		Rect2(65, 230, 1128, 375),
		23
	)


func _draw_pause() -> void:
	UI.label(screen, "灯を休める", Rect2(69, 80, 1000, 63), 42)
	UI.label(screen, "ここまでの夜は記録されます。", Rect2(71, 180, 1000, 54), 27, UI.MUTED)
	_button("Continue", "旅を続ける", Rect2(340, 280, 599, 57), _close_overlay)
	_button("Help", "旅の手引き", Rect2(340, 357, 599, 57), _open_overlay.bind("help"))
	_button("SaveTitle", "保存してタイトルへ", Rect2(340, 434, 599, 57), _save_title)
	_button("Quit", "ゲームを終了", Rect2(340, 511, 599, 57), request_quit)


func _save_title() -> void:
	run.save_game()
	overlay = ""
	run.to_title()
