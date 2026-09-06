extends Node
## プレイ状態の唯一の保存先。入力・時刻進行はゲーム進行のため非冪等。

signal judged(kind: String, lane: int)
signal finished
signal screen_changed

const Rules = preload("res://scripts/rhythm_rules.gd")

var songs: Array = Rules.read_json("res://data/songs.json")
var thresholds: Dictionary = Rules.read_json("res://data/judgment.json")
var screen := "title"
var selected_song := 0
var difficulty := "easy"
var song_time := 0.0
var offset_ms := 0
var score := 0
var combo := 0
var max_combo := 0
var accuracy := 1.0
var gauge := 0.5
var counts: Dictionary = {"Perfect": 0, "Good": 0, "Miss": 0}
var rank := "D"
var cleared := false
var chart: Dictionary = {}
var notes: Array = []
var records: Dictionary = {}
var error_message := ""
var save_path := "user://records.json"
var _earned := 0.0
var _ghost_penalty := 0
var _held: Array[bool] = [false, false]


func _ready() -> void:
	load_records()


func select_song(index: int) -> void:
	selected_song = clampi(index, 0, songs.size() - 1)


func set_difficulty(value: String) -> void:
	if value in ["easy", "hard"]:
		difficulty = value


func set_offset(value: int) -> void:
	offset_ms = clampi(value, -200, 200)
	save_records()


func show_title() -> void:
	_change_screen("title")


func show_select() -> void:
	_change_screen("select")


func show_result() -> void:
	_change_screen("result")


func _change_screen(value: String) -> void:
	if screen == value:
		return
	screen = value
	_held = [false, false]
	screen_changed.emit()


func start_song() -> void:
	var path := "res://data/charts/%s_%s.json" % [songs[selected_song].id, difficulty]
	var loaded: Variant = Rules.read_json(path)
	if not loaded is Dictionary or not Rules.validate_chart(loaded):
		error_message = "譜面を読み込めませんでした"
		return
	chart = loaded
	notes = chart.notes.duplicate(true)
	for note: Dictionary in notes:
		note.status = "pending"
		note.judgment = ""
	song_time = -float(offset_ms) / 1000.0
	score = 0
	combo = 0
	max_combo = 0
	accuracy = 1.0
	gauge = float(thresholds.initial_gauge)
	counts = {"Perfect": 0, "Good": 0, "Miss": 0}
	rank = "D"
	cleared = false
	_earned = 0.0
	_ghost_penalty = 0
	_held = [false, false]
	error_message = ""
	_change_screen("play")


func advance(audio_time: float) -> void:
	if screen != "play":
		return
	# 音声ミックス間の小さな逆行を吸収し、フレーム飛びでも全ノーツを処理する。
	song_time = maxf(song_time, audio_time - float(offset_ms) / 1000.0)
	for note: Dictionary in notes:
		if note.status == "pending":
			if song_time > Rules.note_time(note, chart) + float(thresholds.good) + 0.000001:
				_judge_note(note, "Miss")
		elif note.status == "holding" and song_time >= Rules.end_time(note, chart):
			_judge_note(note, str(note.judgment))
	if audio_time >= float(chart.duration):
		finish_song()


func press_lane(lane: int, audio_time: float) -> void:
	if screen != "play" or lane not in [0, 1] or _held[lane]:
		return
	advance(audio_time)
	if screen != "play":
		return
	_held[lane] = true
	for note: Dictionary in notes:
		if int(note.lane) != lane or note.status != "pending":
			continue
		var kind := Rules.judgment(song_time - Rules.note_time(note, chart), thresholds)
		if kind == "Miss":
			break
		if note.type == "long":
			note.status = "holding"
			note.judgment = kind
		else:
			_judge_note(note, kind)
		return
	combo = 0
	gauge = maxf(0.0, gauge - float(thresholds.ghost_loss))
	_ghost_penalty += int(thresholds.ghost_score_loss)
	_update_score()
	judged.emit("ghost", lane)


func release_lane(lane: int, audio_time: float) -> void:
	if screen != "play" or lane not in [0, 1]:
		return
	advance(audio_time)
	_held[lane] = false
	for note: Dictionary in notes:
		if int(note.lane) == lane and note.status == "holding":
			_judge_note(note, "Miss")


func _judge_note(note: Dictionary, kind: String) -> void:
	if note.status == "judged":
		return
	note.status = "judged"
	note.judgment = kind
	counts[kind] += 1
	if kind == "Miss":
		combo = 0
		gauge = maxf(0.0, gauge - float(thresholds.miss_loss))
	else:
		combo += 1
		max_combo = maxi(max_combo, combo)
		var key := kind.to_lower()
		_earned += float(thresholds[key + "_weight"])
		gauge = minf(1.0, gauge + float(thresholds[key + "_gain"]))
	var judged_count := int(counts.Perfect) + int(counts.Good) + int(counts.Miss)
	accuracy = _earned / float(maxi(1, judged_count))
	_update_score()
	judged.emit(kind, int(note.lane))


func _update_score() -> void:
	score = maxi(0, roundi(_earned / float(maxi(1, notes.size()))
		* float(thresholds.max_score)) - _ghost_penalty)


func finish_song() -> void:
	if screen != "play":
		return
	for note: Dictionary in notes:
		if note.status != "judged":
			_judge_note(note, "Miss")
	cleared = gauge >= float(thresholds.clear_gauge)
	rank = Rules.rank_for(accuracy, thresholds)
	_save_best()
	show_result()
	finished.emit()


func abort_song() -> void:
	show_select()


func get_record(song_index: int, level: String) -> Dictionary:
	var key := "%s_%s" % [songs[song_index].id, level]
	return records.get(key, {})


func _save_best() -> void:
	var key := "%s_%s" % [songs[selected_song].id, difficulty]
	var previous: Dictionary = records.get(key, {})
	if previous.is_empty() or score > int(previous.score):
		records[key] = {"score": score, "rank": rank, "accuracy": accuracy,
			"max_combo": max_combo, "cleared": cleared}
	elif cleared and not bool(previous.cleared):
		previous.cleared = true
	save_records()


func load_records() -> void:
	records = {}
	offset_ms = 0
	var loaded: Variant = Rules.read_json(save_path)
	if not loaded is Dictionary:
		return
	var raw_offset: Variant = loaded.get("offset_ms", 0)
	if raw_offset is int or raw_offset is float:
		offset_ms = clampi(int(raw_offset), -200, 200)
	var raw_records: Variant = loaded.get("records", {})
	if not raw_records is Dictionary:
		return
	for song: Dictionary in songs:
		for level: String in ["easy", "hard"]:
			var key := "%s_%s" % [song.id, level]
			var record: Dictionary = Rules.clean_record(raw_records.get(key))
			if not record.is_empty():
				records[key] = record


func save_records() -> void:
	var value := {"version": 1, "offset_ms": offset_ms, "records": records}
	var serialized := JSON.stringify(value, "\t", true)
	if FileAccess.file_exists(save_path):
		if FileAccess.get_file_as_string(save_path) == serialized:
			return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		error_message = "記録を保存できませんでした"
		return
	file.store_string(serialized)
	file.close()
