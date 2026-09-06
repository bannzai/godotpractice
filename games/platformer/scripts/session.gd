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


func reset_run() -> void:
	stage = 0
	score = 0
	coins = 0
	lives = 3
	powered = false
	begin_stage()


func begin_stage() -> void:
	phase = "playing"
	seconds = STAGE_SECONDS
	invulnerable = 0.0
	death_reason = ""


func title() -> void:
	phase = "title"


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
	begin_stage()
