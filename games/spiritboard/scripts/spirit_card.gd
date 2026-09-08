extends Button
## 札の表示。非公開の札は名前・攻撃力・画像を描かない。

const UI = preload("res://scripts/spirit_ui.gd")
const Catalog = preload("res://scripts/card_catalog.gd")

var card_id: String = ""
var face_down: bool = false
var selected: bool = false
var exhausted: bool = false
var power: int = 0
var compact: bool = false
var actor: Control
var illustration: Texture2D
var back: Texture2D
var hover: float = 0.0
var hover_tween: Tween


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back = load("res://assets/art/card_back.svg")
	if not card_id.is_empty():
		illustration = load("res://assets/art/%s.svg" % card_id)
	focus_entered.connect(_hover.bind(true))
	focus_exited.connect(_hover.bind(false))
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	button_down.connect(_press)
	if not face_down and not card_id.is_empty() and compact:
		actor = load("res://scripts/spirit_actor.gd").new()
		add_child(actor)
		actor.position = Vector2(8, 20)
		actor.setup(card_id, Vector2(size.x - 16, size.y - 42))
	queue_redraw()


func _draw() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("172d32") if compact else Color("d9cfb1")
	style.border_color = UI.JADE if hover > 0.3 else UI.GOLD if selected else Color("617063")
	style.set_border_width_all(3 if selected or has_focus() else 1)
	style.set_corner_radius_all(3)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if face_down:
		draw_texture_rect(back, Rect2(5, 5, size.x - 10, size.y - 10), false)
		return
	if card_id.is_empty():
		return
	var ink: Color = UI.PAPER if compact else Color("263a3b")
	var font: Font = get_theme_default_font()
	var card: Dictionary = Catalog.card(card_id)
	if not compact:
		var area: Vector2 = Vector2(size.x - 8, size.y - 43)
		var image_size: Vector2 = illustration.get_size()
		var fitted: Vector2 = image_size * minf(area.x / image_size.x, area.y / image_size.y)
		draw_texture_rect(
			illustration, Rect2(Vector2(4, 21) + (area - fitted) / 2.0, fitted), false
		)
	draw_string(
		font, Vector2(7, 17), str(card.name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, 15, ink
	)
	draw_string(
		font,
		Vector2(7, size.y - 7),
		"攻 %d" % power,
		HORIZONTAL_ALIGNMENT_LEFT,
		80,
		16,
		UI.GOLD if compact else ink
	)
	if exhausted:
		draw_rect(Rect2(3, 22, size.x - 6, size.y - 25), Color(0.08, 0.11, 0.14, 0.4))
		draw_string(
			font, Vector2(size.x - 44, size.y - 8), "済", HORIZONTAL_ALIGNMENT_LEFT, 40, 16, UI.MUTED
		)


# マウス・フォーカス入力一回の触感として再生するため非冪等。
func _hover(entered: bool) -> void:
	if hover_tween:
		hover_tween.kill()
	pivot_offset = size * 0.5
	z_index = 5 if entered else 0
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "hover", 1.0 if entered else 0.0, 0.12)
	hover_tween.tween_property(self, "scale", Vector2.ONE * (1.035 if entered else 1.0), 0.12)
	hover_tween.tween_method(func(_value: float) -> void: queue_redraw(), 0.0, 1.0, 0.12)


func _press() -> void:
	scale = Vector2.ONE * 0.97
	_hover(true)
