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
var tutorial_active: bool = false
var tutorial_step: int = 0
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
	speed = 0
	tutorial_active = true
	tutorial_step = 0
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
	save_city()
	if state.outcome != "playing":
		set_phase("result")


func advance_now() -> void:
	elapsed = 0.0
	next_month()


func advance_tutorial() -> bool:
	if not tutorial_active:
		return false
	if tutorial_step < 2:
		tutorial_step += 1
		return true
	finish_tutorial()
	return false


func finish_tutorial() -> void:
	tutorial_active = false
	tutorial_step = 0
	speed = 1
	changed.emit()


func build(cell: Vector2i, kind: String) -> bool:
	if phase != "playing" or not Sim.can_place(state, cell, kind):
		notice.emit(Sim.placement_reason(state, cell, kind))
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
	# 前回の保存は、同じディレクトリに書いた内容の検証が済むまで保持する。
	var temporary_path: String = save_path + ".tmp"
	var serialized: String = JSON.stringify(state)
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		notice.emit("保存できませんでした。空き容量を確認してください")
		return false
	var stored: bool = file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if not stored or write_error != OK or FileAccess.get_file_as_string(temporary_path) != serialized:
		notice.emit("保存できませんでした。空き容量を確認してください")
		return false
	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		notice.emit("保存できませんでした。空き容量を確認してください")
		return false
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
	tutorial_active = false
	tutorial_step = 0
	set_phase("playing" if state.outcome == "playing" else "result")
	changed.emit()
	return true
