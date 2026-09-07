extends Control
## 霊の攻撃・被弾・消滅を、三つの斜めコマで全画面に重ねる。
## ゲーム進行の状態は持たず、同梱アトラスと一時的な演出状態だけを扱う。

signal finished

const STAGE_SIZE := Vector2(1280.0, 720.0)
const ATLAS_PATH := "res://assets/generated/spirit-cutins.png"
const ATLAS_COLUMNS: int = 4
const ATLAS_ROWS: int = 3
const SPIRIT_IDS: Array[String] = [
	"child", "warrior", "water", "beast",
	"headless", "doll", "crow", "monk",
	"moth", "fox", "bride", "bell",
]
const ACTIONS: Array[String] = ["attack", "hurt", "dissolve"]
const ACTION_DURATIONS: Dictionary = {
	"attack": 0.76,
	"hurt": 0.64,
	"dissolve": 1.02,
}
const INK_BLACK := Color("050505")
const FLASHLIGHT_YELLOW := Color("ffd84a")
const BLOOD_RED := Color("c51f2f")
const SPIRIT_BLUE := Color("c4f7ff")
const PAPER_WHITE := Color("f4ecd9")
const PANEL_SHADER := """
shader_type canvas_item;

uniform vec4 ink_tint : source_color = vec4(1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(source.rgb, vec3(gray), desaturate);
	COLOR = source * ink_tint;
	COLOR.a *= fade;
}
"""
const TONE_SHADER := """
shader_type canvas_item;

uniform float opacity : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec2 cell = fract(UV * vec2(182.0, 103.0)) - vec2(0.5);
	float dot_shape = 1.0 - smoothstep(0.12, 0.27, length(cell));
	COLOR = vec4(0.0, 0.0, 0.0, dot_shape * opacity);
}
"""

var _action: String = "attack"
var _caption: String = ""
var _portrait: AtlasTexture
var _panels: Array[Polygon2D] = []
var _frames: Array[Line2D] = []
var _accent_frames: Array[Line2D] = []
var _background: ColorRect
var _tone: ColorRect
var _flash: ColorRect
var _caption_group: Control
var _caption_label: Label
var _action_label: Label
var _caption_rule: ColorRect
var _play_tween: Tween
var _play_generation: int = 0
var _built: bool = false


func _ready() -> void:
	_ensure_built()


## 同じ引数なら同じ初期表示へ戻すため冪等。
func setup(spirit_id: String, action: String, caption: String = "") -> void:
	_ensure_built()
	_cancel_playback()
	_action = action if action in ACTIONS else "attack"
	_caption = caption if not caption.is_empty() else _default_caption(_action)
	_select_portrait(spirit_id if spirit_id in SPIRIT_IDS else SPIRIT_IDS[0])
	_action_label.text = _action_word(_action)
	_caption_label.text = _caption
	_apply_progress(0.0)
	hide()


## 一回のカットインと finished の通知を発生させるため非冪等。
func play() -> void:
	_ensure_built()
	_cancel_playback()
	_play_generation += 1
	var generation: int = _play_generation
	show()
	_apply_progress(0.0)
	_play_tween = create_tween()
	_play_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_play_tween.set_trans(Tween.TRANS_QUART)
	_play_tween.set_ease(Tween.EASE_OUT)
	_play_tween.tween_method(
		_apply_progress,
		0.0,
		1.0,
		float(ACTION_DURATIONS[_action])
	)
	# 最終姿勢を一フレーム以上描画してから閉じる。
	_play_tween.tween_interval(0.05)
	_play_tween.finished.connect(_finish_playback.bind(generation), CONNECT_ONE_SHOT)


## 同じ進捗なら同じコマ・色・位置を再現するため冪等。
func seek_progress(progress: float) -> void:
	_ensure_built()
	_cancel_playback()
	show()
	_apply_progress(clampf(progress, 0.0, 1.0))


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	z_index = 100

	_background = ColorRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.color = INK_BLACK
	_background.size = STAGE_SIZE
	add_child(_background)

	var image_shader := Shader.new()
	image_shader.code = PANEL_SHADER
	for index: int in range(3):
		var panel := Polygon2D.new()
		panel.polygon = _panel_points(index)
		panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var panel_material := ShaderMaterial.new()
		panel_material.shader = image_shader
		panel.material = panel_material
		add_child(panel)
		_panels.append(panel)

	_tone = ColorRect.new()
	_tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tone.color = Color.WHITE
	_tone.size = STAGE_SIZE
	var tone_shader := Shader.new()
	tone_shader.code = TONE_SHADER
	var tone_material := ShaderMaterial.new()
	tone_material.shader = tone_shader
	_tone.material = tone_material
	add_child(_tone)

	for index: int in range(3):
		var frame := _make_frame(_panel_points(index), INK_BLACK, 18.0)
		add_child(frame)
		_frames.append(frame)
		var accent_frame := _make_frame(_panel_points(index), FLASHLIGHT_YELLOW, 3.0)
		add_child(accent_frame)
		_accent_frames.append(accent_frame)

	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = STAGE_SIZE
	add_child(_flash)

	_make_caption()
	_select_portrait(SPIRIT_IDS[0])
	hide()


