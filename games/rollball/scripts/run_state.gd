extends Node
## タイトルから結果までの進行と、付着物の体積を保持する。

signal changed

const INITIAL_DIAMETER: float = 0.8
const TARGET_DIAMETER: float = 3.2
const TIME_LIMIT: float = 180.0
const COLLECT_RATIO: float = 0.72
const DEFAULT_STAGE: String = "atelier"

var phase: String = "title"
var selected_stage: String = DEFAULT_STAGE
var tutorial_seen: bool = false
var diameter: float = INITIAL_DIAMETER
var remaining: float = TIME_LIMIT
var volumes: Array[float] = []
var collected: int:
	get:
		return volumes.size()


func reset() -> void:
	_reset_run_values()
	phase = "title"
	changed.emit()


func open_stage_select() -> void:
	_reset_run_values()
	phase = "stage_select"
	changed.emit()


func select_stage(stage_id: String) -> void:
	if stage_id.is_empty() or selected_stage == stage_id:
		return
	selected_stage = stage_id
	changed.emit()


func begin_tutorial() -> void:
	_reset_run_values()
	phase = "tutorial"
	changed.emit()


func finish_tutorial() -> void:
	tutorial_seen = true


func start_run() -> void:
	_reset_run_values()
	phase = "playing"
	changed.emit()


func can_collect(size: float) -> bool:
	return phase == "playing" and size > 0.0 and size <= diameter * COLLECT_RATIO


func collect(volume: float) -> void:
	# 接触ごとに別の物体を追加するため非冪等。呼び出し側で取得済み物体を除外する。
	if phase != "playing" or not is_finite(volume) or volume <= 0.0:
		return
	volumes.append(volume)
	_update_diameter()
	if diameter >= TARGET_DIAMETER:
		phase = "won"
	changed.emit()


func shed() -> float:
	# 衝突ごとに最後の付着物を一つ剥がすため非冪等。呼び出し側で衝突間隔を制御する。
	if phase != "playing" or volumes.is_empty():
		return 0.0
	var volume: float = volumes.pop_back()
	_update_diameter()
	changed.emit()
	return volume


func tick(delta: float) -> void:
	# 経過時間を積算するため非冪等。物理フレームごとに一度呼ぶ。
	if phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		phase = "lost"
	changed.emit()


func _update_diameter() -> void:
	var total_volume: float = 0.0
	for volume: float in volumes:
		total_volume += volume
	diameter = pow(pow(INITIAL_DIAMETER, 3.0) + 6.0 * total_volume / PI, 1.0 / 3.0)


func _reset_run_values() -> void:
	diameter = INITIAL_DIAMETER
	remaining = TIME_LIMIT
	volumes.clear()
