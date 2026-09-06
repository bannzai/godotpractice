extends RefCounted
## 時間判定・譜面検証・保存値の解釈を UI と独立させる。


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data


static func judgment(delta: float, thresholds: Dictionary) -> String:
	# 浮動小数点の拍→秒変換でも境界値を包含する。
	if absf(delta) <= float(thresholds.perfect) + 0.000001:
		return "Perfect"
	if absf(delta) <= float(thresholds.good) + 0.000001:
		return "Good"
	return "Miss"


static func note_time(note: Dictionary, chart: Dictionary) -> float:
	return float(chart.offset) + float(note.beat) * 60.0 / float(chart.bpm)


static func end_time(note: Dictionary, chart: Dictionary) -> float:
	return note_time(note, chart) + float(note.length) * 60.0 / float(chart.bpm)


static func rank_for(accuracy: float, thresholds: Dictionary) -> String:
	for rank_name: String in ["S", "A", "B", "C", "D"]:
		if accuracy >= float(thresholds.ranks[rank_name]):
			return rank_name
	return "D"


static func validate_chart(chart: Dictionary) -> bool:
	if not chart.has_all(["bpm", "offset", "duration", "notes"]):
		return false
	if float(chart.bpm) <= 0 or float(chart.duration) < 60 or float(chart.duration) > 90:
		return false
	if not chart.notes is Array or chart.notes.is_empty():
		return false
	var previous_beat := -1.0
	var lane_end: Array[float] = [-1.0, -1.0]
	for item: Variant in chart.notes:
		if not item is Dictionary or not item.has_all(["beat", "type", "lane", "length"]):
			return false
		var note: Dictionary = item
		var lane := int(note.lane)
		if lane not in [0, 1] or note.type not in ["coral", "mint", "long"]:
			return false
		if float(note.beat) <= previous_beat or float(note.beat) <= lane_end[lane]:
			return false
		if float(note.length) < 0 or (note.type == "long") != (float(note.length) > 0):
			return false
		if note_time(note, chart) < 0 or end_time(note, chart) > float(chart.duration):
			return false
		previous_beat = float(note.beat)
		lane_end[lane] = previous_beat + float(note.length)
	return true


static func clean_record(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	if not value.has_all(["score", "rank", "accuracy", "max_combo", "cleared"]):
		return {}
	if not value.score is float and not value.score is int:
		return {}
	if not value.accuracy is float and not value.accuracy is int:
		return {}
	if not value.max_combo is float and not value.max_combo is int:
		return {}
	if value.rank not in ["S", "A", "B", "C", "D"] or not value.cleared is bool:
		return {}
	return {
		"score": clampi(int(value.score), 0, 1000000), "rank": value.rank,
		"accuracy": clampf(float(value.accuracy), 0.0, 1.0),
		"max_combo": maxi(0, int(value.max_combo)), "cleared": value.cleared,
	}
