extends Control
## 画面表示は状態を参照し、操作をゲーム本体へ通知する。

signal requested(action: String, value: String)

const World := preload("res://scripts/voxel_world.gd")
const Data := preload("res://scripts/voxel_data.gd")
const ORIGAMI_PAPER := preload("res://assets/textures/origami-paper.png")
const CONSTRUCTION_PAPER := preload("res://assets/textures/construction-paper-sky.png")
const GOLD := Color("e9a74f")
const INK := Color("203a39")
const PAPER := Color("f4e5bd")
const PALE_PAPER := Color("fff4d7")
const DESK := Color("694735")

var model: Node
var screen: Control
var overlay: Control
var play_hud: Control
var health: ProgressBar
var hunger_bar: ProgressBar
var clock_label: Label
var quest: Label
var target: Label
var placement: Label
var progress: ProgressBar
var toast: Label
var tutorial: PanelContainer
var tutorial_title: Label
var tutorial_body: Label
var tutorial_step: int = -1
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
var _selected_style: StyleBox
var _normal_style: StyleBox
var _icon_cache: Dictionary = {}
var _paper_texture: Texture2D
var _tutorial_origin: Vector3


func configure(state: Node) -> void:
	model = state
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://assets/ui/theme.tres")
	_paper_texture = ORIGAMI_PAPER
	play_hud = Control.new()
	play_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play_hud)
	_selected_style = _paper_style(Color("ffd878"))
	_normal_style = _paper_style(Color("f7e9c1"))
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
	toast = _label(self, "", Vector2(320, 548), 20, Vector2(640, 40))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Color("fff1c5"))


func _build_hud() -> void:
	var vitals: PanelContainer = _panel(play_hud, Vector2(28, 24), Vector2(300, 104))
	vitals.rotation_degrees = -1.0
	_label(vitals, "からだの紙片", Vector2(16, 8), 15)
	_label(vitals, "生命", Vector2(16, 38), 16)
	health = _bar(vitals, Vector2(80, 41), Vector2(200, 16), Color("e87d66"))
	_label(vitals, "空腹", Vector2(16, 70), 16)
	hunger_bar = _bar(vitals, Vector2(80, 73), Vector2(200, 12), GOLD)
	var journal: PanelContainer = _panel(play_hud, Vector2(925, 24), Vector2(327, 172))
	journal.rotation_degrees = 0.7
	clock_label = _label(journal, "", Vector2(20, 10), 21)
	quest = _label(journal, "", Vector2(20, 46), 16, Vector2(295, 116))
	_label(play_hud, "+", Vector2(627, 338), 30)
	var context_sheet: PanelContainer = _panel(play_hud,
		Vector2(320, 374), Vector2(640, 86))
	context_sheet.rotation_degrees = 0.35
	context_sheet.modulate.a = 0.92
	target = _label(context_sheet, "", Vector2(20, 8), 18, Vector2(600, 30))
	target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_color_override("font_color", INK)
	placement = _label(context_sheet, "", Vector2(10, 42), 16, Vector2(620, 28))
	placement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement.add_theme_color_override("font_color", Color("7d4c32"))
	progress = _bar(context_sheet, Vector2(240, 4), Vector2(160, 5), GOLD)
	progress.max_value = 1.0
	for index: int in range(9):
		var cell: PanelContainer = _panel(play_hud,
			Vector2(296 + index * 77, 607), Vector2(72, 88))
		cell.rotation_degrees = [-1.8, 0.9, -0.4, 1.4, -1.0, 0.5, -1.3, 1.1, -0.6][index]
		slots.append(cell)
		var icon := TextureRect.new()
		icon.position = Vector2(18, 10)
		icon.size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.get_child(0).add_child(icon)
		slot_icons.append(icon)
		slot_labels.append(_label(cell, "", Vector2(3, 48), 13, Vector2(67, 35)))
		slot_labels[-1].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_tutorial()


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
	clock_label.text = "%d日目の%s" % [model.day, "夜" if model.is_night() else "昼"]
	quest.text = "工作メモ\n%s 石のつるはしを折る\n%s 紙の家を組み立てる\n%s 3日間、灯りを守る\n→ %s" % [
		_mark(model.tool_level >= 2), _mark(model.house_built),
		_mark(model.survived_three_days()), _next_goal()]
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
			slot_labels[index].add_theme_color_override("font_color", INK)
	_selected_slot = model.selected


