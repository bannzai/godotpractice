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
const CutIn := preload("res://scripts/cut_in.gd")
const NOTE_INK := Color("181108")
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
var street_view: Control
var street_selected: int = 0
var combat_page: int = 0
var street_hint: Label
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
	backdrop.set_district(run.depth)
	backdrop.set_darkness(run.darkness)
	sound.set_environment(scene_kind, run.darkness, run.depth)
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


func _draw_title() -> void:
	var keyart: TextureRect = UI.texture(
		screen, "res://assets/generated/title-keyart.png", Rect2(0, 0, 1280, 720)
	)
	keyart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var veil := ColorRect.new()
	veil.color = Color("00000096")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(veil)
	veil.position = Vector2.ZERO
	veil.size = Vector2(1280, 720)
	UI.label(screen, "昭和怪異録", Rect2(61, 54, 520, 35), 22, UI.GOLD)
	var title: Label = UI.label(screen, "夜を継ぐ者", Rect2(55, 91, 670, 120), 72, UI.PAPER)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	UI.label(screen, "妹の声を追い、十二の夜道へ。", Rect2(64, 218, 600, 47), 27)
	UI.label(
		screen,
		"照らした入口だけが、次の選択になる。\n強い魂を得るほど、手帳の赤字は増えてゆく。",
		Rect2(66, 279, 555, 90),
		20,
		UI.GHOST
	)
	_button("StartRun", "懐中電灯を点ける", Rect2(65, 413, 327, 58), _start_run)
	var resume: Button = _button("ResumeRun", "夜道へ戻る", Rect2(411, 413, 254, 58), _resume)
	resume.disabled = not run.has_save()
	_button("OpenCodex", "黒い手帳を開く", Rect2(65, 489, 285, 51), _open_overlay.bind("codex"))
	_button("Help", "失踪記録", Rect2(368, 489, 220, 51), _open_overlay.bind("help"))
	UI.label(screen, "事件番号", Rect2(67, 581, 116, 30), 18, UI.MUTED)
	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "空欄なら今夜の日付"
	seed_input.add_theme_font_size_override("font_size", 18)
	screen.add_child(seed_input)
	seed_input.position = Vector2(188, 575)
	seed_input.size = Vector2(268, 40)
	UI.label(screen, "同じ番号で同じ町", Rect2(470, 583, 180, 24), 14, UI.MUTED)


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
	var keyart: TextureRect = UI.texture(
		screen, "res://assets/generated/title-keyart.png", Rect2(0, 0, 1280, 720)
	)
	keyart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UI.panel(screen, Rect2(621, 42, 617, 635), Color("050505ed"))
	UI.label(screen, "第一夜　妹の声", Rect2(662, 77, 527, 52), 31, UI.GOLD)
	UI.label(screen, Story.INTRO.title, Rect2(661, 145, 532, 70), 36)
	UI.label(screen, Story.INTRO.text, Rect2(662, 229, 522, 278), 22, UI.GHOST)
	UI.label(
		screen,
		"手帳の最初の頁：\n通りを歩く → 墓地へ入る → 霊を迎える → 霊戦",
		Rect2(662, 485, 522, 71),
		18,
		UI.RED
	)
	_button("BeginJourney", "懐中電灯を握り、通りへ", Rect2(662, 582, 521, 62), run.begin_journey)


func _header(title: String, subtitle: String = "") -> void:
	UI.panel(screen, Rect2(25, 20, 610, 83), Color("030303e8"))
	UI.label(screen, title, Rect2(47, 31, 560, 40), 29)
	UI.label(screen, subtitle, Rect2(49, 72, 550, 24), 14, UI.GHOST)
	_button("OpenCodex", "黒い手帳", Rect2(1081, 29, 166, 52), _open_overlay.bind("codex"))
	_button("Pause", "…", Rect2(1013, 29, 51, 52), _open_overlay.bind("pause"))
	first_focus = null


