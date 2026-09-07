extends SceneTree
## シーンとアセットクレジットの検証。実行方法は Makefile の selfcheck target を参照。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const Rules = preload("res://scripts/puzzle_rules.gd")
const Session = preload("res://scripts/session.gd")

var failed: bool = false


func _initialize() -> void:
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_motion()
	_check_clearing()
	_check_chains()
	_check_nuisance()
	_check_cpu()
	_check_cpu_reachability()
	_check_records()
	_check_session()

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


func _board(bottom_rows: Array) -> Array:
	var result: Array = Rules.empty_board()
	for index: int in range(bottom_rows.size()):
		result[Rules.HEIGHT - bottom_rows.size() + index] = bottom_rows[index].duplicate()
	return result


func _check_motion() -> void:
	var board: Array = Rules.empty_board()
	var before: Array = board.duplicate(true)
	_check(board.size() == 12 and board[0].size() == 6, "盤面: 6列12行")
	_check(Rules.fits(board, Vector2i(2, 0), 0), "出現: 上にはみ出せる")
	_check(not Rules.fits(board, Vector2i(2, -3), 0), "出現: 隠し領域の下限")
	_check(not Rules.fits(board, Vector2i(0, 3), 3), "移動: 左壁")
	_check(not Rules.fits(board, Vector2i(5, 3), 1), "移動: 右壁")
	_check(not Rules.fits(board, Vector2i(2, 11), 2), "移動: 床")
	_check(Rules.cells(Vector2i(2, 3), -1)[1] == Vector2i(1, 3), "回転: 負の角度")
	var right: Dictionary = Rules.rotated(board, Vector2i(5, 4), 0, 1)
	_check(right.valid and right.position == Vector2i(4, 4), "回転: 右壁蹴り")
	var left: Dictionary = Rules.rotated(board, Vector2i(0, 4), 0, -1)
	_check(left.valid and left.position == Vector2i(1, 4), "回転: 左壁蹴り")
	var floor_kick: Dictionary = Rules.rotated(board, Vector2i(2, 11), 1, 1)
	_check(floor_kick.valid and floor_kick.position == Vector2i(2, 10), "回転: 床蹴り")
	_check(Rules.drop_position(board, Vector2i(2, 0), 0) == Vector2i(2, 11), "落下: 縦組")
	_check(Rules.drop_position(board, Vector2i(2, 0), 2) == Vector2i(2, 10), "落下: 下向き")
	var placed: Dictionary = Rules.place(board, Vector2i(2, 11), 0, [1, 2])
	_check(placed.board == _board([[0, 0, 2, 0, 0, 0], [0, 0, 1, 0, 0, 0]]), "固定: 色と向き")
	_check(not placed.overflow and board == before, "固定: 入力を破壊しない")
	_check(Rules.place(board, Vector2i(2, 0), 0, [1, 2]).overflow, "固定: 天井越え")
	_check(Rules.place(board, Vector2i(2, 11), 0, [1]).overflow, "固定: 不正な組")
	_check(Rules.place(board, Vector2i(2, 11), 0, [1, 9]).board == board, "固定: 不正色は無変更")
	board[11][2] = 3
	_check(not Rules.fits(board, Vector2i(2, 11), 0), "移動: 既存ピースと衝突")
	_check(Rules.place(board, Vector2i(2, 11), 0, [1, 2]).board == board, "固定: 衝突は無変更")
	_check(Rules.drop_position(board, Vector2i(2, 0), 0) == Vector2i(2, 10), "落下: 既存ピース上")
	var trapped: Array = Rules.empty_board()
	for y: int in range(8, 12):
		trapped[y].fill(5)
	trapped[10][2] = 0
	trapped[9][2] = 0
	var rejected: Dictionary = Rules.rotated(trapped, Vector2i(2, 10), 0, 1)
	_check(not rejected.valid and rejected.position == Vector2i(2, 10), "回転: 閉所では不変")