func _build_tutorial() -> void:
	tutorial = _panel(play_hud, Vector2(30, 150), Vector2(366, 205))
	tutorial.rotation_degrees = -0.8
	tutorial_title = _label(tutorial, "", Vector2(18, 12), 21, Vector2(330, 30))
	tutorial_body = _label(tutorial, "", Vector2(18, 48), 17, Vector2(330, 142))
	tutorial.hide()


func start_tutorial(origin: Vector3) -> void:
	_tutorial_origin = origin
	tutorial_step = 0
	tutorial.show()
	_refresh_tutorial()


func update_tutorial(position: Vector3, target_id: int) -> void:
	if tutorial_step < 0:
		return
	if tutorial_step == 0 and position.distance_to(_tutorial_origin) > 0.75:
		tutorial_step = 1
	elif tutorial_step == 1 and target_id in [Data.WOOD, Data.LEAVES]:
		tutorial_step = 2
	elif tutorial_step == 2 and int(model.inventory.get("wood", 0)) > 0:
		tutorial_step = 3
	elif tutorial_step == 3 and int(model.inventory.get("plank", 0)) > 0:
		tutorial_step = -1
		tutorial.hide()
		notify_text("最初の折り方を覚えました。右上の工作メモを進めよう")
		return
	_refresh_tutorial()


func skip_tutorial() -> void:
	if tutorial_step < 0:
		return
	tutorial_step = -1
	tutorial.hide()
	notify_text("手順書をしまいました。M / View で島の模型を見られます")


func _refresh_tutorial() -> void:
	if tutorial_step < 0:
		return
	var titles: Array[String] = [
		"折り方手順書  1 / 4", "折り方手順書  2 / 4",
		"折り方手順書  3 / 4", "折り方手順書  4 / 4",
	]
	var pages: Array[String] = [
		"① 紙の島を歩く\nWASD / 左スティック\n\nまず木立へ近づこう。\nH / B で手順書をしまう",
		"② 木の紙を見つける\nマウス / 矢印 / 右スティック\n\n照準を木に重ねると金色になります。\nH / B で手順書をしまう",
		"③ 木をひらいて集める\n左クリック / Q / RT を長押し\n\n折り目が開くまで押し続けよう。\nH / B で手順書をしまう",
		"④ 最初の工作\nE / X で折り方手順書を開く\n\n木材から木の板を折ろう。\nH / B で手順書をしまう",
	]
	tutorial_title.text = titles[tutorial_step]
	tutorial_body.text = pages[tutorial_step]


func _next_goal() -> String:
	if model.tool_level < 2:
		return "木を集め、E / X で道具を折る"
	if not model.house_built:
		return "紙ブロックで床・壁・屋根を組む"
	if not model.survived_three_days():
		return "夜は家と灯りで身を守る"
	return "三度目の朝を待つ"


