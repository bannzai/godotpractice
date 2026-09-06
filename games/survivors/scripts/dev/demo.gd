extends SceneTree
## 26 秒の録画専用シナリオ。時刻ごとに実 InputEvent を投入して通常の UI と移動を通す。
## 時間短縮のため敵・武器・経験値・残り時間を途中で設定する。通常プレイの成績検証ではない。
## 通常ルールでの 600 秒生存は playthrough.gd が担当する。

const Rules = preload("res://scripts/game_rules.gd")
const FPS: int = 30
const TOTAL_FRAMES: int = 780

var state: Node
var main: Node
var failed: bool = false
var movement_start: Vector2
var healed: bool = false
var upgrade_selected: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 録画フレームに合わせて入力とデモ状態を一度ずつ適用するため非冪等。
func _run() -> void:
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("RunState")
	print("デモ: 26 秒 / 実入力イベント / 敵・武器・経験値・時刻は録画用に設定")
	for frame: int in range(TOTAL_FRAMES):
		_event(frame)
		await process_frame
		if frame == 319:
			healed = state.hp > 55.0
		if frame == 435:
			upgrade_selected = state.phase == "playing"
	_check(healed, "回復アイテムの取得")
	_check(upgrade_selected, "強化選択からプレイへ復帰")
	_check(state.phase == "title", "結果画面からタイトルへ戻る")
	await RenderingServer.frame_post_draw
	var status: Error = root.get_texture().get_image().save_png("tmp/movie-play-last.png")
	_check(status == OK, "末尾フレームの保存")
	main.audio.shutdown()
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("demo OK")
	quit(1 if failed else 0)


func _event(frame: int) -> void:
	match frame:
		45: _key(KEY_ENTER, true)
		47: _key(KEY_ENTER, false)
		90:
			_check(state.phase == "playing", "タイトルから Enter で開始")
			_prepare_battle()
		105: _key(KEY_D, true)
		165:
			_key(KEY_D, false)
			_key(KEY_S, true)
		225:
			_key(KEY_S, false)
			_key(KEY_A, true)
		285:
			_key(KEY_A, false)
			_key(KEY_W, true)
			state.invulnerable = 0.0
			state.take_damage(28.0)
			state.items.append({"pos": state.player_pos + Vector2(0, -65), "kind": "heal"})
		330:
			_key(KEY_W, false)
			_check(state.player_pos.distance_to(movement_start) > 30.0, "実入力で移動")
			state.xp = 0
			state.gain_xp(Rules.xp_needed(state.level))
		375: _key(KEY_RIGHT, true)
		377: _key(KEY_RIGHT, false)
		405: _key(KEY_ENTER, true)
		407: _key(KEY_ENTER, false)
		420: _prepare_boss()
		435: _key(KEY_A, true)
		495:
			_key(KEY_A, false)
			_key(KEY_D, true)
		555:
			_key(KEY_D, false)
			_key(KEY_W, true)
		600:
			_key(KEY_W, false)
			# ボス戦中に自然に得た追加強化も、実入力で決定してから結末へ進める。
			state.xp = 0
			_key(KEY_ENTER, true)
		602: _key(KEY_ENTER, false)
		615: state.elapsed = Rules.DURATION - 0.1
		660: _check(state.phase == "result" and state.won, "時間満了によるクリア結果")
		690: _key(KEY_RIGHT, true)
		692: _key(KEY_RIGHT, false)
		720: _key(KEY_ENTER, true)
		722: _key(KEY_ENTER, false)
	if frame % (FPS * 2) == 0:
		print("デモ %02d 秒: %s / HP %.0f / 撃破 %d" % [frame / FPS, state.phase,
			state.hp, state.kills])


func _prepare_battle() -> void:
	# Enter による開始を確認した後、録画区間だけ乱数種を固定して再現できるようにする。
	state.start_run(77)
	movement_start = state.player_pos
	state.weapons = {"bolt": 3, "orbit": 2, "pulse": 2}
	state.level = 18
	state.xp = 0
	state.hp = 70.0
	state.elapsed = 300.0
	for index: int in range(30):
		state.spawn_enemy(index % 3, state.player_pos +
			Vector2.from_angle(index * 2.399) * (180.0 + float(index % 5) * 48.0))
	state.items.append({"pos": state.player_pos + Vector2(240, 60), "kind": "magnet"})


func _prepare_boss() -> void:
	state.elapsed = 574.0
	state.boss_spawned = true
	state.spawn_enemy(3, state.player_pos + Vector2(190, -35))
	state.hp = state.max_hp
	for index: int in range(18):
		state.spawn_enemy(index % 3, state.player_pos +
			Vector2.from_angle(index * 2.399) * 310.0)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("demo FAIL: " + label)
