class_name QuestHealth
extends Control
## HP は演出中の表示値だけを持ち、戦闘の正は Game のままにする。

var bar: ProgressBar
var caption: Label
var maximum: int
var animation: Tween
var fill: StyleBoxFlat


func setup(monster: Dictionary, rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	maximum = Catalog.stats(monster).hp
	bar = ProgressBar.new()
	bar.max_value = maximum
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	bar.size = size
	fill = bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	bar.add_theme_stylebox_override("fill", fill)
	caption = Label.new()
	caption.position.y = size.y + 2
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("617369"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	_set_display(monster.hp)


func present(hp: int, new_maximum: int = 0) -> void:
	if new_maximum > 0:
		maximum = new_maximum
		bar.max_value = maximum
	if animation != null:
		animation.kill()
	animation = create_tween()
	animation.tween_method(_set_display, float(bar.value), float(hp), 0.42)


func _set_display(hp: float) -> void:
	bar.value = hp
	fill.bg_color = Color("c77354") if hp / maximum <= 0.3 else Color("45926b")
	caption.text = "HP  %d / %d" % [roundi(hp), maximum]
