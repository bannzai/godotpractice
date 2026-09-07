# gdlint: disable=max-public-methods,max-file-lines,max-returns
extends Control
## 進行の正は Game。ここでは入力の配送と状態に対応する描画・演出だけを行う。

const INK := Color("0f380f")
const PAPER := Color("9bbc0f")
const GREEN := Color("306230")
const GOLD := Color("8bac0f")
const MUTED := Color("306230")
const PIXEL_ROOT := "res://assets/pixel/"

var page: Control
var world: QuestWorld
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music_name: String = ""
var ambience_name: String = ""
var closing: bool = false
var busy: bool = false
var menu_open: bool = false
var notice: String = ""
var step_clock: float = 0.0
var enemy_picture: QuestActor
var player_picture: QuestActor
var battle_message: Label
var first_button: Button
var effects: BattleEffects
var player_health: QuestHealth
var enemy_health: QuestHealth
var drawn_mode: String = ""
var audio_suspended: bool = false
var tutorial_active: bool = false
var tutorial_step: int = -1
var tutorial_message: Label
var region_map_open: bool = false
var region_selection: String = "town"
var region_preview: String = ""
var region_unavailable_reason: String = ""
var choice_preview: String = ""
var choice_preview_label: Label
var battle_preview: String = ""
var focused_choice: Button
var battle_preview_label: Label


func _ready() -> void:
	get_tree().auto_accept_quit = false
	theme = preload("res://themes/quest.tres")
	music = AudioStreamPlayer.new()
	music.volume_db = -6.0
	add_child(music)
	sound = AudioStreamPlayer.new()
	sound.volume_db = -10.0
	add_child(sound)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -18.0
	add_child(ambience)
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
	audio_suspended = true
	music.stop()
	sound.stop()
	ambience.stop()
	music.stream = null
	sound.stream = null
	ambience.stream = null


func _exit_tree() -> void:
	stop_audio()
	# --quit-after は終了直前のため await で次フレームを待てない。
	# stop が要求した音声のフェード・解放をミキサースレッドに処理させる。
	# https://github.com/godotengine/godot/pull/122742
	OS.delay_msec(150)


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
	if event.is_action_pressed("menu") and Game.mode == "field" and tutorial_active:
		skip_tutorial()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and Game.mode == "field" and region_map_open:
		close_region_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and Game.mode == "field":
		menu_open = not menu_open
		refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and Game.mode == "field" and tutorial_active:
		if tutorial_step > 0:
			tutorial_active = false
			tutorial_step = -1
			notice = "東門の先の草むらで、最初の仲間を探そう。"
			refresh()
		get_viewport().set_input_as_handled()
	elif (
		event.is_action_pressed("interact")
		and Game.mode == "field"
		and not menu_open
		and not region_map_open
	):
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
	focused_choice = null
	choice_preview = ""
	choice_preview_label = null
	battle_preview = ""
	battle_preview_label = null
	tutorial_message = null
	world = null
	effects = BattleEffects.new()
	page.add_child(effects)
	effects.setup(page)
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
	var track: String = "field"
	match Game.mode:
		"title": track = "title"
		"battle": track = "boss" if Game.trainer else "battle"
		"clear", "gameover": track = "result"
	_play_music(track)
	var ambience_track := ""
	if Game.mode == "field" and Game.zone in ["town", "route"]:
		ambience_track = Game.zone + "_ambience"
	_play_ambience(ambience_track)
	if drawn_mode != Game.mode:
		drawn_mode = Game.mode
		_pixel_wipe()
	if first_button != null and (Game.mode != "field" or menu_open or region_map_open):
		first_button.grab_focus()


## アルファ補間を使わず、4色パレット内の市松を消して場面を開く。
func _pixel_wipe() -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.size = Vector2(1280, 720)
	page.add_child(overlay)
	var cells: Array[ColorRect] = []
	for y: int in 12:
		for x: int in 20:
			var cell := ColorRect.new()
			cell.color = INK if (x + y) % 2 == 0 else GREEN
			cell.position = Vector2(x * 64, y * 60)
			cell.size = Vector2(64, 60)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(cell)
			cells.append(cell)
	for phase: int in 32:
		if not is_instance_valid(overlay):
			return
		for index: int in cells.size():
			if index % 20 + index / 20 == phase:
				cells[index].visible = false
		await get_tree().create_timer(0.008).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()


func _panel(rect: Rect2, color: Color, radius: int = 0) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	node.add_theme_stylebox_override("panel", style)
	page.add_child(node)
	return node


func _window(rect: Rect2) -> Panel:
	var node: Panel = _panel(rect, INK, 10)
	var style: StyleBoxFlat = node.get_theme_stylebox("panel") as StyleBoxFlat
	style.set_border_width_all(4)
	style.border_color = PAPER
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


