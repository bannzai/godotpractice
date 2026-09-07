class_name FighterVisual
extends AnimatedSprite2D
## 判定側の時間からフレームを選び、独立再生によるヒットストップ中の進行を防ぐ。

const TEAL: SpriteFrames = preload("res://assets/characters/teal-frames.tres")
const AMBER: SpriteFrames = preload("res://assets/characters/amber-frames.tres")
const FLASH_SHADER: Shader = preload("res://assets/characters/fighter-flash.gdshader")

var _knockout_time: float = 0.0
var _knockout_delay: float = 0.0
var _hurt_started_at: float = 0.0
var _was_hurt: bool = false
var _flash_material: ShaderMaterial


func configure(index: int) -> void:
	sprite_frames = TEAL if index == 0 else AMBER
	offset = Vector2(0.0, -80.0)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not is_instance_valid(_flash_material):
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = FLASH_SHADER
		material = _flash_material
	_knockout_time = 0.0
	_knockout_delay = 0.0
	_hurt_started_at = 0.0
	_was_hurt = false
	animation = &"idle"
	set_frame_and_progress(0, 0.0)
	pause()
	_flash_material.set_shader_parameter("flash", 0.0)
	_flash_material.set_shader_parameter("accent", Color("a4ffed" if index == 0 else "ffe0a0"))


func start_hurt(at: float) -> void:
	_hurt_started_at = at
	_was_hurt = true


## KO演出だけは入力停止後も経過時間を消費するため非冪等。
func sync_state(body: FighterBody, delta: float, recovery: float) -> void:
	scale.x = body.facing
	_flash_material.set_shader_parameter("flash", clampf(body.hit_flash / 0.16, 0.0, 1.0))
	var next: StringName = _state_animation(body)
	var was_ko: bool = animation == &"ko"
	var hurt: bool = next == &"hurt"
	if hurt and not _was_hurt:
		_hurt_started_at = body.animation_time
	_was_hurt = hurt
	if next != animation:
		animation = next
	if next == &"ko":
		if not was_ko:
			_knockout_time = 0.0
			_knockout_delay = body.hitstop
		_advance_knockout(body, delta)
		_flash_material.set_shader_parameter("flash",
			clampf(body.hit_flash / 0.16, 0.0, 1.0) * maxf(0.0, 1.0 - _knockout_time / 0.16))
		_set_sample(_knockout_time * 8.0, false)
	elif not body.action.is_empty():
		_set_sample(_attack_frame(body, recovery), false)
	elif hurt:
		_set_sample((body.animation_time - _hurt_started_at) * 18.0, false)
	elif next == &"jump":
		_set_sample(clampf((body.velocity.y + 710.0) / 1420.0, 0.0, 1.0) * 7.0, false)
	else:
		_set_sample(body.animation_time * sprite_frames.get_animation_speed(animation), true)


## ラウンド終了で判定時間が止まっても、残りの停止時間と倒れる演出を消費する。
func _advance_knockout(body: FighterBody, delta: float) -> void:
	if not body.visible:
		return
	if body.enabled:
		_knockout_delay = body.hitstop
		if _knockout_delay > 0.0:
			return
	elif _knockout_delay > 0.0:
		_knockout_delay = maxf(0.0, _knockout_delay - delta)
		return
	_knockout_time = minf(0.875, _knockout_time + delta)


func _state_animation(body: FighterBody) -> StringName:
	if body.health <= 0:
		return &"ko"
	if body.stun > 0.0 and not body.is_visually_guarding():
		return &"hurt"
	if not body.action.is_empty():
		if body.action == "special":
			return &"special"
		return StringName(body.attack_stance + "_" + body.action)
	if body.is_visually_guarding():
		return &"crouch_guard" if body.crouching else &"guard"
	var movement: StringName = &"idle"
	if body.position.y < FighterBody.FLOOR_Y - 1.0:
		movement = &"jump"
	elif body.crouching:
		movement = &"crouch"
	elif absf(body.velocity.x) > 15.0:
		movement = &"walk"
	return movement


func _attack_frame(body: FighterBody, recovery: float) -> float:
	var startup: float = float(body.move_data.startup)
	var active: float = float(body.move_data.active)
	if body.attack_time < startup:
		return clampf(body.attack_time / startup, 0.0, 1.0) * 3.0
	if body.attack_time < startup + active:
		return 3.0 + (body.attack_time - startup) / active * 2.0
	return 5.0 + clampf((body.attack_time - startup - active) / recovery, 0.0, 1.0) * 2.99


func _set_sample(sample: float, loop: bool) -> void:
	var count: int = sprite_frames.get_frame_count(animation)
	var cursor: float = fposmod(sample, float(count)) if loop else clampf(sample, 0.0, count - 1.0)
	set_frame_and_progress(int(cursor), fposmod(cursor, 1.0))
