extends SceneTree
## シーン・素材・入力・試合進行・実接触を検証する。実行方法は Makefile を参照。
## 物理フレームを進めて戦闘を再現するため、検証実行は非冪等。
## release ビルドで assert が消えるため、明示的な判定と exit code で結果を返す。

const MATCH_SCRIPT: Script = preload("res://scripts/match_state.gd")

var failed: bool = false
var checked: int = 0
var _main_scene: PackedScene
var _first: FighterBody
var _second: FighterBody
var _contacts: int = 0
var _guards: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# SceneTreeスクリプトのpreload時点ではautoloadがまだ登録されていない。
	_main_scene = load("res://scenes/main.tscn")
	_check_scenes("res://scenes")
	_check_assets_credited()
	_check_audio()
	_check_moves()
	_check_commands()
	_check_match()
	_check_input()
	await _check_combat()
	await _check_main_inputs(false)
	await _check_main_inputs(true)
	await _check_presentation()
	print("検証条件数: %d" % checked)
	if failed:
		quit(1)
	else:
		print("selfcheck OK")
		quit(0)


func _check(cond: bool, label: String) -> void:
	checked += 1
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


func _check_moves() -> void:
	for stance: String in ["standing", "crouching", "air"]:
		for kind: String in ["lp", "hp", "lk", "hk"]:
			var fast: Dictionary = FighterRules.move(kind, stance, 0)
			var strong: Dictionary = FighterRules.move(kind, stance, 1)
			var label: String = stance + "/" + kind
			_check(not fast.is_empty(), label + "の技定義")
			_check(float(fast.active) >= 0.1, label + "の接触可能時間")
			_check(int(fast.damage) < int(strong.damage), label + "のキャラ威力差")
			_check(float(fast.startup) < float(strong.startup), label + "のキャラ速度差")
			_check(float(fast.reach) < float(strong.reach), label + "のキャラ間合い差")
			_check(float(fast.hit_recovery) < float(fast.guard_recovery), label + "の命中硬直")
			_check(float(fast.guard_recovery) < float(fast.whiff_recovery), label + "の空振り硬直")
			if stance == "air":
				_check(fast.level == "overhead", label + "は立ちガードが必要")
			if stance == "crouching" and kind in ["lk", "hk"]:
				_check(fast.level == "low", label + "は下段")
	_check(FighterRules.move("invalid", "standing", 0).is_empty(), "未定義の技を拒否")
	_check(FighterRules.move("lp", "invalid", 0).is_empty(), "未定義の姿勢を拒否")
	_check(not FighterRules.move("special", "standing", 0).is_empty(), "必殺技の定義")
	_check(FighterRules.blocks("mid", false, false), "立ちで中段防御")
	_check(FighterRules.blocks("mid", true, false), "屈みで中段防御")
	_check(FighterRules.blocks("low", true, false), "屈みで下段防御")
	_check(not FighterRules.blocks("low", false, false), "立ちで下段防御不可")
	_check(FighterRules.blocks("overhead", false, false), "立ちで空中攻撃防御")
	_check(not FighterRules.blocks("overhead", true, false), "屈みで空中攻撃防御不可")
	for level: String in ["mid", "low", "overhead"]:
		_check(not FighterRules.blocks(level, false, true), "空中ガードなし: " + level)


func _check_commands() -> void:
	var buffer: FighterCommand = FighterCommand.new()
	for facing: float in [1.0, -1.0]:
		buffer.reset()
		buffer.push(Vector2.DOWN, facing, 0.1)
		buffer.push(Vector2(facing, 1.0), facing, 0.1)
		buffer.push(Vector2(facing, 0.0), facing, 0.1)
		_check(buffer.consume(), "左右それぞれの下・斜め前・前コマンド成立")
		_check(not buffer.consume(), "消費したコマンドの再発動なし")
	buffer.reset()
	buffer.push(Vector2.RIGHT, 1.0, 0.1)
	buffer.push(Vector2(1.0, 1.0), 1.0, 0.1)
	buffer.push(Vector2.DOWN, 1.0, 0.1)
	_check(not buffer.consume(), "逆順コマンドを拒否")
	buffer.reset()
	buffer.push(Vector2.DOWN, 1.0, 0.1)
	buffer.push(Vector2(1.0, 1.0), 1.0, 0.1)
	buffer.push(Vector2.RIGHT, 1.0, 0.1)
	buffer.push(Vector2.RIGHT, 1.0, FighterCommand.WINDOW + 0.1)
	_check(not buffer.consume(), "期限切れコマンドを拒否")
	buffer.reset()
	buffer.push(Vector2.DOWN, 1.0, 0.1)
	buffer.push(Vector2.LEFT, 1.0, 0.1)
	buffer.push(Vector2(1.0, 1.0), 1.0, 0.1)
	buffer.push(Vector2.RIGHT, 1.0, 0.1)
	_check(not buffer.consume(), "途中に逆方向が入ったコマンドを拒否")
	buffer.reset()
	buffer.reset()
	_check(buffer.history.is_empty() and buffer.clock == 0.0, "入力履歴の初期化は冪等")


