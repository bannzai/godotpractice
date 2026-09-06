extends Node
## 都市と画面をまたぐ進行の唯一の保持先。

signal changed
signal phase_changed
signal notice(message: String)

const Sim = preload("res://scripts/simulation.gd")
const SAVE_PATH: String = "user://city-save.json"

var state: Dictionary = {}
var analysis: Dictionary = {}
var phase: String = "title"
var speed: int = 1
var elapsed: float = 0.0
var save_path: String = SAVE_PATH
var saving_enabled: bool = true


func _ready() -> void:
	state = Sim.new_city()
	analysis = Sim.analyze(state)


# 月内の経過時間を積算するゲームループのため非冪等。
func _process(delta: float) -> void:
	if phase != "playing" or speed == 0:
		return
	elapsed += delta * speed
	if elapsed >= 4.0:
		elapsed -= 4.0
		next_month()


func start_city() -> void:
	state = Sim.new_city()
	analysis = Sim.analyze(state)
	elapsed = 0.0
	speed = 1
	set_phase("playing")
	changed.emit()


func set_phase(value: String) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit()


# 月送りはプレイヤーの操作またはタイマーに対して一度だけ進める。
func next_month() -> void:
	if phase != "playing":
		return
	state = Sim.advance_month(state)
	analysis = Sim.analyze(state)
	changed.emit()
	notice.emit("%d月の収支  %+d" % [state.month, state.income - state.expenses])
	if state.outcome != "playing":
		set_phase("result")
	else:
		save_city()


func build(cell: Vector2i, kind: String) -> bool:
	if phase != "playing" or not Sim.can_place(state, cell, kind):
		notice.emit("ここには建設できません。空き地・資金・水辺を確認")
		return false
	state = Sim.place(state, cell, kind)
	analysis = Sim.analyze(state)
	changed.emit()
	return true


func set_tax(value: float) -> void:
	state.tax = int(value)
	analysis = Sim.analyze(state)
	changed.emit()


func save_city() -> bool:
	if not saving_enabled:
		return true
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		notice.emit("保存できませんでした。空き容量を確認してください")
		return false
	file.store_string(JSON.stringify(state))
	return true


func saved_city() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(save_path)) != OK:
		return {}
	return Sim.decode_save(json.data)


func resume_city() -> bool:
	var saved: Dictionary = saved_city()
	if saved.is_empty():
		notice.emit("再開できる保存データがありません")
		return false
	state = saved
	analysis = Sim.analyze(state)
	elapsed = 0.0
	speed = 1
	set_phase("playing" if state.outcome == "playing" else "result")
	changed.emit()
	return true
