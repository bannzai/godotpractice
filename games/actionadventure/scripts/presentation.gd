class_name AdventurePresentation
extends Control
## 進行の正は state に置き、ここでは表示と入力の受け渡しだけを担う。

const INK := Color("20251b")
const PANEL := Color("4d573d")
const STONE := Color("6f7753")
const STONE_LIGHT := Color("a2a76b")
const PAPER := Color("f0dfa6")
const PARCHMENT := Color("d8bd78")
const MUTED := Color("c3c88c")
const GOLD := Color("e1bd62")
const TEAL := Color("8cad62")
const DANGER := Color("b9574f")

var _host: Node
var _state: Node
var _screen: Control
var _mode: String = ""
var _hp_label: Label
var _coins_label: Label
var _keys_label: Label
var _room_label: Label
var _objective_label: Label
var _notice_label: Label
var _tool_label: Label
var _dialogue_label: Label
var _tool_buttons: Dictionary = {}
var _tool_preview_label: Label
var _shown_coins: int = -1
var _coin_tween: Tween
var _fade_tween: Tween


func setup(host: Node, state: Node) -> void:
	_host = host
	_state = state
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	refresh()


func refresh() -> void:
	if not is_instance_valid(_state):
		return
	var next_mode: String = _state.mode
	if next_mode != _mode:
		_mode = next_mode
		_rebuild()
	if _mode in ["play", "menu", "dialogue"]:
		_refresh_hud()
	elif _mode == "title" and is_instance_valid(_notice_label):
		_notice_label.text = _host.notice
	if _mode == "menu":
		_refresh_tools()
	if _mode == "dialogue" and is_instance_valid(_dialogue_label):
		_dialogue_label.text = _host.dialogue_text


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = load("res://assets/fonts/Stick-Regular.ttf") as Font
	result.default_font_size = 20
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("8c8c69"))
	result.set_stylebox("normal", "Button", _style(PANEL, STONE_LIGHT, 3, 2))
	result.set_stylebox("hover", "Button", _style(STONE, GOLD, 4, 2))
	result.set_stylebox("pressed", "Button", _style(GOLD, INK, 4, 2))
	result.set_stylebox("disabled", "Button", _style(Color("414437"), Color("67694f"), 2, 2))
	result.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, PAPER, 3, 1))
	return result


func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.07, 0.08, 0.05, 0.75)
	style.shadow_size = 5
	style.shadow_offset = Vector2(4, 5)
	return style


func _rebuild() -> void:
	var initial_screen: bool = not is_instance_valid(_screen)
	if _coin_tween:
		_coin_tween.kill()
	if _fade_tween:
		_fade_tween.kill()
	if is_instance_valid(_screen):
		remove_child(_screen)
		_screen.queue_free()
	_tool_buttons.clear()
	_tool_preview_label = null
	_shown_coins = -1
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	match _mode:
		"title":
			_title()
		"play", "menu", "dialogue":
			_hud()
			if _mode == "menu":
				_menu()
			elif _mode == "dialogue":
				_dialogue()
		"map":
			_map()
		"ending":
			_result(true)
		"gameover":
			_result(false)
	if initial_screen:
		return
	_screen.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_screen, "modulate:a", 1.0, 0.2)


func _panel(rect: Rect2, fill: Color = PANEL, border: Color = STONE_LIGHT) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, 3, 2))
	_screen.add_child(panel)
	return panel


