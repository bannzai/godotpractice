extends SceneTree
## 通常入力だけで全十二室を巡る。状態・座標・在庫は読み取り専用。

const DEADLINE_FRAMES: int = 7200
var main: Node
var world: Node
var state: Node
var frames: int = 0
var held: Key = KEY_NONE
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	world = main.world
	state = main.state
	await _wait(5)
	await _tap(KEY_ENTER)
	for room: int in range(12):
		if failed:
			break
		if state.room != room:
			_fail("部屋 %d へ通常移動できなかった" % room)
			break
		print("playthrough 部屋 %d: HP %d / %d" % [room, state.hp, state.max_hp])
		await _wait(26)
		match room:
			0:
				await _walk(Vector2(380, 320))
				await _tap(KEY_E)
				_check(state.mode == "dialogue", "村人との会話")
				await _tap(KEY_ESCAPE)
			1:
				await _walk(Vector2(450, 290))
				await _tap(KEY_E)
				_check(state.mode == "dialogue" and main.shop_open, "道具屋との会話")
				await _tap(KEY_ESCAPE)
			4:
				await _walk(Vector2(890, 570))
				await _tap(KEY_E)
				_check(state.opened.has("field-heart"), "野外のハート宝箱")
			5:
				await _walk(Vector2(640, 260))
				await _tap(KEY_E)
			6:
				await _walk(Vector2(470, 350))
				await _tap(KEY_E)
				_check(state.boomerang_owned, "風の輪を通常取得")
			7:
				await _walk(Vector2(600, 384))
				await _tap(KEY_D)
				await _tap(KEY_K)
				await _wait(70)
				_check(state.has_flag("wind-bridge"), "風の輪で対岸のスイッチを起動")
			8:
				await _walk(Vector2(340, 330))
				await _tap(KEY_E)
				_check(state.bombs_owned, "爆弾袋を通常取得")
				await _walk(Vector2(900, 330))
				await _tap(KEY_D)
				await _tap(KEY_K)
				await _wait(80)
				_check(state.has_flag("broken-wall"), "爆弾でひび割れ壁を破壊")
			9:
				await _walk(Vector2(300, 384))
				await _walk(Vector2(546, 384))
				_check(state.has_flag("weight"), "石を押して床の灯を起動")
				await _walk(Vector2(546, 300))
				await _walk(Vector2(850, 300))
				await _tap(KEY_E)
				_check(state.keys == 1, "小さな鍵を通常取得")
				await _walk(Vector2(1060, 384))
				await _tap(KEY_E)
				_check(state.unlocked.has("iron") and state.keys == 0, "鍵を使って扉を解錠")
			10:
				await _walk(Vector2(416, 384))
				_check(state.has_flag("star"), "穴を避けて床スイッチを起動")
				await _walk(Vector2(830, 384))
				await _walk(Vector2(830, 290))
				await _tap(KEY_E)
				_check(state.opened.has("deep-heart"), "遺跡のハート宝箱")
				await _walk(Vector2(830, 384))
			11:
				await _fight_boss()
				await _walk(Vector2(870, 384))
				await _tap(KEY_E)
		if room < 5:
			await _walk(Vector2(world.hero.position.x, 580))
			await _exit_right(room)
		elif room > 5 and room < 11:
			await _exit_right(room)
	_check(state.mode == "ending" and state.has_flag("treasure"), "祭壇の灯りを受け取り結末へ")
	_release()
	main.stop_audio()
	await _wait(20)
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("playthrough OK: 通常入力だけで全十二室と結末を完走 (%d フレーム)" % frames)
	quit(1 if failed else 0)


# 操作シナリオは時間と入力イベントを消費するので非冪等。
func _walk(target: Vector2) -> void:
	var guard: int = 0
	while not failed and world.hero.position.distance_to(target) > 7:
		guard += 1
		if guard > 900:
			_fail("座標 %s に移動できない。現在 %s" % [target, world.hero.position])
			break
		var offset: Vector2 = target - world.hero.position
		var key: Key = KEY_NONE
		if absf(offset.y) > 5:
			key = KEY_S if offset.y > 0 else KEY_W
		elif absf(offset.x) > 5:
			key = KEY_D if offset.x > 0 else KEY_A
		_hold(key)
		await _step()
	_release()


func _exit_right(room: int) -> void:
	var guard: int = 0
	_hold(KEY_D)
	while not failed and state.room == room:
		guard += 1
		if guard > 900:
			_fail("部屋 %d の東出口で停止。座標 %s" % [room, world.hero.position])
			break
		await _step()
	_release()


func _fight_boss() -> void:
	var guard: int = 0
	while not failed and not state.has_flag("boss"):
		guard += 1
		var boss: Node2D = world.enemies[0]
		var offset: Vector2 = boss.position - world.hero.position
		var key: Key = KEY_NONE
		if absf(offset.y) > 20:
			key = KEY_S if offset.y > 0 else KEY_W
		elif absf(offset.x) > 96:
			key = KEY_D if offset.x > 0 else KEY_A
		elif absf(offset.x) < 80:
			key = KEY_A if offset.x > 0 else KEY_D
		_hold(key)
		if guard % 22 == 0 and offset.length() < 120:
			_release()
			await _tap(KEY_D if offset.x > 0 else KEY_A)
			await _tap(KEY_J)
			if guard % 88 == 0 and state.bombs > 0:
				await _tap(KEY_K)
		await _step()
	_release()
	_check(state.has_flag("boss"), "剣と道具で梟を撃破")


func _hold(key: Key) -> void:
	if key == held:
		return
	_release()
	held = key
	if held != KEY_NONE:
		_key(held, true)


func _release() -> void:
	if held != KEY_NONE:
		_key(held, false)
		held = KEY_NONE


func _tap(key: Key) -> void:
	if failed:
		return
	_key(key, true)
	await _wait(2)
	_key(key, false)
	await _wait(2)


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _wait(count: int) -> void:
	for i: int in range(count):
		await _step()


func _step() -> void:
	await physics_frame
	frames += 1
	if not failed and frames > DEADLINE_FRAMES:
		_fail("120 秒の攻略期限を超過")
	if not failed and state.mode == "gameover":
		_fail("部屋 %d で倒れた。座標 %s" % [state.room, world.hero.position])


func _check(condition: bool, message: String) -> void:
	if not condition and not failed:
		_fail(message)
	elif not failed:
		print("playthrough 確認: " + message)


func _fail(message: String) -> void:
	if failed:
		return
	failed = true
	printerr("playthrough FAILED: " + message)