func _draw_map() -> void:
	street_view = RouteView.new()
	street_view.run = run
	street_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(street_view)
	street_view.position = Vector2.ZERO
	street_view.size = Vector2(1280, 720)
	var branches: Array = run.route[mini(run.depth, run.route.size() - 1)]
	var required: int = run.tutorial_required_branch()
	street_selected = required if required >= 0 else clampi(street_selected, 0, branches.size() - 1)
	street_view.set_active_branch(street_selected, true)
	backdrop.aim_at(Vector2(264 if street_selected == 0 else 1016, 330))
	UI.panel(screen, Rect2(24, 62, 946, 82), Color("030303e6"))
	UI.label(
		screen,
		"第 %02d 区画　%s" % [run.depth + 1, "最初の夜道" if run.depth < 2 else "妹の声を追う"],
		Rect2(47, 72, 455, 32),
		24,
		UI.GOLD
	)
	street_hint = UI.label(
		screen, street_view.active_line(), Rect2(47, 107, 894, 28), 16, UI.GHOST
	)
	_button("OpenParty", "霊を組む", Rect2(922, 75, 130, 54), _open_overlay.bind("party"))
	_button("OpenCodex", "手帳を開く", Rect2(1062, 75, 186, 54), _open_overlay.bind("codex"))
	first_focus = null
	for index: int in range(branches.size()):
		var info: Dictionary = branches[index]
		var title_text: String = street_view.entrance_name(index)
		var hint: String = _node_hint(info)
		var x: float = 86.0 + index * 752.0 if branches.size() > 1 else 462.0
		var entrance: Button = _button(
			"Branch%d" % index,
			title_text + "\n" + hint,
			Rect2(x, 434, 356, 91),
			_enter_node.bind(index)
		)
		entrance.focus_entered.connect(_approach_entrance.bind(index))
		entrance.mouse_entered.connect(_approach_entrance.bind(index))
		if index == street_selected:
			first_focus = entrance
	if required >= 0:
		UI.panel(screen, Rect2(339, 548, 602, 117), Color("080000ed"))
		var lesson: String = "灯の先まで歩き、墓地の入口に立つ。"
		if run.tutorial_step == run.TUTORIAL_BATTLE:
			lesson = "迎えた霊と、ざわめく路地で最初の戦いへ。"
		UI.label(screen, "手帳の赤い書き込み", Rect2(365, 559, 400, 30), 19, UI.RED)
		UI.label(screen, lesson, Rect2(365, 591, 435, 54), 20)
		_button("SkipTutorial", "案内を破る", Rect2(800, 579, 115, 54), _skip_tutorial)


func _approach_entrance(index: int) -> void:
	if street_selected == index:
		return
	street_selected = index
	if is_instance_valid(street_view):
		street_view.set_active_branch(index)
		street_hint.text = street_view.active_line()
	backdrop.aim_at(Vector2(264 if index == 0 else 1016, 330))
	sound.play_sfx("step")


