extends Button
## カードの表示は定義データから描画し、ルールの状態を所有しない。

const Catalog = preload("res://scripts/card_catalog.gd")
const Actor = preload("res://scripts/card_actor.gd")
const BACK = preload("res://assets/art/card_back.svg")
const FRAME = preload("res://assets/art/generated/card_frame.png")
const GOLD := Color("d6b45f")
const INK := Color("173c2a")
const PAPER := Color("e9dfc4")
const BURGUNDY := Color("712f35")

var card_id: String = "":
	set(value):
		card_id = value
		if is_node_ready():
			_sync_actor()
var face_down: bool = false:
	set(value):
		face_down = value
		if is_node_ready():
			_sync_actor()
var selected: bool = false
var defense: bool = false
var exhausted: bool = false
var bonus: int = 0
var compact: bool = false
var available: bool = false
var unavailable_reason: String = ""
var preview_text: String = ""
var font: Font
var actor: Control
var frame: TextureRect
var status_band: Label
var hover_amount: float = 0.0:
	set(value):
		hover_amount = value
		queue_redraw()
var hover_tween: Tween
var pulse: float = 0.0


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font = get_theme_default_font()
	focus_entered.connect(_hover.bind(true))
	focus_exited.connect(_hover.bind(false))
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	button_down.connect(_press)
	button_up.connect(_hover.bind(true))
	resized.connect(_sync_actor)
	set_process(true)
	_sync_actor()


func _sync_actor() -> void:
	if not is_instance_valid(actor):
		actor = Actor.new()
		actor.name = "Character"
		actor.z_index = 1
		add_child(actor)
	actor.visible = not face_down and not card_id.is_empty()
	if actor.visible:
		actor.position = Vector2(8, 24)
		actor.setup(card_id, Vector2(size.x - 16, size.y - 65))
		actor.modulate = Color("9babc0") if exhausted else Color.WHITE
	if not is_instance_valid(frame):
		frame = TextureRect.new()
		frame.name = "Ornament"
		frame.texture = FRAME
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.z_index = 2
		add_child(frame)
	frame.position = Vector2.ZERO
	frame.size = size
	frame.visible = actor.visible
	if not is_instance_valid(status_band):
		status_band = Label.new()
		status_band.name = "StatusBand"
		status_band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_band.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_band.z_index = 3
		status_band.add_theme_font_size_override("font_size", 10)
		add_child(status_band)
	status_band.position = Vector2(8, size.y * 0.42)
	status_band.size = Vector2(size.x - 16, 23)
	_sync_status_band()
	pivot_offset = size * 0.5
	queue_redraw()


func _sync_status_band() -> void:
	status_band.visible = not unavailable_reason.is_empty() or not preview_text.is_empty()
	if not status_band.visible:
		return
	var box := StyleBoxFlat.new()
	if not unavailable_reason.is_empty():
		status_band.text = unavailable_reason
		status_band.add_theme_color_override("font_color", Color("f6e5c1"))
		box.bg_color = Color(0.16, 0.06, 0.05, 0.94)
	else:
		status_band.text = preview_text
		status_band.add_theme_color_override("font_color", Color("fff0b8"))
		box.bg_color = Color(0.04, 0.20, 0.12, 0.94)
	box.set_corner_radius_all(3)
	status_band.add_theme_stylebox_override("normal", box)


func _process(delta: float) -> void:
	if not available:
		return
	pulse = fmod(pulse + delta * 3.0, TAU)
	queue_redraw()


# 演出再生は入力ごとに始めるため非冪等。
func play_action(action: String) -> void:
	if is_instance_valid(actor) and actor.visible:
		actor.play_action(action)


func _hover(entered: bool) -> void:
	if hover_tween:
		hover_tween.kill()
	z_index = 3 if entered else 0
	hover_tween = create_tween().set_parallel(true)
	hover_tween.tween_property(self, "hover_amount", 1.0 if entered else 0.0, 0.12)
	hover_tween.tween_property(self, "scale", Vector2.ONE * (1.035 if entered else 1.0), 0.12)


# 押下ごとの触感を表すため非冪等。離した時は _hover で元に戻す。
func _press() -> void:
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2.ONE * 0.97, 0.06)


func _draw() -> void:
	var border: Color = GOLD if selected or has_focus() else Color("745f3b")
	border = border.lerp(Color("fff0a8"), hover_amount)
	if available:
		border = border.lerp(Color("fff4b8"), 0.45 + sin(pulse) * 0.25)
	draw_style_box(_box(PAPER, border), Rect2(Vector2.ZERO, size))
	if face_down:
		draw_texture_rect(BACK, Rect2(5, 5, size.x - 10, size.y - 10), false)
		return
	if card_id.is_empty():
		_line("空き", 0, size.y / 2.0 + 6, size.x, 13, Color("806f52"))
		return
	var card: Dictionary = Catalog.card(card_id)
	var accent: Color = Color("b7543b") if card.type == "monster" \
		and int(card_id.substr(1)) < 12 else Color("386d68")
	if card.type != "monster":
		accent = BURGUNDY if card.type == "trap" else Color("39755b")
	draw_rect(Rect2(7, 23, size.x - 14, size.y - 63), Color("162b20"))
	draw_line(Vector2(9, 23), Vector2(size.x - 9, 23), Color(accent, 0.55), 1, true)
	draw_line(Vector2(9, size.y - 39), Vector2(size.x - 9, size.y - 39),
		Color(accent, 0.42), 1, true)
	_line(card.name, 5, 18, size.x - 10, 13, INK)
	var caption: String = "魔法" if card.type == "spell" else "罠・伏せて発動"
	if card.type == "monster":
		caption = "攻 %d  /  守 %d" % [card.attack + bonus, card.defense]
	_line(caption, 4, size.y - 23, size.x - 8, 11, BURGUNDY if bonus == 0 else INK)
	var status: String = "レベル%d・%s" % [card.level, card.attribute]
	if card.type != "monster":
		status = "魔法" if card.type == "spell" else "罠"
	elif defense:
		status = "守備表示"
	elif exhausted:
		status = "攻撃済み"
	_line(status, 4, size.y - 8, size.x - 8, 10, Color("385947"))


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
	box.set_border_width_all(3 if available or selected else 2)
	box.set_corner_radius_all(5)
	box.shadow_color = Color(0, 0, 0, 0.40)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	return box