func _check_match() -> void:
	var state: Node = MATCH_SCRIPT.new()
	state.reset_match(1)
	state.reset_match(1)
	_check(state.selected == 1 and state.wins == [0, 0], "試合初期化とキャラ選択")
	_check(state.round_number == 1 and state.remaining == 99.0, "99秒の第1ラウンド")
	state.advance_round()
	_check(state.round_number == 1, "未決着では次ラウンドへ進まない")
	state.tick(0.5, 1000, 1000)
	_check(state.remaining == 98.5, "試合時間を更新")
	state.tick(0.1, 700, 0)
	_check(state.round_over and state.round_winner == 0, "CPUのKOでプレイヤー勝利")
	_check(state.wins == [1, 0] and state.reason == "決着", "KOで1本を加算")
	var stopped_time: float = state.remaining
	state.tick(1.0, 700, 0)
	state.finish_round(700, 0)
	_check(state.wins == [1, 0], "決着後の重複加算なし")
	_check(state.remaining == stopped_time, "決着中はタイマー停止")
	state.advance_round()
	_check(state.round_number == 2 and state.remaining == 99.0, "第2ラウンドの初期化")
	state.tick(100.0, 400, 300)
	_check(state.reason == "時間切れ" and state.round_winner == 0, "時間切れは残HPで勝敗")
	_check(state.remaining == 0.0 and state.wins == [2, 0], "タイマー下限と2本先取")
	state.advance_round()
	_check(state.screen == MATCH_SCRIPT.Screen.RESULT, "2本先取で結果画面")
	state.tick(10.0, 0, 1000)
	_check(state.wins == [2, 0], "結果画面では試合更新なし")
	state.reset_match(0)
	state.tick(100.0, 500, 500)
	_check(state.round_winner == -1 and state.wins == [0, 0], "時間切れ同点は引き分け")
	state.advance_round()
	_check(state.round_number == 2 and not state.round_over, "引き分け後も再開")
	state.tick(0.1, 0, 0)
	_check(state.round_winner == -1 and state.wins == [0, 0], "同時KOは引き分け")
	state.reset_match(0)
	state.tick(0.1, 0, 1000)
	state.advance_round()
	state.tick(0.1, 0, 1000)
	state.advance_round()
	_check(state.wins == [0, 2] and state.screen == MATCH_SCRIPT.Screen.RESULT, "CPUも2本先取")
	state.free()


func _check_input() -> void:
	var actions: Array[String] = [
		"move_left",
		"move_right",
		"move_up",
		"move_down",
		"lp",
		"hp",
		"lk",
		"hk",
		"confirm",
		"back",
		"pause",
		"mute",
	]
	for action_name: String in actions:
		_check(InputMap.has_action(action_name), "入力アクション: " + action_name)
		var keyboard: bool = false
		var gamepad: bool = false
		for event: InputEvent in InputMap.action_get_events(action_name):
			keyboard = keyboard or event is InputEventKey
			gamepad = gamepad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		_check(keyboard and gamepad, "キーボードとパッドの割当: " + action_name)
	var fullscreen_f11: bool = false
	for event: InputEvent in InputMap.action_get_events("fullscreen"):
		if event is InputEventKey:
			fullscreen_f11 = fullscreen_f11 or event.physical_keycode == KEY_F11
	_check(fullscreen_f11, "全画面切替に正しいF11キー値を割当")


