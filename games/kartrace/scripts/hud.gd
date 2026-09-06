extends Control
## レースの値は autoload から読み、画面内には表示状態だけを保持する。

signal start_requested
signal title_requested
signal kart_selected(kind: int)

const Course = preload("res://scripts/course_data.gd")
const CREAM: Color = Color("fff3d8")
const INK: Color = Color("183e50")
const MINT: Color = Color("4ce0c5")
const PORTRAITS: Array[String] = ["otter", "fox", "owl"]
const ITEMS: Array[String] = ["pulse", "buoy", "turbo"]
var state: Node
var menu: Control
var race: Control
var result: Control
var place: Label
var lap: Label
var timer: Label
var lap_timer: Label
var speed: Label
var item: Label
var item_icon: TextureRect
var notice: Label
var center: Label
var standings: Label
var best: Label
var choice: Label
var cards: Array[Button] = []
var map: Control
var flash: ColorRect
var result_reveal: float = 1.0
var last_phase: String = ""
var popup_tween: Tween


func _ready() -> void:
	state = get_node("/root/RaceState")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _theme()
	_build_menu()
	_build_race()
	_build_results()
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.94, 0.8, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _theme() -> Theme:
	var skin: Theme = Theme.new()
	skin.default_font = load("res://assets/fonts/MPLUSRounded1c-Medium.ttf")
	skin.default_font_size = 20
	skin.set_color("font_color", "Label", CREAM)
	for mode: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = MINT if mode == "normal" else Color("ffcd77")
		style.set_corner_radius_all(14)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.border_color = CREAM
		style.set_border_width_all(3 if mode == "focus" else 0)
		skin.set_stylebox(mode, "Button", style)
		skin.set_color("font_color" + ("" if mode == "normal" else "_" + mode), "Button", INK)
	return skin


func _panel(parent: Control, rect: Rect2, color: Color = Color("183e50ed")) -> Panel:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.border_color = Color("54827f")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	return panel


func _label(parent: Control, text: String, pos: Vector2, font_size: int = 24,
		color: Color = CREAM) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _image(parent: Control, path: String, rect: Rect2) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.position = rect.position
	image.size = rect.size
	return image


