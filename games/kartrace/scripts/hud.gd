extends Control
## レース状態を、80年代アーケード筐体とコース内計器の表現へ変換する。

signal start_requested
signal garage_requested
signal course_requested
signal title_requested
signal kart_selected(kind: int)

const Course = preload("res://scripts/course_data.gd")
const INK: Color = Color("07142e")
const NIGHT: Color = Color("101044")
const CYAN: Color = Color("20f6ff")
const MAGENTA: Color = Color("ff2d95")
const YELLOW: Color = Color("ffe74a")
const WHITE: Color = Color("fff9df")
const MUTED: Color = Color("7581a6")
const PORTRAITS: Array[String] = ["otter", "fox", "owl"]
const ITEMS: Array[String] = ["pulse", "buoy", "turbo"]

var state: Node
var menu: Control
var garage: Control
var tutorial: Control
var race: Control
var result: Control
var lap: Label
var timer: Label
var lap_timer: Label
var speed: Label
var gear: Label
var item: Label
var item_hint: Label
var item_icon: TextureRect
var notice: Label
var center: Label
var standings: Label
var best: Label
var choice: Label
var garage_choice: Label
var cards: Array[Button] = []
var map: Control
var garage_map: Control
var gauge: Control
var flash: ColorRect
var active_poster: Panel
var tutorial_title: Label
var tutorial_detail: Label
var tutorial_steps: Array[Panel] = []
var result_reveal: float = 1.0
var tutorial_step: int = 0
var gauge_speed: float = 0.0
var last_phase: String = ""
var popup_tween: Tween
var pulse_clock: float = 0.0


func _ready() -> void:
	state = get_node("/root/RaceState")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _theme()
	_build_menu()
	_build_garage()
	_build_tutorial()
	_build_race()
	_build_results()
	var scanlines: Control = Control.new()
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanlines.draw.connect(_draw_scanlines.bind(scanlines))
	add_child(scanlines)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 0.9, 0.3, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)


func _theme() -> Theme:
	var skin: Theme = Theme.new()
	skin.default_font = load("res://assets/fonts/PottaOne-Regular.ttf")
	skin.default_font_size = 20
	skin.set_color("font_color", "Label", WHITE)
	for mode: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = MAGENTA if mode == "normal" else YELLOW
		style.border_color = CYAN if mode in ["normal", "focus"] else WHITE
		style.set_border_width_all(4 if mode == "focus" else 2)
		style.content_margin_left = 16
		style.content_margin_right = 16
		skin.set_stylebox(mode, "Button", style)
		skin.set_color("font_color" + ("" if mode == "normal" else "_" + mode),
			"Button", INK if mode != "normal" else WHITE)
	return skin


func _solid(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var block: ColorRect = ColorRect.new()
	block.color = color
	block.position = rect.position
	block.size = rect.size
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)
	return block


func _panel(parent: Control, rect: Rect2, color: Color = Color("07142ee8"),
		border: Color = CYAN, width: int = 2) -> Panel:
	var panel: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	return panel