func _button_at(
	text: String,
	rect: Rect2,
	callback: Callable,
	primary: bool = false,
	preview: String = ""
) -> Button:
	var node := Button.new()
	node.text = text
	node.set_meta("choice_text", text)
	node.set_meta("choice_preview", preview)
	node.position = rect.position
	node.size = rect.size
	node.theme_type_variation = &"Primary" if primary else &"Button"
	node.pivot_offset = rect.size / 2.0
	node.mouse_entered.connect(_focus_choice.bind(node))
	node.mouse_entered.connect(_button_motion.bind(node, 1.0))
	node.mouse_exited.connect(_button_motion.bind(node, 1.0))
	node.button_down.connect(_button_motion.bind(node, 1.0))
	node.button_up.connect(_button_motion.bind(node, 1.0))
	node.focus_entered.connect(_choice_focused.bind(node))
	node.focus_exited.connect(_choice_unfocused.bind(node))
	node.pressed.connect(func() -> void:
		if busy or closing:
			return
		_play_sound("ui")
		callback.call()
	)
	page.add_child(node)
	if first_button == null:
		first_button = node
	return node


func _focus_choice(button: Button) -> void:
	if not button.disabled:
		button.grab_focus()


func _choice_focused(button: Button) -> void:
	focused_choice = button
	button.text = "▶ " + str(button.get_meta("choice_text", button.text))
	choice_preview = str(button.get_meta("choice_preview", ""))
	if is_instance_valid(choice_preview_label) and not choice_preview.is_empty():
		choice_preview_label.text = choice_preview
	if Game.mode == "battle":
		battle_preview = choice_preview
		if is_instance_valid(battle_preview_label):
			battle_preview_label.text = battle_preview


func _choice_unfocused(button: Button) -> void:
	button.text = str(button.get_meta("choice_text", button.text.trim_prefix("▶ ")))
	if focused_choice == button:
		focused_choice = null


## ホバー状態へ滑らかに近づける。重複イベントでは前のTweenを置き換える。
func _button_motion(button: Button, target: float) -> void:
	if button.disabled:
		return
	if button.has_meta("motion"):
		(button.get_meta("motion") as Tween).kill()
	var tween: Tween = button.create_tween()
	button.set_meta("motion", tween)
	tween.tween_property(button, "scale", Vector2.ONE * target, 0.12)


func _picture(id: String, rect: Rect2) -> QuestActor:
	var node := QuestActor.new()
	page.add_child(node)
	node.setup(id, rect)
	return node


