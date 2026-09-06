extends Control
## 画面表示は状態を参照し、操作をゲーム本体へ通知する。

signal requested(action: String, value: String)

const GOLD := Color("f5c879")
const INK := Color("102b36")

var model: Node
var screen: Control
var overlay: Control
var play_hud: Control
var health: ProgressBar
var hunger_bar: ProgressBar
var clock_label: Label
var quest: Label
var target: Label
var progress: ProgressBar
var toast: Label
var slots: Array[PanelContainer] = []
var slot_labels: Array[Label] = []
var slot_icons: Array[TextureRect] = []
var flash: ColorRect
var _last_screen: String = ""
var _toast_tween: Tween
var _health_tween: Tween
var _last_hp: float = -1.0
var _selected_slot: int = -1
var _slot_items: Array[String] = []
var _selected_style: StyleBoxFlat
var _normal_style: StyleBoxFlat
var _icon_cache: Dictionary = {}


func configure(state: Node) -> void:
	model = state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://assets/ui/theme.tres")
	play_hud = Control.new()
	play_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play_hud)
	_selected_style = _style(GOLD)
	_selected_style.border_color = GOLD
	_normal_style = _style(INK)
	_slot_items.resize(9)
	_build_hud()
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.9, 0.3, 0.2, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.hide()
	toast = _label(self, "", Vector2(320, 543), 20, Vector2(640, 40))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", GOLD)


func _build_hud() -> void:
	var vitals: PanelContainer = _panel(play_hud, Vector2(28, 26), Vector2(300, 100))
	_label(vitals, "生命", Vector2(16, 12), 17)
	health = _bar(vitals, Vector2(80, 16), Vector2(200, 18), Color("ef9376"))
	_label(vitals, "空腹", Vector2(16, 52), 17)
	hunger_bar = _bar(vitals, Vector2(80, 58), Vector2(200, 14), GOLD)
	var journal: PanelContainer = _panel(play_hud, Vector2(925, 26), Vector2(327, 156))
	clock_label = _label(journal, "", Vector2(20, 12), 22)
	quest = _label(journal, "", Vector2(20, 52), 17, Vector2(295, 95))
	_label(play_hud, "+", Vector2(627, 338), 30)
	target = _label(play_hud, "", Vector2(390, 397), 18, Vector2(500, 32))
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = _bar(play_hud, Vector2(560, 386), Vector2(160, 5), GOLD)
	progress.max_value = 1.0
	for index: int in range(9):
		var cell: PanelContainer = _panel(play_hud,
			Vector2(302 + index * 76, 594), Vector2(70, 79))
		slots.append(cell)
		var icon := TextureRect.new()
		icon.position = Vector2(17, 6)
		icon.size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.get_child(0).add_child(icon)
		slot_icons.append(icon)
		slot_labels.append(_label(cell, "", Vector2(4, 44), 13, Vector2(66, 32)))
		slot_labels[-1].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(play_hud, "移動 WASD / 左スティック   採集・攻撃 左クリック / RT   設置 右クリック / LT",
		Vector2(295, 678), 13)
	_label(play_hud, "E / X クラフト    F / Y 食べる    Tab / 十字 選択    Esc / Start 休止",
		Vector2(370, 697), 12)


func refresh() -> void:
	var phase: String = model.phase
	play_hud.visible = phase == "play"
	if phase != _last_screen:
		_last_screen = phase
		_show_screen(phase)
	if phase != "play":
		return
	if not is_equal_approx(_last_hp, model.hp):
		_last_hp = model.hp
		if _health_tween:
			_health_tween.kill()
		_health_tween = create_tween()
		_health_tween.tween_property(health, "value", model.hp, 0.18)
	hunger_bar.value = model.hunger
	clock_label.text = "%d 日目  /  %s" % [model.day, "夜の時間" if model.is_night() else "陽の時間"]
	quest.text = "%s 石のつるはしを作る\n%s 屋根と壁のある家を建てる\n%s 3 日間を生き延びる" % [
		_mark(model.tool_level >= 2), _mark(model.house_built), _mark(model.survived_three_days())]
	for index: int in range(9):
		var item: String = model.hotbar[index]
		slot_labels[index].text = "%s\n%d" % [model.item_name(item), model.inventory.get(item, 0)]
		if _slot_items[index] != item:
			_slot_items[index] = item
			var icon_path: String = "res://assets/icons/%s.svg" % item
			if not _icon_cache.has(item) and ResourceLoader.exists(icon_path):
				_icon_cache[item] = load(icon_path)
			slot_icons[index].texture = _icon_cache.get(item)
		if _selected_slot != model.selected:
			slots[index].add_theme_stylebox_override("panel",
				_selected_style if index == model.selected else _normal_style)
			slot_labels[index].add_theme_color_override("font_color",
				INK if index == model.selected else Color("f5eee0"))
	_selected_slot = model.selected