func _check_combat() -> void:
	_first = FighterBody.new()
	_second = FighterBody.new()
	root.add_child(_first)
	root.add_child(_second)
	_first.configure(0, false)
	_second.configure(1, true)
	_first.opponent = _second
	_second.opponent = _first
	_second.struck.connect(_record_contact)
	await _check_normal_contact()
	await _check_guard_contact()
	await _check_guard_levels()
	await _check_projectile_contact()
	await _check_air_and_pause()
	_first.queue_free()
	_second.queue_free()
	_clear_projectiles()
	await process_frame


func _reset_pair(first_x: float = 500.0, second_x: float = 600.0) -> void:
	_clear_projectiles()
	_first.reset_fighter(Vector2(first_x, 570.0))
	_second.reset_fighter(Vector2(second_x, 570.0))
	_first.facing = 1.0
	_second.facing = -1.0
	_first.enabled = true
	_second.enabled = true
	_contacts = 0
	_guards = 0


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _until_contact() -> void:
	for frame: int in range(90):
		await _frames(1)
		if _contacts > 0:
			return


func _record_contact(_at: Vector2, blocked: bool) -> void:
	_contacts += 1
	if blocked:
		_guards += 1


func _clear_projectiles() -> void:
	for projectile: Node in get_nodes_in_group("projectiles"):
		projectile.queue_free()


func _check_normal_contact() -> void:
	_reset_pair()
	await _frames(3)
	_check(_first.start_attack("hp"), "通常技の開始")
	_check(not _first.start_attack("lp"), "技中の上書きを拒否")
	await _until_contact()
	_check(_contacts == 1 and _guards == 0, "Area2D同士の実接触で命中")
	_check(_second.health == 908, "キャラ性能に対応した92ダメージ")
	_check(_first.hitstop > 0.0 and _second.hitstop > 0.0, "両者にヒットストップ")
	_check(_second.velocity.x > 0.0 and _second.stun > 0.0, "被弾側のノックバックと硬直")
	_check(not _second.start_attack("lp"), "被弾硬直中は反撃不可")
	await _frames(60)
	_check(_contacts == 1 and _second.health == 908, "1回の攻撃中に重複ダメージなし")
	_check(_first.action.is_empty(), "命中硬直が終了して待機に戻る")
	_check(_second.position.x > 600.0, "ノックバックが座標に反映")
	_reset_pair(300.0, 950.0)
	_check(_first.start_attack("hp"), "遠距離で技を開始")
	await _frames(60)
	_check(_contacts == 0 and _second.health == 1000, "間合い外の攻撃は空振り")
	_check(_first.action.is_empty() and _first.last_outcome == "空振り", "空振り硬直終了")


func _check_guard_contact() -> void:
	_reset_pair(1100.0, 1195.0)
	_second.control(Vector2.RIGHT)
	await _frames(3)
	_first.start_attack("hp")
	await _until_contact()
	_check(_contacts == 1 and _guards == 1 and _second.health == 1000, "後ろ入力で実接触を防御")
	_check(_first.last_outcome == "ガード", "ガード専用硬直への分岐")
	_check(_second.hitstop > 0.0 and _second.stun > 0.0, "ガード硬直とヒットストップ")
	var data: Dictionary = FighterRules.move("hp", "standing", 0)
	_second.receive_hit(data, _first.position)
	_check(_second.health == 1000 and _guards == 2, "ガード硬直中も連続ガード")
	await _frames(60)
	_check(_first.action.is_empty(), "ガードさせた後の硬直終了")


func _check_guard_levels() -> void:
	_reset_pair(1100.0, 1195.0)
	_second.control(Vector2.RIGHT)
	_first.control(Vector2.DOWN)
	await _frames(3)
	_first.start_attack("lk")
	await _until_contact()
	_check(_contacts == 1 and _guards == 0 and _second.health < 1000, "下段は立ちガードを崩す")
	_reset_pair(1100.0, 1195.0)
	_second.control(Vector2(1.0, 1.0))
	_first.control(Vector2.DOWN)
	await _frames(3)
	_first.start_attack("lk")
	await _until_contact()
	_check(_contacts == 1 and _guards == 1 and _second.health == 1000, "下段は屈みガードで防ぐ")
	var overhead: Dictionary = FighterRules.move("hp", "air", 0)
	_reset_pair(1100.0, 1195.0)
	_second.control(Vector2.RIGHT)
	_check(_second.receive_hit(overhead, _first.position), "空中攻撃は立ちガードで防ぐ")
	_reset_pair(1100.0, 1195.0)
	_second.control(Vector2(1.0, 1.0))
	_check(not _second.receive_hit(overhead, _first.position), "空中攻撃は屈みガードを崩す")
	_check(_second.health < 1000, "屈みへの空中攻撃でダメージ")
	_second.control(Vector2.RIGHT)
	_check(not _second.receive_hit(overhead, _first.position), "被弾硬直をガードへ変更できない")