func _show_screen(phase: String) -> void:
	_clear(screen)
	screen.visible = phase != "play"
	if phase == "play":
		close_overlay()
		return
	var desk_texture := TextureRect.new()
	desk_texture.texture = CONSTRUCTION_PAPER
	desk_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk_texture.stretch_mode = TextureRect.STRETCH_SCALE
	desk_texture.modulate = Color("62483d")
	desk_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(desk_texture)
	var tint := ColorRect.new()
	tint.color = Color(0.09, 0.055, 0.035, 0.18)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(tint)
	var copy_sheet: PanelContainer = _panel(screen, Vector2(56, 66), Vector2(460, 588))
	copy_sheet.rotation_degrees = -0.7
	var art_sheet: PanelContainer = _panel(screen, Vector2(552, 76), Vector2(660, 520))
	art_sheet.rotation_degrees = 0.8
	var art := TextureRect.new()
	art.texture = load("res://assets/art/title.svg")
	art.position = Vector2(14, 14)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.size = Vector2(632, 492)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_sheet.get_child(0).add_child(art)
	art.set_deferred("size", Vector2(632, 492))
	var paper_glaze := TextureRect.new()
	paper_glaze.texture = _paper_texture
	paper_glaze.position = Vector2(14, 14)
	paper_glaze.size = Vector2(632, 492)
	paper_glaze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper_glaze.stretch_mode = TextureRect.STRETCH_SCALE
	paper_glaze.modulate = Color(1, 0.93, 0.78, 0.19)
	paper_glaze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_sheet.get_child(0).add_child(paper_glaze)
	var emblem := TextureRect.new()
	emblem.texture = load("res://assets/art/logo.svg")
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.position = Vector2(342, 57)
	emblem.size = Vector2(86, 78)
	emblem.visible = phase == "title"
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy_sheet.get_child(0).add_child(emblem)
	_label(copy_sheet, "紙の島をひらき、明日の灯りを折る。", Vector2(24, 34), 17)
	_label(copy_sheet, "灯守の島" if phase == "title" else
		("三度目の朝" if phase == "clear" else "灯りの消えた夜"), Vector2(20, 78), 50)
	_label(copy_sheet, "採る。折る。組み立てる。" if phase == "title" else
		("あなたの家に、新しい朝が訪れました。" if phase == "clear" else
		"持ち物を失っても、島と家は残っています。"), Vector2(24, 158), 18)
	var actions := VBoxContainer.new()
	actions.position = Vector2(24, 218)
	actions.size = Vector2(410, 260)
	actions.add_theme_constant_override("separation", 10)
	copy_sheet.get_child(0).add_child(actions)
	if phase == "title":
		_button(actions, "新しい紙の島をひらく  →", "new")
		_button(actions, "保存した島から再開", "load")
		_button(actions, "机の上で島の模型を見る", "map")
	elif phase == "failed":
		_button(actions, "島で目を覚ます", "respawn")
		_button(actions, "タイトルへ", "title")
	else:
		_button(actions, "タイトルへ", "title")
	_button(actions, "折り方手順書を読む", "help")
	_label(copy_sheet, "1日は3分。石の道具と家を折り、3日間を生き延びよう。",
		Vector2(24, 508), 15, Vector2(410, 28))
	actions.get_child(0).grab_focus()
	screen.modulate.a = 0.0
	create_tween().tween_property(screen, "modulate:a", 1.0, 0.35)


func show_menu(kind: String) -> void:
	_set_buttons_enabled(screen, false)
	_clear(overlay)
	overlay.show()
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.075, 0.045, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var box: PanelContainer = _panel(overlay, Vector2(160, 70), Vector2(960, 574))
	box.rotation_degrees = -0.25
	_label(box, {"pause": "ひと休み", "craft": "折り方手順書",
		"help": "折り方手順書  1ページ目", "map": "机上の島模型"}[kind],
		Vector2(28, 20), 34)
	if kind == "craft":
		_build_crafting(box)
	elif kind == "map":
		_build_map(box)
	elif kind == "help":
		_label(box, "① 木立へ歩く　WASD / 左スティック\n"
			+ "② 木の紙に照準を重ねる　マウス / 矢印 / 右スティック\n"
			+ "③ 金色になった紙をひらく　左クリック / Q / RT を長押し\n"
			+ "④ 折り方を選ぶ　E / X → 木の板 → 作業台 → つるはし\n\n"
			+ "右クリック / R / LT で、半透明の完成予想位置に紙ブロックを置けます。\n"
			+ "F / Y で食べる。Tab / Z / 十字左右で机上の紙片を選びます。\n"
			+ "M / View で島の模型、Esc / Start で休止、F11 で全画面。\n\n"
			+ "家は内側1×1・高さ2を床・壁・屋根で囲み、入口に柱とまぐさを付けます。\n"
			+ "たいまつの近くには敵が湧きません。夜は家と灯りで身を守ろう。",
			Vector2(32, 88), 18, Vector2(900, 402))
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


func _build_map(box: Control) -> void:
	var frame: PanelContainer = _panel(box.get_child(0), Vector2(30, 82), Vector2(640, 400))
	frame.add_theme_stylebox_override("panel", _paper_style(Color("e7c990")))
	var container := SubViewportContainer.new()
	container.position = Vector2(12, 12)
	container.size = Vector2(616, 376)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.get_child(0).add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(616, 376)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	container.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("78a7a2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff0d0")
	environment.ambient_light_energy = 0.85
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -28, 0)
	light.light_color = Color("ffe2a8")
	light.light_energy = 1.2
	light.shadow_enabled = true
	viewport.add_child(light)
	var table := MeshInstance3D.new()
	var table_mesh := PlaneMesh.new()
	table_mesh.size = Vector2(74, 74)
	table.mesh = table_mesh
	var table_material := StandardMaterial3D.new()
	table_material.albedo_color = DESK
	table_material.albedo_texture = CONSTRUCTION_PAPER
	table_material.roughness = 1.0
	table.material_override = table_material
	table.position = Vector3(16, -1.1, 16)
	viewport.add_child(table)
	var island := World.new()
	viewport.add_child(island)
	island.configure(model.data)
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.16
	marker_mesh.bottom_radius = 0.7
	marker_mesh.height = 3.2
	marker_mesh.radial_segments = 6
	marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("ffd55f")
	marker_material.emission_enabled = true
	marker_material.emission = Color("ffb936")
	marker_material.emission_energy_multiplier = 1.5
	marker.material_override = marker_material
	marker.position = model.data.spawn + Vector3(0, 2.0, 0)
	viewport.add_child(marker)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(16, 42, 29)
	camera.look_at(Vector3(16, 3.5, 16))
	camera.fov = 42
	camera.current = true
	var close_hint: String = ("M / View でも閉じられます。" if model.phase == "play"
		else "「戻る」でタイトルへ戻ります。")
	_label(box, "紙の模型で、木立・浜・家の位置を確かめる。\n\n"
		+ "黄色い中心が出発地点。\n木立は島の四方にあります。\n浜の内側で家を折ると守りやすい。\n\n"
		+ "次の工作\n→ %s\n\n%s" % [_next_goal(), close_hint],
		Vector2(700, 94), 17, Vector2(225, 370))


