extends SceneTree

const SessionScript: Script = preload("res://scripts/session.gd")
var failures: int = 0


# 検証はシナリオを順に実行して結果を累積するため、冪等ではない。
func _init() -> void:
	var game: SessionScript = SessionScript.new()
	game.save_enabled = false
	game.start()
	_check(game.board.size() == 12 and game.board[0].size() == 6, "盤面は 6 列 12 行")
	_check(game.phase == "playing" and game.pair.size() == 2 and game.next_pair.size() == 2, "開始と次ペア")
	game.pivot = Vector2i(0, 5)
	_check(not game.move(-1) and game.pivot.x == 0, "左壁の衝突")
	game.rotation = 0
	_check(game.rotate_piece(-1) and game.pivot.x == 1 and game.rotation == 3, "左壁で回転時の蹴り")
	game.pivot = Vector2i(2, 11)
	game.rotation = 1
	_check(game.rotate_piece(1) and game.pivot.y == 10, "床で回転時の蹴り")
	game.start()
	game.pair = [0, 1]
	game.pivot = Vector2i(1, 1)
	game.rotation = 1
	game.board[11][1] = 2
	_check(game.ghost_cells()[0] == Vector2i(1, 10), "着地点予告の衝突")
	game.drop()
	_check(game.board[10][1] == 0 and game.board[11][2] == 1, "横向きペアの独立落下")
	game.start()
	game.toggle_pause()
	var paused_position: Vector2i = game.pivot
	game.tick(10.0)
	game.drop()
	_check(game.phase == "paused" and game.pivot == paused_position and not game.move(1), "停止中の時間と入力を無効化")
	game.toggle_pause()
	game.tick(1.0)
	_check(game.pivot.y == paused_position.y + 1, "再開後の自然落下")
	game.start()
	for y: int in range(8, 12):
		game.board[y][0] = 0
	game.board[7][0] = 1
	for y: int in range(9, 12):
		game.board[y][1] = 1
	game._resolve()
	_check(game.phase == "clearing" and game.pending.size() == 4 and game.chains == 1, "四つの直交接続を消去待ちにする")
	game.tick(0.2)
	_check(game.board[11][0] == 0, "消去表示中は盤面を保持")
	game.toggle_pause()
	game.tick(2.0)
	_check(game.phase == "paused" and game.chains == 1, "連鎖の途中でも停止可能")
	game.toggle_pause()
	game.tick(1.0)
	_check(game.phase == "clearing" and game.chains == 2 and game.pending.size() == 4, "重力によって二連鎖が成立")
	game.tick(1.0)
	_check(game.phase == "playing" and game.cleared == 8 and game.score == 200 and game.best_chain == 2, "二連鎖の得点と次の手番")
	_check(game.board[11][0] == -1 and game.board[11][1] == -1, "消去後の空盤面")
	game.start()
	for index: int in range(4):
		game.board[index][index] = 0
	_check(game._matching_cells().is_empty(), "斜め接続は消去しない")
	game.start()
	for x: int in range(3):
		game.board[11][x] = 0
	_check(game._matching_cells().is_empty(), "三つでは消去しない")
	game.start()
	for x: int in range(4):
		game.board[11][x] = 0
		game.board[10][x] = 1
	game._resolve()
	_check(game.pending.size() == 8 and game.chains == 1, "別色のグループを同時消去")
	game.start()
	game.board[0][2] = 3
	game._spawn()
	_check(game.phase == "over", "出現位置が塞がると終了")
	game.start()
	_check(game.phase == "playing" and game.score == 0 and game.board[0][2] == -1, "終了後のリスタート")
	game.free()
	_check_record()
	_check_random_play()
	print("検証完了: 失敗 %d 件" % failures)
	quit(0 if failures == 0 else 1)