func _show_screen(phase: String) -> void:
	_clear(screen)
	screen.visible = phase != "play"
	if phase == "play":
		close_overlay()
		return
	var tint := ColorRect.new()
	tint.color = Color(0.035, 0.11, 0.15, 0.72)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(tint)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/title.svg")
	art.position = Vector2(505, 65)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(740, 555)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(art)
	art.set_deferred("size", Vector2(740, 555))
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/art/logo.svg")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.position = Vector2(354, 143)
	emblem.size = Vector2(86, 78)
	emblem.visible = phase == "title"
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(emblem)
	_label(screen, "小さな島で、明日の灯りをつくろう。", Vector2(76, 110), 18)
	_label(screen, "灯守の島" if phase == "title" else
		("三度目の朝" if phase == "clear" else "灯りの消えた夜"), Vector2(70, 150), 58)
	_label(screen, "採る。つくる。夜を越える。" if phase == "title" else
		("あなたの家に、新しい朝が訪れました。" if phase == "clear" else
		"持ち物を失っても、島と家は残っています。"), Vector2(77, 245), 19)
	var actions := VBoxContainer.new()
	actions.position = Vector2(78, 320)
	actions.size = Vector2(344, 240)
	actions.add_theme_constant_override("separation", 12)
	screen.add_child(actions)
	if phase == "title":
		_button(actions, "新しい島へ", "new")
		_button(actions, "保存した島から再開", "load")
	elif phase == "failed":
		_button(actions, "島で目を覚ます", "respawn")
		_button(actions, "タイトルへ", "title")
	else:
		_button(actions, "タイトルへ", "title")
	_button(actions, "遊び方", "help")
	_label(screen, "1 日は 3 分。石の道具と家を作り、3 日間を生き延びよう。",
		Vector2(78, 617), 17)
	_label(screen, "キーボード・マウス / ゲームパッド対応   •   F11 全画面",
		Vector2(78, 648), 14)
	actions.get_child(0).grab_focus()
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.35)


func show_menu(kind: String) -> void:
	_set_buttons_enabled(screen, false)
	_clear(overlay)
	overlay.show()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.1, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var box: PanelContainer = _panel(overlay, Vector2(160, 70), Vector2(960, 574))
	_label(box, {"pause": "ひと休み", "craft": "ものづくり", "help": "島での暮らし方"}[kind],
		Vector2(28, 20), 34)
	if kind == "craft":
		_build_crafting(box)
	elif kind == "help":
		_label(box, "木を長押しで採る → 板 → 作業台 → 木のつるはし → 石のつるはし\n\n"
			+ "家は、内側 1×1・高さ 2 の空間を床・四方の壁・屋根で囲みます。\n"
			+ "入口は 1 か所。両脇の柱と上のまぐさを付けると家になります。\n"
			+ "たいまつの近くには敵が湧きません。夜は家と灯りで身を守ろう。\n\n"
			+ "採集 / 攻撃：左クリック・Q・RT     設置：右クリック・R・LT\n"
			+ "移動：WASD・左スティック     視点：マウス・矢印・右スティック\n"
			+ "ジャンプ：Space・A     食べる：F・Y     クラフト：E・X\n"
			+ "持ち替え：1〜9・ホイール・Tab / Z・十字左右     休止：Esc・Start",
			Vector2(32, 90), 19, Vector2(900, 405))
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(30, 496)
	buttons.add_theme_constant_override("separation", 15)
	box.get_child(0).add_child(buttons)
	_button(buttons, "戻る", "close")
	if kind == "pause":
		_button(buttons, "保存する", "save")
		_button(buttons, "タイトルへ", "title")
		_button(buttons, "遠征を終える", "retire")
		_label(box, "島と持ち物を保存して、いつでも続きを遊べます。\n\n"
			+ "休止中は、時間・空腹・敵の動きも止まります。", Vector2(32, 120), 22)
	buttons.get_child(0).grab_focus()


