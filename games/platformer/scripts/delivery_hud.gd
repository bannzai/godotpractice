class_name DeliveryHUD
extends Control
## プレイ中は収集数と残機だけを画面の両隅に表示し、ゲームの値は常に Session から読む。

var session: Node
var route: DeliveryRoute
var shown_coins: float = 0.0
var previous_lives: int = 3
var coin_value: Label
var life_value: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	session = get_node("/root/Session")
	shown_coins = session.coins
	previous_lives = session.lives
	var coin_badge: Panel = _panel(Rect2(24, 22, 116, 62))
	_add_icon(coin_badge, "ui_coin", Vector2(13, 13))
	coin_value = _label(coin_badge, "%02d" % session.coins, Vector2(56, 11), 27)
	var life_badge: Panel = _panel(Rect2(1140, 22, 116, 62))
	_add_icon(life_badge, "ui_life", Vector2(13, 13))
	life_value = _label(life_badge, "%02d" % session.lives, Vector2(56, 11), 27)


func _process(delta: float) -> void:
	# 取得数の追従と残機変化の強調は経過時間を消費するため非冪等。
	shown_coins = move_toward(shown_coins, session.coins, delta * 12)
	coin_value.text = "%02d" % int(shown_coins)
	life_value.text = "%02d" % session.lives
	if previous_lives != session.lives:
		previous_lives = session.lives
		life_value.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(life_value, "scale", Vector2.ONE, 0.3)


func _panel(rect: Rect2) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _add_icon(parent: Node, file: String, at: Vector2) -> void:
	var icon: TextureRect = TextureRect.new()
	icon.texture = load("res://assets/images/%s.svg" % file)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = at
	icon.size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


func _label(parent: Node, text: String, at: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.size = Vector2(53, 40)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color("132d38"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
