extends Button
## カードの表示は定義データから描画し、ルールの状態を所有しない。

const Catalog = preload("res://scripts/card_catalog.gd")
const Actor = preload("res://scripts/card_actor.gd")
const BACK = preload("res://assets/art/card_back.svg")
const GOLD := Color("dfbc72")
const INK := Color("102536")

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
var font: Font
var actor: Control
var hover_amount: float = 0.0:
	set(value):
		hover_amount = value
		queue_redraw()
var hover_tween: Tween


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
	_sync_actor()


func _sync_actor() -> void:
	if not is_instance_valid(actor):
		actor = Actor.new()
		actor.name = "Character"
		add_child(actor)
	actor.visible = not face_down and not card_id.is_empty()
	if actor.visible:
		actor.position = Vector2(6, 25)
		actor.setup(card_id, Vector2(size.x - 12, size.y - 67))
		actor.modulate = Color("9babc0") if exhausted else Color.WHITE
	pivot_offset = size * 0.5
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
	var border: Color = GOLD if selected or has_focus() else Color("426073")
	border = border.lerp(Color("8affe0"), hover_amount)
	draw_style_box(_box(INK, border), Rect2(Vector2.ZERO, size))
	if face_down:
		draw_texture_rect(BACK, Rect2(5, 5, size.x - 10, size.y - 10), false)
		return
	if card_id.is_empty():
		_line("＋", 0, size.y / 2.0 + 8, size.x, 24, Color("426073"))
		return
	var card: Dictionary = Catalog.card(card_id)
	var accent: Color = Color("f3bc78") if card.type == "monster" \
		and int(card_id.substr(1)) < 12 else Color("96cdec")
	if card.type != "monster":
		accent = Color("d2a2f4") if card.type == "trap" else Color("80dcca")
	draw_rect(Rect2(6, 24, size.x - 12, size.y - 65), Color("071621"))
	draw_line(Vector2(9, 23), Vector2(size.x - 9, 23), Color(accent, 0.55), 1, true)
	draw_line(Vector2(9, size.y - 39), Vector2(size.x - 9, size.y - 39),
		Color(accent, 0.42), 1, true)
	_line(card.name, 5, 18, size.x - 10, 13, Color("f5ead4"))
	var caption: String = "魔法" if card.type == "spell" else "罠・伏せて発動"
	if card.type == "monster":
		caption = "攻 %d  /  守 %d" % [card.attack + bonus, card.defense]
	_line(caption, 4, size.y - 23, size.x - 8, 11, GOLD if bonus == 0 else Color("9effd7"))
	var status: String = "レベル%d・%s" % [card.level, card.attribute]
	if card.type != "monster":
		status = "魔法" if card.type == "spell" else "罠"
	elif defense:
		status = "守備表示"
	elif exhausted:
		status = "攻撃済み"
	_line(status, 4, size.y - 8, size.x - 8, 10, Color("9eb9c5"))


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
	box.shadow_color = Color(0, 0, 0, 0.40)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 3)
	return box
