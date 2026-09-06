extends Control
## 同じキャラの5動作を開始・途中・終了の実描画で比較する撮影専用画面。

const Actor := preload("res://scripts/spirit_actor.gd")
const Catalog := preload("res://scripts/card_catalog.gd")
const POSES: Array[String] = ["idle", "move", "action", "hit", "vanish"]
const POSE_LABELS: Array[String] = ["待機", "移動", "行動", "被弾", "消失"]
const TIMES: Array[float] = [0.0, 0.3, 0.59]
const TIME_LABELS: Array[String] = ["開始", "途中", "終了"]

var character_id: String = ""


func setup(id: String) -> void:
	if character_id == id:
		return
	character_id = id
	for child: Node in get_children():
		child.free()
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = load("res://scenes/ui/theme.tres")
	var background := ColorRect.new()
	background.color = Color("101f27")
	background.size = size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_label("幽契の夜路　人物・霊の動作一覧", Rect2(28, 18, 880, 40), 28)
	_label(_display_name(id), Rect2(900, 18, 350, 40), 28, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("各列の動作を、上から開始・途中・終了の順に静止表示", Rect2(30, 66, 1100, 30), 18)
	for column: int in range(POSES.size()):
		_label(POSE_LABELS[column], Rect2(110 + column * 230, 104, 220, 30), 22,
			HORIZONTAL_ALIGNMENT_CENTER)
	for row: int in range(TIMES.size()):
		_label(TIME_LABELS[row], Rect2(14, 194 + row * 182, 88, 30), 20,
			HORIZONTAL_ALIGNMENT_CENTER)
		_label("%.2f 秒" % TIMES[row], Rect2(14, 225 + row * 182, 88, 30), 16,
			HORIZONTAL_ALIGNMENT_CENTER)
		for column: int in range(POSES.size()):
			_cell(id, column, row)


func _display_name(id: String) -> String:
	if Catalog.CARDS.has(id):
		return str(Catalog.card(id).name)
	if Catalog.ENEMIES.has(id):
		return str(Catalog.enemy(id).name)
	return "札を携えた旅人" if id == "hero" else "夜路の商人"


func _cell(id: String, column: int, row: int) -> void:
	var panel := Panel.new()
	panel.position = Vector2(110 + column * 230, 140 + row * 182)
	panel.size = Vector2(220, 174)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b323b") if row != 1 else Color("203a41")
	style.border_color = Color("6c715b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var actor: Control = Actor.new()
	panel.add_child(actor)
	actor.position = Vector2(10, 7)
	actor.setup(id, Vector2(200, 160))
	actor.seek_pose(POSES[column], TIMES[row])


func _label(
	text: String, rect: Rect2, font_size: int,
	alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