func _check_projectile_contact() -> void:
	_reset_pair(500.0, 900.0)
	await _frames(3)
	_check(_first.start_attack("special"), "必殺技を開始")
	await _frames(20)
	_check(get_nodes_in_group("projectiles").size() == 1, "投射物を1発生成")
	_check(not _first.start_attack("lp"), "飛び道具発射後も必殺技硬直を維持")
	await _until_contact()
	_check(_contacts == 1 and _second.health == 899, "飛び道具が実接触で101ダメージ")
	await _frames(20)
	_check(get_nodes_in_group("projectiles").is_empty(), "命中した投射物を消去")
	_check(_contacts == 1, "飛び道具の命中は1回だけ")


func _check_air_and_pause() -> void:
	_reset_pair(500.0, 1000.0)
	_first.control(Vector2(1.0, -1.0))
	await _frames(8)
	_check(_first.position.y < 570.0 and _first.position.x > 500.0, "前ジャンプ")
	_check(_first.start_attack("hk") and _first.attack_stance == "air", "空中通常技を選択")
	_check(not _first.start_attack("special"), "空中技中の必殺技を拒否")
	_first.enabled = false
	_first.hitstop = 0.1
	var paused_at: Vector2 = _first.position
	var paused_attack: float = _first.attack_time
	await _frames(8)
	_check(_first.position == paused_at, "無効化中は移動停止")
	_check(_first.hitstop == 0.1 and _first.attack_time == paused_attack, "無効化中は全硬直も停止")
	_reset_pair(500.0, 1000.0)
	_first.control(Vector2(-1.0, -1.0))
	await _frames(8)
	_check(_first.position.y < 570.0 and _first.position.x < 500.0, "後ろジャンプ")
	_first.reset_fighter(Vector2(500.0, 570.0))
	_first.reset_fighter(Vector2(500.0, 570.0))
	_check(_first.health == 1000 and _first.velocity == Vector2.ZERO, "再初期化でHPと移動リセット")
	_check(
		_first.action.is_empty() and _first.hitstop == 0.0 and _first.stun == 0.0, "再初期化で技と硬直リセット"
	)


