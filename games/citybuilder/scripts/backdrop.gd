extends Control
## タイトル専用の背景。街の状態を持たず、描画だけを更新する。

const KEYART: Texture2D = preload("res://assets/branding/keyart.svg")
const MOUNTAINS: Texture2D = preload("res://assets/backgrounds/mountains.svg")
const CLOUDS: Texture2D = preload("res://assets/backgrounds/clouds.svg")
const CANVAS := Vector2(1280.0, 720.0)

var elapsed: float = 0.0
var parallax := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	# 時間と追従位置の積算は背景アニメーションのため非冪等。
	elapsed += delta
	var pointer := get_local_mouse_position() / CANVAS - Vector2(0.5, 0.5)
	pointer.x = clampf(pointer.x, -0.5, 0.5)
	pointer.y = clampf(pointer.y, -0.5, 0.5)
	parallax = parallax.lerp(pointer, 1.0 - exp(-delta * 2.5))
	queue_redraw()


func _draw() -> void:
	# 余白を外へ拡大して、視差による画面端の空白を防ぐ。
	var town_offset := parallax * Vector2(9.0, 4.0)
	town_offset.x += sin(elapsed * 0.13) * 1.5
	draw_texture_rect(KEYART, Rect2(Vector2(-10, -6) + town_offset, Vector2(1300, 732)), false)
	_draw_horizon()
	_draw_clouds()
	_draw_birds()


func _draw_horizon() -> void:
	# 遠景の上部だけを薄く重ね、街の建物がある高さへは描かない。
	var distant_offset := parallax * Vector2(2.5, 1.0)
	var destination := Rect2(Vector2(-12, 135) + distant_offset, Vector2(1304, 150))
	draw_texture_rect_region(
		MOUNTAINS, destination, Rect2(0, 0, 1280, 147), Color(0.95, 1.0, 0.95, 0.13)
	)


func _draw_clouds() -> void:
	var drift := fmod(elapsed * 5.0, 1280.0)
	var cloud_offset := parallax * Vector2(16.0, 6.0)
	for repeat: int in range(-1, 2):
		var origin := Vector2(drift + repeat * 1280, 10) + cloud_offset
		draw_texture_rect(CLOUDS, Rect2(origin, Vector2(1280, 240)), false, Color(1, 1, 1, 0.45))
	var upper_drift := fmod(elapsed * 2.0, 1536.0)
	for repeat: int in range(-1, 2):
		var origin := Vector2(upper_drift + repeat * 1536 - 170, -120) + parallax * 4.0
		draw_texture_rect(CLOUDS, Rect2(origin, Vector2(1536, 288)), false, Color(1, 1, 1, 0.2))


func _draw_birds() -> void:
	for index: int in range(3):
		var flight := elapsed * 7.0 + index * 24.0
		var center := Vector2(855 + sin(flight * 0.018) * 120, 205 + index * 7)
		center += parallax * 5.0
		center.y += sin(elapsed * 0.7 + index) * 5.0
		var wing := 2.0 + sin(elapsed * 3.5 + index * 0.4) * 1.4
		var tint := Color(0.17, 0.3, 0.32, 0.33)
		draw_line(center - Vector2(5, wing), center, tint, 1.3, true)
		draw_line(center, center + Vector2(5, -wing), tint, 1.3, true)
