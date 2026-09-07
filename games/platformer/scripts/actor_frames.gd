class_name ActorFrames
extends RefCounted
## キャラクターごとに独立したシートから、足元を揃えた6フレームの動作を構成する。

const PLAYER_STATES: Array[String] = ["idle", "run", "jump", "fall", "stomp", "hurt", "death"]
const ENEMY_STATES: Array[String] = ["idle", "walk", "attack", "hurt", "death"]
const PLAYER_SHEET: String = "res://assets/images/generated/player_sheet.png"
const WALKER_SHEET: String = "res://assets/images/generated/walker_sheet.png"
const SHELL_SHEET: String = "res://assets/images/generated/shell_sheet.png"
const COMIC_SHADER: String = "res://resources/comic_outline.gdshader"
const FRAME_COUNT: int = 6


static func build(kind: String) -> SpriteFrames:
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation("default")
	var sheet: Texture2D = load(_sheet_path(kind))
	var columns: int = FRAME_COUNT
	var states: Array[String] = PLAYER_STATES if kind == "player" else ENEMY_STATES
	for row: int in states.size():
		var state: String = states[row]
		result.add_animation(state)
		result.set_animation_speed(state, 9.0 if state == "idle" else 14.0)
		result.set_animation_loop(state, state not in ["hurt", "death", "stomp"])
		for frame_index: int in FRAME_COUNT:
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = sheet
			frame.region = _cell_region(sheet, frame_index, row, columns, states.size())
			result.add_frame(state, frame)
	return result


static func normalized_scale(kind: String, frames: SpriteFrames) -> Vector2:
	var frame: AtlasTexture = frames.get_frame_texture("idle", 0) as AtlasTexture
	if frame == null or not frame.region.has_area():
		return Vector2.ONE
	var reference_size: Vector2 = Vector2(64, 80 if kind == "player" else 56)
	return reference_size / frame.region.size


static func build_comic_material() -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = load(COMIC_SHADER) as Shader
	result.set_shader_parameter("key_checker_background", true)
	result.set_shader_parameter("key_chroma_background", true)
	return result


static func _sheet_path(kind: String) -> String:
	match kind:
		"player":
			return PLAYER_SHEET
		"walker":
			return WALKER_SHEET
		"shell":
			return SHELL_SHEET
	return ""


static func _cell_region(
	sheet: Texture2D, column: int, row: int, columns: int, rows: int
) -> Rect2:
	var sheet_size: Vector2 = sheet.get_size()
	var left: int = int(floor(sheet_size.x * column / columns))
	var right: int = int(floor(sheet_size.x * (column + 1) / columns))
	var top: int = int(floor(sheet_size.y * row / rows))
	var bottom: int = int(floor(sheet_size.y * (row + 1) / rows))
	return Rect2(left, top, maxi(1, right - left), maxi(1, bottom - top))
