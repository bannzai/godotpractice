class_name DeliveryHUD
extends Control
## 補間値は表示専用。ゲームの値は常に Session から読む。

var session: Node
var route: DeliveryRoute
var values: Array[Label] = []
var shown_score: float = 0.0
var shown_coins: float = 0.0
var previous_lives: int = 3
var progress: ProgressBar
var power_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	session = get_node("/root/Session")
	shown_score = session.score
	shown_coins = session.coins
	previous_lives = session.lives
	var route_card: Panel = _panel(Rect2(28, 24, 370, 88))
	_label(route_card, "%02d  /  02" % (session.stage + 1), Vector2(20, 13), 14)
	_label(route_card, DeliveryRoute.NAMES[session.stage], Vector2(112, 10), 25)
	_label(route_card, "ひかりを右端のポストへ", Vector2(20, 51), 15)
	progress = ProgressBar.new()
	progress.position = Vector2(228, 60)
	progress.show_percentage = false
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color("3a9891")
	fill.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("fill", fill)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color("d8ded1")
	track.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", track)
	route_card.add_child(progress)
	progress.size = Vector2(120, 7)
	var names: Array[String] = ["スコア", "集めたひかり", "残りの便", "残り時間"]
	var icons: Array[String] = ["ui_score", "ui_coin", "ui_life", "ui_time"]
	for index: int in 4:
		var card: Panel = _panel(Rect2(418 + index * 210, 24, 192, 88))
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("res://assets/images/%s.svg" % icons[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.position = Vector2(14, 30)
		icon.size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		_label(card, names[index], Vector2(57, 11), 14)
		var value: Label = _label(card, "", Vector2(55, 33), 28)
		value.pivot_offset = Vector2(58, 21)
		values.append(value)
	power_label = _label(self, "", Vector2(35, 121), 17)
	power_label.add_theme_color_override("font_color", Color("fff6d8"))
	power_label.add_theme_color_override("font_shadow_color", Color("153e4a"))
	power_label.add_theme_constant_override("shadow_offset_y", 2)


func _process(delta: float) -> void:
	# 取得時の数値の追従は経過時間を消費するため非冪等。
	shown_score = move_toward(shown_score, session.score,
		maxf(150, absf(session.score - shown_score) * 8) * delta)
	shown_coins = move_toward(shown_coins, session.coins, delta * 12)
	values[0].text = "%06d" % int(shown_score)
	values[1].text = "%02d" % int(shown_coins)
	values[2].text = "%02d" % session.lives
	values[3].text = "%03d" % int(ceil(session.seconds))
	values[3].add_theme_color_override("font_color",
		Color("ba5547") if session.seconds < 30 else Color("153e4a"))
	if previous_lives != session.lives:
		previous_lives = session.lives
		values[2].scale = Vector2(1.35, 1.35)
		create_tween().tween_property(values[2], "scale", Vector2.ONE, 0.3)
	power_label.text = "ひかりの加護  /  あと一度、衝突に耐えられます" if session.powered else ""
	if is_instance_valid(route):
		progress.value = route.player.position.x / route.goal_x * 100


func _panel(rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _label(parent: Node, text: String, at: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