func _label(parent: Control, text: String, pos: Vector2, font_size: int = 24,
		color: Color = WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _image(parent: Control, path: String, rect: Rect2) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.texture = load(path)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	button.mouse_entered.connect(func() -> void: button.modulate = Color("fff5b7"))
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	return button


func _build_menu() -> void:
	menu = Control.new()
	add_child(menu)
	_solid(menu, Rect2(0, 0, 1280, 720), Color("08143b91"))
	_solid(menu, Rect2(0, 0, 1280, 16), MAGENTA)
	_solid(menu, Rect2(0, 704, 1280, 16), CYAN)
	_label(menu, "ARCADE CABINET  1987 / BAY AREA", Vector2(44, 31), 18, CYAN)
	_label(menu, "潮風カート", Vector2(42, 73), 72, YELLOW)
	_label(menu, "NEON HARBOR GRAND PRIX", Vector2(49, 160), 27, MAGENTA)
	_label(menu, "夕焼けの環状道路を、3周で奪い取れ。", Vector2(49, 207), 21)
	_panel(menu, Rect2(43, 260, 690, 340), Color("080f32e8"), MAGENTA, 4)
	_label(menu, "SELECT DRIVER", Vector2(66, 278), 21, CYAN)
	for index: int in range(3):
		var button: Button = _button(menu, "", Rect2(65 + index * 218, 321, 196, 203),
			func() -> void: kart_selected.emit(index))
		cards.append(button)
		_image(button, "res://assets/portraits/%s.svg" % PORTRAITS[index],
			Rect2(23, 11, 150, 150))
		var driver: Label = _label(button, ["しずく", "あかね", "すみれ"][index],
			Vector2(62, 160), 20, INK)
		driver.size.x = 100
	choice = _label(menu, "", Vector2(68, 546), 18, YELLOW)
	_panel(menu, Rect2(777, 65, 458, 535), Color("111047e8"), CYAN, 4)
	_label(menu, "NEXT MISSION", Vector2(817, 94), 20, MAGENTA)
	_label(menu, "ガレージへ行く", Vector2(815, 137), 39, WHITE)
	_label(menu, "車種を決めたら、壁のポスターから\n走るコースを選択する。",
		Vector2(817, 201), 20, Color("c9d9ff"))
	_label(menu, "←  →", Vector2(848, 299), 46, CYAN)
	_label(menu, "ドライバーを選ぶ", Vector2(947, 311), 20)
	_label(menu, "ENTER / A", Vector2(837, 380), 34, YELLOW)
	_label(menu, "選んだ車種でガレージへ", Vector2(837, 428), 20)
	_button(menu, "ENTER / A  ガレージへ進む", Rect2(815, 489, 382, 70),
		func() -> void: garage_requested.emit())
	_label(menu, "F11: 全画面  /  M: 消音", Vector2(50, 645), 17, Color("9aacd3"))


func _build_garage() -> void:
	garage = Control.new()
	add_child(garage)
	_solid(garage, Rect2(0, 0, 1280, 720), Color("21182ff0"))
	_solid(garage, Rect2(0, 0, 1280, 83), Color("07142ef5"))
	_label(garage, "PIT GARAGE", Vector2(38, 17), 42, YELLOW)
	_label(garage, "壁のポスターから次のレースを選ぶ", Vector2(328, 30), 22, CYAN)
	active_poster = _panel(garage, Rect2(52, 116, 689, 512), Color("171152"), MAGENTA, 7)
	_solid(active_poster, Rect2(19, 18, 651, 70), MAGENTA)
	_label(active_poster, "SUNSET CIRCUIT  /  ROUND 01", Vector2(39, 28), 25, WHITE)
	garage_map = Control.new()
	garage_map.position = Vector2(51, 118)
	garage_map.size = Vector2(587, 245)
	garage_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garage_map.draw.connect(_draw_garage_map)
	active_poster.add_child(garage_map)
	_label(active_poster, "サンゴ湾サーキット", Vector2(49, 373), 34, YELLOW)
	_label(active_poster, "3 LAPS  /  CURVE  /  BRIDGE  /  BOOST", Vector2(51, 421), 18, CYAN)
	garage_choice = _label(active_poster, "選択中：夕焼けの海上環状コース",
		Vector2(50, 459), 18, WHITE)
	for index: int in range(2):
		var x: float = 780.0 + index * 225.0
		var locked: Panel = _panel(garage, Rect2(x, 125, 195, 276),
			Color("171a2de6"), MUTED, 3)
		_label(locked, "LOCKED", Vector2(41, 27), 22, MUTED)
		_label(locked, "整備中", Vector2(45, 91), 31, Color("9299b2"))
		_label(locked, "今回は選択不可", Vector2(27, 198), 17, MUTED)
		_label(locked, "新コースは\nピット完成後に解放", Vector2(25, 226), 14, MUTED)
	_panel(garage, Rect2(780, 433, 420, 194), Color("07142ef2"), CYAN, 3)
	_label(garage, "点滅中のポスターが選択対象", Vector2(807, 455), 18, CYAN)
	_label(garage, "ENTER / A", Vector2(808, 497), 33, YELLOW)
	_label(garage, "このコースのピットへ入る", Vector2(808, 542), 20)
	_button(garage, "ENTER / A  このコースで走る", Rect2(805, 574, 369, 45),
		func() -> void: course_requested.emit())
	_label(garage, "ESC: タイトルへ戻る", Vector2(50, 664), 17, Color("a8b4d4"))


func _build_tutorial() -> void:
	tutorial = Control.new()
	add_child(tutorial)
	_solid(tutorial, Rect2(0, 0, 1280, 116), Color("07142ef4"))
	_label(tutorial, "PIT CREW LESSON", Vector2(39, 17), 32, YELLOW)
	_label(tutorial, "スタート前に計器と操作を3つだけ確認", Vector2(347, 29), 20, CYAN)
	for index: int in range(3):
		var step_panel: Panel = _panel(tutorial, Rect2(52 + index * 230, 143, 204, 85),
			Color("07142ee8"), MUTED, 3)
		tutorial_steps.append(step_panel)
		_label(step_panel, "%02d" % (index + 1), Vector2(15, 12), 34, MUTED)
		_label(step_panel, ["アクセル", "ハンドル", "ドリフト"][index],
			Vector2(65, 22), 20)
	_panel(tutorial, Rect2(52, 264, 748, 214), Color("07142ef0"), MAGENTA, 5)
	tutorial_title = _label(tutorial, "", Vector2(91, 293), 42, YELLOW)
	tutorial_detail = _label(tutorial, "", Vector2(92, 359), 24, WHITE)
	_panel(tutorial, Rect2(850, 264, 380, 214), Color("111047eb"), CYAN, 4)
	_label(tutorial, "SKIP TUTORIAL", Vector2(891, 291), 22, MAGENTA)
	_label(tutorial, "ENTER / A", Vector2(890, 340), 34, YELLOW)
	_label(tutorial, "すぐにスタートラインへ", Vector2(891, 391), 19)
	_label(tutorial, "ESC でもスキップ", Vector2(891, 430), 16, Color("a8b4d4"))
	_label(tutorial, "実際の入力を受け取ると、次のピットボードが点灯します。",
		Vector2(54, 518), 18, CYAN)


func _build_race() -> void:
	race = Control.new()
	race.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(race)
	_panel(race, Rect2(24, 23, 198, 91), Color("07142edc"), MAGENTA, 3)
	_label(race, "LAP", Vector2(43, 35), 18, CYAN)
	lap = _label(race, "1 / 3", Vector2(42, 55), 37, YELLOW)
	_panel(race, Rect2(466, 22, 349, 89), Color("07142edc"), CYAN, 3)
	timer = _label(race, "", Vector2(500, 29), 27, YELLOW)
	lap_timer = _label(race, "", Vector2(501, 70), 16, CYAN)
	_panel(race, Rect2(1018, 22, 238, 111), Color("07142edc"), YELLOW, 3)
	item_icon = _image(race, "res://assets/items/turbo.svg", Rect2(1032, 35, 70, 70))
	item = _label(race, "", Vector2(1106, 37), 19, YELLOW)
	item_hint = _label(race, "", Vector2(1107, 76), 15, CYAN)
	_panel(race, Rect2(994, 523, 262, 175), Color("07142edc"), CYAN, 3)
	map = Control.new()
	race.add_child(map)
	map.position = Vector2(1017, 547)
	map.size = Vector2(218, 126)
	map.draw.connect(_draw_map)
	_panel(race, Rect2(20, 486, 291, 215), Color("07142edc"), MAGENTA, 3)
	gauge = Control.new()
	race.add_child(gauge)
	gauge.position = Vector2(38, 497)
	gauge.size = Vector2(255, 190)
	gauge.draw.connect(_draw_gauge)
	speed = _label(race, "000", Vector2(103, 609), 30, YELLOW)
	gear = _label(race, "N", Vector2(225, 609), 36, MAGENTA)
	center = _label(race, "", Vector2(400, 220), 88, YELLOW)
	center.add_theme_color_override("font_outline_color", INK)
	center.add_theme_constant_override("outline_size", 8)
	center.size = Vector2(480, 160)
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice = _label(race, "", Vector2(305, 444), 31, CYAN)
	notice.add_theme_color_override("font_outline_color", INK)
	notice.add_theme_constant_override("outline_size", 6)
	notice.size.x = 670
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_results() -> void:
	result = Control.new()
	add_child(result)
	_solid(result, Rect2(0, 0, 1280, 720), Color("07142e75"))
	_panel(result, Rect2(195, 38, 890, 632), Color("0a0c35f2"), MAGENTA, 6)
	_solid(result, Rect2(216, 61, 848, 72), MAGENTA)
	_label(result, "FINAL SCORE / サンゴ湾サーキット", Vector2(255, 78), 31, WHITE)
	_label(result, "電光順位表", Vector2(250, 160), 28, CYAN)
	standings = _label(result, "", Vector2(251, 211), 25, YELLOW)
	best = _label(result, "", Vector2(681, 211), 22, CYAN)
	_label(result, "次の走行を選ぶ", Vector2(251, 511), 19, WHITE)
	_button(result, "ENTER / A  もう一度走る", Rect2(250, 550, 371, 70),
		func() -> void: start_requested.emit())
	_button(result, "タイトルへ戻る", Rect2(658, 550, 371, 70),
		func() -> void: title_requested.emit())


func _process(delta: float) -> void:
	result_reveal = minf(1.0, result_reveal + delta * 1.5)
	pulse_clock += delta
	if is_instance_valid(active_poster) and garage.visible:
		active_poster.modulate = Color.WHITE.lerp(CYAN, 0.08 + sin(pulse_clock * 5.0) * 0.05)


func set_tutorial_step(value: int) -> void:
	tutorial_step = clampi(value, 0, 2)


func refresh() -> void:
	menu.visible = state.phase == "title"
	garage.visible = state.phase == "garage"
	tutorial.visible = state.phase == "tutorial"
	race.visible = state.phase in ["countdown", "racing"]
	result.visible = state.phase == "results"
	if state.phase != last_phase:
		last_phase = state.phase
		if state.phase == "results":
			result_reveal = 0.0
		_transition()
	if menu.visible:
		choice.text = ["しずく：加速と旋回が得意", "あかね：直線の最高速が得意",
			"すみれ：小回りと立て直しが得意"][state.selected_kart]
		for index: int in range(3):
			cards[index].modulate = Color.WHITE if index == state.selected_kart else Color("5d6585")
	if garage.visible:
		garage_map.queue_redraw()
	if tutorial.visible:
		var titles: Array[String] = ["アクセル計器を点灯", "左右のラインを確認", "ドリフトを準備"]
		var details: Array[String] = ["↑ または RT を押す", "← → または左スティックを倒す",
			"SPACE / X を押す（E / B でも次へ）"]
		tutorial_title.text = titles[tutorial_step]
		tutorial_detail.text = details[tutorial_step]
		for index: int in range(tutorial_steps.size()):
			var active: bool = index == tutorial_step
			tutorial_steps[index].modulate = CYAN if active else (
				Color("89ffb4") if index < tutorial_step else Color("66708c"))
	if race.visible and not state.racers.is_empty():
		var player: Dictionary = state.racers[0]
		lap.text = "%d / 3" % mini(player.lap, 3)
		timer.text = "TIME  %s" % format_time(
			player.finish_time if player.finish_time >= 0 else state.elapsed)
		var lap_seconds: float = state.elapsed - player.lap_started
		if player.finish_time >= 0 and not player.lap_times.is_empty():
			lap_seconds = player.lap_times.back()
		lap_timer.text = "LAP TIME  " + format_time(lap_seconds)
		gauge_speed = absf(player.speed) * 3.6
		speed.text = "%03d" % roundi(gauge_speed)
		gear.text = "R" if player.speed < -1.0 else (
			"N" if gauge_speed < 2.0 else ("1" if gauge_speed < 32.0 else (
			"2" if gauge_speed < 62.0 else "3")))
		gauge.queue_redraw()
		item.text = ["PULSE", "BUOY", "TURBO"][player.item - 1] if player.item > 0 else "EMPTY"
		item_hint.text = "E / B  FIRE" if player.item > 0 else "箱を通過して補給"
		item_icon.visible = player.item > 0
		if player.item > 0:
			item_icon.texture = load("res://assets/items/%s.svg" % ITEMS[player.item - 1])
		center.text = str(ceili(state.countdown)) if state.phase == "countdown" else ""
		if player.finish_time >= 0:
			center.text = "GOAL!"
		if player.speed < -1:
			center.text = "WRONG WAY"
		map.queue_redraw()
	if result.visible:
		standings.text = ""
		var row: int = 1
		for racer_data: Dictionary in state.results():
			standings.text += "%d  %-8s  %s\n\n" % [row, racer_data.name,
				format_time(racer_data.finish_time * result_reveal)]
			row += 1
		best.text = "BEST TIME\n\n" + format_time(state.best_time)


static func format_time(seconds: float) -> String:
	if seconds <= 0:
		return "--:--.--"
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]