func _check_main_inputs(gamepad: bool) -> void:
	var label: String = "ゲームパッド" if gamepad else "キーボード"
	var main: Control = _main_scene.instantiate()
	var state: Node = root.get_node("Match")
	var was_muted: bool = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	root.add_child(main)
	await _frames(2)
	_check(state.screen == MATCH_SCRIPT.Screen.TITLE, label + "起動時タイトル")
	await _tap_control(gamepad, KEY_ENTER, JOY_BUTTON_A)
	_check(state.screen == MATCH_SCRIPT.Screen.SELECT, label + "決定で選択画面へ")
	var original_selection: int = state.selected
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 1.0)
	else:
		_send_key(KEY_D, true)
	await _frames(2)
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 0.0)
	else:
		_send_key(KEY_D, false)
	_check(state.selected != original_selection, label + "左右入力でキャラ選択")
	await _tap_control(gamepad, KEY_ENTER, JOY_BUTTON_A)
	_check(state.screen == MATCH_SCRIPT.Screen.STAGE, label + "決定で世界地図へ")
	var original_stage: int = main.stage_index
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 1.0)
	else:
		_send_key(KEY_D, true)
	await _frames(2)
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 0.0)
	else:
		_send_key(KEY_D, false)
	_check(main.stage_index != original_stage, label + "左右入力で会場選択")
	await _tap_control(gamepad, KEY_ENTER, JOY_BUTTON_A)
	_check(state.screen == MATCH_SCRIPT.Screen.FIGHT, label + "地図の決定で対戦開始")
	_check(is_instance_valid(main.player) and is_instance_valid(main.cpu), label + "両闘士生成")
	main.intro = 0.0
	await _frames(2)
	_check(main.tutorial_active and main.tutorial_step == 0, label + "初戦で場面内チュートリアルを表示")
	if gamepad:
		await _tap_control(true, KEY_SPACE, JOY_BUTTON_A)
		_check(not main.tutorial_active and main.tutorial_seen, label + "決定入力でチュートリアルをスキップ")
	else:
		_send_key(KEY_D, true)
		await _frames(3)
		_send_key(KEY_D, false)
		_check(main.tutorial_step == 1, label + "移動入力でチュートリアルを進める")
		await _tap_control(false, KEY_J, JOY_BUTTON_X)
		_check(main.tutorial_step == 2, label + "通常技入力でチュートリアルを進める")
		await _frames(50)
	await _enter_special(gamepad)
	_check(main.player.action == "special", label + "入力履歴を通じて必殺技発動")
	if not gamepad:
		_check(not main.tutorial_active and main.tutorial_seen, label + "必殺技でチュートリアル完了")
	_check(main.commands.history.is_empty(), label + "成立したコマンド履歴を消費")
	await _frames(20)
	_check(not get_nodes_in_group("projectiles").is_empty(), label + "必殺技から投射物生成")
	await _frames(50)
	await _check_main_pause(main, state, gamepad, label)
	var start_x: float = main.player.position.x
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, -1.0)
	else:
		_send_key(KEY_A, true)
	await _frames(6)
	_check(main.player.position.x < start_x, label + "移動入力で後退")
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_Y, -1.0)
	else:
		_send_key(KEY_W, true)
	await _frames(5)
	_check(main.player.position.y < 570.0, label + "上入力でジャンプ")
	await _tap_control(gamepad, KEY_K, JOY_BUTTON_Y)
	_check(main.player.action == "hp", label + "通常攻撃入力")
	_check(main.player.attack_stance == "air", label + "ジャンプ中の攻撃姿勢")
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 0.0)
		_send_axis(JOY_AXIS_LEFT_Y, 0.0)
	else:
		_send_key(KEY_A, false)
		_send_key(KEY_W, false)
	var hp_before_cpu: int = main.player.health
	for frame: int in range(360):
		await _frames(1)
		if main.player.health < hp_before_cpu:
			break
	_check(main.cpu.position.x < 890.0, label + "CPUが自律的に接近")
	_check(main.player.health < hp_before_cpu, label + "CPUが自律的に攻撃して命中")
	await _check_main_round_loop(main, state, gamepad, label)
	main.queue_free()
	await create_timer(0.2).timeout
	AudioServer.set_bus_mute(0, was_muted)


func _check_main_pause(main: Control, state: Node, gamepad: bool, label: String) -> void:
	await _tap_control(gamepad, KEY_ESCAPE, JOY_BUTTON_START)
	_check(main.paused, label + "停止入力で一時停止")
	var before: float = state.remaining
	var player_at: Vector2 = main.player.position
	await _frames(5)
	_check(
		state.remaining == before and main.player.position == player_at, label + "一時停止中は時間と位置を維持"
	)
	await _tap_control(gamepad, KEY_ENTER, JOY_BUTTON_A)
	_check(not main.paused, label + "決定入力で再開")
	_check(main.player.action.is_empty(), label + "再開の決定ボタンで攻撃しない")


func _enter_special(gamepad: bool) -> void:
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_Y, 1.0)
	else:
		_send_key(KEY_S, true)
	await _frames(2)
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 1.0)
	else:
		_send_key(KEY_D, true)
	await _frames(2)
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_Y, 0.0)
	else:
		_send_key(KEY_S, false)
	await _frames(2)
	await _tap_control(gamepad, KEY_J, JOY_BUTTON_X)
	if gamepad:
		_send_axis(JOY_AXIS_LEFT_X, 0.0)
	else:
		_send_key(KEY_D, false)