func _skip_tutorial() -> void:
	run.skip_tutorial()


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
	_header(Catalog.NODE_LABELS.get(kind, "夜の記憶"), "照らされたものを見て、手帳の赤字を確かめる。")
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
	UI.panel(screen, Rect2(465, 136, 778, 350), Color("030303ed"))
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
	if run.tutorial_step != run.TUTORIAL_COMPLETE:
		UI.label(
			screen,
			"最初の霊に灯を差し出す。赤字の代償も、選ぶ前に読む。",
			Rect2(72, 616, 870, 34),
			18,
			UI.RED
		)
		_button("SkipTutorial", "案内を破る", Rect2(1045, 594, 176, 48), _skip_tutorial)


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
		"黒い手帳をめくって技を記し、灯で狙う影を選ぶ。"
	)
	UI.label(screen, "第 %d 手" % run.turn, Rect2(52, 120, 180, 32), 22, UI.GOLD)
	UI.label(screen, "霊が倒れれば手帳からも永久に消える", Rect2(810, 120, 420, 32), 18, UI.RED)
	_feedback = UI.label(screen, run.last_message, Rect2(91, 158, 1100, 45), 20, UI.GHOST)
	for index: int in range(mini(3, run.party.size())):
		var member: Dictionary = run.party[index]
		var node: Node2D = _actor(member.species, Vector2(155 + index * 213, 300), 0.70)
		node.set_meta("uid", member.uid)
		actor_nodes.append(node)
	combat_page = clampi(combat_page, 0, mini(3, run.party.size()) - 1)
	_draw_combat_card(run.party[combat_page], combat_page)
	target_index = clampi(target_index, 0, maxi(0, run.enemies.size() - 1))
	for index: int in range(run.enemies.size()):
		var enemy: Dictionary = run.enemies[index]
		var definition: Dictionary = Catalog.spirit(enemy.species)
		var x: float = 850 + index * 195
		var node: Node2D = _actor(
			enemy.species, Vector2(x + 38, 329), 1.10 if enemy.species == "boss" else 0.84
		)
		node.set_meta("uid", enemy.uid)
		node.scale.x = -absf(node.scale.x)
		enemy_nodes.append(node)
		var selected: String = "灯が照らす ● " if target_index == index else "暗がり　"
		_button(
			"Target%d" % index,
			selected + str(definition.name),
			Rect2(x - 59, 399, 218, 49),
			_target.bind(index)
		)
		_health_labels[enemy.uid] = UI.label(
			screen,
			"%s / 速 %d / HP %d" % [Catalog.TYPES[definition.type], definition.speed, enemy.hp],
			Rect2(x - 55, 457, 228, 28),
			17,
			TYPE_COLORS[definition.type]
		)
		_health_labels[enemy.uid].set_meta("species", enemy.species)
		_health_bars[enemy.uid] = UI.bar(
			screen, Rect2(x - 52, 491, 202, 8), enemy.hp, definition.hp, UI.RED
		)
		UI.label(
			screen,
			"予告：%s" % Catalog.MOVES[definition.moves[int(run.turn % 3 == 0)]].name,
			Rect2(x - 55, 509, 230, 30),
			16,
			UI.MUTED
		)
	_button("ResolveTurn", "手帳を閉じ、命令する", Rect2(823, 572, 388, 64), _resolve)
	UI.label(screen, "赤い記述は霊気を消費する", Rect2(823, 649, 385, 25), 15, UI.RED)
	# 技ではなく送信が最初の決定対象なので、通常技だけならEnterで進められる。
	first_focus = screen.get_node("ResolveTurn")
	if run.tutorial_step == run.TUTORIAL_BATTLE:
		UI.label(screen, "手帳の技を一つ選び、灯が照らす相手へ命令する。", Rect2(47, 646, 720, 29), 17, UI.RED)
		_button("SkipTutorial", "案内を破る", Rect2(654, 640, 139, 38), _skip_tutorial)


