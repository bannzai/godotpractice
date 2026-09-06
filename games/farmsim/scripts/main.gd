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
var objective_label: Label
var journal_label: Label
var money_shown: float = 120.0
var modal_buttons: Array[Button] = []
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
		"result":
			_result()
	if _audio_started:
		_update_music()


func _title() -> void:
	UI.picture(page, "res://assets/backgrounds/title.svg", Rect2(500, 80, 756, 590))
	UI.panel(page, Rect2(62, 76, 522, 570), Color("fff8edf2"))
	UI.label(page, "小さな畑と、季節の手紙", Rect2(104, 105, 400, 40), 20, UI.MUTED)
	UI.picture(page, "res://assets/ui/logo.svg", Rect2(95, 158, 440, 125))
	UI.label(page, "こもれび農園", Rect2(106, 281, 420, 62), 43)
	UI.label(page, "種をまき、季節を育てる。\n春と夏をめぐる、二十日間の暮らし。",
		Rect2(108, 352, 430, 84), 23)
	UI.button(page, "新しい暮らしをはじめる", Rect2(108, 458, 426, 57), start_new).grab_focus()
	var resume := UI.button(page, "つづきから", Rect2(108, 530, 202, 51), _resume)
	resume.disabled = not FileAccess.file_exists(save_path)
	UI.button(page, "遊び方", Rect2(328, 530, 206, 51), _help)
	UI.label(page, "移動 WASD / 矢印 / 左スティック　　決定 Enter / A　　F11 全画面",
		Rect2(94, 671, 1140, 32), 18, UI.CREAM)


func start_new() -> void:
	Farm.reset()
	mode = "playing"
	busy = false
	money_shown = Farm.money
	refresh()
	_message("まずは目の前の畑へ。クワ → 種 → 水やりの順に育てよう。", 9)


func _resume() -> void:
	if Farm.load_game(save_path):
		mode = "playing" if Farm.phase == "playing" else "result"
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
	UI.panel(page, Rect2(30, 20, 1220, 88))
	UI.label(page, "こもれび農園", Rect2(53, 31, 237, 40), 29)
	UI.label(page, "季節を育てる二十日間", Rect2(56, 72, 240, 22), 15, UI.MUTED)
	clock_label = UI.label(page, "", Rect2(316, 39, 350, 49), 25)
	money_label = UI.label(page, "", Rect2(675, 39, 206, 47), 30)
	stamina_label = UI.label(page, "", Rect2(935, 29, 240, 32), 19)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.add_theme_stylebox_override("background", UI.box(Color("e1e7ce"), 7))
	stamina_bar.add_theme_stylebox_override("fill", UI.box(Color("94ac64"), 7))
	page.add_child(stamina_bar)
	stamina_bar.position = Vector2(937, 72)
	stamina_bar.size = Vector2(278, 12)
	_field_labels()
	_journal()
	_toolbar()
	notice = UI.label(page, "", Rect2(40, 570, 916, 31), 17, UI.CREAM)
	_update_hud()


func _field_labels() -> void:
	_tag("おうち・ベッド", Vector2(95, 282), 173)
	_tag("井戸", Vector2(275, 259), 66)
	_tag("町の商店", Vector2(817, 281), 116)
	_tag("出荷箱", Vector2(824, 432), 98)
	_tag("あなたの畑", Vector2(514, 202), 149)


