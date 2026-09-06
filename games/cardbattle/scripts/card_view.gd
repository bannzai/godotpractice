extends Button
## カードの表示は定義データから描画し、ルールの状態を所有しない。

const Catalog = preload("res://scripts/card_catalog.gd")
const BACK = preload("res://assets/art/card_back.svg")
const ART := {
	"炎": preload("res://assets/art/fire.svg"),
	"水": preload("res://assets/art/water.svg"),
	"風": preload("res://assets/art/wind.svg"),
	"土": preload("res://assets/art/earth.svg"),
}
const GOLD := Color("dfbc72")
const INK := Color("102536")
var card_id: String = ""
var face_down: bool = false
var selected: bool = false
var defense: bool = false
var exhausted: bool = false
var bonus: int = 0
var compact: bool = false
var font: Font


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font = get_theme_default_font()
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var border: Color = GOLD if selected or has_focus() else Color("426073")
	if is_hovered():
		border = Color("58d6c0")
	draw_style_box(_box(INK, border), Rect2(Vector2.ZERO, size))
	if face_down:
		draw_texture_rect(BACK, Rect2(5, 5, size.x - 10, size.y - 10), false)
		return
	if card_id.is_empty():
		_line("＋", 0, size.y / 2.0 + 8, size.x, 24, Color("426073"))
		return
	var card: Dictionary = Catalog.card(card_id)
	var art_height: float = size.y * 0.49
	draw_texture_rect(
		ART.get(card.attribute, ART["風"]), Rect2(6, 25, size.x - 12, art_height), false
	)
	_line(card.name, 5, 19, size.x - 10, 13, Color("f5ead4"))
	var caption: String = "魔法" if card.type == "spell" else "罠・伏せて発動"
	if card.type == "monster":
		caption = "%s %d  /  %s %d" % ["攻", card.attack + bonus, "守", card.defense]
	_line(caption, 4, size.y - 23, size.x - 8, 11, GOLD)
	var status: String = "レベル%d・%s" % [card.level, card.attribute]
	if card.type != "monster":
		status = "魔法" if card.type == "spell" else "罠"
	elif defense:
		status = "守備表示"
	elif exhausted:
		status = "攻撃済み"
	_line(status, 4, size.y - 8, size.x - 8, 10, Color("9eb9c5"))
	if exhausted:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.06, 0.1, 0.25))


func _line(value: String, x: float, y: float, width: float, pixels: int, color: Color) -> void:
	var text_width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var actual: int = pixels
	if text_width > width:
		actual = maxi(8, int(pixels * width / text_width))
	draw_string(font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_CENTER, width, actual, color)


func _box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	return box