func _draw_combat_card(member: Dictionary, index: int) -> void:
	var definition: Dictionary = Catalog.spirit(member.species)
	var x: float = 40.0
	var paper: TextureRect = UI.texture(
		screen, "res://assets/external/textures/parchment.webp", Rect2(x, 382, 744, 254)
	)
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	paper.modulate = Color("9d8b62")
	UI.panel(screen, Rect2(x, 382, 744, 254), Color("100d08a8"))
	UI.label(
		screen,
		"霊の手帳　技の頁 %d / %d" % [index + 1, mini(3, run.party.size())],
		Rect2(x + 27, 393, 420, 31),
		19,
		UI.GOLD
	)
	_health_names[member.uid] = UI.label(screen, definition.name, Rect2(x + 28, 427, 300, 38), 27)
	_health_labels[member.uid] = UI.label(
		screen,
		"%s / 速 %d / HP %d" % [Catalog.TYPES[definition.type], definition.speed, member.hp],
		Rect2(x + 28, 467, 305, 28),
		16,
		TYPE_COLORS[definition.type]
	)
	_health_labels[member.uid].set_meta("species", member.species)
	_health_bars[member.uid] = UI.bar(
		screen, Rect2(x + 28, 501, 294, 8), member.hp, definition.hp, TYPE_COLORS[definition.type]
	)
	for choice: int in range(2):
		var move: Dictionary = Catalog.MOVES[definition.moves[choice]]
		var prefix: String = "✕ " if moves[index] == choice else "□ "
		var choice_button: Button = _button(
			"Move%d_%d" % [index, choice],
			"%s%s%s" % [prefix, move.name, " (%d)" % move.cost if move.cost > 0 else ""],
			Rect2(x + 356, 418 + choice * 75, 354, 61),
			_select_move.bind(index, choice),
			"威力 %.1f倍 / 霊気 %d" % [move.power, move.cost]
		)
		choice_button.add_theme_font_size_override("font_size", 20)
		if move.cost > 0:
			choice_button.add_theme_color_override("font_color", UI.RED)
	_button("CombatPrevious", "前の頁", Rect2(x + 356, 574, 158, 45), _combat_page_move.bind(-1))
	_button("CombatNext", "次の頁", Rect2(x + 552, 574, 158, 45), _combat_page_move.bind(1))


func _combat_page_move(direction: int) -> void:
	combat_page = posmod(combat_page + direction, mini(3, run.party.size()))
	render()
	_focus_safely.call_deferred(screen.get_node("Move%d_%d" % [combat_page, moves[combat_page]]))


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
	var player_cut_in_shown: bool = false
	var hurt_cut_in_shown: bool = false
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
			if event.get("actor_side", "") == "party" and not player_cut_in_shown:
				await _show_cut_in(attacker, "attack", event.get("text", ""))
				player_cut_in_shown = true
			if is_instance_valid(attacker):
				attacker.play_motion("attack")
			await get_tree().create_timer(0.12).timeout
			if is_instance_valid(victim):
				if not hurt_cut_in_shown and victim.character_id in CutIn.SPIRIT_IDS:
					await _show_cut_in(victim, "hurt", event.get("text", ""))
					hurt_cut_in_shown = true
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
				await _show_cut_in(victim, "dissolve", event.get("text", ""))
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


func _show_cut_in(actor: Node2D, action: String, caption: String) -> void:
	if not is_instance_valid(actor) or actor.character_id not in CutIn.SPIRIT_IDS:
		return
	var cut_in := CutIn.new()
	screen.add_child(cut_in)
	cut_in.setup(actor.character_id, action, caption)
	cut_in.play()
	await cut_in.finished
	cut_in.queue_free()


