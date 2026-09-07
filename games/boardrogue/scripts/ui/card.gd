extends Button
## 盤上と手札の札。伏せた敵札は絵・名前・説明のすべてを隠す。

signal dragged(data: Dictionary, target: Vector2i)

const BACK = preload("res://assets/art/logo_mark.svg")
const Catalog = preload("res://scripts/core/catalog.gd")
const Actor = preload("res://scripts/visual/actor.gd")
const UI = preload("res://scripts/ui/widgets.gd")

var card_id: String = ""
var concealed: bool = false
var face_down: bool = false
var side: int = 0
var selected: bool = false
var exhausted: bool = false
var board_pos := Vector2i(-1, -1)
var hand_index: int = -1
var unit_uid: int = -1
var actor: Node2D
var legal: bool = false


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size / 2
	_sync_actor()
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(legal)


func _process(_delta: float) -> void:
	if legal:
		queue_redraw()


func _draw() -> void:
	var accent: Color = UI.JADE if side == 0 else UI.RED
	var border: Color = UI.GOLD if selected or has_focus() else Color(accent, 0.45)
	if legal:
		var pulse: float = 0.66 + sin(Time.get_ticks_msec() * 0.008) * 0.28
		border = Color(UI.RED if side == 1 else UI.JADE, pulse)
	var fill := Color("ead7adf2") if side == 0 else Color("d9c49af2")
	if is_hovered():
		fill = fill.lightened(0.13)
	draw_style_box(UI.box(fill, border), Rect2(Vector2.ZERO, size))
	if legal:
		draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), Color(border, 0.35), false, 3.0)
	if card_id.is_empty():
		_line("・" if not legal else "◇", size.y / 2 + 8, 22, border)
		return
	if concealed:
		draw_texture_rect(
			BACK, Rect2(size.x / 2 - 23, size.y / 2 - 28, 46, 46), false, Color(UI.GOLD, 0.7)
		)
		_line("潜伏", size.y - 8, 13, UI.GOLD)
		return
	var card: Dictionary = Catalog.CARDS[card_id]
	_line(card.name, 17, 13, UI.INK)
	var status: String = "攻 %d" % int(card.atk)
	if face_down:
		status += "・伏"
	elif exhausted:
		status += "・済"
	_line(status, size.y - 6, 13, UI.GOLD)


func _line(value: String, y: float, pixels: int, color: Color) -> void:
	draw_string(
		get_theme_default_font(),
		Vector2(2, y),
		value,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 4,
		pixels,
		color
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if (hand_index < 0 and unit_uid < 0) or side != 0 or concealed:
		return null
	var preview := Label.new()
	preview.text = Catalog.CARDS[card_id].name
	preview.add_theme_color_override("font_color", UI.GOLD)
	set_drag_preview(preview)
	return {"hand": hand_index, "uid": unit_uid}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return board_pos.x >= 0 and data is Dictionary and data.has("hand") and data.has("uid")


# ドラッグ完了という入力イベントを一度配送するため非冪等。
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dragged.emit(data, board_pos)


func reveal_face() -> void:
	concealed = false
	face_down = false
	_sync_actor()
	queue_redraw()


func _sync_actor() -> void:
	if card_id.is_empty() or concealed:
		return
	if not is_instance_valid(actor):
		actor = Actor.new()
		add_child(actor)
	actor.position = Vector2(size.x / 2, size.y / 2 + 2)
	actor.setup(card_id, minf((size.x - 10) / 256.0, (size.y - 27) / 320.0))
	actor.modulate = Color.WHITE
	if face_down:
		actor.modulate.a = 0.34
	if exhausted:
		actor.modulate = Color("8f9a91")