func _check_clearing() -> void:
	var three: Array = _board([[1, 1, 1, 0, 0, 0]])
	_check(Rules.clear_groups(three).colored == 0, "消去: 3個は残る")
	var diagonal: Array = _board([[1, 0, 1, 0, 0, 0], [0, 1, 0, 1, 0, 0]])
	_check(Rules.clear_groups(diagonal).colored == 0, "消去: 斜めはつながらない")
	var board: Array = _board([[1, 1, 0, 2, 2, 0], [1, 1, 5, 2, 2, 5]])
	var original: Array = board.duplicate(true)
	var cleared: Dictionary = Rules.clear_groups(board)
	_check(cleared.colored == 8 and cleared.cleared.size() == 10, "消去: 同時2色とおじゃま")
	_check(cleared.board == Rules.empty_board() and board == original, "消去: 結果盤面と非破壊")
	board = _board([[1, 1, 1, 1, 5, 5]])
	cleared = Rules.clear_groups(board)
	_check(cleared.board == _board([[0, 0, 0, 0, 0, 5]]), "おじゃま: 隣接1段だけ消去")
	board = _board([[1, 0, 0, 0, 0, 0], [0, 2, 0, 0, 0, 0], [3, 0, 0, 0, 0, 0]])
	original = board.duplicate(true)
	var fallen: Array = Rules.gravity(board)
	_check(fallen == _board([[1, 0, 0, 0, 0, 0], [3, 2, 0, 0, 0, 0]]), "重力: 順序を保持")
	_check(board == original and Rules.gravity(fallen) == fallen, "重力: 非破壊かつ安定後冪等")


func _check_chains() -> void:
	var board: Array = _board([[0, 0, 2, 0, 0, 0], [0, 2, 1, 2, 0, 0], [1, 1, 1, 2, 0, 0]])
	var original: Array = board.duplicate(true)
	var resolved: Dictionary = Rules.resolve(board)
	_check(resolved.chains == 2 and resolved.score == 120, "連鎖: 2連鎖で40+80点")
	_check(resolved.attack == 3, "連鎖: 1+2個のおじゃま")
	_check(resolved.board == Rules.empty_board(), "連鎖: 最終盤面")
	_check(board == original and Rules.resolve(board) == resolved, "連鎖: 入力非破壊と再現性")
	if resolved.steps.size() == 2:
		_check(
			resolved.steps[0].after_gravity == _board([[0, 0, 0, 2, 0, 0], [0, 2, 2, 2, 0, 0]]),
			"連鎖: 1回目落下の盤面"
		)
		_check(resolved.steps[1].colored == 4, "連鎖: 2回目に4個")
	_check(Rules.resolve(resolved.board).chains == 0, "連鎖: 解決後に再加算しない")
	_check(Rules.score_for(4, 3) == 160 and Rules.score_for(4, 4) == 320, "得点: 指数増加")
	_check(Rules.score_for(3, 1) == 0 and Rules.score_for(4, 0) == 0, "得点: 境界")
	_check(Rules.attack_for(0, 4) == 0 and Rules.attack_for(3, 4) == 4, "攻撃: 連鎖で増加")
	_check(Rules.fall_interval(0) > Rules.fall_interval(60), "速度: 時間で加速")
	_check(is_equal_approx(Rules.fall_interval(9999), 0.12), "速度: 下限")
	_check(Rules.fall_interval(-10) == Rules.fall_interval(0), "速度: 負の時間")


func _check_nuisance() -> void:
	var board: Array = Rules.empty_board()
	var original: Array = board.duplicate(true)
	var result: Dictionary = Rules.add_nuisance(board, 8, 4)
	_check(result.board == _board([[0, 0, 0, 0, 5, 5], [5, 5, 5, 5, 5, 5]]), "おじゃま: 列巡回")
	_check(result.placed.size() == 8 and not result.overflow, "おじゃま: 予告数を配置")
	_check(board == original, "おじゃま: 入力非破壊")
	_check(Rules.add_nuisance(board, -3).board == board, "おじゃま: 負数は無変更")
	for y: int in range(Rules.HEIGHT):
		board[y][0] = 5
	result = Rules.add_nuisance(board, 1)
	_check(result.overflow and result.board == board, "おじゃま: 天井で終了")


func _check_cpu() -> void:
	var board: Array = _board([[1, 2, 0, 3, 0, 0], [1, 2, 3, 3, 4, 0]])
	var original: Array = board.duplicate(true)
	for difficulty: int in range(3):
		var choice: Dictionary = Rules.cpu_choice(board, [3, 4], difficulty, [1, 1])
		_check(not choice.is_empty(), "CPU: 全難易度で配置候補")
		if choice.is_empty():
			continue
		_check(Rules.fits(board, choice.position, choice.rotation), "CPU: 合法位置")
		_check(not Rules.fits(board, choice.position + Vector2i.DOWN, choice.rotation), "CPU: 接地")
		_check(
			not Rules.place(board, choice.position, choice.rotation, [3, 4]).overflow, "CPU: 盤内固定"
		)
		_check(choice == Rules.cpu_choice(board, [3, 4], difficulty, [1, 1]), "CPU: 決定的な評価")
	_check(board == original, "CPU: 評価が入力を破壊しない")
	board = _board([[1, 1, 1, 0, 0, 0]])
	var smart: Dictionary = Rules.cpu_choice(board, [1, 2], 1)
	var smart_board: Array = Rules.place(board, smart.position, smart.rotation, [1, 2]).board
	_check(Rules.resolve(smart_board).score >= 40, "CPU: 通常は確定消去を選ぶ")
	board = _board([[0, 0, 0, 0, 0, 1]])
	_check(
		Rules.cpu_choice(board, [1, 2], 0) != Rules.cpu_choice(board, [1, 2], 1),
		"CPU: 初級の高さ優先と通常の接続優先で配置が変わる"
	)
	for y: int in range(Rules.HEIGHT):
		board[y].fill(5)
	_check(Rules.cpu_choice(board, [1, 2], 2).is_empty(), "CPU: 配置不能は空")