func _promote_actor(unit: Dictionary) -> void:
	if _empty_slots.is_empty():
		return
	var slot: Dictionary = _empty_slots.pop_front()
	var node: Node2D = _actor(unit.species, slot.point, 0.73)
	node.set_meta("uid", unit.uid)
	actor_nodes.append(node)
	node.play_motion("move")
	for widgets: Dictionary in [_health_bars, _health_labels, _health_names]:
		if widgets.has(slot.uid):
			widgets[unit.uid] = widgets[slot.uid]
			widgets.erase(slot.uid)
	var definition: Dictionary = Catalog.spirit(unit.species)
	if _health_names.has(unit.uid):
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
	UI.panel(screen, Rect2(433, 69, 810, 581), Color("030303f2"))
	var saved: bool = run.ending in ["saved", "scarred"]
	UI.label(screen, "夜明け" if saved else "夜は、まだ終わらない", Rect2(76, 111, 350, 56), 33, UI.GOLD)
	_actor("hero_%d" % run.darkness_stage(), Vector2(232, 364), 1.4)
	UI.label(screen, end.title, Rect2(469, 101, 734, 73), 40)
	UI.label(screen, end.text, Rect2(469, 201, 733, 123), 24, UI.MUTED)
	var totals: Label = UI.label(
		screen,
		(
			"辿った区画　%d / 12　　集めた霊　%d　　最後の闇　%d"
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
		"辿った区画　%d / 12　　集めた霊　%d　　最後の闇　%d"
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
	var portrait_scale: float = 0.70 if id in CutIn.SPIRIT_IDS else 1.0
	node.scale = Vector2.ONE * factor * portrait_scale
	node.setup(id)
	node.set_meta("species", id)
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
	var shade := ColorRect.new()
	shade.color = Color("000000ee")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.size = Vector2(1280, 720)
	screen.add_child(shade)
	for rect: Rect2 in [Rect2(72, 33, 557, 650), Rect2(651, 33, 557, 650)]:
		var page: TextureRect = UI.texture(
			screen, "res://assets/external/textures/parchment.webp", rect
		)
		page.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		page.modulate = Color("c7b27b")
		UI.panel(screen, rect, Color("09060212"))
	var spine := ColorRect.new()
	spine.color = Color("100b07")
	spine.position = Vector2(623, 34)
	spine.size = Vector2(34, 648)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(spine)
	match overlay:
		"codex":
			_draw_codex()
		"party":
			_draw_party()
		"help":
			_draw_help()
		"pause":
			_draw_pause()
	_button("CloseOverlay", "手帳を閉じる", Rect2(1019, 615, 169, 48), _close_overlay)


func _draw_notebook_heading(title: String, section: String) -> void:
	UI.label(screen, title, Rect2(101, 55, 500, 49), 34, NOTE_INK)
	UI.label(screen, section, Rect2(681, 55, 470, 39), 22, NOTE_INK)
	UI.label(
		screen,
		"第 %02d 区画　同行 %d体" % [mini(run.depth + 1, 12), run.party.size()],
		Rect2(682, 97, 470, 30),
		18,
		NOTE_INK
	)
	UI.label(
		screen,
		"霊気 %d　　お守り %d" % [run.ether, run.relics],
		Rect2(682, 127, 470, 31),
		20,
		NOTE_INK
	)
	UI.label(
		screen,
		"闇堕ち度 %d / 100%s" % [run.darkness, "　命令を失う危険" if run.darkness >= 60 else ""],
		Rect2(682, 158, 470, 28),
		18,
		UI.RED
	)
	UI.bar(screen, Rect2(682, 188, 465, 8), run.darkness, 100, UI.RED)


func _draw_codex() -> void:
	_draw_notebook_heading("霊の手帳", "見つけた霊 %d / 12" % run.discovered.size())
	var ids: Array = Catalog.SPIRITS.keys()
	for index: int in range(4):
		var id: String = ids[codex_page * 4 + index]
		var definition: Dictionary = Catalog.spirit(id)
		var right_page: bool = index >= 2
		var x: float = 97.0 if not right_page else 677.0
		var y: float = 126.0 + (index % 2) * 229.0 if not right_page else 218.0 + (index % 2) * 187.0
		var card_height: float = 207.0 if not right_page else 169.0
		UI.panel(screen, Rect2(x, y, 506, card_height), Color("0b0805e8"))
		_actor(id, Vector2(x + 92, y + card_height * 0.52), 0.48 if not right_page else 0.40)
		UI.label(screen, definition.name, Rect2(x + 176, y + 16, 305, 36), 25)
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
			Rect2(x + 176, y + 53, 304, 25),
			16,
			TYPE_COLORS[definition.type]
		)
		UI.label(
			screen,
			"体力 %d　攻撃 %d　速さ %d" % [definition.hp, definition.attack, definition.speed],
			Rect2(x + 176, y + 82, 304, 27),
			16
		)
		UI.label(
			screen,
			definition.lore,
			Rect2(x + 176, y + 114, 305, card_height - 122),
			15,
			UI.MUTED
		)
	_button("CodexPrevious", "前の頁", Rect2(326, 615, 146, 48), _codex_move.bind(-1))
	UI.label(screen, "%d / 3" % (codex_page + 1), Rect2(493, 623, 106, 30), 20, NOTE_INK)
	_button("CodexNext", "次の頁", Rect2(668, 615, 146, 48), _codex_move.bind(1))


func _codex_move(direction: int) -> void:
	codex_page = posmod(codex_page + direction, 3)
	render()


func _draw_party() -> void:
	_draw_notebook_heading("同行霊の記録", "前衛を一体選び、控えと入れ替える")
	UI.label(screen, "前衛三体", Rect2(101, 112, 470, 34), 22, NOTE_INK)
	for index: int in range(mini(3, run.party.size())):
		var member: Dictionary = run.party[index]
		var definition: Dictionary = Catalog.spirit(member.species)
		var y: float = 160.0 + index * 139.0
		_actor(member.species, Vector2(155, y + 59), 0.35)
		_button(
			"Front%d" % index,
			"%s%s\nHP %d / %d　%s" % [
				"✕ " if swap_front == index else "□ ",
				definition.name,
				member.hp,
				definition.hp,
				Catalog.TYPES[definition.type]
			],
			Rect2(216, y + 13, 381, 92),
			_select_front.bind(index)
		)
	UI.label(screen, "控えの頁", Rect2(681, 218, 470, 35), 22, NOTE_INK)
	if run.party.size() <= 3:
		UI.label(
			screen,
			"控えの霊はまだいない。\n墓地や依代から魂を迎えれば、ここへ記される。",
			Rect2(681, 273, 465, 106),
			20,
			NOTE_INK
		)
	for index: int in range(3, run.party.size()):
		var member: Dictionary = run.party[index]
		_button(
			"Reserve%d" % index,
			"%s　HP %d" % [Catalog.spirit(member.species).name, member.hp],
			Rect2(
				681 + ((index - 3) % 2) * 236,
				269 + ((index - 3) / 2) * 67,
				222,
				55
			),
			_swap.bind(index)
		)


func _select_front(index: int) -> void:
	swap_front = index
	render()


func _swap(index: int) -> void:
	run.swap_party(swap_front, index)


func _draw_help() -> void:
	_draw_notebook_heading("失踪記録と手引き", "力を得ることと、人でいること")
	UI.label(
		screen,
		(
			"十二の区画を歩き、照らされた入口へ入る。\n\n"
			+ "墓地では魂を迎えられる。\n"
			+ "生きた依代を殺めれば、強い大霊を得る。\n"
			+ "どちらも手帳へ闇の代償が赤字で記される。\n\n"
			+ "休息や人を守る選択で闇を鎮め、\n"
			+ "第十二区画の夜葬の主を倒して妹の声を取り戻す。"
		),
		Rect2(102, 137, 477, 435),
		21,
		NOTE_INK
	)
	UI.label(
		screen,
		(
			"霊戦\n"
			+ "前衛は三体。手帳をめくり、各霊の技を選ぶ。\n"
			+ "懐中電灯で敵を選び、命令を送る。\n"
			+ "怨→哀→怒→怨は二倍、逆は半分。\n"
			+ "倒れた霊は永久に手帳から消える。\n\n"
			+ "夜道\n"
			+ "左右で入口へ歩く。黄色い灯と太枠が現在地。\n"
			+ "選択後は自動保存される。"
		),
		Rect2(682, 218, 466, 355),
		20,
		NOTE_INK
	)


func _draw_pause() -> void:
	_draw_notebook_heading("灯を休める", "ここまでの夜は自動で記録される")
	UI.label(
		screen,
		"頁を閉じても、夜は待っている。",
		Rect2(103, 132, 476, 45),
		22,
		NOTE_INK
	)
	_button("Continue", "夜道へ戻る", Rect2(109, 215, 464, 61), _close_overlay)
	_button("Help", "失踪記録を読む", Rect2(109, 304, 464, 61), _open_overlay.bind("help"))
	_button("SaveTitle", "記録して表紙へ", Rect2(109, 393, 464, 61), _save_title)
	_button("Quit", "灯を消して終了", Rect2(109, 482, 464, 61), request_quit)


func _save_title() -> void:
	run.save_game()
	overlay = ""
	run.to_title()
