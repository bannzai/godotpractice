extends Control
## 進行の正は Game。ここでは入力の配送と状態に対応する描画・演出だけを行う。

const INK := Color("203f40")
const PAPER := Color("f8f3df")
const GREEN := Color("3b7564")
const GOLD := Color("edbc60")
const MUTED := Color("6c8277")
const FONT = preload("res://assets/fonts/MPLUSRounded1c-Regular.ttf")

var page: Control
var world: QuestWorld
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var music_name: String = ""
var closing: bool = false
var busy: bool = false
var menu_open: bool = false
var notice: String = ""
var step_clock: float = 0.0
var enemy_picture: TextureRect
var player_picture: TextureRect
var battle_message: Label
var first_button: Button


func _ready() -> void:
	get_tree().auto_accept_quit = false
	var skin := Theme.new()
	skin.default_font = FONT
	skin.default_font_size = 20
	theme = skin
	music = AudioStreamPlayer.new()
	music.volume_db = -6.0
	add_child(music)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -10.0
	add_child(sound)
	refresh()
	print("monsterquest boot")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		closing = true
		stop_audio()
		# 音声サーバーに停止を反映してから通常のウィンドウ終了を行う。
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()


func stop_audio() -> void:
	music.stop()
	sound.stop()


func _exit_tree() -> void:
	stop_audio()
	music.stream = null
	sound.stream = null