func _check_records() -> void:
	var empty: Dictionary = {"high_score": 0, "best_chain": 0, "tutorial_seen": false}
	_check(Rules.parse_records(null) == empty, "保存: 未作成")
	_check(Rules.parse_records([]) == empty, "保存: 不正形式")
	_check(Rules.parse_records({"high_score": "100", "best_chain": -2}) == empty, "保存: 不正型と負数")
	_check(
		(
			Rules.parse_records({"high_score": 240.0, "best_chain": 3.0})
			== {"high_score": 240, "best_chain": 3, "tutorial_seen": false}
		),
		"保存: JSONの浮動小数を解釈"
	)
	_check(
		Rules.parse_records({"tutorial_seen": true}).tutorial_seen,
		"保存: 初回チュートリアル完了を解釈"
	)
	_check(
		not Rules.parse_records({"tutorial_seen": 1}).tutorial_seen,
		"保存: チュートリアル完了の不正型を拒否"
	)
	_check(Rules.parse_records({"high_score": INF, "best_chain": NAN}) == empty, "保存: 非有限値")
	_check(Rules.parse_records({"best_chain": 999}).best_chain == 18, "保存: 盤面上の連鎖上限")


func _check_session() -> void:
	var state: Node = Session.new()
	state.save_enabled = false
	state.start_game("cpu", 123)
	var original: Array = state.boards.duplicate(true)
	state.start_game("cpu", 123)
	_check(state.boards == original, "対戦: 固定seedで同じ初手と次組")
	_check(state.boards[0].next.size() >= 2, "対戦: 次とその次を保持")
	state.toggle_pause()
	var position: Vector2i = state.boards[0].position
	state.move_piece(1)
	state.hard_drop()
	state._process(3.0)
	_check(state.elapsed == 0.0 and state.boards[0].position == position, "ポーズ: 入力と時間停止")
	state.toggle_pause()
	state.boards[0].board = _board([[0, 0, 2, 0, 0, 0], [0, 2, 1, 2, 0, 0], [1, 1, 1, 2, 0, 0]])
	state.boards[0].phase = "land"
	state.boards[0].pending = 2
	state._tick(0, 0.3)
	_check(state.boards[0].phase == "clear" and state.score == 40, "進行: 1回目消去")
	_check(state.boards[0].pending == 1 and state.boards[1].pending == 0, "対戦: 攻撃を予告で相殺")
	state._tick(0, 0.6)
	state._tick(0, 0.3)
	_check(state.score == 120 and state.max_chain == 2, "進行: 時間差で2連鎖")
	_check(state.boards[0].pending == 0 and state.boards[1].pending == 1, "対戦: 相殺後の余りを相手へ")
	state._tick(0, 0.6)
	state._tick(0, 0.3)
	_check(state.boards[0].phase == "falling", "進行: 連鎖完了後に次の組")
	state._finish(0, "検証")
	_check(state.screen == "round" and state.wins == [1, 0], "勝敗: 1本目では対戦継続")
	state._finish(0, "検証")
	_check(state.wins == [1, 0], "勝敗: 決着の重複呼び出しは無変更")
	state.next_round()
	_check(state.screen == "play" and state.wins == [1, 0], "勝敗: 次ラウンドで本数保持")
	state._finish(0, "検証")
	_check(state.screen == "result" and state.wins == [2, 0], "勝敗: 2本先取で結果")
	_check(state.records.high_score == 120 and state.records.best_chain == 2, "記録: 対戦の成績")
	state.start_game("solo", 123)
	_check(state.wins == [0, 0] and state.score == 0 and state.max_chain == 0, "再戦: 試合状態初期化")
	state._process(90.0)
	_check(state.screen == "result" and state.result_text == "時間終了", "ひとり: 90秒で終了")
	state.show_title()
	_check(state.screen == "title", "画面: 結果からタイトル")
	state.start_game("cpu", 123)
	for row: Array in state.boards[1].board:
		row.fill(5)
	state.boards[1].board[0][2] = 0
	_check(Rules.fits(state.boards[1].board, Vector2i(2, 0), 0), "CPU: 出現だけ可能な天井")
	state._falling(1, 2.0)
	_check(state.screen == "round" and state.wins == [1, 0], "CPU: 固定不能は敗北で終了")
	state.free()


