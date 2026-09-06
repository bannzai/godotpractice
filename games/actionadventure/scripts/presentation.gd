class_name AdventurePresentation
extends Control
## 進行の正は state に置き、ここでは表示と入力の受け渡しだけを担う。

const INK := Color("0a2029")
const PANEL := Color("112e37")
const PAPER := Color("f7ecd2")
const MUTED := Color("a0c5bf")
const GOLD := Color("f4cb77")
const TEAL := Color("77d1bf")

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
	result.default_font = load("res://assets/fonts/font.ttf") as Font
	result.default_font_size = 19
	result.set_color("font_color", "Label", PAPER)
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_pressed_color", "Button", INK)
	result.set_color("font_disabled_color", "Button", Color("68857f"))
	result.set_stylebox("normal", "Button", _style(PANEL, Color("52716b"), 2, 12))
	result.set_stylebox("hover", "Button", _style(Color("23505a"), GOLD, 2, 12))
	result.set_stylebox("pressed", "Button", _style(GOLD, GOLD, 2, 12))
	result.set_stylebox("disabled", "Button", _style(Color("102b32"), PANEL, 1, 12))
	result.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, TEAL, 3, 12))
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
		"ending":
			_result(true)
		"gameover":
			_result(false)
	if initial_screen:
		return
	_screen.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_screen, "modulate:a", 1.0, 0.2)


func _panel(rect: Rect2, fill: Color = PANEL, border: Color = Color("52716b")) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, 1, 14))
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
		"res://assets/backgrounds/title.svg", Rect2(0, 0, 1280, 720)
	)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _title() -> void:
	_background()
	_texture("res://assets/backgrounds/hero-keyart.svg", Rect2(812, 302, 360, 360))
	_panel(Rect2(36, 40, 548, 640), Color(0.03, 0.12, 0.16, 0.94))
	_label("風と海、そして忘れられた灯。", Rect2(76, 72, 470, 36), 19, TEAL)
	_label("灯守の島", Rect2(70, 110, 486, 96), 68, PAPER)
	_label("小さな勇気で、島に夜明けを。", Rect2(78, 220, 450, 40), 22, GOLD)
	var intro: Label = _label(
		"剣と道具を手に、海辺の遺跡へ。\n眠る灯台に、もう一度光を届けよう。",
		Rect2(78, 284, 450, 76), 20, MUTED
	)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label = _label(_host.notice, Rect2(78, 352, 450, 36), 14, GOLD)
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button("冒険をはじめる", Rect2(78, 390, 434, 58), _call.bind("start_new"), true)
	_button("つづきから", Rect2(78, 460, 278, 52), _call.bind("continue_game"))
	_button("終了", Rect2(368, 460, 144, 52), _call.bind("shutdown"))
	_label("移動  WASD / 矢印　　剣  J / Space", Rect2(78, 550, 454, 28), 17, MUTED)
	_label("道具  K　 話す・調べる  E　 持ち物  Tab", Rect2(78, 586, 454, 28), 17, MUTED)
	_label("ゲームパッド対応　・　持ち物から冒険を記録", Rect2(78, 630, 454, 26), 15, TEAL)
	_label("潮の記憶を、灯す旅。", Rect2(842, 650, 390, 38), 23, PAPER)


func _hud() -> void:
	_panel(Rect2(32, 16, 1216, 82), INK)
	_texture("res://assets/props/heart.svg", Rect2(52, 36, 34, 34))
	_hp_label = _label("", Rect2(94, 29, 212, 42), 26, GOLD)
	_texture("res://assets/props/coin.svg", Rect2(330, 36, 32, 32))
	_coins_label = _label("", Rect2(370, 31, 84, 40), 24)
	_texture("res://assets/props/key.svg", Rect2(458, 36, 32, 32))
	_keys_label = _label("", Rect2(496, 31, 76, 40), 24)
	_room_label = _label("", Rect2(612, 24, 444, 32), 22, PAPER)
	_objective_label = _label("", Rect2(612, 61, 606, 24), 15, TEAL)
	_panel(Rect2(32, 660, 1216, 46), INK)
	_tool_label = _label("", Rect2(50, 667, 440, 26), 17, GOLD)
	_label("J 剣　 K 道具　 E 調べる　 Tab 持ち物", Rect2(798, 667, 434, 26), 16, MUTED)
	_notice_label = _label("", Rect2(292, 100, 696, 28), 19, GOLD)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_shadow_color", INK)
	_notice_label.add_theme_constant_override("shadow_offset_x", 2)
	_notice_label.add_theme_constant_override("shadow_offset_y", 2)