func _draw_map() -> void:
	var points: PackedVector2Array = []
	for index: int in range(65):
		var point: Vector3 = Course.sample(index / 64.0 * Course.LENGTH)
		points.append(Vector2(point.x * 1.85 + 107, point.z * 1.25 + 61))
	map.draw_polyline(points, MAGENTA, 7, true)
	for index: int in range(state.racers.size() - 1, -1, -1):
		var point: Vector3 = Course.sample(state.racers[index].progress)
		map.draw_circle(Vector2(point.x * 1.85 + 107, point.z * 1.25 + 61),
			6 if index == 0 else 4, YELLOW if index == 0 else CYAN)


func _draw_garage_map() -> void:
	garage_map.draw_rect(Rect2(0, 0, 587, 245), Color("080c2b"))
	var points: PackedVector2Array = []
	for index: int in range(97):
		var point: Vector3 = Course.sample(index / 96.0 * Course.LENGTH)
		points.append(Vector2(point.x * 4.15 + 290, point.z * 2.7 + 120))
	garage_map.draw_polyline(points, Color("301a63"), 25, true)
	garage_map.draw_polyline(points, CYAN, 7, true)
	garage_map.draw_circle(points[0], 12, YELLOW)
	garage_map.draw_string(theme.default_font, Vector2(24, 31), "COURSE PREVIEW",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, MAGENTA)