# 検証専用の保存先だけを初期化し、実ユーザーの最高記録から隔離する。
func _check_record() -> void:
	var path: String = ProjectSettings.globalize_path("res://../../tmp/blockpuzzle-selfcheck-record.cfg")
	var setup: ConfigFile = ConfigFile.new()
	setup.set_value("record", "score", 123)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK or setup.save(path) != OK:
		_check(false, "記録検証専用ファイルの準備")
		return
	var first: SessionScript = SessionScript.new()
	first.record_path = path
	first._ready()
	_check(first.best_score == 123, "保存済み最高記録の読込")
	first.start()
	first.score = 987
	first._finish()
	first.free()
	var second: SessionScript = SessionScript.new()
	second.record_path = path
	second._ready()
	_check(second.best_score == 987, "更新した最高記録を別インスタンスで復元")
	second.start()
	second.score = 10
	second._finish()
	second.free()
	var saved: ConfigFile = ConfigFile.new()
	var load_error: Error = saved.load(path)
	_check(load_error == OK and saved.get_value("record", "score", 0) == 987, "低いスコアで最高記録を減らさない")


# 固定した乱数列で操作と手番を進めるため、冪等ではない。
func _check_random_play() -> void:
	var game: SessionScript = SessionScript.new()
	game.save_enabled = false
	game._random.seed = 2065
	var inputs: RandomNumberGenerator = RandomNumberGenerator.new()
	inputs.seed = 912
	game.start()
	var issue: String = ""
	var inspected: int = 0
	for turn: int in range(200):
		if game.phase == "over":
			game.start()
		for action: int in range(inputs.randi_range(2, 10)):
			match inputs.randi_range(0, 3):
				0:
					game.move(-1 if inputs.randi_range(0, 1) == 0 else 1)
				1:
					game.rotate_piece(-1 if inputs.randi_range(0, 1) == 0 else 1)
				2:
					game.tick(inputs.randf_range(0.0, 0.9))
				3:
					game.step()
			issue = _state_issue(game)
			inspected += 1
			if not issue.is_empty():
				break
		if not issue.is_empty():
			break
		game.drop()
		issue = _state_issue(game)
		inspected += 1
		if not issue.is_empty():
			break
		for resolution: int in range(24):
			if game.phase != "clearing":
				break
			game.tick(1.0)
			issue = _state_issue(game)
			inspected += 1
			if not issue.is_empty():
				break
		if game.phase == "clearing" and issue.is_empty():
			issue = "連鎖処理が終わらない"
		if not issue.is_empty():
			break
	game.free()
	_check(issue.is_empty(), "固定乱数 200 手の盤面・消去対象・境界検証（%d 状態）%s" % [inspected, issue])


func _state_issue(game: SessionScript) -> String:
	if game.board.size() != SessionScript.HEIGHT:
		return "行数が変化"
	for row: Array in game.board:
		if row.size() != SessionScript.WIDTH:
			return "列数が変化"
		for color: int in row:
			if color < -1 or color >= SessionScript.COLOR_COUNT:
				return "不正な盤面色"
	var unique: Dictionary = {}
	for cell: Vector2i in game.pending:
		if not _inside(cell):
			return "消去対象が盤面外"
		if game.board[cell.y][cell.x] == -1 or unique.has(cell):
			return "消去対象が空または重複"
		unique[cell] = true
	if game.phase == "clearing" and game.pending.size() < 4:
		return "消去中の対象が四つ未満"
	if game.phase != "clearing" and not game.pending.is_empty():
		return "消去中以外で対象が残存"
	if game.phase == "playing":
		for cell: Vector2i in game.cells() + game.ghost_cells():
			if not _inside(cell):
				return "操作中または予告のペアが盤面外"
			if game.board[cell.y][cell.x] != -1:
				return "操作中または予告のペアが固定済みセルと重複"
	return ""


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SessionScript.WIDTH and cell.y >= 0 and cell.y < SessionScript.HEIGHT


# 各検証の失敗数を加算するため、冪等ではない。
func _check(condition: bool, description: String) -> void:
	if condition:
		print("成功: " + description)
	else:
		failures += 1
		printerr("失敗: " + description)