func _button(parent: Control, text: String, rect: Rect2, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	parent.add_child(button)
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(action)
	button.mouse_entered.connect(func() -> void: button.modulate = Color("fff4ce"))
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	return button


func _build_menu() -> void:
	menu = Control.new()
	add_child(menu)
	_panel(menu, Rect2(38, 34, 510, 646))
	_label(menu, "サンゴ湾サーキット", Vector2(70, 59), 20, MINT)
	_label(menu, "潮風カート", Vector2(65, 82),  60)
	_label(menu, "ひとつの島。３周の勝負。", Vector2(72, 173), 22)
	_image(menu, "res://assets/ui/logo.svg", Rect2(355, 70, 155, 86))
	_label(menu, "ドライバーを選ぼう", Vector2(72, 227), 18, Color("bad4cc"))
	for index: int in range(3):
		var button: Button = _button(menu, "", Rect2(70 + index * 149, 263, 136, 132),
			func() -> void: kart_selected.emit(index))
		cards.append(button)
		_image(button, "res://assets/portraits/%s.svg" % PORTRAITS[index], Rect2(15, 4, 106, 106))
		_label(button, ["しずく", "あかね", "すみれ"][index], Vector2(33, 103), 17, INK)
	choice = _label(menu, "", Vector2(72, 414), 20)
	_label(menu, "３周 / CPU ３台 / アイテム３種", Vector2(72, 457), 18, Color("bad4cc"))
	_button(menu, "レースをはじめる  →", Rect2(70, 512, 446, 64),
		func() -> void: start_requested.emit())
	_label(menu, "← → 選択　Enter / A 決定", Vector2(85, 596), 18)
	_label(menu, "F11 全画面　M 消音", Vector2(85, 630), 16, Color("bad4cc"))
	_panel(menu, Rect2(895, 43, 340, 64))
	_label(menu, "海風と、最後のひと押し。", Vector2(918, 60), 20)
	_panel(menu, Rect2(603, 551, 632, 129))
	_label(menu, "↑ アクセル　↓ ブレーキ・バック　← → ハンドル", Vector2(628, 570), 18)
	_label(menu, "Space ドリフト　E アイテム　Esc タイトル", Vector2(628, 605), 18)
	_label(menu, "パッド：RT / LT 加減速　左スティック　X ドリフト　B アイテム",
		Vector2(628, 643), 15, Color("bad4cc"))


func _build_race() -> void:
	race = Control.new()
	race.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(race)
	_panel(race, Rect2(30, 27, 172, 126))
	place = _label(race, "1 位", Vector2(54, 28), 56, MINT)
	lap = _label(race, "1 / 3 周", Vector2(57, 108), 21)
	_panel(race, Rect2(475, 28, 330, 58))
	timer = _label(race, "", Vector2(507, 38), 24)
	lap_timer = _label(race, "", Vector2(505, 91), 19, INK)
	_panel(race, Rect2(1018, 28, 232, 113))
	item_icon = _image(race, "res://assets/items/turbo.svg", Rect2(1032, 44, 66, 66))
	item = _label(race, "", Vector2(1103, 48), 19)
	_label(race, "E / B で使う", Vector2(1103, 84), 16, MINT)
	_panel(race, Rect2(30, 555, 231, 136))
	map = Control.new()
	race.add_child(map)
	map.position = Vector2(46, 567)
	map.draw.connect(_draw_map)
	_panel(race, Rect2(1018, 566, 232, 125))
	speed = _label(race, "0", Vector2(1044, 566), 52)
	_label(race, "km/h", Vector2(1163, 600), 21, MINT)
	_label(race, "Space / X ドリフト", Vector2(1038, 650), 17)
	center = _label(race, "", Vector2(400, 230), 86)
	center.size = Vector2(480, 160)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = _label(race, "", Vector2(300, 475), 31, MINT)
	notice.size.x = 680
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_results() -> void:
	result = Control.new()
	add_child(result)
	_panel(result, Rect2(325, 42, 630, 638))
	_label(result, "サンゴ湾サーキット", Vector2(485, 70), 20, MINT)
	_label(result, "レース結果", Vector2(472, 107), 48)
	_image(result, "res://assets/ui/trophy.svg", Rect2(364, 97, 84, 84))
	standings = _label(result, "", Vector2(370, 217), 26)
	best = _label(result, "", Vector2(381, 489), 22, MINT)
	_button(result, "もう一度走る", Rect2(367, 532, 262, 66),
		func() -> void: start_requested.emit())
	_button(result, "タイトルへ", Rect2(649, 532, 262, 66),
		func() -> void: title_requested.emit())
	_label(result, "Enter / A 再走　Esc タイトル", Vector2(451, 625), 18)


func _process(delta: float) -> void:
	# 結果表示に入ってからタイムを数え上げる視覚演出。
	result_reveal = minf(1.0, result_reveal + delta * 1.5)


func refresh() -> void:
	menu.visible = state.phase == "title"
	race.visible = state.phase in ["countdown", "racing"]
	result.visible = state.phase == "results"
	if state.phase != last_phase:
		last_phase = state.phase
		if state.phase == "results":
			result_reveal = 0
		_transition()
	if menu.visible:
		choice.text = ["しずく：加速と曲がりやすさが得意", "あかね：最高速で追い抜く", "すみれ：安定したハンドリング"][state.selected_kart]
		for index: int in range(3):
			cards[index].modulate = Color.WHITE if index == state.selected_kart else Color("8ba5a0")
	if race.visible and not state.racers.is_empty():
		var player: Dictionary = state.racers[0]
		place.text = "%d 位" % state.rank_of(0)
		lap.text = "%d / 3 周" % mini(player.lap, 3)
		timer.text = "タイム  %s" % format_time(state.elapsed)
		var lap_seconds: float = state.elapsed - player.lap_started
		if player.finish_time >= 0 and not player.lap_times.is_empty():
			lap_seconds = player.lap_times.back()
		lap_timer.text = "ラップ  " + format_time(lap_seconds)
		speed.text = "%03d" % roundi(absf(player.speed) * 3.6)
		item.text = ["パルス", "ブイ", "ターボ"][player.item - 1] if player.item > 0 else "空っぽ"
		item_icon.visible = player.item > 0
		if player.item > 0:
			item_icon.texture = load("res://assets/items/%s.svg" % ITEMS[player.item - 1])
		center.text = str(ceili(state.countdown)) if state.phase == "countdown" else ""
		if player.finish_time >= 0:
			center.text = "ゴール！"
		if player.speed < -1:
			center.text = "逆走中"
		map.queue_redraw()
	if result.visible:
		standings.text = ""
		var row: int = 1
		for racer: Dictionary in state.results():
			standings.text += "%d位  %-8s   %s\n\n" % [
				row, racer.name, format_time(racer.finish_time * result_reveal)]
			row += 1
		best.text = "ベストタイム  " + format_time(state.best_time)


static func format_time(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.--"
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]


func _draw_map() -> void:
	var points: PackedVector2Array = []
	for index: int in range(65):
		var point: Vector3 = Course.sample(index / 64.0 * Course.LENGTH)
		points.append(Vector2(point.x * 1.9 + 100, point.z * 1.35 + 53))
	map.draw_polyline(points, Color("739b99"), 8, true)
	for index: int in range(state.racers.size() - 1, -1, -1):
		var point: Vector3 = Course.sample(state.racers[index].progress)
		map.draw_circle(Vector2(point.x * 1.9 + 100, point.z * 1.35 + 53),
			6 if index == 0 else 4, MINT if index == 0 else Color("ffab80"))


func popup(text: String, impact: bool = false) -> void:
	if popup_tween:
		popup_tween.kill()
	notice.text = text
	notice.modulate.a = 1
	notice.scale = Vector2.ONE * 1.07
	popup_tween = create_tween().set_parallel(true)
	popup_tween.tween_property(notice, "scale", Vector2.ONE, 0.2)
	popup_tween.tween_property(notice, "modulate:a", 0.0, 0.5).set_delay(1.0)
	if impact:
		flash.color = Color(1.0, 0.94, 0.8, 0.38)
	popup_tween.tween_property(flash, "color:a", 0.0, 0.2)


func _transition() -> void:
	flash.color = Color(0.07, 0.21, 0.26, 0.75)
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)
