extends SceneTree
## 実ゲームの入力と更新を固定刻みで進め、描画によらない一連の操作を検証する。

const Stage: GDScript = preload("res://scripts/stage_data.gd")
const TEST_SAVE: String = "res://tmp/integration-save.json"

var game: Control
var state: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	game.automatic = false
	root.add_child(game)
	state = root.get_node("GameState")
	state.save_path = TEST_SAVE
	state.high_score = 0
	Input.use_accumulated_input = false
	_check_inputs()
	_check_direction_inputs()
	_check_collisions_and_items()
	_check_bomb_and_damage()
	_check_repeated_hit_animation()
	await _check_full_stage()
	_release_inputs()
	game.music.stop()
	for voice: AudioStreamPlayer in game.sounds.values():
		voice.stop()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await process_frame
	if FileAccess.file_exists(TEST_SAVE):
		_check(DirAccess.remove_absolute(TEST_SAVE) == OK, "検証用保存を片付ける")
	if failed:
		quit(1)
	else:
		print("integration_check OK")
		quit(0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("integration_check FAIL: " + label)
		failed = true


func _check_inputs() -> void:
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	_check(state.mode == state.Mode.NAVIGATION, "Enter入力でタイトルから航路図")
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	_check(state.mode == state.Mode.TUTORIAL, "航路確定で初回の計器チェック")
	var tutorial_position: Vector2 = game.player
	_key(KEY_D, true)
	_key(KEY_D, false)
	_check(game.tutorial_step == 1 and game.player == tutorial_position, "操縦桿入力を場面内で検出")
	_key(KEY_Z, true)
	_key(KEY_Z, false)
	_check(game.tutorial_step == 2, "射撃入力を場面内で検出")
	_key(KEY_X, true)
	_key(KEY_X, false)
	_check(state.mode == state.Mode.PLAYING and state.tutorial_seen, "ボム入力で計器チェック完了")
	_check(game.music.playing and game.music.stream.loop, "出撃時にステージBGMをループ再生")
	_check(game.music.stream.resource_path.ends_with("stage.ogg"), "ステージBGMを選択")
	var before: Vector2 = game.player
	_key(KEY_D, true)
	game.advance(0.1)
	_key(KEY_D, false)
	_check(is_equal_approx(game.player.x - before.x, 34.0), "キーボードで右へ移動")
	before = game.player
	_key(KEY_D, true)
	_key(KEY_W, true)
	game.advance(0.1)
	_key(KEY_D, false)
	_key(KEY_W, false)
	_check(is_equal_approx(game.player.distance_to(before), 34.0), "斜め移動の速度を正規化")
	_check(game.player.x > before.x and game.player.y < before.y, "右上方向へ移動")
	before = game.player
	_axis(JOY_AXIS_LEFT_X, -1.0)
	game.advance(0.1)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_check(is_equal_approx(before.x - game.player.x, 34.0), "ゲームパッドのスティックで移動")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	before = game.player
	var elapsed: float = state.elapsed
	_key(KEY_D, true)
	game.advance(1.0)
	_key(KEY_D, false)
	_check(game.paused and game.player == before and state.elapsed == elapsed, "ポーズ中は更新停止")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_check(not game.paused, "Escape入力で再開")
	game.return_title()
	_button(JOY_BUTTON_A, true)
	_button(JOY_BUTTON_A, false)
	_check(state.mode == state.Mode.NAVIGATION, "ゲームパッドA入力で航路図")
	_button(JOY_BUTTON_A, true)
	_button(JOY_BUTTON_A, false)
	_check(state.mode == state.Mode.PLAYING, "ゲームパッドA入力で選択航路へ再出撃")
	_button(JOY_BUTTON_A, true)
	game.advance(0.05)
	_button(JOY_BUTTON_A, false)
	_check(game.bullets.size() > 0, "ゲームパッドA入力で射撃")
	_key(KEY_D, true)
	game.advance(5.0)
	_key(KEY_D, false)
	_check(game.player.x <= 938.0, "画面端で移動を制限")


func _check_direction_inputs() -> void:
	game.start_run()
	var directions: Dictionary = {
		KEY_LEFT: Vector2.LEFT,
		KEY_A: Vector2.LEFT,
		KEY_RIGHT: Vector2.RIGHT,
		KEY_D: Vector2.RIGHT,
		KEY_UP: Vector2.UP,
		KEY_W: Vector2.UP,
		KEY_DOWN: Vector2.DOWN,
		KEY_S: Vector2.DOWN,
	}
	for code: Key in directions:
		game.player = Vector2(640, 500)
		_key(code, true)
		game.advance(0.05)
		_key(code, false)
		var expected: Vector2 = Vector2(640, 500) + directions[code] * 17.0
		_check(game.player.is_equal_approx(expected), "矢印/WASDの各方向: " + OS.get_keycode_string(code))


func _check_collisions_and_items() -> void:
	game.start_run()
	game.spawn_enemy({"x": 640.0, "kind": "scout", "drop": "power"})
	game.enemies[0].position = Vector2(640.0, 400.0)
	_key(KEY_Z, true)
	for tick: int in range(55):
		game.advance(1.0 / 60.0)
	_key(KEY_Z, false)
	_check(game.enemies.is_empty(), "押し続けのショットが敵へ命中して撃破")
	_check(state.score == 120 and game.effects.size() > 0, "撃破で得点と爆発を生成")
	_check(game.items.size() == 1, "撃破した敵から指定のアイテムが出現")
	if not game.items.is_empty():
		game.player = game.items[0].position
		game.advance(0.01)
	_check(state.power == 2 and game.items.is_empty(), "接触でパワーアップを回収")
	game.items.append({"position": game.player, "kind": "power", "age": 0.0})
	game.advance(0.01)
	game.bullets.clear()
	game.fire_player()
	_check(state.power == 3 and game.bullets.size() == 3, "第2段階の強化で3本のショット")
	var before: int = state.score
	game.items.append({"position": game.player, "kind": "score", "age": 0.0})
	game.advance(0.01)
	_check(state.score == before + 500, "接触でスコアアイテムを回収")
	game.items.append({"position": Vector2(500, 761), "kind": "power", "age": 0.0})
	game.advance(0.01)
	_check(game.items.is_empty(), "画面外に流れたアイテムを除去")


func _check_bomb_and_damage() -> void:
	game.start_run()
	game.boss_active = true
	game.boss_hp = Stage.BOSS_HP
	game.spawn_enemy({"x": 450.0, "kind": "fan", "drop": "bomb"})
	game.enemies[0].position = Vector2(450.0, 300.0)
	game.bullets.append(_bullet(Vector2(400, 400), false))
	game.bullets.append(_bullet(Vector2(800, 400), true))
	_key(KEY_X, true)
	_key(KEY_X, false)
	_check(state.bombs == 2, "X入力でボムを1個消費")
	_check(game.bullets.size() == 1 and game.bullets[0].friendly, "ボムで敵弾だけを除去")
	_check(game.enemies.is_empty() and game.boss_hp == 275, "ボムで雑魚撃破とボスへ大ダメージ")
	_check(game.flash > 0 and game.invulnerable > 0, "ボムの発光と無敵時間")
	if not game.items.is_empty():
		game.player = game.items[0].position
		game.advance(0.01)
	_check(state.bombs == 3, "敵ドロップからボム補充")
	game.start_run()
	game.invulnerable = 0.0
	game.bullets.append(_bullet(game.player - Vector2(0, 100), false, Vector2(0, 1000)))
	game.advance(0.2)
	_check(state.lives == 2, "フレーム間を横切る高速敵弾でも被弾を検出")
	game.bullets.append(_bullet(game.player, false))
	game.advance(0.01)
	_check(state.lives == 2, "被弾直後の無敵時間で連続被弾を防ぐ")
	for hit: int in range(2):
		game.invulnerable = 0.0
		game.bullets.append(_bullet(game.player, false))
		game.advance(0.01)
	_check(state.mode == state.Mode.RESULT and state.lives == 0, "敵弾の被弾でゲームオーバー")
	game.return_title()
	_check(state.mode == state.Mode.TITLE, "ゲームオーバー後にタイトルへ戻る")


func _check_full_stage() -> void:
	game.start_run()
	state.power = 3
	game.invulnerable = 999.0
	var saw_boss: bool = false
	var saw_second_phase: bool = false
	_key(KEY_Z, true)
	# 出現と射撃の実処理を通し、被弾による中断だけを無敵時間で除外する。
	for tick: int in range(12600):
		# 音声の再生・解放はエンジンのフレーム更新を通す必要がある。
		if tick % 120 == 0:
			await process_frame
		if game.boss_active:
			if not saw_boss:
				_check(game.music.playing and game.music.stream.loop, "ボスBGMをループ再生")
				_check(game.music.stream.resource_path.ends_with("boss.ogg"), "ボス登場時にBGM切替")
			saw_boss = true
			game.player.x = game.boss_position.x
			saw_second_phase = saw_second_phase or Stage.boss_phase(game.boss_hp) == 2
		game.advance(1.0 / 60.0)
		if state.mode == state.Mode.RESULT:
			break
	_key(KEY_Z, false)
	_check(game.wave_index == Stage.waves().size(), "時間進行ですべての敵ウェーブを消化")
	_check(saw_boss and saw_second_phase, "ボスが登場して攻撃の第2段階まで進む")
	_check(state.mode == state.Mode.RESULT and state.cleared, "自機ショットでボス撃破からクリア")
	_check(state.elapsed >= Stage.BOSS_TIME and state.elapsed < 210.0, "約3分でクリアできる長さ")
	_check(state.score >= 10000 and game.boss_hp == 0, "ボス撃破得点を加算")
	print("全ステージ進行時間: %.2f秒" % state.elapsed)
	var record: int = state.high_score
	state.high_score = 0
	state.load_high_score()
	_check(state.high_score == record, "クリア結果の最高得点を保存済み")
	game.start_run()
	_check(state.score == 0 and state.high_score == record, "結果から再出撃して最高得点を保持")
	_check(game.enemies.is_empty() and not game.boss_active, "再出撃でステージを初期化")
	game.return_title()
	_check(state.mode == state.Mode.TITLE, "再出撃後にもタイトルへ戻れる")


func _bullet(position: Vector2, friendly: bool, velocity: Vector2 = Vector2.ZERO) -> Dictionary:
	return {"position": position, "friendly": friendly, "velocity": velocity}


# 入力イベントは押下/解放を区別するため非冪等。各検査で解放までを組にする。
func _key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# アナログ軸の状態をイベントとして渡し、GodotのInputMap解釈を通す。
func _axis(axis: JoyAxis, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# ボタン入力は押下ごとのイベントを発火するため非冪等。
func _button(button: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_inputs() -> void:
	for code: Key in [KEY_ENTER, KEY_D, KEY_W, KEY_Z, KEY_X, KEY_ESCAPE]:
		_key(code, false)
	_button(JOY_BUTTON_A, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)


func _check_repeated_hit_animation() -> void:
	game.start_run()
	state.elapsed = Stage.BOSS_TIME
	game.wave_index = game.waves.size()
	game.boss_active = true
	game.boss_hp = Stage.BOSS_HP
	game.invulnerable = 10.0
	var saw_hit: bool = false
	var saw_attack: bool = false
	var saw_movement: bool = false
	for tick: int in range(150):
		if tick % 8 == 0:
			game.damage_boss(1)
		game.advance(1.0 / 60.0)
		saw_hit = saw_hit or game.boss_pose == "hit"
		saw_attack = saw_attack or game.boss_pose == "attack"
		saw_movement = saw_movement or game.boss_pose in ["idle", "move"]
	_check(saw_hit and saw_attack and saw_movement, "連射命中が続いてもボスの被弾・攻撃・通常姿勢が切り替わる")
	game.damage_boss(Stage.BOSS_HP)
	_check(game.boss_pose == "death", "撃破時は被弾より死亡姿勢を優先")
	var has_death: bool = false
	for effect: Dictionary in game.effects:
		has_death = (
			has_death or (effect.get("kind", "") == "death" and effect.get("actor", "") == "boss")
		)
	_check(has_death, "結果へ移っても死亡アニメーション用データを残す")
	_check(game.music.stream.resource_path.ends_with("result.ogg"), "撃破後に結果BGMへ切替")
	game.return_title()
	_check(game.music.stream.resource_path.ends_with("title.ogg"), "タイトルへ戻ると専用BGMへ切替")