func _tag(text: String, at: Vector2, width: float) -> void:
	var panel: Panel = UI.panel(page, Rect2(at, Vector2(width, 30)), Color("fff8e6d9"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.label(panel, text, Rect2(8, 1, width - 16, 28), 17)


func _journal() -> void:
	UI.panel(page, Rect2(980, 128, 270, 431))
	UI.label(page, "季節の手帳", Rect2(1003, 148, 220, 43), 28)
	UI.label(page, "今季の目標", Rect2(1005, 203, 200, 30), 17, UI.MUTED)
	objective_label = UI.label(page, "", Rect2(1005, 242, 225, 88), 23)
	journal_label = UI.label(page, "", Rect2(1005, 342, 223, 88), 18, UI.MUTED)
	UI.button(page, "手帳・持ちもの", Rect2(1003, 448, 222, 44), open_menu)
	UI.button(page, "遊び方", Rect2(1003, 505, 222, 35), _help)


func _toolbar() -> void:
	UI.panel(page, Rect2(30, 608, 1220, 92))
	for index: int in 4:
		var at := Vector2(46 + index * 121, 620)
		var button: Button = UI.button(page, "%d  %s" % [index + 1, Farm.TOOLS[index]],
			Rect2(at, Vector2(111, 65)), _select_tool.bind(index))
		button.add_theme_font_size_override("font_size", 16)
		button.icon = load("res://assets/ui/%s.svg" % TOOL_ICONS[index])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		tool_buttons.append(button)
	seed_button = UI.button(page, "", Rect2(542, 621, 177, 63), _cycle_crop)
	seed_button.add_theme_font_size_override("font_size", 17)
	UI.button(page, "使う  Space / X", Rect2(735, 621, 211, 63), use_tool)
	UI.button(page, "調べる  F / A", Rect2(962, 621, 267, 63), interact)
	context_label = UI.label(page, "", Rect2(987, 566, 258, 32), 16, UI.CREAM)


func _update_hud() -> void:
	if mode != "playing" or not is_instance_valid(clock_label):
		return
	clock_label.text = "%s %d日　%s" % [Farm.season_name(), (Farm.day - 1) % 10 + 1,
		Farm.clock_text()]
	money_label.text = "%d G" % roundi(money_shown)
	stamina_label.text = "体力　%d / 100" % Farm.stamina
	stamina_bar.value = Farm.stamina
	objective_label.text = "所持金 %d / %d G\nまたは 全4種を出荷" % [Farm.money, Farm.TARGET_MONEY]
	var shipped_types: int = 0
	var pending: int = 0
	for id: String in Farm.CROPS:
		if int(Farm.shipped[id]) > 0:
			shipped_types += 1
		pending += int(Farm.shipping[id]) * int(Farm.CROPS[id].sell)
	journal_label.text = "出荷した作物　%d / 4種\n明朝の売上　%d G\n季節の終わりまで　%d日" % [
		shipped_types, pending, 11 - ((Farm.day - 1) % 10 + 1)]
	seed_button.text = "%sの種 ×%d\nR / Y で切替" % [
		Farm.CROPS[Farm.selected_crop].name, Farm.seeds[Farm.selected_crop]]
	for index: int in tool_buttons.size():
		tool_buttons[index].modulate = Color("ffdb8c") if index == Farm.selected_tool else Color.WHITE
	var near: String = _nearby()
	context_label.text = {"bed": "F / A　ベッドで休む", "shop": "F / A　町の商店へ",
		"shipping": "F / A　作物を出荷", "well": "F / A　井戸を調べる"}.get(near,
		"Q・E / LB・RB　道具切替")


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
			notice.text = "移動 WASD / 矢印　　向いているマスに道具を使います　　Tab / Start 手帳"
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
			open_shop()
		"well":
			_message("井戸の清水。ジョウロの水はいつでも満タンです。")
			world.effect("water", world.WELL)
			sound.play("water")
		_:
			_message("家のベッド・出荷箱・町の商店・井戸の近くで調べよう。")


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
		UI.picture(modal, "res://assets/crops/%s_ripe.svg" % id, Rect2(304, y, 52, 52))
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
		UI.picture(modal, "res://assets/crops/%s_ripe.svg" % id, Rect2(307, y, 66, 66))
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


func open_shop() -> void:
	_open_modal("町の種屋 ― リラの店")
	UI.label(modal, "育つ季節を確かめて選んでね。　所持金 %d G" % Farm.money,
		Rect2(300, 195, 680, 37), 19, UI.MUTED)
	for index: int in 4:
		var id: String = Farm.CROPS.keys()[index]
		var data: Dictionary = Farm.CROPS[id]
		var y: int = 240 + index * 62
		UI.picture(modal, "res://assets/crops/%s_ripe.svg" % id, Rect2(301, y, 50, 50))
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
	_open_modal("暮らしのしおり")
	var text: String = "①  移動：WASD / 矢印 / 左スティック・十字キー\n"
	text += "②  道具：1〜4 / Q・E / LB・RB　種の切替：R / Y\n"
	text += "③  向いたマスへ：Space / X　調べる：F・Enter / A\n"
	text += "\n"
	text += "畑は クワ → 種 → 水。毎日水をあげた日だけ成長します。\n"
	text += "収穫したら出荷箱へ。家で眠ると翌朝、代金が届きます。\n"
	text += "深夜2時・体力0で翌朝へ。無理をすると所持金の10%を失います。\n"
	text += "Tab / Start で手帳とセーブ。お弁当で体力回復。"
	if not extra.is_empty():
		text = extra
	UI.label(modal, text, Rect2(300, 208, 696, 327), 20)


func _result() -> void:
	UI.picture(page, "res://assets/backgrounds/title.svg", Rect2(604, 77, 650, 575))
	UI.panel(page, Rect2(102, 72, 654, 565), Color("fff8edf5"))
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
	if mode == "title":
		sound.track("title")
	elif mode == "result":
		sound.track("result")
	elif Farm.money >= 700:
		sound.track("festival")
	else:
		sound.track(Farm.season())
