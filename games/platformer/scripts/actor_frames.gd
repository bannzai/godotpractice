class_name ActorFrames
extends RefCounted
## キャラクターごとに独立したシートから、足元を揃えた6フレームの動作を構成する。

const PLAYER_STATES: Array[String] = ["idle", "run", "jump", "fall", "stomp", "hurt", "death"]
const ENEMY_STATES: Array[String] = ["idle", "walk", "attack", "hurt", "death"]


static func build(kind: String) -> SpriteFrames:
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation("default")
	var sheet: Texture2D = load("res://assets/images/%s_sheet.svg" % kind)
	var cell: Vector2 = Vector2(64, 80 if kind == "player" else 56)
	var states: Array[String] = PLAYER_STATES if kind == "player" else ENEMY_STATES
	for row: int in states.size():
		var state: String = states[row]
		result.add_animation(state)
		result.set_animation_speed(state, 9.0 if state == "idle" else 14.0)
		result.set_animation_loop(state, state not in ["hurt", "death", "stomp"])
		for column: int in 6:
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(column, row) * cell, cell)
			result.add_frame(state, frame)
	return result
