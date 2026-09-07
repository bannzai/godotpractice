extends Control
## 農場の操作と画面。作物・経済・日付・保存は Farm が保持する。

const UI = preload("res://scripts/farm_ui.gd")
const TOOL_ICONS: Array[String] = ["hoe", "water", "seed", "hand"]
const TOOL_ANIMATIONS: Array[String] = ["hoe", "water", "hoe", "harvest"]

var save_path: String = Farm.SAVE_PATH
var page: Control
var world: Node2D
var sound: Node
var mode: String = "title"
var modal: Control
var busy: bool = false
var notice: Label
var clock_label: Label
var money_label: Label
var stamina_label: Label
var stamina_bar: ProgressBar
var tool_buttons: Array[Button] = []
var seed_button: Button
var context_label: Label
var preview_label: Label
var objective_label: Label
var journal_label: Label
var money_shown: float = 120.0
var modal_buttons: Array[Button] = []
var tutorial_step: int = -1
var tutorial_active: bool = false
var _audio_started: bool = false
var _ui_elapsed: float = 0.0
var _notice_remaining: float = 0.0
var _closing: bool = false


func _ready() -> void:
	print("farmsim boot")
	DisplayServer.window_set_title("こもれび農園")
	theme = load("res://themes/farm.tres")
	get_tree().auto_accept_quit = false
	sound = load("res://scripts/farm_sound.gd").new()
	add_child(sound)
	Farm.changed.connect(_state_changed)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _closing:
		_closing = true
		stop_audio()
		await get_tree().create_timer(0.2).timeout
		get_tree().quit()


func stop_audio() -> void:
	if is_instance_valid(sound):
		sound.stop_audio()


func refresh() -> void:
	if is_instance_valid(page):
		remove_child(page)
		page.queue_free()
	modal = null
	world = null
	tool_buttons.clear()
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var background_layer := CanvasLayer.new()
	background_layer.layer = -2
	page.add_child(background_layer)
	background_layer.add_child(load("res://scripts/farm_backdrop.gd").new())
	match mode:
		"title":
			_title()
		"playing":
			_field()
		"map":
			_village_map()
		"result":
			_result()
	if _audio_started:
		_update_music()


func _title() -> void:
	UI.picture(page, "res://assets/backgrounds/title.png", Rect2(586, 54, 650, 612))
	UI.panel(page, Rect2(55, 48, 566, 624), Color("ead7abf2"))
	UI.label(page, "昭和の山里から届いた、母の便り", Rect2(92, 80, 470, 38), 20, UI.MUTED)
	UI.picture(page, "res://assets/ui/logo.png", Rect2(86, 125, 195, 145))
	UI.label(page, "こもれび農園日記", Rect2(251, 154, 330, 68), 39)
	UI.label(page, "種をまき、村を歩き、季節を版に残す。\n春と夏、二十日間の農家暮らし。",
		Rect2(93, 279, 466, 88), 24)
	UI.panel(page, Rect2(92, 378, 470, 70), Color("f0dfb9e8"))
	UI.label(page, "母より　『まず畑を一枚、耕してごらん。』", Rect2(109, 393, 434, 41), 20)
	UI.button(page, "新しい日記をひらく", Rect2(92, 475, 470, 58), start_new).grab_focus()
	var resume := UI.button(page, "つづきの頁", Rect2(92, 552, 224, 52), _resume)
	resume.disabled = not FileAccess.file_exists(save_path)
	UI.button(page, "母の手紙", Rect2(338, 552, 224, 52), _help)
	UI.label(page, "F11　全画面", Rect2(1073, 671, 153, 30), 17, UI.CREAM)


func start_new() -> void:
	Farm.reset()
	mode = "playing"
	busy = false
	money_shown = Farm.money
	refresh()
	tutorial_step = 0
	tutorial_active = true
	_tutorial_letter.call_deferred()


func _tutorial_letter() -> void:
	_open_modal("母からの手紙", "畑仕事は、いっぺんに覚えなくていいよ。\n光る一マスを見て、クワ、種、水の順に試してごらん。\n日記帳には、できることと、できない理由が出るからね。")
	UI.button(modal, "手紙どおりに始める", Rect2(300, 414, 326, 58), _begin_tutorial).grab_focus()
	UI.button(modal, "もう知っているので省く", Rect2(650, 414, 330, 58), _skip_tutorial)