func _check_cpu_reachability() -> void:
	var board: Array = Rules.empty_board()
	var candidates: Array[Dictionary] = Rules.reachable_landings(board)
	_check(candidates.size() == 22, "CPU到達: 空盤面は縦12通りと横10通り")
	for candidate: Dictionary in candidates:
		_check_input_path(board, candidate)
	for y: int in range(Rules.HEIGHT):
		board[y][3] = Rules.NUISANCE
	for y: int in range(Rules.HEIGHT - 3, Rules.HEIGHT):
		board[y][5] = 1
	var original: Array = board.duplicate(true)
	candidates = Rules.reachable_landings(board)
	_check(candidates.size() == 10, "CPU到達: 高い壁の左3列だけで縦6通りと横4通り")
	for candidate: Dictionary in candidates:
		for cell: Vector2i in Rules.cells(candidate.position, candidate.rotation):
			_check(cell.x < 3, "CPU到達: 天井まで続く壁を越えない")
		_check_input_path(board, candidate)
	for difficulty: int in range(3):
		var choice: Dictionary = Rules.cpu_choice(board, [1, 2], difficulty, [1, 1])
		_check(not choice.is_empty(), "CPU到達: 壁の手前で配置可能")
		if choice.is_empty():
			continue
		_check(choice.position.x < 3, "CPU到達: 壁の向こうの消去を選ばない")
		_check_input_path(board, choice)
	_check(board == original, "CPU到達: 経路探索と先読みが入力を変更しない")
	board[0][2] = 5
	_check(Rules.reachable_landings(board).is_empty(), "CPU到達: 出現地点が塞がれば候補なし")
	_check(Rules.cpu_choice(board, [1, 2], 2, [1, 1]).is_empty(), "CPU到達: 出現不可で別列に出さない")
	board = _board([[1, 2, 0, 3, 0, 0], [1, 2, 3, 3, 4, 0]])
	var started: int = Time.get_ticks_usec()
	var strong: Dictionary = Rules.cpu_choice(board, [3, 4], 2, [1, 1])
	print("CPU到達: 強いCPUの探索 %.2f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	_check_input_path(board, strong)

	board = Rules.empty_board()
	for y: int in range(4, Rules.HEIGHT):
		board[y][3] = 5
	for y: int in range(Rules.HEIGHT - 3, Rules.HEIGHT):
		board[y][5] = 1
	var start: Vector2i = Vector2i(2, 5)
	for difficulty: int in range(3):
		var choice: Dictionary = Rules.cpu_choice(board, [1, 2], difficulty, [1, 1], start, 3)
		_check(not choice.is_empty(), "CPU現在地: 途中まで落下しても接地候補あり")
		if choice.is_empty():
			continue
		for cell: Vector2i in Rules.cells(choice.position, choice.rotation):
			_check(cell.x < 3, "CPU現在地: 落下後には越えられない壁を越えない")
		_check_input_path(board, choice, start, 3)
	_check(
		Rules.reachable_landings(board).any(
			func(candidate: Dictionary) -> bool: return candidate.position.x > 3
		),
		"CPU現在地: 出現時だけは壁の上から右側へ到達できる"
	)


func _check_input_path(
	board: Array,
	candidate: Dictionary,
	start_position: Vector2i = Vector2i(2, 0),
	start_rotation: int = 0
) -> void:
	var position: Vector2i = start_position
	var rotation: int = start_rotation
	for action: String in candidate.path:
		match action:
			"left":
				position += Vector2i.LEFT
			"right":
				position += Vector2i.RIGHT
			"down":
				position += Vector2i.DOWN
			"rotate_left", "rotate_right":
				var turn: Dictionary = Rules.rotated(
					board, position, rotation, -1 if action == "rotate_left" else 1
				)
				_check(turn.valid, "CPU経路: 各回転が成功する")
				position = turn.position
				rotation = turn.rotation
			_:
				_check(false, "CPU経路: 未定義の操作がない")
		_check(Rules.fits(board, position, rotation), "CPU経路: 中間位置で衝突しない")
	_check(position == candidate.position and rotation == candidate.rotation, "CPU経路: 目的位置に到達")
	_check(not Rules.fits(board, position + Vector2i.DOWN, rotation), "CPU経路: 終点で接地")