func _refresh_hud() -> void:
	_hp_label.text = "♥ ".repeat(_state.hp) + "· ".repeat(_state.max_hp - _state.hp)
	_keys_label.text = str(_state.keys)
	_room_label.text = _host.room_name()
	_objective_label.text = "目的  " + _host.objective()
	_notice_label.text = _host.notice
	var selected: String = "なし"
	if _state.tool == "boomerang":
		selected = "ブーメラン"
	elif _state.tool == "bomb":
		selected = "爆弾"
	_tool_label.text = "道具  %s　 爆弾 %d　 薬 %d" % [selected, _state.bombs, _state.potions]
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
	shade.color = Color(0.02, 0.08, 0.12, 0.75)
	shade.size = Vector2(1280, 720)
	_screen.add_child(shade)


func _menu() -> void:
	_shade()
	_panel(Rect2(290, 118, 700, 520), INK, GOLD)
	_label("旅の道具", Rect2(334, 146, 570, 62), 38, PAPER)
	_label("道具を選んで、島の仕掛けを解き明かそう。", Rect2(336, 214, 590, 30), 18, MUTED)
	_texture("res://assets/props/boomerang.svg", Rect2(338, 273, 50, 50))
	_texture("res://assets/props/bomb.svg", Rect2(338, 344, 50, 50))
	_tool_buttons["boomerang"] = _button(
		"", Rect2(408, 270, 532, 58), _host.select_tool.bind("boomerang")
	)
	_tool_buttons["bomb"] = _button(
		"", Rect2(408, 342, 532, 58), _host.select_tool.bind("bomb")
	)
	_tool_buttons["potion"] = _button(
		"", Rect2(408, 414, 532, 58), _host.select_tool.bind("potion")
	)
	_button("冒険へ戻る", Rect2(336, 510, 604, 50), _call.bind("close_menu"), true)
	_button("記録する", Rect2(336, 574, 290, 44), _call.bind("save_progress"))
	_button("タイトルへ", Rect2(650, 574, 290, 44), _call.bind("to_title"))


func _refresh_tools() -> void:
	var boomerang: Button = _tool_buttons["boomerang"]
	boomerang.disabled = not _state.boomerang_owned
	var equipped: String = "  装備中" if _state.tool == "boomerang" else ""
	boomerang.text = "ブーメラン" + equipped if _state.boomerang_owned else "ブーメラン  未発見"
	var bomb: Button = _tool_buttons["bomb"]
	bomb.disabled = not _state.bombs_owned
	equipped = "  装備中" if _state.tool == "bomb" else ""
	bomb.text = "爆弾  ×%d%s" % [_state.bombs, equipped] if _state.bombs_owned else "爆弾  未発見"
	var potion: Button = _tool_buttons["potion"]
	potion.text = "回復薬を使う  ×%d" % _state.potions
	potion.disabled = _state.potions <= 0 or _state.hp >= _state.max_hp


func _dialogue() -> void:
	_panel(Rect2(160, 428, 960, 214), Color(0.03, 0.12, 0.16, 0.98), GOLD)
	_label(_host.dialogue_title, Rect2(192, 448, 820, 34), 25, GOLD)
	_dialogue_label = _label(_host.dialogue_text, Rect2(192, 494, 876, 70), 20, PAPER)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _host.shop_open:
		_button("爆弾 3 個  /  10 枚", Rect2(192, 580, 280, 44), _host.buy_item.bind("bomb"), true)
		_button("回復薬  /  15 枚", Rect2(488, 580, 280, 44), _host.buy_item.bind("potion"))
		_button("会話を終える", Rect2(788, 580, 300, 44), _call.bind("close_dialogue"))
	else:
		_button("わかった", Rect2(788, 580, 300, 44), _call.bind("close_dialogue"), true)


func _result(cleared: bool) -> void:
	_background()
	_shade()
	_panel(Rect2(286, 114, 708, 500), Color(0.03, 0.12, 0.16, 0.96), GOLD)
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
