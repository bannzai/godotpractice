extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Rules = preload("res://scripts/rhythm_rules.gd")
const State = preload("res://scripts/rhythm_state.gd")

var failed := false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_rhythm()

	if failed:
		quit(1)
	else:
		print("selfcheck OK")
		quit(0)


func _check(cond: bool, label: String) -> void:
	if not cond:
		push_error("selfcheck FAIL: " + label)
		failed = true


## tree には入れず (autoload に依存する _ready を走らせず) インスタンス化だけを確認して free する
func _check_scenes(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "シーン: %s を走査できる" % path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension() != "tscn":
			continue
		var scene_path: String = path.path_join(filename)
		var scene: PackedScene = load(scene_path)
		_check(scene != null, "シーン: %s をロードできる" % scene_path)
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		_check(instance != null, "シーン: %s をインスタンス化できる" % scene_path)
		if instance != null:
			instance.free()
	for subdirectory: String in directory.get_directories():
		_check_scenes(path.path_join(subdirectory))


## selfcheck はソースツリーで実行する前提。エクスポート後の .import 実体だけの構成は対象外。
func _check_assets_credited() -> void:
	var credits: String = FileAccess.get_file_as_string("res://assets/CREDITS.md")
	_check(not credits.is_empty(), "CREDITS: assets/CREDITS.md を読み取れる")
	_check_asset_directory("res://assets", credits)


func _check_asset_directory(path: String, credits: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	_check(directory != null, "CREDITS: %s を走査できる" % path)
	if directory == null:
		return
	directory.include_hidden = true
	for filename: String in directory.get_files():
		if filename in ["CREDITS.md", ".gdignore"] or filename.get_extension() in ["import", "uid"]:
			continue
		_check(
			credits.contains(filename),
			"CREDITS: %s が assets/CREDITS.md に記録されていない" % path.path_join(filename)
		)
	for subdirectory: String in directory.get_directories():
		_check_asset_directory(path.path_join(subdirectory), credits)


func _check_rhythm() -> void:
	var state: Node = State.new()
	# ユーザーの記録には一切触れず、作業ディレクトリ内の検証専用ファイルを使う。
	state.save_path = "res://tmp/selfcheck-records.json"
	_check_judgments(state)
	_check_charts(state)
	_check_long_notes(state)
	_check_roundtrip(state)
	_check_save_data(state)
	state.free()


func _check_judgments(state: Node) -> void:
	for delta: float in [-0.055, 0.0, 0.055]:
		_check(Rules.judgment(delta, state.thresholds) == "Perfect", "Perfect の境界")
	for delta: float in [-0.120, -0.056, 0.056, 0.120]:
		_check(Rules.judgment(delta, state.thresholds) == "Good", "Good の境界")
	for delta: float in [-0.121, 0.121]:
		_check(Rules.judgment(delta, state.thresholds) == "Miss", "Miss の境界")
	for item: Array in [[1.0, "S"], [0.98, "S"], [0.9, "A"], [0.8, "B"],
			[0.7, "C"], [0.699, "D"], [0.0, "D"]]:
		_check(Rules.rank_for(item[0], state.thresholds) == item[1], "ランク境界")


func _check_charts(state: Node) -> void:
	_check(state.songs.size() >= 3, "3 曲以上")
	for song_index: int in range(state.songs.size()):
		state.select_song(song_index)
		var easy_count := 0
		for level: String in ["easy", "hard"]:
			state.set_difficulty(level)
			state.start_song()
			_check(state.screen == "play", "全譜面を開始できる")
			_check(Rules.validate_chart(state.chart), "譜面の範囲・単調増加・同レーン重複")
			var kinds: Dictionary = {}
			for note: Dictionary in state.notes:
				kinds[note.type] = true
				_check(float(note.beat) >= 8, "開始カウント後にノーツが始まる")
				_check(Rules.end_time(note, state.chart) <= float(state.chart.duration) - 4,
					"曲の余韻前に全ノーツが終了する")
			_check(kinds.has_all(["coral", "mint", "long"]), "全譜面に 3 種のノーツ")
			if level == "easy":
				easy_count = state.notes.size()
			else:
				_check(state.notes.size() > easy_count, "難易度でノーツ密度が変わる")
			_play_perfect(state)
			_check(state.score == 1000000 and state.counts.Miss == 0,
				"全 6 譜面でロングと別レーンを同時に演奏できる")
			state.abort_song()
	var invalid: Dictionary = state.chart.duplicate(true)
	invalid.notes[1].beat = invalid.notes[0].beat
	_check(not Rules.validate_chart(invalid), "同拍の重複を拒否")
	invalid = state.chart.duplicate(true)
	invalid.notes[0].length = 500.0
	invalid.notes[0].type = "long"
	_check(not Rules.validate_chart(invalid), "音源の範囲外を拒否")


func _play_perfect(state: Node) -> void:
	var events: Array[Dictionary] = []
	for note: Dictionary in state.notes:
		events.append({"time": Rules.note_time(note, state.chart),
			"lane": int(note.lane), "press": true})
		events.append({"time": Rules.end_time(note, state.chart) + 0.00001,
			"lane": int(note.lane), "press": false})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	for event: Dictionary in events:
		if event.press:
			state.press_lane(event.lane, event.time)
		else:
			state.release_lane(event.lane, event.time)
	state.advance(float(state.chart.duration))


func _prepare_short_chart(state: Node) -> void:
	state.start_song()
	state.offset_ms = 0
	state.chart = {"bpm": 120.0, "offset": 0.0, "duration": 60.0, "notes": []}
	state.notes = [
		{"beat": 4.0, "type": "long", "lane": 0, "length": 2.0,
			"status": "pending", "judgment": ""},
		{"beat": 5.0, "type": "mint", "lane": 1, "length": 0.0,
			"status": "pending", "judgment": ""},
		{"beat": 8.0, "type": "coral", "lane": 0, "length": 0.0,
			"status": "pending", "judgment": ""},
	]


func _check_long_notes(state: Node) -> void:
	_prepare_short_chart(state)
	state.press_lane(0, 2.0)
	_check(state.notes[0].status == "holding", "ロング開始は保持状態")
	state.press_lane(1, 2.5)
	state.release_lane(1, 2.5)
	state.release_lane(0, 3.0)
	_check(state.counts.Perfect == 2 and state.counts.Miss == 0, "終端まで保持で成功")
	state.press_lane(0, 4.12)
	state.release_lane(0, 4.12)
	_check(state.counts.Good == 1, "入力時の advance が Good 境界を Miss にしない")
	_prepare_short_chart(state)
	state.press_lane(0, 2.0)
	state.release_lane(0, 2.99)
	_check(state.notes[0].judgment == "Miss", "ロング途中離しは Miss")
	state.advance(10.0)
	_check(state.counts.Miss == 3, "フレーム飛びで複数の見逃しを一括処理")
	state.advance(8.0)
	_check(is_equal_approx(state.song_time, 10.0), "音声時刻の小さな逆行で巻き戻らない")
	state.advance(10.0)
	_check(state.counts.Miss == 3, "同じ音声時刻の再処理で重複判定しない")
	_prepare_short_chart(state)
	state.offset_ms = 100
	state.press_lane(0, 2.1)
	_check(state.notes[0].status == "holding", "100 ms の入力遅延を補正")
	state.release_lane(0, 3.1)
	_check(state.counts.Perfect == 1, "補正後のロング終端")
	state.press_lane(1, 3.2)
	var penalized_gauge: float = state.gauge
	state.press_lane(1, 3.2)
	_check(is_equal_approx(state.gauge, penalized_gauge), "キーリピートで空打ち連打しない")
	_check(state.combo == 0, "空打ちでコンボが切れる")


func _check_roundtrip(state: Node) -> void:
	state.records = {}
	state.offset_ms = 0
	state.select_song(0)
	state.set_difficulty("easy")
	state.start_song()
	_play_perfect(state)
	_check(state.screen == "result" and state.cleared, "全成功でクリア結果へ遷移")
	_check(state.score == 1000000 and state.rank == "S", "全 Perfect で 100 万点・S")
	_check(state.max_combo == state.notes.size(), "最大コンボは全ノーツ数")
	state.finish_song()
	_check(state.score == 1000000, "終了の重複通知で結果が変わらない")
	state.show_select()
	state.start_song()
	state.advance(float(state.chart.duration))
	_check(state.screen == "result" and not state.cleared, "全見逃しで失敗結果へ遷移")
	_check(state.score == 0 and state.rank == "D", "全 Miss で 0 点・D")
	_check(state.get_record(0, "easy").score == 1000000, "低いスコアで自己ベストを上書きしない")
	state.show_title()
	_check(state.screen == "title", "結果からタイトルに戻れる")
	state.start_song()
	state.abort_song()
	_check(state.screen == "select", "演奏を中断して選曲に戻れる")


func _check_save_data(state: Node) -> void:
	state.set_offset(999)
	state.load_records()
	_check(state.offset_ms == 200, "キャリブレーションを制限して保存")
	_check(state.get_record(0, "easy").score == 1000000, "再読込でスコアとランクを復元")
	state.set_offset(-999)
	_check(state.offset_ms == -200, "負のキャリブレーションの制限")
	var file := FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string("{壊れた JSON")
	file.close()
	state.load_records()
	_check(state.records.is_empty() and state.offset_ms == 0, "破損保存で初期状態へ復旧")
	file = FileAccess.open(state.save_path, FileAccess.WRITE)
	file.store_string('{"offset_ms": [], "records": {"starlight_easy": {"score": "bad"}}}')
	file.close()
	state.load_records()
	_check(state.records.is_empty() and state.offset_ms == 0, "誤った型の保存を安全に無視")
	state.save_records()