func _make_frame(points: PackedVector2Array, color: Color, width: float) -> Line2D:
	var frame := Line2D.new()
	frame.points = points
	frame.closed = true
	frame.width = width
	frame.default_color = color
	frame.antialiased = true
	return frame


func _make_caption() -> void:
	_caption_group = Control.new()
	_caption_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_group.position = Vector2(42.0, 578.0)
	_caption_group.size = Vector2(1196.0, 116.0)
	add_child(_caption_group)

	var caption_back := ColorRect.new()
	caption_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_back.color = Color("050505ed")
	caption_back.size = _caption_group.size
	_caption_group.add_child(caption_back)

	_caption_rule = ColorRect.new()
	_caption_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_rule.color = FLASHLIGHT_YELLOW
	_caption_rule.position = Vector2(0.0, 0.0)
	_caption_rule.size = Vector2(_caption_group.size.x, 6.0)
	_caption_group.add_child(_caption_rule)

	_action_label = Label.new()
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_label.position = Vector2(24.0, 11.0)
	_action_label.size = Vector2(146.0, 94.0)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 58)
	_action_label.add_theme_color_override("font_color", FLASHLIGHT_YELLOW)
	_caption_group.add_child(_action_label)

	_caption_label = Label.new()
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.position = Vector2(185.0, 14.0)
	_caption_label.size = Vector2(976.0, 91.0)
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.add_theme_font_size_override("font_size", 30)
	_caption_label.add_theme_color_override("font_color", PAPER_WHITE)
	_caption_group.add_child(_caption_label)


func _select_portrait(spirit_id: String) -> void:
	var source: Texture2D = load(ATLAS_PATH) as Texture2D
	var index: int = SPIRIT_IDS.find(spirit_id)
	var cell_size := Vector2(
		float(source.get_width()) / float(ATLAS_COLUMNS),
		float(source.get_height()) / float(ATLAS_ROWS)
	)
	_portrait = AtlasTexture.new()
	_portrait.atlas = source
	_portrait.region = Rect2(
		float(index % ATLAS_COLUMNS) * cell_size.x,
		float(index / ATLAS_COLUMNS) * cell_size.y,
		cell_size.x,
		cell_size.y
	)
	_portrait.filter_clip = true
	for panel: Polygon2D in _panels:
		panel.texture = _portrait


func _apply_progress(value: float) -> void:
	var progress: float = clampf(value, 0.0, 1.0)
	var entering: float = smoothstep(0.0, 0.18, progress)
	var leaving: float = smoothstep(0.78, 1.0, progress)
	var entrance_alpha: float = lerpf(0.26, 1.0, entering)
	var exit_alpha: float = lerpf(1.0, 0.32, leaving)
	var alpha: float = entrance_alpha * exit_alpha
	var impact: float = _action_impact(progress)
	var accent: Color = _action_color(_action)

	if _action == "dissolve":
		alpha *= lerpf(1.0, 0.46, smoothstep(0.52, 1.0, progress))
	_background.modulate = Color(1.0, 1.0, 1.0, alpha * 0.96)
	for index: int in range(_panels.size()):
		_apply_panel(index, progress, entering, alpha, impact, accent)

	var tone_material := _tone.material as ShaderMaterial
	tone_material.set_shader_parameter("opacity", alpha * (0.17 + impact * 0.16))
	_tone.modulate = Color(1.0, 1.0, 1.0, alpha)
	_flash.color = Color(accent.r, accent.g, accent.b, impact * _flash_strength())
	_caption_group.position = Vector2(42.0, lerpf(720.0, 578.0, entering))
	_caption_group.modulate = Color(1.0, 1.0, 1.0, alpha)
	_action_label.add_theme_color_override("font_color", accent)
	_caption_rule.color = accent
	_action_label.rotation = sin(progress * TAU * 8.0) * impact * 0.035