## 時間に応じた移動と入力イベントを処理するため非冪等。
func _process(delta: float) -> void:
	step_clock = maxf(0.0, step_clock - delta)
	if Game.mode != "field" or busy or menu_open or step_clock > 0.0:
		return
	var direction := Vector2i.ZERO
	if Input.is_action_pressed("walk_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("walk_right"):
		direction = Vector2i.RIGHT
	elif Input.is_action_pressed("walk_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("walk_down"):
		direction = Vector2i.DOWN
	if direction != Vector2i.ZERO:
		walk(direction)


## 押下を一回のユーザー操作として扱うため非冪等。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
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
	if busy:
		return
	if event.is_action_pressed("menu") and Game.mode == "field":
		menu_open = not menu_open
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and Game.mode == "field" and not menu_open:
		interact()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	first_button = null
	world = null
	_panel(Rect2(0, 0, 1280, 720), PAPER)
	match Game.mode:
		"title":
			_show_title()
		"field":
			_show_field()
		"battle":
			_show_battle()
		"clear", "gameover":
			_show_result()
	_play_music("battle" if Game.mode == "battle" else "field")
	if first_button != null and (Game.mode != "field" or menu_open):
		first_button.grab_focus()


func _panel(rect: Rect2, color: Color, radius: int = 0) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	node.add_theme_stylebox_override("panel", style)
	page.add_child(node)
	return node


func _label_at(text: String, rect: Rect2, font_size: int = 20, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(node)
	return node


func _button_at(text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	for color_name: String in [
		"font_color", "font_hover_color", "font_focus_color", "font_pressed_color"
	]:
		node.add_theme_color_override(color_name, PAPER if primary else INK)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GREEN if primary else Color("e8e8d3")
		style.set_corner_radius_all(12)
		if state != "normal":
			style.set_border_width_all(3)
			style.border_color = GOLD
		node.add_theme_stylebox_override(state, style)
	node.pressed.connect(callback)
	page.add_child(node)
	if first_button == null:
		first_button = node
	return node


func _picture(id: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(Catalog.SPECIES[id].image)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(node)
	return node


func _show_title() -> void:
	_panel(Rect2(694, 0, 586, 720), Color("dce7cd"))
	_panel(Rect2(763, 106, 444, 444), Color("c3d7b5"), 220)
	_panel(Rect2(40, 44, 195, 36), GREEN, 18)
	_label_at("小さな冒険、大きな出会い", Rect2(54, 46, 180, 32), 14, PAPER)
	_label_at("こもれびの\n調査隊", Rect2(70, 144, 620, 188), 68)
	_label_at("草むらの向こうで、きみを待っている。", Rect2(76, 355, 570, 42), 23)
	_label_at("見つけて、仲間にして、一緒に強くなる。\n６種のいきものと旅する、手のひらの冒険。", Rect2(76, 410, 570, 75), 20, MUTED)
	_button_at("はじめから冒険する  →", Rect2(76, 524, 440, 58), start_new, true)
	var resume_button: Button = _button_at("つづきから", Rect2(76, 594, 214, 48), resume_game)
	resume_button.disabled = not FileAccess.file_exists(Game.SAVE_PATH)
	_button_at("遊び方・クレジット", Rect2(302, 594, 214, 48), _show_help)
	_picture("sprout", Rect2(950, 116, 220, 220))
	_picture("tide", Rect2(762, 302, 248, 248))
	_picture("ember", Rect2(1000, 360, 230, 230))
	_label_at("森と、海と、きみの物語。", Rect2(824, 626, 400, 40), 22, GREEN)
	_footer("矢印 / WASD・方向パッドで選択    Enter / A 決定    F11 全画面")
	if not notice.is_empty():
		_label_at(notice, Rect2(76, 480, 590, 40), 17, GREEN)


func _show_help() -> void:
	_prepare_modal()
	_panel(Rect2(64, 96, 1152, 556), PAPER, 22)
	_label_at("調査隊のてびき", Rect2(104, 118, 1000, 60), 36)
	_label_at(
		(
			"① 町の右側から草むらへ。弱らせた相手ほど捕まえやすい。\n"
			+ "② 回復の家で全回復と道具の補充。７体目からは預かりへ。\n"
			+ "③ 炎 → 草 → 水 → 炎 の順に２倍。逆向きは半分のダメージ。\n"
			+ "④ 育てた仲間と町の右上の隊長に勝つと、調査は大成功！\n\n"
			+ "移動：矢印 / WASD / 方向パッド / 左スティック\n"
			+ "話す：Enter / Space / A　　メニュー：Esc / Tab / Start　　全画面：F11\n\n"
			+ "絵と音：本プロジェクトの独自生成。書体：M PLUS Rounded 1c（OFL 1.1）。\n"
			+ "詳細な素材情報：同梱 assets/CREDITS.md とフォントのライセンス。"
		),
		Rect2(104, 190, 1080, 370),
		21
	)
	_button_at("閉じる", Rect2(900, 570, 260, 52), refresh, true).grab_focus()


func _footer(text: String) -> void:
	_label_at(text, Rect2(28, 676, 1224, 32), 16, MUTED)


func start_new() -> void:
	Game.new_game()
	notice = "右の道から草むらへ。まずは仲間を探してみよう！"
	menu_open = false
	refresh()


func resume_game() -> void:
	if Game.load_game():
		notice = "おかえりなさい。調査の続きを始めよう。"
		menu_open = false
	else:
		notice = "セーブを読み込めませんでした。データは変更していません。"
	refresh()


func _show_field() -> void:
	var names: Dictionary = {"town": "こもれびの町", "route": "ひだまりの小径", "home": "自宅", "clinic": "回復の家"}
	_label_at(names[Game.zone], Rect2(28, 20, 650, 55), 32)
	_label_at("調査目標：仲間を育てて隊長に挑もう", Rect2(690, 28, 560, 40), 19, GREEN)
	world = QuestWorld.new()
	world.position = Vector2(24, 100)
	page.add_child(world)
	world.setup(Game.zone)
	world.set_player(Game.cell)
	_panel(Rect2(1000, 100, 256, 560), Color("e8ead8"), 16)
	_label_at("調査ノート", Rect2(1020, 112, 220, 44), 24)
	_label_at(
		"仲間  %d / 6\nボール  %d\n回復薬  %d" % [Game.party.size(), Game.balls, Game.potions],
		Rect2(1020, 166, 220, 100),
		21
	)
	if not Game.party.is_empty():
		var lead: Dictionary = Game.party[Game.active_index]
		_picture(lead.species, Rect2(1050, 284, 154, 154))
		_label_at(
			"%s  Lv.%d" % [Catalog.SPECIES[lead.species].name, lead.level],
			Rect2(1018, 436, 224, 35),
			20
		)
		_health_bar(lead, Rect2(1020, 480, 208, 12))
	_button_at("話す / 調べる", Rect2(1018, 518, 220, 48), interact)
	_button_at("手持ち・道具", Rect2(1018, 578, 220, 48), open_menu)
	_footer("移動：矢印 / WASD / 左スティック　 話す：Enter / A　 手持ち・保存：Esc / Start")
	if not notice.is_empty():
		_panel(Rect2(44, 590, 916, 52), PAPER, 12)
		_label_at(notice, Rect2(60, 598, 880, 36), 18)
	if menu_open:
		_show_menu()


func _health_bar(monster: Dictionary, rect: Rect2) -> void:
	var maximum: int = Catalog.stats(monster).hp
	_panel(rect, Color("ccd5be"), 6)
	var ratio: float = float(monster.hp) / maximum
	_panel(
		Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)),
		GREEN if ratio > 0.3 else Color("c57455"),
		6
	)
	_label_at(
		"HP %d / %d" % [monster.hp, maximum],
		Rect2(rect.position + Vector2(0, 14), Vector2(rect.size.x, 30)),
		15,
		MUTED
	)


## 一歩ごとに位置・抽選が進むため非冪等。移動中は再入を止める。
func walk(direction: Vector2i) -> void:
	if busy or menu_open or Game.mode != "field":
		return
	step_clock = 0.16
	var next: Vector2i = Game.cell + direction
	if not QuestWorld.walkable(Game.zone, next):
		return
	Game.cell = next
	Game.steps += 1
	busy = true
	var tween: Tween = create_tween()
	tween.tween_property(
		world.visual_player, "position", Vector2(next) * 40.0 + Vector2(20, 20), 0.12
	)
	await tween.finished
	busy = false
	var destination: Dictionary = QuestWorld.portal(Game.zone, Game.cell)
	if not destination.is_empty():
		Game.zone = destination.zone
		Game.cell = destination.cell
		notice = ""
		if Game.zone == "clinic":
			Game.heal_party()
			_play_sound("heal")
			notice = "みんな全回復！ ボールと回復薬も補充した。預かりはメニューから。"
		elif Game.zone == "home":
			notice = "おかえり。メニューから調査の記録を保存できるよ。"
		refresh()
		return
	if QuestWorld.is_grass(Game.zone, Game.cell) and Game.rng.randf() < 0.20:
		begin_battle(Catalog.encounter(Game.rng.randf()), Game.rng.randi_range(3, 6), false)


func interact() -> void:
	if Game.mode != "field" or busy:
		return
	if Game.zone == "town" and (Game.cell - Vector2i(18, 6)).length() <= 1.0:
		menu_open = true
		_prepare_modal()
		_panel(Rect2(250, 228, 760, 270), PAPER, 20)
		_label_at("隊長 ヒナギク", Rect2(280, 250, 690, 50), 30)
		_label_at("仲間との絆を、見せてくれる？\n相手は Lv.8 の水タイプ。草タイプが有利だよ。", Rect2(280, 306, 690, 85), 22)
		(
			_button_at(
				"挑戦する",
				Rect2(282, 414, 324, 56),
				func() -> void: begin_battle("crab", 8, true),
				true
			)
			. grab_focus()
		)
		_button_at("まだ準備する", Rect2(624, 414, 324, 56), close_menu)
	elif Game.zone == "clinic":
		Game.heal_party()
		_play_sound("heal")
		notice = "全回復と道具の補充が完了！ 預かり交換は手持ちメニューから。"
		refresh()
	elif Game.zone == "home":
		save_progress()
	else:
		notice = "町の右から草むらへ。回復の家は中央、隊長は右上にいるよ。"
		refresh()


func open_menu() -> void:
	if busy or Game.mode != "field":
		return
	menu_open = true
	refresh()


func close_menu() -> void:
	menu_open = false
	refresh()


func _show_menu() -> void:
	_prepare_modal()
	_panel(Rect2(68, 110, 1144, 546), PAPER, 20)
	_label_at("旅の仲間", Rect2(100, 128, 500, 50), 32)
	_label_at("選ぶと先頭に交代", Rect2(870, 140, 310, 40), 18, MUTED)
	for index: int in Game.party.size():
		var monster: Dictionary = Game.party[index]
		var x: int = 100 + (index % 3) * 362
		var y: int = 200 + (index / 3) * 145
		_panel(Rect2(x, y, 340, 130), Color("e9edda"), 12)
		_picture(monster.species, Rect2(x + 4, y + 12, 95, 95))
		var caption: String = "%s Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level]
		if index == Game.active_index:
			caption = "★ " + caption
		_button_at(caption, Rect2(x + 98, y + 12, 230, 42), select_lead.bind(index))
		_health_bar(monster, Rect2(x + 106, y + 68, 210, 10))
	_label_at(
		"ボール %d   回復薬 %d   預かり %d" % [Game.balls, Game.potions, Game.storage.size()],
		Rect2(100, 502, 760, 40),
		22
	)
	_button_at("先頭を回復", Rect2(100, 566, 198, 52), field_potion)
	_button_at("預かり交換", Rect2(316, 566, 198, 52), _show_storage)
	_button_at("セーブ", Rect2(532, 566, 198, 52), save_progress, true)
	_button_at("タイトル", Rect2(748, 566, 198, 52), _confirm_title)
	_button_at("戻る", Rect2(964, 566, 198, 52), close_menu)


func select_lead(index: int) -> void:
	if Game.party[index].hp > 0:
		Game.active_index = index
	refresh()


## 道具を１個消費するユーザー操作なので非冪等。
func field_potion() -> void:
	var monster: Dictionary = Game.party[Game.active_index]
	if Game.potions > 0 and monster.hp < Catalog.stats(monster).hp:
		Game.potions -= 1
		monster.hp = mini(Catalog.stats(monster).hp, monster.hp + 30)
		_play_sound("heal")
	refresh()


func save_progress() -> void:
	notice = "調査の記録を保存した。" if Game.save_game() else "保存に失敗しました。空き容量を確認してください。"
	menu_open = false
	refresh()


func _confirm_title() -> void:
	_prepare_modal()
	_panel(Rect2(270, 230, 740, 260), PAPER, 20)
	_label_at("保存してタイトルへ戻りますか？", Rect2(308, 262, 670, 70), 27)
	_button_at("保存して戻る", Rect2(308, 376, 310, 64), _save_and_title, true).grab_focus()
	_button_at("冒険を続ける", Rect2(646, 376, 310, 64), refresh)


func _save_and_title() -> void:
	if Game.save_game():
		to_title()
	else:
		notice = "保存に失敗したため冒険を続けます。"
		close_menu()


func _show_storage(offset: int = 0) -> void:
	if Game.zone != "clinic":
		notice = "預かりの仲間との交換は、町の回復の家でできます。"
		close_menu()
		return
	refresh()
	_prepare_modal()
	_panel(Rect2(80, 122, 1120, 526), PAPER, 20)
	_label_at("預かりの仲間", Rect2(108, 140, 700, 50), 32)
	_label_at("選んだ仲間と手持ちの先頭を交換します。", Rect2(108, 200, 1000, 40), 20)
	for index: int in range(offset, mini(offset + 6, Game.storage.size())):
		var monster: Dictionary = Game.storage[index]
		var y: int = 260 + ((index - offset) / 3) * 128
		var x: int = 108 + ((index - offset) % 3) * 360
		_picture(monster.species, Rect2(x, y, 90, 90))
		_button_at(
			"%s Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level],
			Rect2(x + 96, y + 20, 238, 52),
			exchange_storage.bind(index)
		)
	if Game.storage.is_empty():
		_label_at("手持ちが６体のとき、捕まえた仲間をここで預かります。", Rect2(108, 300, 1000, 70), 24, MUTED)
	if offset > 0:
		_button_at("前へ", Rect2(108, 568, 180, 50), _show_storage.bind(offset - 6))
	if offset + 6 < Game.storage.size():
		_button_at("次へ", Rect2(310, 568, 180, 50), _show_storage.bind(offset + 6))
	_button_at("戻る", Rect2(960, 568, 200, 50), refresh, true).grab_focus()


## 選択した二体の入れ替えなので非冪等。
func exchange_storage(index: int) -> void:
	Game.swap_storage(Game.active_index, index)
	refresh()


## 抽選済みの戦闘を開始し、画面が閉じるまで入力を遮断する。
func begin_battle(id: String, level: int, trainer: bool) -> void:
	if busy or Game.mode != "field":
		return
	_prepare_modal()
	menu_open = false
	busy = true
	var curtain: Panel = _panel(Rect2(0, 0, 1280, 720), INK)
	curtain.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(curtain, "modulate:a", 1.0, 0.25)
	await tween.finished
	Game.start_battle(id, level, trainer)
	refresh()
	busy = false


func _show_battle() -> void:
	_panel(Rect2(0, 0, 1280, 486), Color("dce7cd"))
	_panel(Rect2(80, 226, 536, 204), Color("c2d4ad"), 100)
	_panel(Rect2(710, 216, 460, 128), Color("bdd1a5"), 64)
	_label_at("隊長 ヒナギクとの腕試し" if Game.trainer else "草むらでの出会い", Rect2(36, 20, 1000, 45), 26)
	_label_at("炎 → 草 → 水 → 炎   有利２倍 / 不利½", Rect2(754, 30, 510, 32), 17, GREEN)
	_monster_card(Game.enemy, Rect2(60, 98, 394, 128))
	var lead: Dictionary = Game.party[Game.active_index]
	_monster_card(lead, Rect2(780, 340, 430, 128))
	enemy_picture = _picture(Game.enemy.species, Rect2(826, 88, 260, 260))
	player_picture = _picture(lead.species, Rect2(194, 212, 300, 270))
	_panel(Rect2(24, 498, 660, 160), Color("e7ead7"), 18)
	battle_message = _label_at(
		"%s はどうする？" % Catalog.SPECIES[lead.species].name, Rect2(48, 514, 608, 116), 25
	)
	battle_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var moves: Array = Catalog.moves(lead)
	for index: int in moves.size():
		var move_id: String = moves[index]
		var move: Dictionary = Catalog.MOVES[move_id]
		_button_at(
			"%s ・ %s" % [move.name, _type_name(move.type)],
			Rect2(704 + (index % 2) * 278, 500 + (index / 2) * 57, 260, 48),
			battle_turn.bind("attack", move_id),
			true
		)
	_button_at("ボール %d" % Game.balls, Rect2(704, 618, 126, 42), battle_turn.bind("capture", ""))
	_button_at("回復 %d" % Game.potions, Rect2(840, 618, 126, 42), battle_turn.bind("potion", ""))
	_button_at("交代", Rect2(978, 618, 120, 42), _show_switch)
	_button_at("逃げる", Rect2(1110, 618, 130, 42), battle_turn.bind("flee", ""))
	_footer("技を選択：矢印 / 方向パッド　 決定：Enter / A　 相手より速いと先に攻撃できる")


func _monster_card(monster: Dictionary, rect: Rect2) -> void:
	_panel(rect, PAPER, 18)
	_label_at(
		"%s  Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level],
		Rect2(rect.position + Vector2(20, 10), Vector2(350, 40)),
		25
	)
	_label_at(
		_type_name(Catalog.SPECIES[monster.species].type),
		Rect2(rect.position + Vector2(20, 50), Vector2(65, 35)),
		17,
		GREEN
	)
	_health_bar(monster, Rect2(rect.position + Vector2(92, 60), Vector2(rect.size.x - 114, 12)))


func _type_name(type: String) -> String:
	return Catalog.TYPES.get(type, type)


func _show_switch() -> void:
	if busy:
		return
	_prepare_modal()
	_panel(Rect2(80, 170, 1120, 380), PAPER, 18)
	_label_at("次に戦う仲間を選ぶ（交代すると相手が行動）", Rect2(110, 194, 1060, 45), 26)
	for index: int in Game.party.size():
		var monster: Dictionary = Game.party[index]
		var caption: String = "%s  HP %d" % [Catalog.SPECIES[monster.species].name, monster.hp]
		var node: Button = _button_at(
			caption,
			Rect2(112 + (index % 3) * 360, 268 + (index / 3) * 82, 330, 62),
			battle_turn.bind("switch", str(index))
		)
		node.disabled = monster.hp == 0 or index == Game.active_index
	_button_at("戻る", Rect2(930, 460, 240, 58), refresh, true).grab_focus()


## 一ターンの消費と順次演出を伴うため非冪等。重複押下は無視する。
func battle_turn(action: String, move_id: String) -> void:
	if busy or Game.mode != "battle":
		return
	refresh()
	busy = true
	var events: Array = Game.resolve_turn(action, move_id)
	for event: Dictionary in events:
		battle_message.text = event.get("text", "")
		if event.kind == "attack":
			await animate_attack(event)
		elif event.kind == "capture":
			_play_sound("capture")
			var tween: Tween = create_tween()
			tween.tween_property(enemy_picture, "modulate:a", 0.15, 0.3)
			tween.tween_property(enemy_picture, "modulate:a", 1.0, 0.3)
			await tween.finished
		else:
			await get_tree().create_timer(0.75).timeout
	busy = false
	notice = events.back().get("text", "") if not events.is_empty() else ""
	refresh()


## アニメーションは時間経過に従って見た目を動かすので非冪等。
func animate_attack(event: Dictionary) -> void:
	_play_sound("attack")
	var target: TextureRect = enemy_picture if event.target == "enemy" else player_picture
	var attacker: TextureRect = player_picture if event.target == "enemy" else enemy_picture
	var origin: Vector2 = attacker.position
	var damage_text: Label = _label_at(
		"−%d" % event.damage,
		Rect2(target.position + Vector2(70, 10), Vector2(160, 80)),
		52,
		Color("ad4c3b")
	)
	var tween: Tween = create_tween()
	tween.tween_property(
		attacker, "position:x", origin.x + (28 if event.target == "enemy" else -28), 0.13
	)
	tween.tween_property(target, "modulate", Color("ff967f"), 0.12)
	tween.tween_property(target, "modulate", Color.WHITE, 0.12)
	tween.tween_property(attacker, "position", origin, 0.13)
	tween.tween_property(damage_text, "position:y", damage_text.position.y - 35, 0.35)
	await tween.finished
	damage_text.queue_free()


func _show_result() -> void:
	var won: bool = Game.mode == "clear"
	_panel(Rect2(670, 0, 610, 720), Color("dce7cd"))
	_label_at("調査、大成功！" if won else "今日は、ひと休み。", Rect2(76, 128, 620, 90), 48)
	_label_at(
		"仲間と歩いた道が、\nきみを一人前の調査隊員にした。" if won else "仲間たちはよく頑張った。\n町で回復して、もう一度出かけよう。",
		Rect2(80, 254, 590, 120),
		27
	)
	_label_at(
		"出会った仲間  %d 体\n歩いた距離  %d 歩" % [Game.party.size() + Game.storage.size(), Game.steps],
		Rect2(80, 400, 520, 90),
		24,
		GREEN
	)
	_button_at("タイトルへ", Rect2(80, 548, 460, 64), to_title, true)
	if not won:
		_button_at("町で回復して再開", Rect2(80, 622, 460, 52), retry)
	_picture("sprout" if won else "ember", Rect2(752, 178, 426, 426))
	_footer("Enter / A で決定")


func retry() -> void:
	Game.heal_party()
	Game.zone = "town"
	Game.cell = Vector2i(11, 7)
	Game.mode = "field"
	notice = "みんな元気になった。新しい調査に出かけよう。"
	refresh()


func to_title() -> void:
	Game.mode = "title"
	menu_open = false
	notice = ""
	refresh()


func _play_music(track: String) -> void:
	if music_name == track:
		return
	music_name = track
	music.stop()
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % track)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	music.stream = stream
	# 初期フレームで終了する起動検証では再生を開始せず、音声の終了競合を避ける。
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree():
		music.play()


## 効果音を入力や演出ごとに鳴らすため非冪等。
func _play_sound(track: String) -> void:
	sound.stream = load("res://assets/audio/%s.wav" % track)
	sound.play()


func _prepare_modal() -> void:
	for child: Node in page.get_children():
		if child is Button:
			child.disabled = true
			child.focus_mode = Control.FOCUS_NONE
	first_button = null