func _begin_tutorial() -> void:
	close_modal()
	tutorial_step = 1
	tutorial_active = true
	Farm.selected_tool = 0
	_update_hud()
	_message(_tutorial_hint(), 20)


func _skip_tutorial() -> void:
	close_modal()
	tutorial_step = -1
	tutorial_active = false
	_message("日記の『次の一手』を見ながら、二十日間の農場を育てよう。", 7)


func _tutorial_hint() -> String:
	return {
		1: "母の手紙 1/3　目の前の光る土へ、クワを使って耕そう。",
		2: "母の手紙 2/3　同じマスへ、選ばれた種袋から種をまこう。",
		3: "母の手紙 3/3　同じマスへ水をあげれば、明朝に育つよ。",
	}.get(tutorial_step, "日記の『次の一手』を見て、光る対象へ向かおう。")


func _advance_tutorial(tool: int) -> void:
	if not tutorial_active:
		return
	if tutorial_step == 1 and tool == 0:
		tutorial_step = 2
		Farm.selected_tool = 2
	elif tutorial_step == 2 and tool == 2:
		tutorial_step = 3
		Farm.selected_tool = 1
	elif tutorial_step == 3 and tool == 1:
		tutorial_step = -1
		tutorial_active = false
		_message("母の手紙どおりにできたね。眠ると作物が育ち、収穫後は出荷箱へ。", 12)
		return
	else:
		return
	_message(_tutorial_hint(), 20)


func _resume() -> void:
	if Farm.load_game(save_path):
		mode = "playing" if Farm.phase == "playing" else "result"
		tutorial_step = -1
		tutorial_active = false
		money_shown = Farm.money
		refresh()
		_message("おかえりなさい。前回の農場から再開しました。")
	else:
		_help("セーブを読み込めませんでした。ファイルは変更していません。")


func return_title() -> void:
	mode = "title"
	busy = false
	refresh()


func show_result() -> void:
	mode = "result"
	busy = false
	refresh()


func _field() -> void:
	var world_layer := CanvasLayer.new()
	world_layer.layer = -1
	page.add_child(world_layer)
	world = load("res://scripts/farm_world.gd").new()
	world_layer.add_child(world)
	UI.panel(page, Rect2(938, 18, 322, 684), Color("e4c890f4"))
	UI.label(page, "農家の日記", Rect2(961, 31, 270, 45), 30)
	clock_label = UI.label(page, "", Rect2(961, 77, 274, 62), 23)
	money_label = UI.label(page, "", Rect2(961, 139, 274, 38), 23)
	stamina_label = UI.label(page, "", Rect2(961, 177, 274, 30), 17)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", UI.box(Color("ad895d"), 2))
	stamina_bar.add_theme_stylebox_override("fill", UI.box(Color("315c43"), 2))
	page.add_child(stamina_bar)
	stamina_bar.position = Vector2(961, 207)
	stamina_bar.size = Vector2(274, 10)
	_field_labels()
	_journal()
	_toolbar()
	UI.panel(page, Rect2(27, 629, 891, 65), Color("332c26e8"))
	notice = UI.label(page, "", Rect2(49, 640, 850, 44), 19, UI.CREAM)
	_update_hud()


func _field_labels() -> void:
	_tag("おうち・ベッド", Vector2(87, 283), 173)
	_tag("井戸", Vector2(271, 260), 66)
	_tag("村への道", Vector2(810, 278), 118)
	_tag("出荷箱", Vector2(818, 432), 98)
	_tag("今日の畑", Vector2(514, 269), 132)