func _build_crafting(box: Control) -> void:
	_label(box, "1  紙をそろえる　→　2  折り線を選ぶ　→　3  完成品を机へ",
		Vector2(30, 66), 16, Vector2(890, 24))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 98)
	scroll.size = Vector2(555, 376)
	scroll.follow_focus = true
	box.get_child(0).add_child(scroll)
	scroll.add_child(list)
	var preview_panel: PanelContainer = _panel(box.get_child(0), Vector2(615, 98), Vector2(310, 376))
	preview_panel.add_theme_stylebox_override("panel", _paper_style(Color("fff2c9")))
	var preview := _label(preview_panel, "", Vector2(22, 18), 17, Vector2(266, 188))
	_label(preview_panel, "机上の予備紙片  /  枠%dへ置く" % (model.selected + 1),
		Vector2(22, 210), 15, Vector2(266, 24))
	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.position = Vector2(20, 238)
	inventory_scroll.size = Vector2(270, 120)
	inventory_scroll.follow_focus = true
	preview_panel.get_child(0).add_child(inventory_scroll)
	var items := VBoxContainer.new()
	inventory_scroll.add_child(items)
	for item: String in model.inventory:
		if int(model.inventory[item]) <= 0:
			continue
		var item_button: Button = _button(items,
			"%s  × %d" % [model.item_name(item), model.inventory[item]], "equip", item)
		item_button.custom_minimum_size = Vector2(245, 34)
		item_button.add_theme_font_size_override("font_size", 14)
	for recipe: Dictionary in model.RECIPES:
		var costs: Array[String] = []
		for item: String in recipe.costs:
			costs.append("%s×%d" % [model.item_name(item), recipe.costs[item]])
		var reason: String = model.recipe_reason(recipe)
		var state_text: String = "折れます" if reason.is_empty() else reason
		var button: Button = _button(list, "%s\n%s → %s" % [
			recipe.name, " ＋ ".join(costs), state_text],
			"craft", recipe.id)
		button.custom_minimum_size = Vector2(525, 66)
		button.add_theme_font_size_override("font_size", 16)
		button.disabled = not reason.is_empty()
		button.tooltip_text = state_text
		button.focus_entered.connect(func() -> void: _show_recipe_preview(preview, recipe))
		button.mouse_entered.connect(func() -> void: _show_recipe_preview(preview, recipe))
		if preview.text.is_empty():
			_show_recipe_preview(preview, recipe)


func _show_recipe_preview(label: Label, recipe: Dictionary) -> void:
	var costs: Array[String] = []
	for item: String in recipe.costs:
		costs.append("・%s　%d / %d" % [model.item_name(item),
			model.inventory.get(item, 0), recipe.costs[item]])
	var reason: String = model.recipe_reason(recipe)
	label.text = "完成見本\n%s　×%d\n\n必要な紙片\n%s\n\n%s" % [
		recipe.name, recipe.count, "\n".join(costs),
		"✓ この折り方を選べます" if reason.is_empty() else "× " + reason]



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
	panel.add_theme_stylebox_override("panel", _paper_style(PAPER))
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


func _paper_style(color: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _paper_texture
	style.modulate_color = color
	style.texture_margin_left = 10.0
	style.texture_margin_top = 10.0
	style.texture_margin_right = 10.0
	style.texture_margin_bottom = 10.0
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
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