func _check_main_round_loop(main: Control, state: Node, gamepad: bool, label: String) -> void:
	for round_index: int in range(2):
		main.player.health = 1000
		main.cpu.health = 0
		for frame: int in range(30):
			await _frames(1)
			if state.round_over:
				break
		_check(state.round_over and state.wins[0] == round_index + 1, label + "KOが実際の試合ループで勝利に反映")
		main.outro = 2.8
		await _frames(3)
		if round_index == 0:
			_check(
				state.round_number == 2 and main.player.health == 1000 and main.cpu.health == 1000,
				label + "次ラウンドで両者HPを初期化"
			)
			main.intro = 0.0
			await _frames(2)
	_check(
		state.screen == MATCH_SCRIPT.Screen.RESULT and state.wins == [2, 0], label + "2本先取で実際の結果画面へ"
	)
	_check(
		not is_instance_valid(main.player) and not is_instance_valid(main.cpu),
		label + "結果画面で戦闘ノードを解放"
	)
	await _tap_control(gamepad, KEY_ENTER, JOY_BUTTON_A)
	_check(
		state.screen == MATCH_SCRIPT.Screen.FIGHT and state.wins == [0, 0], label + "結果画面から入力で再戦"
	)
	_check(state.round_number == 1 and main.player.health == 1000, label + "再戦の試合とHP初期化")
	for round_index: int in range(2):
		main.intro = 0.0
		main.player.health = 400
		main.cpu.health = 500
		state.remaining = 0.01
		await _frames(3)
		_check(state.round_over and state.reason == "時間切れ", label + "実際の時間切れ決着")
		main.outro = 2.8
		await _frames(3)
	_check(
		state.screen == MATCH_SCRIPT.Screen.RESULT and state.wins == [0, 2],
		label + "時間切れによるCPU勝利で結果画面へ"
	)
	await _tap_control(gamepad, KEY_ESCAPE, JOY_BUTTON_B)
	_check(state.screen == MATCH_SCRIPT.Screen.TITLE, label + "結果画面から入力でタイトルへ")


