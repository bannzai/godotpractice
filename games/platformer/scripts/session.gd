extends Node
## 画面をまたぐ進行の唯一の状態。tick と取得イベントは時間・入力を消費するため非冪等。

const STAGE_SECONDS: float = 180.0
const STAGE_COUNT: int = 2
var phase: String = "title"
var stage: int = 0
var score: int = 0
var coins: int = 0
var lives: int = 3
var powered: bool = false
var seconds: float = STAGE_SECONDS
var invulnerable: float = 0.0
var death_reason: String = ""
var unlocked_stage: int = 0
var tutorial_seen: bool = false
var tutorial_step: int = 0


func reset_run() -> void:
	_reset_run_values()
	begin_stage()


func reset_run_to_map() -> void:
	_reset_run_values()
	phase = "map"


func _reset_run_values() -> void:
	stage = 0
	score = 0
	coins = 0
	lives = 3
	powered = false
	unlocked_stage = 0
	tutorial_step = 0


func begin_stage() -> void:
	phase = "playing"
	seconds = STAGE_SECONDS
	invulnerable = 0.0
	death_reason = ""
	tutorial_step = 3 if tutorial_seen or stage > 0 else 0


func title() -> void:
	phase = "title"


func show_map() -> void:
	phase = "map"


func select_stage(stage_index: int) -> bool:
	if phase != "map" or stage_index < 0 or stage_index > unlocked_stage:
		return false
	if stage_index >= STAGE_COUNT:
		return false
	stage = stage_index
	begin_stage()
	return true


func advance_to_map() -> bool:
	if phase != "stage_clear":
		return false
	unlocked_stage = mini(STAGE_COUNT - 1, maxi(unlocked_stage, stage + 1))
	stage = unlocked_stage
	phase = "map"
	return true


func start_tutorial() -> void:
	if phase == "playing" and stage == 0 and not tutorial_seen:
		tutorial_step = 0


func advance_tutorial() -> void:
	if phase != "playing" or tutorial_seen:
		return
	tutorial_step += 1
	if tutorial_step >= 3:
		finish_tutorial()


func finish_tutorial() -> void:
	tutorial_step = 3
	tutorial_seen = true


func collect_coin() -> void:
	if phase == "playing":
		coins += 1
		score += 100


func collect_power() -> void:
	if phase == "playing":
		powered = true
		invulnerable = 1.2
		score += 500


func damage(fatal: bool = false, reason: String = "敵にぶつかった") -> String:
	if phase != "playing" or (not fatal and invulnerable > 0.0):
		return "ignored"
	if powered and not fatal:
		powered = false
		invulnerable = 1.8
		return "shrunk"
	powered = false
	lives -= 1
	phase = "game_over" if lives == 0 else "dead"
	death_reason = reason
	return "dead"


func tick(delta: float) -> void:
	if phase != "playing":
		return
	invulnerable = maxf(0.0, invulnerable - delta)
	seconds = maxf(0.0, seconds - delta)
	if seconds == 0.0:
		damage(true, "時間切れ")


func finish_stage() -> void:
	if phase != "playing":
		return
	score += int(ceil(seconds)) * 10
	phase = "complete" if stage == STAGE_COUNT - 1 else "stage_clear"


func advance_stage() -> void:
	if phase != "stage_clear":
		return
	stage += 1
	unlocked_stage = maxi(unlocked_stage, stage)
	begin_stage()