func _build_crafting(box: Control) -> void:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 86)
	scroll.size = Vector2(560, 390)
	scroll.follow_focus = true
	box.get_child(0).add_child(scroll)
	scroll.add_child(list)
	for recipe: Dictionary in model.RECIPES:
		var cost_text: String = ""
		for item: String in recipe.costs:
			cost_text += "%s×%d  " % [model.item_name(item), recipe.costs[item]]
		var button: Button = _button(list, "%s   %s" % [recipe.name, cost_text],
			"craft", recipe.id)
		button.custom_minimum_size = Vector2(535, 44)
		button.add_theme_font_size_override("font_size", 16)
		button.modulate.a = 1.0 if model.recipe_available(recipe) else 0.55
	_label(box, "持ち物  /  枠 %d に装備" % (model.selected + 1), Vector2(625, 90), 17)
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.position = Vector2(625, 130)
	inventory_scroll.size = Vector2(295, 340)
	inventory_scroll.follow_focus = true
	box.get_child(0).add_child(inventory_scroll)
	var items := VBoxContainer.new()
	inventory_scroll.add_child(items)
	for item: String in model.inventory:
		if int(model.inventory[item]) <= 0:
			continue
		var item_button: Button = _button(items,
			"%s  × %d" % [model.item_name(item), model.inventory[item]], "equip", item)
		item_button.custom_minimum_size = Vector2(265, 38)
		item_button.add_theme_font_size_override("font_size", 16)



func close_overlay() -> void:
	_set_buttons_enabled(screen, true)
	overlay.hide()
	_clear(overlay)
	if screen.visible:
		_focus_first_button(screen)


## 通知は出来事ごとに発生するため、呼ぶたびに表示時間を更新する。
func notify_text(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.1)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.6)


func damage_flash() -> void:
	flash.color.a = 0.35
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


func _button(parent: Node, text: String, action: String, value: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140, 48)
	parent.add_child(button)
	button.pressed.connect(func() -> void: requested.emit(action, value))
	button.mouse_entered.connect(func() -> void:
		create_tween().tween_property(button, "modulate", Color(1.15, 1.1, 0.9), 0.1))
	button.mouse_exited.connect(func() -> void:
		create_tween().tween_property(button, "modulate", Color.WHITE, 0.12))
	return button


func _panel(parent: Node, pos: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(INK))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var content := Control.new()
	content.custom_minimum_size = dimensions
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	return panel


func _label(parent: Node, text: String, pos: Vector2, font_size: int,
		dimensions: Vector2 = Vector2(600, 40)) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent is PanelContainer:
		parent.get_child(0).add_child(label)
	else:
		parent.add_child(label)
	return label


func _bar(parent: Node, pos: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = dimensions
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", _style(color))
	bar.add_theme_stylebox_override("background", _style(Color("294950")))
	if parent is PanelContainer:
		parent.get_child(0).add_child(bar)
	else:
		parent.add_child(bar)
	bar.size = dimensions
	bar.set_deferred("size", dimensions)
	return bar


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	style.border_color = Color("47626b")
	style.set_border_width_all(1)
	return style


func _mark(done: bool) -> String:
	return "✓" if done else "○"


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _set_buttons_enabled(parent: Node, enabled: bool) -> void:
	for child: Node in parent.get_children():
		if child is Button:
			child.disabled = not enabled
		_set_buttons_enabled(child, enabled)


func _focus_first_button(parent: Node) -> bool:
	for child: Node in parent.get_children():
		if child is Button and not child.disabled and child.is_visible_in_tree():
			child.grab_focus()
			return true
		if _focus_first_button(child):
			return true
	return false