func _label(
	text: String, rect: Rect2, font_size: int = 20, color: Color = PAPER
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(label)
	return label


func _texture(path: String, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = load(path) as Texture2D
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(picture)
	picture.position = rect.position
	picture.size = rect.size
	return picture


func _button(text: String, rect: Rect2, action: Callable, focus: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pivot_offset = rect.size * 0.5
	button.pressed.connect(action)
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	_screen.add_child(button)
	if focus:
		button.grab_focus.call_deferred()
	return button


func _hover(button: Button, entered: bool) -> void:
	# 入力のたびに進む演出。前の Tween を破棄して重複を防ぐ。
	if button.has_meta("hover_tween"):
		var previous: Tween = button.get_meta("hover_tween")
		previous.kill()
	var animation: Tween = button.create_tween()
	button.set_meta("hover_tween", animation)
	var target: Vector2 = Vector2.ONE * (1.025 if entered else 1.0)
	animation.tween_property(button, "scale", target, 0.12)


func _call(method: String) -> void:
	_host.call(method)


func _background() -> void:
	var picture: TextureRect = _texture(
		"res://assets/backgrounds/title.png", Rect2(0, 0, 1280, 720)
	)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _title() -> void:
	_background()
	_texture("res://assets/backgrounds/hero-keyart.png", Rect2(785, 246, 430, 430))
	_panel(Rect2(50, 62, 562, 572), Color(0.22, 0.25, 0.18, 0.96), STONE_LIGHT)
	_label("潮風に埋もれた古い石版", Rect2(88, 92, 470, 36), 20, MUTED)
	_label("灯守の島", Rect2(84, 132, 486, 96), 68, PAPER)
	_label("失われた灯を、もう一度。", Rect2(90, 230, 450, 40), 24, GOLD)
	var intro: Label = _label(
		"村の長老が刻む短い教えから旅は始まる。\n羊皮紙の地図を手に、東の遺跡へ。",
		Rect2(90, 292, 450, 76), 21, PAPER
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label = _label(_host.notice, Rect2(90, 366, 450, 42), 16, GOLD)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("長老の教えから冒険を始める", Rect2(90, 424, 472, 62), _call.bind("start_new"), true)
	_button("刻まれた旅を続ける", Rect2(90, 504, 308, 54), _call.bind("continue_game"))
	_button("石版を閉じる", Rect2(414, 504, 148, 54), _call.bind("shutdown"))
	_label("金の灯を追い、島の夜を明かす。", Rect2(90, 582, 450, 30), 18, MUTED)
	_label("4〜8色で刻まれた、潮と石の冒険。", Rect2(790, 666, 430, 32), 21, PAPER)


func _hud() -> void:
	_panel(Rect2(26, 14, 350, 86), Color("394431"), STONE_LIGHT)
	_texture("res://assets/props/heart.png", Rect2(44, 28, 42, 42))
	_hp_label = _label("", Rect2(91, 26, 140, 42), 25, PAPER)
	_texture("res://assets/props/coin.png", Rect2(226, 30, 34, 34))
	_coins_label = _label("", Rect2(264, 27, 70, 38), 23, GOLD)
	_texture("res://assets/props/key.png", Rect2(294, 30, 34, 34))
	_keys_label = _label("", Rect2(330, 27, 42, 38), 23, PAPER)
	_panel(Rect2(388, 14, 866, 86), Color("394431"), STONE_LIGHT)
	_room_label = _label("", Rect2(420, 22, 344, 34), 24, PAPER)
	_objective_label = _label("", Rect2(758, 26, 464, 50), 17, GOLD)
	_tool_label = _label("", Rect2(420, 61, 324, 26), 15, MUTED)
	_notice_label = _label("", Rect2(260, 105, 760, 30), 20, GOLD)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_shadow_color", INK)
	_notice_label.add_theme_constant_override("shadow_offset_x", 2)
	_notice_label.add_theme_constant_override("shadow_offset_y", 2)


func _refresh_hud() -> void:
	_hp_label.text = "◆ ".repeat(_state.hp) + "◇ ".repeat(_state.max_hp - _state.hp)
	_keys_label.text = str(_state.keys)
	_room_label.text = _host.room_name()
	_objective_label.text = "次の灯　" + _host.objective()
	_notice_label.text = _host.notice
	var selected: String = "なし"
	if _state.tool == "boomerang":
		selected = "ブーメラン"
	elif _state.tool == "bomb":
		selected = "爆弾"
	_tool_label.text = "刻印　%s　爆弾 %d　薬 %d　地図 M" % [selected, _state.bombs, _state.potions]
	var coins: int = _state.coins
	if coins != _shown_coins:
		if _coin_tween:
			_coin_tween.kill()
		if _shown_coins < 0:
			_coins_label.text = str(coins)
		else:
			_coin_tween = create_tween()
			_coin_tween.tween_method(_set_coin_text, float(_shown_coins), float(coins), 0.3)
		_shown_coins = coins


func _set_coin_text(value: float) -> void:
	if is_instance_valid(_coins_label):
		_coins_label.text = str(roundi(value))


func _shade() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.06, 0.04, 0.78)
	shade.size = Vector2(1280, 720)
	_screen.add_child(shade)


func _menu() -> void:
	_shade()
	_panel(Rect2(238, 120, 804, 526), Color("343b2d"), STONE_LIGHT)
	_label("道具を刻む石版", Rect2(286, 148, 650, 58), 38, PAPER)
	_label("選ぶと起きることを確かめてから装備する。", Rect2(288, 207, 650, 30), 18, MUTED)
	_texture("res://assets/props/boomerang.png", Rect2(286, 264, 54, 54))
	_texture("res://assets/props/bomb.png", Rect2(286, 334, 54, 54))
	_tool_buttons["boomerang"] = _button(
		"", Rect2(360, 260, 624, 58), _host.select_tool.bind("boomerang")
	)
	_tool_buttons["bomb"] = _button(
		"", Rect2(360, 330, 624, 58), _host.select_tool.bind("bomb")
	)
	_tool_buttons["potion"] = _button(
		"", Rect2(360, 400, 624, 58), _host.select_tool.bind("potion")
	)
	_tool_preview_label = _label("", Rect2(288, 468, 696, 44), 17, GOLD)
	_tool_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("冒険へ戻る", Rect2(288, 522, 696, 46), _call.bind("close_menu"), true)
	_button("旅を石版に記録", Rect2(288, 584, 334, 42), _call.bind("save_progress"))
	_button("タイトルへ", Rect2(650, 584, 334, 42), _call.bind("to_title"))
	for kind: String in _tool_buttons:
		var button: Button = _tool_buttons[kind]
		button.focus_entered.connect(_show_tool_preview.bind(kind))
		button.mouse_entered.connect(_show_tool_preview.bind(kind))


func _refresh_tools() -> void:
	var boomerang: Button = _tool_buttons["boomerang"]
	boomerang.disabled = not _state.boomerang_owned
	var equipped: String = "  装備中" if _state.tool == "boomerang" else ""
	boomerang.text = "風の輪　遠い灯を押す" + equipped \
		if _state.boomerang_owned else "× 風の輪　遺跡の宝庫で見つける"
	var bomb: Button = _tool_buttons["bomb"]
	bomb.disabled = not _state.bombs_owned
	equipped = "  装備中" if _state.tool == "bomb" else ""
	bomb.text = "爆弾 ×%d　ひび割れ壁を壊す%s" % [_state.bombs, equipped] \
		if _state.bombs_owned else "× 爆弾　崩れた回廊で袋を見つける"
	var potion: Button = _tool_buttons["potion"]
	potion.text = (
		"回復薬 ×%d　体力を最大まで戻す" % _state.potions
		if _state.potions > 0 else "× 回復薬　道具屋で手に入れる"
	)
	potion.disabled = _state.potions <= 0 or _state.hp >= _state.max_hp


func _show_tool_preview(kind: String) -> void:
	if not is_instance_valid(_tool_preview_label):
		return
	var previews: Dictionary = {
		"boomerang": "選択後: K / Y で投げ、離れたスイッチを点灯する。",
		"bomb": "選択後: K / Y で足元へ置き、約1秒後に壁と敵へ爆発。",
		"potion": "選択後: その場で1個を使い、失ったハートをすべて回復。",
	}
	_tool_preview_label.text = previews[kind]


func _dialogue() -> void:
	_panel(Rect2(132, 404, 1016, 264), Color("353d2f"), STONE_LIGHT)
	_label(_host.dialogue_title, Rect2(174, 426, 900, 36), 26, GOLD)
	_dialogue_label = _label(_host.dialogue_text, Rect2(174, 474, 916, 80), 21, PAPER)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _host.shop_open:
		_button("爆弾3個 / 10枚", Rect2(174, 590, 286, 48), _host.buy_item.bind("bomb"), true)
		_button("回復薬 / 15枚", Rect2(482, 590, 286, 48), _host.buy_item.bind("potion"))
		_button("石版を閉じる", Rect2(790, 590, 316, 48), _call.bind("close_dialogue"))
	elif _host._tutorial_active():
		_button("次の刻みを読む", Rect2(174, 590, 590, 48), _call.bind("_next_tutorial"), true)
		_button("案内を省く", Rect2(790, 590, 316, 48), _call.bind("_skip_tutorial"))
	else:
		_button("石版を閉じる", Rect2(790, 590, 316, 48), _call.bind("close_dialogue"), true)


func _map() -> void:
	_background()
	_shade()
	_panel(Rect2(96, 66, 1088, 588), Color("6f5837"), INK)
	var parchment := ColorRect.new()
	parchment.position = Vector2(124, 92)
	parchment.size = Vector2(1032, 534)
	parchment.color = PARCHMENT
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(parchment)
	_label("羊皮紙の地図", Rect2(154, 112, 420, 52), 38, INK)
	_label("金の灯が現在地　・　点線の先が次の目的", Rect2(602, 124, 496, 32), 18, Color("5f4b2c"))
	_map_route()
	_label("現在地　%s" % _host.room_name(), Rect2(154, 544, 540, 34), 22, INK)
	var goal: Label = _label(
		"次の灯　%s" % _host.objective(), Rect2(154, 578, 700, 34), 19, Color("6b3c24")
	)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("地図をたたむ", Rect2(896, 558, 226, 48), _call.bind("_close_map"), true)


func _map_route() -> void:
	var field_names: Array[String] = ["村", "商庭", "小径", "湿地", "夕森", "門前"]
	var dungeon_names: Array[String] = ["風", "遠灯", "崩廊", "重間", "星間", "石梟"]
	for row: int in range(2):
		var names: Array[String] = field_names if row == 0 else dungeon_names
		for index: int in range(6):
			var room_index: int = index + row * 6
			var center := Vector2(204 + index * 166, 256 + row * 178)
			if index < 5:
				for dot: int in range(6):
					var trail := ColorRect.new()
					trail.position = center + Vector2(58 + dot * 13, -2)
					trail.size = Vector2(6, 6)
					trail.color = Color("725b35")
					trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_screen.add_child(trail)
			var marker := Panel.new()
			marker.position = center - Vector2(38, 30)
			marker.size = Vector2(76, 60)
			var current: bool = room_index == _state.room
			var visited: bool = room_index <= maxi(_state.checkpoint, _state.room)
			var fill: Color = (
				GOLD if current else (Color("71804b") if visited else Color("79684a"))
			)
			marker.add_theme_stylebox_override("panel", _style(fill, INK, 3, 1))
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_screen.add_child(marker)
			var text: Label = _label(
				names[index], Rect2(center.x - 35, center.y - 17, 70, 34), 18, INK
			)
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("潮風の島　→", Rect2(154, 184, 260, 30), 21, Color("5f4b2c"))
	_label("灯の遺跡　→", Rect2(154, 360, 260, 30), 21, Color("5f4b2c"))


func _result(cleared: bool) -> void:
	_background()
	_shade()
	_panel(Rect2(286, 114, 708, 500), Color("353d2f"), STONE_LIGHT)
	var eyebrow: String = "冒険の記録" if cleared else "まだ、灯は消えない。"
	var title: String = "島に、夜明けが。" if cleared else "ひと休みしよう"
	var body: String = (
		"灯台の光が、遠い海へと伸びていく。\n島の人々に、穏やかな朝が戻った。\n小さな灯守の旅は、ここに刻まれた。"
		if cleared else
		"波の音に耳をすませ、もう一度。\n集めた道具と開いた道は、そのまま。\n最後の入口から冒険をやり直せる。"
	)
	var caption: Label = _label(eyebrow, Rect2(330, 144, 620, 40), 20, TEAL)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var heading: Label = _label(title, Rect2(330, 204, 620, 80), 43, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var prose: Label = _label(body, Rect2(346, 316, 588, 120), 21, PAPER)
	prose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var method: String = "start_new" if cleared else "retry_game"
	var button_text: String = "もう一度、冒険する" if cleared else "もう一度、立ち上がる"
	_button(button_text, Rect2(348, 462, 584, 58), _call.bind(method), true)
	_button("タイトルへ", Rect2(348, 540, 584, 48), _call.bind("to_title"))