func _apply_panel(index: int, progress: float, entering: float, alpha: float,
		impact: float, accent: Color) -> void:
	var panel: Polygon2D = _panels[index]
	var direction: float = -1.0 if index % 2 == 0 else 1.0
	var position_offset: Vector2 = _entry_offset(index) * (1.0 - entering)
	var shake_strength: float = 0.0
	if _action == "attack":
		shake_strength = impact * 13.0
		position_offset.x += progress * direction * 22.0
	elif _action == "hurt":
		shake_strength = impact * 24.0
		position_offset.y += impact * 8.0
	else:
		position_offset.y -= progress * (24.0 + float(index) * 12.0)
	var shake := Vector2(
		sin(progress * TAU * (11.0 + float(index))) * shake_strength,
		cos(progress * TAU * (9.0 + float(index))) * shake_strength * 0.42
	)
	panel.position = position_offset + shake
	_frames[index].position = panel.position
	_accent_frames[index].position = panel.position
	_accent_frames[index].default_color = accent
	_accent_frames[index].modulate = Color(1.0, 1.0, 1.0, alpha)
	_frames[index].modulate = Color(1.0, 1.0, 1.0, alpha)
	panel.uv = _panel_uv(index, progress, impact)

	var panel_material := panel.material as ShaderMaterial
	var desaturate: float = progress * 0.92 if _action == "dissolve" else impact * 0.16
	var tint_amount: float = 0.42 if _action == "hurt" else 0.30
	var tint_mix: float = tint_amount * impact
	if _action == "dissolve":
		tint_amount = progress * 0.58
		tint_mix = tint_amount
	panel_material.set_shader_parameter("desaturate", desaturate)
	panel_material.set_shader_parameter("ink_tint", Color.WHITE.lerp(accent, tint_mix))
	panel_material.set_shader_parameter("fade", alpha * (0.82 + float(index) * 0.08))


func _panel_uv(index: int, progress: float, impact: float) -> PackedVector2Array:
	var texture_size: Vector2 = _portrait.get_size()
	var zoom: float = [1.08, 1.38, 1.68][index]
	if _action == "attack":
		zoom += progress * 0.24 + impact * 0.12
	elif _action == "hurt":
		zoom += impact * 0.22
	else:
		zoom += progress * 0.10
	var center: Vector2 = texture_size * (Vector2(0.5, 0.5) + _panel_pan(index))
	if _action == "attack":
		center.x += progress * texture_size.x * (0.04 if index != 0 else -0.03)
	elif _action == "dissolve":
		center.y -= progress * texture_size.y * 0.08
	var half_view: Vector2 = texture_size / zoom * 0.5
	center.x = clampf(center.x, half_view.x, texture_size.x - half_view.x)
	center.y = clampf(center.y, half_view.y, texture_size.y - half_view.y)
	var top_left: Vector2 = center - half_view
	var bottom_right: Vector2 = center + half_view
	return PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
	])


func _panel_points(index: int) -> PackedVector2Array:
	match index:
		0:
			return PackedVector2Array([
				Vector2(-26.0, -18.0), Vector2(391.0, -18.0),
				Vector2(286.0, 738.0), Vector2(-26.0, 738.0),
			])
		1:
			return PackedVector2Array([
				Vector2(416.0, -18.0), Vector2(831.0, -18.0),
				Vector2(941.0, 738.0), Vector2(311.0, 738.0),
			])
		_:
			return PackedVector2Array([
				Vector2(856.0, -18.0), Vector2(1306.0, -18.0),
				Vector2(1306.0, 738.0), Vector2(966.0, 738.0),
			])


func _entry_offset(index: int) -> Vector2:
	return [Vector2(-190.0, 0.0), Vector2(0.0, -160.0), Vector2(190.0, 0.0)][index]


func _panel_pan(index: int) -> Vector2:
	return [Vector2(-0.04, 0.02), Vector2(0.02, -0.09), Vector2(0.06, -0.15)][index]


func _action_impact(progress: float) -> float:
	var center: float = 0.43
	var width: float = 0.17
	if _action == "hurt":
		center = 0.31
		width = 0.15
	elif _action == "dissolve":
		center = 0.62
		width = 0.28
	var pulse: float = clampf(1.0 - absf(progress - center) / width, 0.0, 1.0)
	return pulse * pulse


func _flash_strength() -> float:
	match _action:
		"hurt":
			return 0.30
		"dissolve":
			return 0.15
		_:
			return 0.20


func _action_color(action: String) -> Color:
	match action:
		"hurt":
			return BLOOD_RED
		"dissolve":
			return SPIRIT_BLUE
		_:
			return FLASHLIGHT_YELLOW


func _action_word(action: String) -> String:
	match action:
		"hurt":
			return "傷"
		"dissolve":
			return "滅"
		_:
			return "撃"


func _default_caption(action: String) -> String:
	match action:
		"hurt":
			return "霊体を裂く衝撃が走る。"
		"dissolve":
			return "輪郭が青白い残響へほどけていく。"
		_:
			return "闇を切り裂き、標的へ襲いかかる。"


func _cancel_playback() -> void:
	_play_generation += 1
	if _play_tween != null and _play_tween.is_valid():
		_play_tween.kill()
	_play_tween = null


func _finish_playback(generation: int) -> void:
	if generation != _play_generation:
		return
	_play_tween = null
	_apply_progress(1.0)
	hide()
	finished.emit()