func _image(path: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(PIXEL_ROOT + path + ".png")
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(node)
	return node


func _backdrop(height: float = 720.0) -> void:
	var backdrop := ForestBackdrop.new()
	page.add_child(backdrop)
	backdrop.setup(Game.mode == "battle" and Game.trainer, height)


func _show_title() -> void:
	_backdrop()
	_image("backgrounds/title_keyart", Rect2(612, 54, 640, 572))
	_window(Rect2(46, 48, 552, 624))
	_image("ui/logo", Rect2(88, 80, 62, 62))
	_label_at("こもれび野外研究所", Rect2(164, 88, 364, 40), 20, GOLD)
	_label_at("こもれびの調査隊", Rect2(80, 166, 490, 74), 52, PAPER)
	_label_at("草むらの向こうで、きみを待っている。", Rect2(82, 246, 470, 34), 19, GOLD)
	_button_at(
		"はじめから",
		Rect2(88, 322, 466, 58),
		start_new,
		true,
		"新しい記録で、こもれびの町から出発する。"
	)
	var resume_button: Button = _button_at(
		"つづきから",
		Rect2(88, 392, 466, 58),
		resume_game,
		false,
		"保存した町や小径から、調査を再開する。"
	)
	resume_button.disabled = not FileAccess.file_exists(Game.SAVE_PATH)
	if resume_button.disabled:
		resume_button.text = "× つづきから（記録なし）"
		resume_button.set_meta("choice_text", resume_button.text)
	_button_at(
		"調査隊のてびき",
		Rect2(88, 462, 466, 58),
		_show_help,
		false,
		"操作、捕獲、タイプ相性と素材情報を読む。"
	)
	_label_at("▶ 選択中", Rect2(88, 552, 160, 30), 17, PAPER)
	choice_preview_label = _label_at(
		"選択肢を決定すると、その内容へ進みます。",
		Rect2(88, 588, 452, 50),
		18,
		GOLD
	)
	_window(Rect2(768, 626, 424, 50))
	_label_at("森と、海と、きみの物語。", Rect2(800, 635, 360, 32), 18, PAPER)
	if not notice.is_empty():
		_window(Rect2(640, 48, 610, 54))
		_label_at(notice, Rect2(660, 59, 570, 32), 17, PAPER)


func _show_help() -> void:
	_prepare_modal()
	_window(Rect2(64, 72, 1152, 588))
	_label_at("調査隊のてびき", Rect2(104, 98, 1000, 60), 36, PAPER)
	_label_at(
		(
			"▶ 町の東門から小径へ。草むらを歩いて仲間を探す。\n"
			+ "▶ 相手の HP が少ないほど、ボールで捕まえやすい。\n"
			+ "▶ 炎 → 草 → 水 → 炎 は効果ばつぐん。逆は半分。\n"
			+ "▶ 回復の家で全回復と補充。７体目からは預かりへ。\n"
			+ "▶ 育てた仲間で町の隊長に勝つと、調査は大成功。\n\n"
			+ "歩く：矢印 / WASD / 方向パッド / 左スティック\n"
			+ "話す：Enter / Space / A　旅支度：Esc / Tab / Start　全画面：F11\n\n"
			+ "書体：DotGothic16（OFL 1.1）。\n"
			+ "詳細な素材情報：同梱 assets/CREDITS.md とフォントのライセンス。"
		),
		Rect2(104, 168, 1080, 384),
		20,
		PAPER
	)
	_button_at("閉じる", Rect2(900, 578, 260, 52), refresh, true, "タイトルへ戻る。").grab_focus()


func start_new() -> void:
	Game.new_game()
	notice = ""
	menu_open = false
	region_map_open = false
	start_tutorial()
	refresh()


func start_tutorial() -> void:
	tutorial_active = true
	tutorial_step = 0


func skip_tutorial() -> void:
	tutorial_active = false
	tutorial_step = -1
	notice = "東門の先の草むらで、最初の仲間を探そう。"
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
	_window(Rect2(24, 18, 768, 54))
	_label_at(names[Game.zone], Rect2(44, 27, 390, 38), 26, PAPER)
	_label_at("地方図で町と小径を行き来できる", Rect2(430, 31, 344, 30), 16, GOLD)
	world = QuestWorld.new()
	world.position = Vector2(24, 84)
	page.add_child(world)
	world.setup(Game.zone)
	world.set_player(Game.cell)
	world.set_highlight(field_objective_cell(), "target")
	_window(Rect2(816, 84, 440, 448))
	_label_at("調査記録", Rect2(840, 102, 390, 42), 28, PAPER)
	_label_at("仲間  %d / 6" % Game.party.size(), Rect2(840, 154, 190, 32), 21, GOLD)
	_image("ui/capture_ball", Rect2(840, 198, 32, 32))
	_label_at("ボール  %d" % Game.balls, Rect2(884, 198, 150, 34), 20, PAPER)
	_image("ui/potion", Rect2(1050, 198, 32, 32))
	_label_at("回復薬  %d" % Game.potions, Rect2(1094, 198, 140, 34), 20, PAPER)
	if not Game.party.is_empty():
		var lead: Dictionary = Game.party[Game.active_index]
		_picture(lead.species, Rect2(968, 240, 128, 128))
		_label_at(
			"%s  Lv.%d" % [Catalog.SPECIES[lead.species].name, lead.level],
			Rect2(840, 376, 390, 35),
			22,
			PAPER
		)
		_health_bar(lead, Rect2(840, 420, 390, 16))
	_window(Rect2(24, 548, 1232, 148))
	_label_at("▶ 次の調査", Rect2(48, 564, 200, 30), 19, GOLD)
	_label_at(field_context_text(), Rect2(48, 598, 1184, 56), 22, PAPER)
	_label_at("Esc / Start：旅支度と地方図", Rect2(48, 658, 560, 26), 16, GOLD)
	if not notice.is_empty() and not tutorial_active:
		_label_at(notice, Rect2(620, 658, 610, 26), 16, PAPER)
	if tutorial_active:
		_show_tutorial()
	elif region_map_open:
		_show_region_map()
	elif menu_open:
		_show_menu()


func field_objective_cell() -> Vector2i:
	if Game.zone == "town":
		if Game.party.size() + Game.storage.size() >= 2:
			return Vector2i(18, 6)
		return Vector2i(23, 7)
	if Game.zone == "route":
		return Vector2i(4, 4)
	return Vector2i(11, 12)


func field_context_text() -> String:
	if tutorial_active:
		return "まずは場面の案内どおりに操作しよう。"
	if Game.zone == "town":
		if (Game.cell - Vector2i(18, 6)).length() <= 1.0:
			return "A / Enter：隊長に挑む　相手は Lv.8・水タイプ / 草が有利"
		if Game.party.size() + Game.storage.size() >= 2:
			return "町の北東にいる隊長へ。▶ の場所で A / Enter。"
		return "東門の ▶ をめざし、小径の草むらで仲間を探そう。"
	if Game.zone == "route":
		return "草むらを歩くと野生の仲間に出会う。弱らせるほど捕まえやすい。"
	if Game.zone == "clinic":
		return "全回復と補充が完了。A / Enter：もう一度回復　南の ▶：町へ"
	return "A / Enter：調査記録を保存　南の ▶：町へ"


func _show_tutorial() -> void:
	_window(Rect2(104, 438, 1072, 218))
	_label_at("はじめての調査", Rect2(136, 462, 420, 38), 27, PAPER)
	var message := (
		"方向キー / WASD / 左スティックで、隊員を一歩動かそう。"
		if tutorial_step == 0
		else "A / Enter は話す・調べる。押して案内を閉じ、東門へ向かおう。"
	)
	tutorial_message = _label_at(message, Rect2(136, 516, 992, 62), 22, PAPER)
	_label_at("Esc / Tab / Start：チュートリアルをスキップ", Rect2(136, 600, 760, 30), 17, GOLD)


func _health_bar(monster: Dictionary, rect: Rect2) -> QuestHealth:
	var node := QuestHealth.new()
	page.add_child(node)
	node.setup(monster, rect)
	return node


## 一歩ごとに位置・抽選が進むため非冪等。移動中は再入を止める。
func walk(direction: Vector2i) -> void:
	if busy or menu_open or region_map_open or Game.mode != "field":
		return
	step_clock = 0.16
	var next: Vector2i = Game.cell + direction
	if not QuestWorld.walkable(Game.zone, next):
		return
	Game.cell = next
	Game.steps += 1
	busy = true
	world.visual_player.set_action("walk")
	world.visual_player.sprite.flip_h = direction.x < 0
	var tween: Tween = create_tween()
	tween.tween_property(
		world.visual_player,
		"position",
		Vector2(next) * QuestWorld.CELL_SIZE + Vector2.ONE * QuestWorld.CELL_SIZE / 2.0,
		0.12
	)
	await tween.finished
	world.visual_player.set_action("idle")
	busy = false
	var advanced_tutorial: bool = tutorial_active and tutorial_step == 0
	if advanced_tutorial:
		tutorial_step = 1
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
		if Game.zone == "clinic":
			effects.burst(world.position + world.visual_player.position, "heal", 36)
		return
	if QuestWorld.is_grass(Game.zone, Game.cell) and Game.rng.randf() < 0.20:
		begin_battle(Catalog.encounter(Game.rng.randf()), Game.rng.randi_range(3, 6), false)
	elif advanced_tutorial:
		refresh()


func interact() -> void:
	if Game.mode != "field" or busy:
		return
	if Game.zone == "town" and (Game.cell - Vector2i(18, 6)).length() <= 1.0:
		menu_open = true
		_prepare_modal()
		_window(Rect2(250, 228, 760, 270))
		_label_at("隊長 ヒナギク", Rect2(280, 250, 690, 50), 30, PAPER)
		_label_at("仲間との絆を、見せてくれる？\n相手は Lv.8 の水タイプ。草タイプが有利だよ。", Rect2(280, 306, 690, 85), 22, PAPER)
		(
			_button_at(
				"挑戦する",
				Rect2(282, 414, 324, 56),
					func() -> void: begin_battle("crab", 8, true),
					true,
					"隊長の Lv.8 アワガニと戦う。草タイプが有利。"
			)
			. grab_focus()
		)
		_button_at("まだ準備する", Rect2(624, 414, 324, 56), close_menu, false, "町へ戻って仲間を育てる。")
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
	region_map_open = false
	refresh()


func close_menu() -> void:
	menu_open = false
	region_map_open = false
	refresh()


func _show_menu() -> void:
	_prepare_modal()
	_window(Rect2(68, 82, 1144, 590))
	_label_at("旅支度", Rect2(100, 102, 500, 50), 32, PAPER)
	_label_at("仲間を選ぶと先頭に交代。右の窓に結果を表示。", Rect2(560, 112, 620, 40), 18, GOLD)
	for index: int in Game.party.size():
		var monster: Dictionary = Game.party[index]
		var y: int = 174 + index * 56
		var caption: String = "%s Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level]
		if index == Game.active_index:
			caption += " / 先頭"
		if monster.hp <= 0:
			caption = "× " + caption + " / 戦闘不能"
		var member_button: Button = _button_at(
			caption,
			Rect2(100, y, 490, 46),
			select_lead.bind(index),
			false,
			(
				"この仲間を先頭にする。"
				if monster.hp > 0
				else "戦闘不能のため先頭にできない。"
			)
		)
		member_button.disabled = monster.hp <= 0
	_picture(Game.party[Game.active_index].species, Rect2(760, 166, 160, 160))
	choice_preview_label = _label_at(
		choice_preview if not choice_preview.is_empty() else "▶ 仲間を選ぶと、ここに結果を表示。",
		Rect2(640, 348, 520, 70),
		20,
		PAPER
	)
	_label_at(
		"ボール %d   回復薬 %d   預かり %d" % [Game.balls, Game.potions, Game.storage.size()],
		Rect2(640, 430, 520, 40),
		22,
		GOLD
	)
	var potion_info: Dictionary = action_info("field_potion")
	var potion_button: Button = _button_at(
		"先頭を回復" if potion_info.enabled else "× 先頭を回復",
		Rect2(100, 526, 198, 50),
		field_potion,
		false,
		potion_info.preview if potion_info.enabled else potion_info.reason
	)
	potion_button.disabled = not potion_info.enabled
	var storage_button: Button = _button_at(
		"預かり交換" if Game.zone == "clinic" else "× 預かり交換",
		Rect2(310, 526, 198, 50),
		_show_storage,
		false,
		"手持ちの先頭と預かりを交換する。" if Game.zone == "clinic" else "回復の家で利用できる。"
	)
	storage_button.disabled = Game.zone != "clinic"
	_button_at("地方図", Rect2(520, 526, 198, 50), show_region_map, false, "町と小径を選んで移動する。")
	_button_at("セーブ", Rect2(730, 526, 198, 50), save_progress, true, "現在の調査を保存する。")
	_button_at("タイトル", Rect2(940, 526, 198, 50), _confirm_title, false, "保存してタイトルへ戻る。")
	_button_at("戻る", Rect2(940, 594, 198, 50), close_menu, false, "フィールドへ戻る。")


func show_region_map() -> void:
	if Game.mode != "field":
		return
	menu_open = true
	region_map_open = true
	region_selection = Game.zone if Game.zone in ["town", "route"] else "town"
	region_unavailable_reason = "現在地です。別の行き先を選んでください。"
	region_preview = region_unavailable_reason
	refresh()


func close_region_map() -> void:
	region_map_open = false
	menu_open = true
	refresh()


func select_region(zone: String) -> void:
	if zone not in ["town", "route"]:
		return
	if zone == Game.zone:
		region_selection = zone
		region_preview = region_unavailable_reason
		return
	region_selection = zone
	region_preview = _region_description(zone)
	if Game.zone != zone:
		Game.zone = zone
		Game.cell = Vector2i(22, 7) if zone == "town" else Vector2i(1, 7)
	menu_open = false
	region_map_open = false
	notice = "地方図から %s へ移動した。" % ("こもれびの町" if zone == "town" else "ひだまりの小径")
	refresh()


func _show_region_map() -> void:
	_prepare_modal()
	_window(Rect2(52, 40, 1176, 640))
	_label_at("こもれび地方図", Rect2(84, 64, 440, 48), 32, PAPER)
	_image("world/region_map", Rect2(80, 126, 800, 450))
	_label_at("町 ━━━━━━━ 小径", Rect2(208, 540, 560, 36), 23, PAPER)
	var town_button: Button = _button_at(
		"× こもれびの町（現在地）" if Game.zone == "town" else "こもれびの町",
		Rect2(912, 144, 272, 62),
		select_region.bind("town"),
		true,
		region_unavailable_reason if Game.zone == "town" else _region_description("town")
	)
	town_button.disabled = Game.zone == "town"
	town_button.focus_entered.connect(_focus_region.bind("town"))
	var route_button: Button = _button_at(
		"× ひだまりの小径（現在地）" if Game.zone == "route" else "ひだまりの小径",
		Rect2(912, 220, 272, 62),
		select_region.bind("route"),
		true,
		region_unavailable_reason if Game.zone == "route" else _region_description("route")
	)
	route_button.disabled = Game.zone == "route"
	route_button.focus_entered.connect(_focus_region.bind("route"))
	var preview_label: Label = _label_at(region_preview, Rect2(912, 310, 272, 126), 19, PAPER)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_button_at("旅支度へ戻る", Rect2(912, 586, 272, 54), close_region_map, false, "行き先を変えずに戻る。")
	var reason_label: Label = _label_at(
		region_unavailable_reason, Rect2(912, 446, 272, 62), 17, GOLD
	)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	if Game.zone == "town":
		route_button.call_deferred("grab_focus")
	else:
		town_button.call_deferred("grab_focus")


func _focus_region(zone: String) -> void:
	region_selection = zone
	region_preview = _region_description(zone)
	# 地図を作り直さず、表示中の説明だけを更新する。
	for child: Node in page.get_children():
		if child is Label and child.position == Vector2(912, 310):
			child.text = region_preview


func _region_description(zone: String) -> String:
	if zone == "route":
		return "草むらで野生の仲間を探し、戦って育てる。"
	return "回復、預かり、保存を整えて、隊長へ挑戦する。"


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
	_window(Rect2(270, 230, 740, 260))
	_label_at("保存してタイトルへ戻りますか？", Rect2(308, 262, 670, 70), 27, PAPER)
	_button_at("保存して戻る", Rect2(308, 376, 310, 64), _save_and_title, true, "保存後にタイトルへ戻る。").grab_focus()
	_button_at("冒険を続ける", Rect2(646, 376, 310, 64), refresh, false, "保存せず旅支度へ戻る。")


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
	_window(Rect2(80, 96, 1120, 552))
	_label_at("預かりの仲間", Rect2(108, 118, 700, 50), 32, PAPER)
	_label_at("選んだ仲間と手持ちの先頭を交換します。", Rect2(108, 172, 1000, 40), 20, GOLD)
	for index: int in range(offset, mini(offset + 6, Game.storage.size())):
		var monster: Dictionary = Game.storage[index]
		var y: int = 230 + (index - offset) * 52
		_button_at(
			"%s Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level],
			Rect2(108, y, 560, 44),
			exchange_storage.bind(index),
			false,
			"この仲間と手持ちの先頭を交換する。"
		)
	if Game.storage.is_empty():
		_label_at("手持ちが６体のとき、捕まえた仲間をここで預かります。", Rect2(108, 258, 1000, 70), 24, PAPER)
	if offset > 0:
		_button_at("前へ", Rect2(708, 508, 180, 50), _show_storage.bind(offset - 6), false, "前の6体を見る。")
	if offset + 6 < Game.storage.size():
		_button_at("次へ", Rect2(708, 568, 180, 50), _show_storage.bind(offset + 6), false, "次の6体を見る。")
	_button_at("戻る", Rect2(940, 568, 200, 50), refresh, true, "旅支度へ戻る。").grab_focus()


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
	_panel(Rect2(0, 0, 1280, 720), INK)
	await get_tree().create_timer(0.20).timeout
	Game.start_battle(id, level, trainer)
	refresh()
	busy = false


func _show_battle() -> void:
	_backdrop(456)
	_window(Rect2(16, 12, 1248, 56))
	_label_at("隊長 ヒナギクとの腕試し" if Game.trainer else "草むらでの出会い", Rect2(36, 22, 700, 38), 25, PAPER)
	_label_at("炎 → 草 → 水 → 炎　有利2倍 / 不利半分", Rect2(790, 27, 446, 30), 16, GOLD)
	enemy_health = _monster_card(Game.enemy, Rect2(44, 82, 374, 122))
	var lead: Dictionary = Game.party[Game.active_index]
	player_health = _monster_card(lead, Rect2(824, 320, 396, 120))
	enemy_picture = _picture(
		"crab_captain" if Game.trainer else Game.enemy.species, Rect2(842, 82, 256, 224)
	)
	if Game.trainer:
		_picture("captain", Rect2(1140, 146, 96, 160))
	player_picture = _picture(lead.species, Rect2(176, 180, 256, 256))
	_window(Rect2(24, 472, 650, 224))
	battle_message = _label_at(
		"%s はどうする？" % Catalog.SPECIES[lead.species].name,
		Rect2(48, 492, 602, 62),
		24,
		PAPER
	)
	battle_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_preview_label = _label_at(
		"▶ 技を選ぶと、威力と相性を表示。",
		Rect2(48, 566, 602, 100),
		19,
		GOLD
	)
	_window(Rect2(690, 472, 300, 224))
	var moves: Array = Catalog.moves(lead)
	for index: int in moves.size():
		var move_id: String = moves[index]
		var move: Dictionary = Catalog.MOVES[move_id]
		var info: Dictionary = action_info("attack", move_id)
		var move_button: Button = _button_at(
			"%s ・ %s" % [move.name, _type_name(move.type)],
			Rect2(706, 486 + index * 49, 268, 44),
			battle_turn.bind("attack", move_id),
			true,
			info.preview
		)
		move_button.icon = load(PIXEL_ROOT + "ui/type_%s.png" % move.type)
		move_button.expand_icon = true
		move_button.add_theme_constant_override("icon_max_width", 24)
	_window(Rect2(1004, 472, 252, 224))
	var utility: Array[Dictionary] = [
		{"action": "capture", "text": "ボール %d" % Game.balls, "call": battle_turn.bind("capture", "")},
		{"action": "potion", "text": "回復薬 %d" % Game.potions, "call": battle_turn.bind("potion", "")},
		{"action": "switch", "text": "交代", "call": _show_switch},
		{"action": "flee", "text": "逃げる", "call": battle_turn.bind("flee", "")},
	]
	for index: int in utility.size():
		var item: Dictionary = utility[index]
		var info: Dictionary = action_info(item.action)
		var caption: String = item.text if info.enabled else "× " + item.text
		if not info.enabled:
			match item.action:
				"capture", "flee": caption += "（隊長戦）"
				"potion": caption += "（HP満タン）" if Game.potions > 0 else "（在庫なし）"
				"switch": caption += "（候補なし）"
		var button: Button = _button_at(
			caption,
			Rect2(1020, 486 + index * 49, 220, 44),
			item.call,
			false,
			info.preview if info.enabled else info.reason
		)
		button.disabled = not info.enabled


func _monster_card(monster: Dictionary, rect: Rect2) -> QuestHealth:
	_window(rect)
	_label_at(
		"%s  Lv.%d" % [Catalog.SPECIES[monster.species].name, monster.level],
		Rect2(rect.position + Vector2(20, 10), Vector2(350, 40)),
		25,
		PAPER
	)
	_label_at(
		_type_name(Catalog.SPECIES[monster.species].type),
		Rect2(rect.position + Vector2(20, 50), Vector2(65, 35)),
		17,
		GOLD
	)
	_image("ui/type_" + Catalog.SPECIES[monster.species].type,
		Rect2(rect.position + Vector2(64, 58), Vector2(24, 24)))
	return _health_bar(monster,
		Rect2(rect.position + Vector2(102, 60), Vector2(rect.size.x - 124, 12)))


func _type_name(type: String) -> String:
	return Catalog.TYPES.get(type, type)


func action_info(action: String, argument: String = "") -> Dictionary:
	if action == "region":
		if argument not in ["town", "route"]:
			return {"enabled": false, "reason": "行き先が存在しない。", "preview": ""}
		if argument == Game.zone:
			return {"enabled": false, "reason": region_unavailable_reason, "preview": ""}
		return {"enabled": true, "reason": "", "preview": _region_description(argument)}
	if action == "attack" and Game.mode == "battle" and Catalog.MOVES.has(argument):
		var move: Dictionary = Catalog.MOVES[argument]
		var amount: int = Catalog.damage(Game.active_monster(), Game.enemy, argument)
		var effectiveness: float = Catalog.effectiveness(
			move.type, Catalog.SPECIES[Game.enemy.species].type
		)
		var relation := (
			"効果ばつぐん"
			if effectiveness > 1.0
			else ("効果はいまひとつ" if effectiveness < 1.0 else "通常の相性")
		)
		return {
			"enabled": true,
			"reason": "",
			"preview": "%s / 予想 %d ダメージ / %s" % [
				_type_name(move.type), amount, relation,
			],
		}
	if action == "capture":
		if Game.trainer:
			return {"enabled": false, "reason": "隊長の仲間は捕まえられない。", "preview": ""}
		if Game.balls <= 0:
			return {"enabled": false, "reason": "ボールがない。回復の家で補充できる。", "preview": ""}
		return {
			"enabled": true,
			"reason": "",
			"preview": "捕獲見込み %d%%。HPを減らすほど上がる。" % roundi(
				Catalog.capture_chance(Game.enemy) * 100.0
			),
		}
	if action == "potion":
		if Game.potions <= 0:
			return {"enabled": false, "reason": "回復薬がない。回復の家で補充できる。", "preview": ""}
		if Game.active_monster().hp >= Catalog.stats(Game.active_monster()).hp:
			return {"enabled": false, "reason": "HPが満タンなので使えない。", "preview": ""}
		return {"enabled": true, "reason": "", "preview": "HPを35回復し、その後に相手が行動する。"}
	if action == "switch":
		var can_switch: bool = false
		for index: int in Game.party.size():
			can_switch = can_switch or (index != Game.active_index and Game.party[index].hp > 0)
		return {
			"enabled": can_switch,
			"reason": "交代できる仲間がいない。" if not can_switch else "",
			"preview": "交代すると相手が行動する。" if can_switch else "",
		}
	if action == "flee":
		return {
			"enabled": not Game.trainer,
			"reason": "隊長との勝負からは逃げられない。" if Game.trainer else "",
			"preview": "戦闘を終えて小径へ戻る。" if not Game.trainer else "",
		}
	if action == "field_potion":
		var maximum: int = Catalog.stats(Game.active_monster()).hp
		if Game.potions <= 0:
			return {"enabled": false, "reason": "回復薬がない。", "preview": ""}
		if Game.active_monster().hp >= maximum:
			return {"enabled": false, "reason": "先頭のHPは満タン。", "preview": ""}
		return {"enabled": true, "reason": "", "preview": "先頭のHPを30回復する。"}
	return {"enabled": true, "reason": "", "preview": ""}


func _show_switch() -> void:
	if busy:
		return
	_prepare_modal()
	_window(Rect2(80, 170, 1120, 380))
	_label_at("次に戦う仲間を選ぶ（交代すると相手が行動）", Rect2(110, 194, 1060, 45), 26, PAPER)
	for index: int in Game.party.size():
		var monster: Dictionary = Game.party[index]
		var caption: String = "%s  HP %d" % [Catalog.SPECIES[monster.species].name, monster.hp]
		if monster.hp == 0:
			caption = "× " + caption + " / 戦闘不能"
		elif index == Game.active_index:
			caption = "× " + caption + " / 戦闘中"
		var node: Button = _button_at(
			caption,
			Rect2(112 + (index % 3) * 360, 268 + (index / 3) * 82, 330, 62),
			battle_turn.bind("switch", str(index)),
			false,
			"交代後に相手が行動する。"
		)
		node.disabled = monster.hp == 0 or index == Game.active_index
	_button_at("戻る", Rect2(930, 460, 240, 58), refresh, true, "技選択へ戻る。").grab_focus()


## 一ターンの消費と順次演出を伴うため非冪等。重複押下は無視する。
func battle_turn(action: String, move_id: String) -> void:
	if busy or Game.mode != "battle":
		return
	refresh()
	busy = true
	_prepare_modal()
	var events: Array = Game.resolve_turn(action, move_id)
	for event: Dictionary in events:
		battle_message.text = event.get("text", "")
		match event.kind:
			"attack":
				await animate_attack(event)
			"capture":
				_play_sound("capture")
				await effects.capture(enemy_picture, event.success)
			"heal":
				_play_sound("heal")
				player_health.present(event.hp_after)
				await effects.celebrate(player_picture, "heal", "+HP")
			"level":
				_play_sound("levelup")
				await effects.celebrate(player_picture, "level", "レベルアップ！")
			"faint":
				_play_sound("defeat")
				var actor: QuestActor = enemy_picture if event.target == "enemy" else player_picture
				actor.set_action("defeat")
				await get_tree().create_timer(0.65).timeout
			"switch":
				player_picture.setup(event.species, Rect2(player_picture.position, player_picture.size))
				player_picture.set_action("idle")
				player_picture.modulate = Color.WHITE
				player_health.present(event.hp_after, event.maximum)
				await get_tree().create_timer(0.5).timeout
			_:
				await get_tree().create_timer(0.55).timeout
	busy = false
	notice = events.back().get("text", "") if not events.is_empty() else ""
	refresh()


## アニメーションは時間経過に従って見た目を動かすので非冪等。
func animate_attack(event: Dictionary) -> void:
	_play_sound("attack")
	var target: QuestActor = enemy_picture if event.target == "enemy" else player_picture
	var attacker: QuestActor = player_picture if event.target == "enemy" else enemy_picture
	var health: QuestHealth = enemy_health if event.target == "enemy" else player_health
	# 表示のHPは被弾する時点から減らし、解決済みターンの最終値へ先回りさせない。
	var countdown: Tween = health.create_tween()
	countdown.tween_interval(0.42)
	countdown.tween_callback(health.present.bind(event.hp_after))
	await effects.attack(attacker, target, event)


func _show_result() -> void:
	var won: bool = Game.mode == "clear"
	_backdrop()
	_window(Rect2(48, 66, 640, 594))
	_image("ui/emblem", Rect2(856, 82, 204, 164))
	_label_at("調査、大成功！" if won else "今日は、ひと休み。", Rect2(76, 128, 580, 90), 44, PAPER)
	_label_at(
		"仲間と歩いた道が、\nきみを一人前の調査隊員にした。" if won else "仲間たちはよく頑張った。\n町で回復して、もう一度出かけよう。",
		Rect2(80, 254, 590, 120),
		27,
		PAPER
	)
	_label_at(
		"出会った仲間  %d 体\n歩いた距離  %d 歩" % [Game.party.size() + Game.storage.size(), Game.steps],
		Rect2(80, 400, 520, 90),
		24,
		GOLD
	)
	if not won:
		_button_at("町で回復して再開", Rect2(80, 526, 460, 56), retry, true, "全回復して町から調査を再開する。")
		_button_at("タイトルへ", Rect2(80, 594, 460, 44), to_title, false, "タイトルへ戻る。")
	else:
		_button_at("タイトルへ", Rect2(80, 540, 460, 56), to_title, true, "調査結果を閉じてタイトルへ戻る。")
	_picture("sprout" if won else "ember", Rect2(752, 240, 426, 380))
	if won:
		effects.burst(Vector2(974, 270), "level", 56)


func retry() -> void:
	Game.heal_party()
	Game.zone = "town"
	Game.cell = Vector2i(11, 7)
	Game.mode = "field"
	tutorial_active = false
	tutorial_step = -1
	region_map_open = false
	notice = "みんな元気になった。新しい調査に出かけよう。"
	refresh()


func to_title() -> void:
	Game.mode = "title"
	menu_open = false
	region_map_open = false
	tutorial_active = false
	tutorial_step = -1
	notice = ""
	refresh()


func _play_music(track: String) -> void:
	if audio_suspended or music_name == track:
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
	if is_inside_tree() and not audio_suspended and music_name == track:
		music.play()


func _play_ambience(track: String) -> void:
	if audio_suspended or ambience_name == track:
		return
	ambience_name = track
	ambience.stop()
	ambience.stream = null
	if track.is_empty():
		return
	var stream: AudioStreamWAV = load("res://assets/audio/%s.wav" % track)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	ambience.stream = stream
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and not audio_suspended and ambience_name == track:
		ambience.play()


## 効果音を入力や演出ごとに鳴らすため非冪等。
func _play_sound(track: String) -> void:
	if audio_suspended:
		return
	sound.stream = load("res://assets/audio/%s.wav" % track)
	sound.play()


func _prepare_modal() -> void:
	for child: Node in page.get_children():
		if child is Button:
			child.disabled = true
			child.focus_mode = Control.FOCUS_NONE
	first_button = null