func _tap_control(gamepad: bool, key: Key, button: JoyButton) -> void:
	if gamepad:
		_send_button(button, true)
	else:
		_send_key(key, true)
	await _frames(2)
	if gamepad:
		_send_button(button, false)
	else:
		_send_key(key, false)
	await _frames(1)


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_button(button: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _send_axis(axis: JoyAxis, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _check_audio() -> void:
	var music: AudioStreamWAV = load("res://assets/audio/arena.wav")
	_check(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "BGMは前方ループ")
	_check(music.loop_end > music.loop_begin, "BGMのループ区間が有効")
	_check(music.get_length() >= 15.0, "競技場曲は15秒以上のフレーズ")
	for name: String in ["title", "final", "result"]:
		var track: AudioStreamWAV = load("res://assets/audio/%s.wav" % name)
		_check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.loop_end > 0,
			"場面別の曲がループする: " + name)
		_check(track.get_length() >= 10.0, "場面別の曲に十分な長さがある: " + name)
	var crowd: AudioStreamWAV = load("res://assets/audio/crowd.wav")
	_check(crowd.loop_mode == AudioStreamWAV.LOOP_FORWARD, "観客の環境音は前方ループ")
	_check(crowd.get_length() >= 10.0, "観客の環境音に十分な長さがある")


func _check_animation_assets() -> void:
	for frames: SpriteFrames in [FighterVisual.TEAL, FighterVisual.AMBER]:
		for stance: String in ["standing", "crouching", "air"]:
			for kind: String in ["lp", "hp", "lk", "hk"]:
				_check(frames.get_frame_count(stance + "_" + kind) == 8, "通常技8フレーム: " + stance + kind)
		for action: String in ["idle", "walk", "jump", "hurt", "ko", "guard", "special"]:
			_check(frames.get_frame_count(action) == 8, "状態8フレーム: " + action)
	var teal: AtlasTexture = FighterVisual.TEAL.get_frame_texture("idle", 0)
	var amber: AtlasTexture = FighterVisual.AMBER.get_frame_texture("idle", 0)
	_check(teal.atlas != amber.atlas, "両キャラは独立した画像ファイルを使う")
	for frames: SpriteFrames in [FighterVisual.TEAL, FighterVisual.AMBER]:
		var first: AtlasTexture = frames.get_frame_texture("idle", 0)
		var sheet: Image = first.atlas.get_image()
		for action: StringName in frames.get_animation_names():
			for index: int in range(frames.get_frame_count(action)):
				var frame: AtlasTexture = frames.get_frame_texture(action, index)
				var bounds: Rect2i = sheet.get_region(Rect2i(frame.region)).get_used_rect()
				_check(bounds.position.x >= 2 and bounds.position.y >= 2 and
					bounds.end.x <= int(frame.region.size.x) - 2 and
					bounds.end.y <= int(frame.region.size.y) - 2,
					"隣のセルの画像が混入しない透明余白: %s/%d" % [action, index])


func _check_visual_timing(body: FighterBody) -> void:
	body.enabled = true
	body.start_attack("hp")
	await _frames(3)
	_check(body.visual.animation == &"standing_hp", "攻撃状態が対応するアニメーションへ反映")
	body.hitstop = 0.15
	var attack_time: float = body.attack_time
	var frame: int = body.visual.frame
	await _frames(4)
	_check(body.attack_time == attack_time and body.visual.frame == frame, "ヒットストップで判定と画像が共に停止")
	body.hitstop = 0.0
	await _frames(45)
	_check(body.action.is_empty() and body.visual.animation == &"idle", "攻撃硬直の終了で待機へ復帰")
	body.control(Vector2.RIGHT)
	await _frames(4)
	_check(body.visual.animation == &"walk", "移動速度に歩行アニメーションが追随")
	body.enabled = false
	frame = body.visual.frame
	await _frames(8)
	_check(body.visual.frame == frame, "入力停止中は歩行フレームが進まない")
	body.health = 0
	await _frames(15)
	_check(body.visual.animation == &"ko" and body.visual.frame > 0, "KOは入力停止後も倒れる動作が進む")
	body.visible = false
	frame = body.visual.frame
	await _frames(8)
	_check(body.visual.frame == frame, "一時停止の非表示中はKO動作も停止")
	body.visible = true
	await _frames(50)
	_check(body.visual.frame == 7, "KOの末尾ポーズを保持")


func _check_presentation() -> void:
	_check_animation_assets()
	var main: Control = _main_scene.instantiate()
	root.add_child(main)
	await _frames(35)
	_check(main.music_name == "title" and main.bgm.playing, "タイトル曲を再生")
	_check(not main.ambience.playing, "タイトルでは会場環境音を停止")
	_check(main.screen_cover.modulate.a < 0.01, "タイトルのフェードが終了")
	main.show_stage()
	await _frames(2)
	_check(main.ambience.playing, "世界地図から観客の環境音を再生")
	main.start_match()
	main.previewing = true
	main.intro = 0.0
	await _frames(2)
	_check(main.music_name == "arena", "対戦で競技場曲へ切替")
	main.player.health = 875
	await _frames(1)
	_check(main.health_display[0] > 875.0 and main.health_display[0] < 1000.0,
		"体力表示は実体力を変えず補間する")
	_check(main.player.health == 875, "表示補間は戦闘の実体力を書き換えない")
	await _frames(50)
	_check(main.health_display[0] == 875.0 and main.health_trail[0] == 875.0,
		"体力表示と遅れて減るゲージが実体力へ収束")
	main.player.reset_fighter(Vector2(390, 570))
	await _check_visual_timing(main.player)
	_check(main.health_display[0] == 0.0, "KO時は表示数値も即座に0になる")
	var state: Node = root.get_node("Match")
	state.wins.assign([1, 0])
	await _frames(2)
	_check(main.music_name == "final", "どちらかがあと1本になると最終ラウンド曲")
	main._spawn_effect(Vector2(600, 400), false, Color.WHITE)
	await _frames(3)
	_check(not get_nodes_in_group("combat_effects").is_empty(), "粒子とダメージ演出を生成")
	await _frames(50)
	_check(get_nodes_in_group("combat_effects").is_empty(), "粒子とダメージ演出は終了後に解放")
	main._clear_arena()
	state.wins.assign([2, 0])
	state.screen = state.Screen.RESULT
	await _frames(30)
	_check(main.music_name == "result" and main.bgm.playing, "結果画面の曲を再生")
	_check(main.screen_cover.modulate.a < 0.01, "結果画面へのフェードが終了")
	main.stop_audio()
	main.stop_audio()
	_check(
		not main.bgm.playing and main.bgm.stream == null
		and not main.ambience.playing and main.ambience.stream == null,
		"音声停止は繰返し可能でリソース参照を解放"
	)
	main.queue_free()
	await create_timer(0.3).timeout