func _tag(text: String, at: Vector2, width: float) -> void:
	var panel: Panel = UI.panel(page, Rect2(at, Vector2(width, 30)), Color("fff8e6d9"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(panel, text, Rect2(8, 1, width - 16, 28), 17)


func _journal() -> void:
	UI.label(page, "今季の目標", Rect2(961, 228, 264, 29), 17, UI.MUTED)
	objective_label = UI.label(page, "", Rect2(961, 256, 274, 58), 19)
	journal_label = UI.label(page, "", Rect2(961, 310, 274, 53), 16, UI.MUTED)
	preview_label = UI.label(page, "", Rect2(961, 365, 274, 58), 17)


func _toolbar() -> void:
	for index: int in 4:
		var at := Vector2(956 + index % 2 * 145, 429 + index / 2 * 54)
		var button: Button = UI.button(page, "%d  %s" % [index + 1, Farm.TOOLS[index]],
			Rect2(at, Vector2(137, 46)), _select_tool.bind(index))
		button.add_theme_font_size_override("font_size", 15)
		button.icon = load("res://assets/ui/%s.png" % TOOL_ICONS[index])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 24)
		tool_buttons.append(button)
	seed_button = UI.button(page, "", Rect2(956, 539, 282, 43), _cycle_crop)
	seed_button.add_theme_font_size_override("font_size", 15)
	UI.button(page, "道具を使う", Rect2(956, 590, 137, 43), use_tool)
	UI.button(page, "調べる", Rect2(1101, 590, 137, 43), interact)
	UI.button(page, "手帳・保存", Rect2(956, 642, 282, 40), open_menu)
	context_label = UI.label(page, "", Rect2(962, 684, 270, 18), 13, UI.MUTED)


func _update_hud() -> void:
	if mode != "playing" or not is_instance_valid(clock_label):
		return
	clock_label.text = "%s　%d日目　%s" % [Farm.season_name(), (Farm.day - 1) % 10 + 1,
		Farm.clock_text()]
	money_label.text = "所持金　%d G" % roundi(money_shown)
	stamina_label.text = "体力　%d / 100" % Farm.stamina
	stamina_bar.value = Farm.stamina
	objective_label.text = "%d / %d G　または全4種出荷" % [Farm.money, Farm.TARGET_MONEY]
	var shipped_types: int = 0
	var pending: int = 0
	for id: String in Farm.CROPS:
		if int(Farm.shipped[id]) > 0:
			shipped_types += 1
		pending += int(Farm.shipping[id]) * int(Farm.CROPS[id].sell)
	journal_label.text = "出荷 %d / 4種　明朝 +%d G\n季節の終わりまで %d日" % [
		shipped_types, pending, 11 - ((Farm.day - 1) % 10 + 1)]
	seed_button.text = "種袋　%s ×%d　（R / Y）" % [
		Farm.CROPS[Farm.selected_crop].name, Farm.seeds[Farm.selected_crop]]
	for index: int in tool_buttons.size():
		tool_buttons[index].modulate = Color("df984d") if index == Farm.selected_tool else Color.WHITE
	var near: String = _nearby()
	context_label.text = {"bed": "F / A　眠って翌朝へ", "shop": "F / A　村の地図へ",
		"shipping": "F / A　作物を明朝の売上へ", "well": "F / A　井戸の話を読む"}.get(
		near, "Space / X　向いたマスへ実行")
	var preview: Dictionary = Farm.tool_preview(world.target_index())
	preview_label.text = ("○ " if preview.ok else "× ") + str(preview.text)


func _state_changed() -> void:
	if mode == "playing" and is_instance_valid(world):
		world.refresh()
		_update_hud()


## 実時間と移動入力を進めるため非冪等。
func _process(delta: float) -> void:
	if not _audio_started and Engine.get_process_frames() > 3:
		_audio_started = true
		_update_music()
	if mode != "playing":
		return
	money_shown = move_toward(money_shown, float(Farm.money), maxf(40, absf(
		Farm.money - money_shown) * 5) * delta)
	_ui_elapsed += delta
	_notice_remaining -= delta
	if _ui_elapsed > 0.1:
		_ui_elapsed = 0
		_update_hud()
		if _notice_remaining <= 0 and is_instance_valid(notice):
			notice.text = _tutorial_hint() if tutorial_active else "日記の『次の一手』を見て、光る対象へ向かおう。"
	if busy or is_instance_valid(modal):
		return
	var result: Dictionary = Farm.tick(delta)
	if not result.is_empty():
		_day_transition(result)
		return
	world.move_player(Input.get_vector("move_left", "move_right", "move_up", "move_down"), delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		if is_instance_valid(modal):
			close_modal()
		elif mode == "playing" and not busy:
			open_menu()
		elif mode == "map":
			_return_to_field()
		get_viewport().set_input_as_handled()
		return
	if mode != "playing" or busy or is_instance_valid(modal):
		return
	for index: int in 4:
		if event.is_action_pressed("tool_%d" % index):
			_select_tool(index)
	if event.is_action_pressed("tool_next"):
		_select_tool((Farm.selected_tool + 1) % 4)
	elif event.is_action_pressed("tool_previous"):
		_select_tool((Farm.selected_tool + 3) % 4)
	elif event.is_action_pressed("crop_next"):
		_cycle_crop()
	elif event.is_action_pressed("use_tool"):
		use_tool()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()


func _select_tool(index: int) -> void:
	if busy or is_instance_valid(modal):
		return
	Farm.selected_tool = index
	_update_hud()
	sound.play("ui")


## 選択を次の種へ進める入力なので非冪等。
func _cycle_crop() -> void:
	if busy or is_instance_valid(modal):
		return
	var ids: Array = Farm.CROPS.keys()
	Farm.selected_crop = ids[(ids.find(Farm.selected_crop) + 1) % ids.size()]
	_update_hud()
	sound.play("ui")


## 一回の使用で作物と体力が変わるため非冪等。
func use_tool() -> void:
	if mode != "playing" or busy or is_instance_valid(modal):
		return
	var index: int = world.target_index()
	var tool: int = Farm.selected_tool
	var result: Dictionary = Farm.use_tool(index)
	_message(str(result.text))
	if not result.ok:
		sound.play("fail")
		return
	_advance_tutorial(tool)
	busy = true
	world.player.animate(TOOL_ANIMATIONS[tool])
	world.effect(TOOL_ICONS[tool], world.cell_center(index))
	sound.play(["hoe", "water", "seed", "harvest"][tool])
	if tool == 3:
		_popup("+1 収穫", world.cell_center(index), UI.GOLD)
		var shake: Tween = create_tween()
		shake.tween_property(world, "position:x", 3.0, 0.04)
		shake.tween_property(world, "position:x", -3.0, 0.04)
		shake.tween_property(world, "position:x", 0.0, 0.04)
		# 収穫の瞬間だけ足を止め、獲得を見せる。
		world.player.sprite.pause()
		await get_tree().create_timer(0.07).timeout
		world.player.sprite.play()
	await get_tree().create_timer(0.42).timeout
	busy = false
	if result.get("advanced_day", false):
		_day_transition(result)


func _nearby() -> String:
	if not is_instance_valid(world):
		return ""
	for item: Array in [["bed", world.BED], ["shipping", world.SHIPPING],
		["shop", world.TOWN], ["well", world.WELL]]:
		if Farm.player_position.distance_to(item[1]) < 86:
			return item[0]
	return ""


func interact() -> void:
	if busy or mode != "playing" or is_instance_valid(modal):
		return
	match _nearby():
		"bed":
			_open_modal("おうちのベッド", "眠ると翌朝になります。\n水をあげた作物が育ち、出荷の代金が届きます。")
			UI.button(modal, "眠って翌朝へ", Rect2(406, 407, 468, 57), sleep_night).grab_focus()
		"shipping":
			var result: Dictionary = Farm.ship_all()
			_message(str(result.text))
			sound.play("ship" if result.ok else "fail")
			if result.ok:
				_popup("明朝 +%d G" % result.amount, world.SHIPPING, UI.GOLD)
		"shop":
			_open_village_map()
		"well":
			_message("井戸の清水。ジョウロの水はいつでも満タンです。")
			world.effect("water", world.WELL)
			sound.play("water")
		_:
			_message("版画の札が光る場所まで歩くと、調べられます。")


## 睡眠を確定した一回の操作で日を進めるため非冪等。
func sleep_night() -> void:
	close_modal()
	_day_transition(Farm.advance_day())


## 日付の切替を一度だけ演出するため非冪等。
func _day_transition(result: Dictionary) -> void:
	busy = true
	var shade := ColorRect.new()
	shade.color = Color("233c44")
	shade.size = Vector2(1280, 720)
	shade.modulate.a = 0
	page.add_child(shade)
	var tween := create_tween()
	tween.tween_property(shade, "modulate:a", 1.0, 0.3)
	await tween.finished
	if Farm.phase != "playing":
		show_result()
		return
	world.refresh()
	world.player.animate("idle")
	_update_music()
	sound.play("next_day")
	tween = create_tween()
	tween.tween_property(shade, "modulate:a", 0.0, 0.4)
	await tween.finished
	shade.queue_free()
	busy = false
	_message(str(result.text), 8)


func _open_modal(heading: String, caption: String = "") -> void:
	close_modal()
	modal_buttons.clear()
	_collect_buttons(page, modal_buttons)
	for button: Button in modal_buttons:
		button.disabled = true
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color("17392acb")
	shade.size = Vector2(1280, 720)
	modal.add_child(shade)
	UI.panel(modal, Rect2(262, 116, 756, 503))
	UI.label(modal, heading, Rect2(298, 139, 682, 57), 34)
	UI.label(modal, caption, Rect2(300, 212, 680, 150), 21)
	UI.button(modal, "閉じる  Esc / B", Rect2(737, 548, 242, 44), close_modal).grab_focus()
	sound.play("ui")


func close_modal() -> void:
	if not is_instance_valid(modal):
		return
	page.remove_child(modal)
	modal.queue_free()
	modal = null
	for button: Button in modal_buttons:
		if is_instance_valid(button):
			button.disabled = false
	modal_buttons.clear()
	if mode == "title":
		refresh()


func _collect_buttons(node: Node, output: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button and not child.disabled:
			output.append(child)
		_collect_buttons(child, output)


func open_menu() -> void:
	if busy or mode != "playing":
		return
	_open_modal("農場の手帳")
	UI.button(modal, "持ちもの", Rect2(300, 212, 210, 48), _inventory).grab_focus()
	UI.button(modal, "作物図鑑", Rect2(535, 212, 210, 48), _catalogue)
	UI.button(modal, "セーブする", Rect2(770, 212, 210, 48), _save)
	UI.label(modal, "春と夏、それぞれ10日間の暮らし。\n\n所持金900 G、または4種類すべてを出荷すると目標達成。\n季節が変わると前の季節の作物は枯れます。",
		Rect2(304, 299, 679, 176), 22)
	UI.button(modal, "タイトルへ戻る", Rect2(300, 548, 253, 44), _confirm_title)


func _inventory() -> void:
	_open_modal("持ちもの")
	for index: int in 4:
		var id: String = Farm.CROPS.keys()[index]
		var y: int = 213 + index * 62
		UI.picture(modal, "res://assets/crops/%s_ripe.png" % id, Rect2(304, y, 52, 52))
		UI.label(modal, "%s　種 %d袋　収穫 %d個　出荷待ち %d個" % [Farm.CROPS[id].name,
			Farm.seeds[id], Farm.harvested[id], Farm.shipping[id]], Rect2(374, y, 600, 51), 21)
	UI.button(modal, "お弁当を食べる ×%d　体力 +30" % Farm.food,
		Rect2(305, 485, 672, 45), _eat).grab_focus()


## 食事は所持品を消費する一回の入力のため非冪等。
func _eat() -> void:
	var result: Dictionary = Farm.eat()
	close_modal()
	_message(str(result.text))
	sound.play("success" if result.ok else "fail")


func _catalogue() -> void:
	_open_modal("作物図鑑")
	for index: int in 4:
		var id: String = Farm.CROPS.keys()[index]
		var data: Dictionary = Farm.CROPS[id]
		var y: int = 211 + index * 77
		UI.picture(modal, "res://assets/crops/%s_ripe.png" % id, Rect2(307, y, 66, 66))
		var shipped: String = "出荷済み" if Farm.shipped[id] > 0 else "未出荷"
		UI.label(modal, "%s　%s　%s" % [data.name, "春" if data.season == "spring" else "夏", shipped],
			Rect2(400, y, 520, 34), 23)
		UI.label(modal, "成長 %d日 ／ 売値 %d G ／ 種 %d G" % [data.days, data.sell, data.seed_price],
			Rect2(400, y + 37, 530, 29), 19, UI.MUTED)


func _save() -> void:
	var succeeded: bool = Farm.save_game(save_path)
	close_modal()
	_message("農場をセーブしました。" if succeeded else "セーブできませんでした。", 6)
	sound.play("success" if succeeded else "fail")


func _confirm_title() -> void:
	_open_modal("農場を離れますか？", "保存していない進行は失われます。\n「セーブして戻る」で、あとから同じ農場へ戻れます。")
	UI.button(modal, "セーブして戻る", Rect2(302, 401, 328, 56), _save_and_title).grab_focus()
	UI.button(modal, "保存せず戻る", Rect2(653, 401, 328, 56), return_title)


func _save_and_title() -> void:
	if Farm.save_game(save_path):
		return_title()
	else:
		close_modal()
		_message("セーブできませんでした。農場に戻りました。")


func _open_village_map() -> void:
	mode = "map"
	busy = false
	refresh()
	sound.play("map")


func _village_map() -> void:
	UI.picture(page, "res://assets/backgrounds/village_map.png", Rect2(0, 0, 1280, 720))
	UI.panel(page, Rect2(70, 65, 1140, 93), Color("332c26df"))
	UI.label(page, "木版・こもれび村の道しるべ", Rect2(103, 80, 620, 42), 31, UI.CREAM)
	UI.label(page, "行き先を選ぶと、そこでできることが日記に記されます。",
		Rect2(104, 122, 790, 27), 18, UI.CREAM)
	var farm_button := UI.button(page, "農場へ戻る", Rect2(170, 522, 286, 58), _return_to_field)
	UI.label(page, "畑仕事・出荷・就寝をつづける", Rect2(171, 587, 333, 31), 19)
	var shop_button := UI.button(page, "リラの種屋へ", Rect2(823, 309, 286, 58), open_shop)
	UI.label(page, "種と弁当を買う　所持金 %d G" % Farm.money,
		Rect2(824, 374, 350, 31), 19)
	UI.panel(page, Rect2(485, 519, 310, 113), Color("ead7abeb"))
	UI.label(page, "村まで歩く", Rect2(515, 536, 250, 34), 24)
	UI.label(page, "赤い道をたどって種屋へ。\n帰りはこの地図から農場を選ぶ。",
		Rect2(514, 570, 252, 52), 17)
	var walker := UI.label(page, "●", Rect2(296, 447, 40, 40), 31, Color("f2d174"))
	var route := create_tween().set_loops()
	route.tween_property(walker, "position", Vector2(590, 398), 1.4)
	route.tween_property(walker, "position", Vector2(948, 208), 1.4)
	route.tween_interval(0.45)
	route.tween_property(walker, "position", Vector2(296, 447), 0.01)
	shop_button.grab_focus()
	farm_button.focus_neighbor_right = shop_button.get_path()
	shop_button.focus_neighbor_left = farm_button.get_path()


func _return_to_field() -> void:
	mode = "playing"
	refresh()
	_message("農場へ戻りました。日記の『次の一手』を確認しよう。", 5)


func open_shop() -> void:
	_open_modal("村の地図 → リラの種屋")
	UI.label(modal, "この季節に買える種だけ版が濃くなります。　所持金 %d G" % Farm.money,
		Rect2(300, 195, 680, 37), 19, UI.MUTED)
	for index: int in 4:
		var id: String = Farm.CROPS.keys()[index]
		var data: Dictionary = Farm.CROPS[id]
		var y: int = 240 + index * 62
		UI.picture(modal, "res://assets/crops/%s_ripe.png" % id, Rect2(301, y, 50, 50))
		UI.label(modal, "%s　%s・%d日" % [data.name, "春" if data.season == "spring" else "夏", data.days],
			Rect2(369, y, 350, 46), 22)
		var buy: Button = UI.button(modal, "%d G　購入" % data.seed_price,
			Rect2(739, y, 239, 46), _buy_seed.bind(id))
		buy.disabled = Farm.money < int(data.seed_price) or data.season != Farm.season()
		if index == 0 and not buy.disabled:
			buy.grab_focus()
	UI.button(modal, "お弁当　%d G / 体力 +%d" % [Farm.FOOD_PRICE, Farm.FOOD_RECOVERY],
		Rect2(301, 497, 678, 39), _buy_food)


## 購入ごとに所持数と通貨が変わるため非冪等。
func _buy_seed(id: String) -> void:
	var result: Dictionary = Farm.buy_seed(id)
	open_shop()
	sound.play("success" if result.ok else "fail")
	_popup(str(result.text), Vector2(639, 460), UI.INK)


## 購入ごとに所持数と通貨が変わるため非冪等。
func _buy_food() -> void:
	var result: Dictionary = Farm.buy_food()
	open_shop()
	sound.play("success" if result.ok else "fail")
	_popup(str(result.text), Vector2(639, 460), UI.INK)


func _help(extra: String = "") -> void:
	_open_modal("母からの手紙")
	var text: String = "歩くときは WASD・矢印、または左スティック。\n"
	text += "日記の道具を 1〜4、Q・E、LB・RB で選べます。\n"
	text += "向いたマスへ Space・X。札のそばでは F・Enter・A。\n"
	text += "\n"
	text += "畑はクワ、種、水の順。水をあげた日だけ育ちます。\n"
	text += "収穫したら出荷箱へ。眠った翌朝、代金が届きます。\n"
	text += "村へは右上の道しるべから。Tab・Start は手帳とセーブ。\n"
	text += "F11 で全画面。深夜二時や体力切れは所持金が減るので早寝してね。"
	if not extra.is_empty():
		text = extra
	UI.label(modal, text, Rect2(300, 208, 696, 327), 20)


func _result() -> void:
	UI.picture(page, "res://assets/backgrounds/title.png", Rect2(604, 77, 650, 575))
	UI.panel(page, Rect2(102, 72, 654, 565), Color("ead7abf5"))
	var won: bool = Farm.phase == "win"
	UI.label(page, "農場から届いた手紙", Rect2(144, 104, 552, 40), 22, UI.MUTED)
	UI.label(page, "実りの季節、おめでとう！" if won else "二十日間の、暮らしの記録",
		Rect2(143, 174, 582, 60), 35)
	UI.label(page, "小さな種が、豊かな毎日になりました。" if won else "次の季節は、どんな畑にしよう。",
		Rect2(148, 261, 570, 43), 23)
	var shipped: int = 0
	for id: String in Farm.shipped:
		shipped += int(Farm.shipped[id])
	UI.label(page, "所持金　%d G\n稼いだ金額　%d G\n出荷した作物　%d個" % [Farm.money, Farm.earned, shipped],
		Rect2(148, 338, 542, 150), 28)
	UI.button(page, "タイトルへ", Rect2(146, 535, 268, 58), return_title).grab_focus()
	UI.button(page, "もう一度", Rect2(437, 535, 269, 58), start_new)


func _message(text: String, seconds: float = 5.0) -> void:
	if is_instance_valid(notice) and mode == "playing":
		notice.text = text
		_notice_remaining = seconds


## 操作結果の短いポップを一度だけ生成するため非冪等。
func _popup(text: String, at: Vector2, color: Color) -> void:
	var popup: Label = UI.label(page, text, Rect2(at - Vector2(160, 40), Vector2(320, 50)), 24, color)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_color_override("font_shadow_color", Color("fff8ec"))
	popup.add_theme_constant_override("shadow_offset_x", 1)
	popup.add_theme_constant_override("shadow_offset_y", 1)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 42, 1.15)
	tween.tween_property(popup, "modulate:a", 0.0, 0.55).set_delay(0.6)
	tween.chain().tween_callback(popup.queue_free)


func _update_music() -> void:
	sound.set_ambience(mode in ["playing", "map"])
	if mode == "title":
		sound.track("title")
	elif mode == "result":
		sound.track("result")
	elif Farm.money >= 700:
		sound.track("festival")
	else:
		sound.track(Farm.season())