func _draw_gauge() -> void:
	var gauge_center: Vector2 = Vector2(126, 104)
	var start: float = PI * 0.76
	var finish: float = PI * 2.24
	gauge.draw_arc(gauge_center, 88, start, finish, 48, Color("23305d"), 17, true)
	gauge.draw_arc(gauge_center, 88, start,
		lerpf(start, finish, clampf(gauge_speed / 120.0, 0.0, 1.0)), 48, MAGENTA, 10, true)
	for index: int in range(11):
		var angle: float = lerpf(start, finish, index / 10.0)
		var outer: Vector2 = gauge_center + Vector2(cos(angle), sin(angle)) * 93
		var inner: Vector2 = gauge_center + Vector2(cos(angle), sin(angle)) * 76
		gauge.draw_line(inner, outer, YELLOW if index % 2 == 0 else CYAN, 3)
	var needle_angle: float = lerpf(start, finish, clampf(gauge_speed / 120.0, 0.0, 1.0))
	gauge.draw_line(gauge_center,
		gauge_center + Vector2(cos(needle_angle), sin(needle_angle)) * 67, YELLOW, 6, true)
	gauge.draw_circle(gauge_center, 10, CYAN)
	gauge.draw_string(theme.default_font, Vector2(10, 24), "SPEED", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 17, CYAN)
	gauge.draw_string(theme.default_font, Vector2(184, 24), "GEAR", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 17, MAGENTA)


func _draw_scanlines(target: Control) -> void:
	for y: int in range(0, 720, 6):
		target.draw_line(Vector2(0, y), Vector2(1280, y), Color(0.02, 0.02, 0.1, 0.07), 1)


func popup(text: String, impact: bool = false) -> void:
	if popup_tween:
		popup_tween.kill()
	notice.text = text
	notice.modulate.a = 1
	notice.scale = Vector2.ONE * 1.08
	popup_tween = create_tween().set_parallel(true)
	popup_tween.tween_property(notice, "scale", Vector2.ONE, 0.16)
	popup_tween.tween_property(notice, "modulate:a", 0.0, 0.5).set_delay(1.0)
	if impact:
		flash.color = Color(1.0, 0.17, 0.58, 0.4)
	popup_tween.tween_property(flash, "color:a", 0.0, 0.2)


func _transition() -> void:
	flash.color = Color(0.12, 0.96, 1.0, 0.54)
	create_tween().tween_property(flash, "color:a", 0.0, 0.32)
