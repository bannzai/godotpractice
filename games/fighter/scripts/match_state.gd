extends Node
## 画面をまたぐ試合状態。時間更新は経過時間を消費するため非冪等。

enum Screen { TITLE, SELECT, FIGHT, RESULT }

var screen: Screen = Screen.TITLE
var selected: int = 0
var wins: Array[int] = [0, 0]
var round_number: int = 1
var remaining: float = 99.0
var round_over: bool = false
var round_winner: int = -1
var reason: String = ""


func reset_match(character: int) -> void:
	selected = clampi(character, 0, 1)
	wins = [0, 0]
	round_number = 1
	reset_round()
	screen = Screen.FIGHT


func reset_round() -> void:
	remaining = 99.0
	round_over = false
	round_winner = -1
	reason = ""


func tick(delta: float, player_hp: int, cpu_hp: int) -> void:
	if round_over or screen != Screen.FIGHT:
		return
	remaining = maxf(0.0, remaining - delta)
	if player_hp <= 0 or cpu_hp <= 0 or remaining <= 0.0:
		finish_round(player_hp, cpu_hp)


func finish_round(player_hp: int, cpu_hp: int) -> void:
	if round_over:
		return
	round_over = true
	reason = "決着" if player_hp <= 0 or cpu_hp <= 0 else "時間切れ"
	round_winner = winner(player_hp, cpu_hp)
	if round_winner >= 0:
		wins[round_winner] += 1


func advance_round() -> void:
	if not round_over:
		return
	if wins.max() >= 2:
		screen = Screen.RESULT
	else:
		round_number += 1
		reset_round()


static func winner(player_hp: int, cpu_hp: int) -> int:
	if player_hp == cpu_hp:
		return -1
	return 0 if player_hp > cpu_hp else 1
