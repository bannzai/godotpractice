extends SceneTree
## 入力と物理フレームを実際に消費する結合検証。状態の配置は各ケースの前提を独立に作るため。

var failed: bool = false
var game: DeliveryGame
var session: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	session = root.get_node("Session")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(3)
	_send_key(KEY_ENTER, true)
	await _frames(2)
	_send_key(KEY_ENTER, false)
	await _frames(2)
	_check(session.phase == "playing", "キーボード Enter でタイトルから開始")
	if session.phase != "playing":
		game.start_run()
	await _frames(5)
	_check(game.route.player.is_on_floor(), "TileMap の地面に着地")
	var start_x: float = game.route.player.position.x
	Input.action_press("move_right")
	await _frames(25)
	_check(game.route.player.position.x > start_x + 60, "左右移動で位置が進む")
	_check(game.route.player.velocity.x > 240, "歩行加速")
	Input.action_press("dash")
	await _frames(15)
	_check(game.route.player.velocity.x > 390, "ダッシュ加速")
	_release()
	await _frames(15)
	_check(absf(game.route.player.velocity.x) < 1, "減速して停止")
	var short_height: float = await _jump_height(2)
	var long_height: float = await _jump_height(30)
	_check(long_height > short_height + 50, "ジャンプ長押しで到達高度が増える")
	print("jump heights: short=", short_height, " long=", long_height)
	await _check_block_and_power()
	await _check_enemy()
	await _check_damage_and_restart()
	await _check_pad_and_pause()
	for stage_index: int in 2:
		await _traverse(stage_index)
	game._show_title()
	_check(session.phase == "title" and game.route == null, "結果からタイトルへ戻る")
	game.queue_free()
	await _frames(2)
	if not failed:
		print("playcheck OK")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		push_error("playcheck FAIL: " + label)
		failed = true
	else:
		print("playcheck: " + label)


func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame


func _release() -> void:
	for action: String in ["move_left", "move_right", "jump", "dash"]:
		Input.action_release(action)


func _jump_height(held_frames: int) -> float:
	game.route.player.position = Vector2(150, 624)
	game.route.player.velocity = Vector2.ZERO
	await _frames(3)
	var lowest_y: float = 624
	Input.action_press("jump")
	for frame: int in 70:
		if frame == held_frames:
			Input.action_release("jump")
		await physics_frame
		lowest_y = minf(lowest_y, game.route.player.position.y)
	return 624 - lowest_y


func _check_block_and_power() -> void:
	game.start_run()
	await _frames(3)
	var block: SupplyBlock = game.route.blocks[0]
	game.route.player.position = Vector2(block.position.x, 624)
	game.route.player.velocity = Vector2.ZERO
	await _frames(4)
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	_check(block.used, "下からの実衝突でブロックを開ける")
	var power: Sprite2D
	for item: Sprite2D in game.route.items:
		if item.get_meta("kind") == "power":
			power = item
	_check(is_instance_valid(power), "ブロックから強化アイテムが出る")
	if is_instance_valid(power):
		game.route.player.position = power.position + Vector2(0, 20)
		game.route.player.velocity = Vector2.ZERO
		await _frames(3)
		_check(session.powered, "アイテムとの重なりで巨大化")
		var shape: RectangleShape2D = game.route.player.body_shape.shape
		_check(shape.size.y == 64, "巨大化で衝突形状も変わる")


func _check_enemy() -> void:
	game.start_run()
	await _frames(3)
	var enemy: TrailEnemy = game.route.enemies[0]
	enemy.position = Vector2(400, 624)
	game.route.player.position = Vector2(400, 525)
	game.route.player.previous_feet = 525
	game.route.player.velocity = Vector2(0, 300)
	await _frames(20)
	_check(not is_instance_valid(enemy) or enemy.mode == "dead", "落下して歩行敵を踏む")
	_check(session.lives == 3 and session.score >= 200, "踏みつけでは被弾せず加点")
	var shell: TrailEnemy = game.route.enemies[1]
	shell.position = Vector2(500, 624)
	game.route.player.position = Vector2(500, 525)
	game.route.player.previous_feet = 525
	game.route.player.velocity = Vector2(0, 300)
	await _frames(18)
	_check(shell.mode == "resting", "殻の敵は踏むと停止")
	shell.stomp(450)
	_check(shell.mode == "sliding" and shell.direction > 0, "停止した殻を蹴ると滑る")


func _check_damage_and_restart() -> void:
	game.start_run()
	await _frames(3)
	session.collect_power()
	session.invulnerable = 0
	game.route.enemies[0].position = game.route.player.position + Vector2(20, 0)
	await _frames(3)
	_check(not session.powered and session.lives == 3, "横から被弾すると一度だけ縮む")
	game.route.player.position.y = 850
	await _frames(3)
	_check(session.phase == "dead" and session.lives == 2, "穴で残機が減る")
	game._continue()
	await _frames(3)
	_check(session.phase == "playing" and session.lives == 2, "残機を保って再開")
	for attempt: int in 2:
		game.route.player.position.y = 850
		await _frames(3)
		if session.phase == "dead":
			game._continue()
			await _frames(3)
	_check(session.phase == "game_over", "3回の落下でゲームオーバー")
	game._continue()
	await _frames(3)
	_check(session.phase == "playing" and session.lives == 3, "結果から新しい配達を始める")


func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _pad_button(pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)


func _check_pad_and_pause() -> void:
	game._show_title()
	await _frames(3)
	_pad_button(true)
	await _frames(2)
	_pad_button(false)
	await _frames(2)
	_check(session.phase == "playing", "パッド A ボタンでタイトルから開始")
	if session.phase != "playing":
		game.start_run()
	await _frames(5)
	var start_x: float = game.route.player.position.x
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	await _frames(20)
	motion.axis_value = 0.0
	Input.parse_input_event(motion)
	_check(game.route.player.position.x > start_x + 40, "パッドのスティックで移動")
	_send_key(KEY_ESCAPE, true)
	await _frames(2)
	_send_key(KEY_ESCAPE, false)
	_check(session.phase == "paused", "Esc で一時停止")
	var paused_seconds: float = session.seconds
	var paused_position: Vector2 = game.route.player.position
	await _frames(20)
	_check(session.seconds == paused_seconds and game.route.player.position == paused_position,
		"一時停止中は時間と物理位置が変化しない")
	_pad_button(true)
	await _frames(2)
	_pad_button(false)
	await _frames(2)
	_check(session.phase == "playing", "パッド A ボタンで一時停止から再開")


func _traverse(stage_index: int) -> void:
	session.reset_run()
	session.stage = stage_index
	game._load_stage()
	await _frames(4)
	Input.action_press("move_right")
	Input.action_press("dash")
	var held: int = 0
	for frame: int in 1800:
		if session.phase != "playing":
			break
		var player: Courier = game.route.player
		var column: int = int((player.position.x + 85) / 48)
		var hazard: bool = game.route.is_gap(column) or player.is_on_wall()
		for enemy: TrailEnemy in game.route.enemies:
			if is_instance_valid(enemy) and enemy.mode != "dead":
				var dx: float = enemy.position.x - player.position.x
				if dx > 0 and dx < 155:
					hazard = true
		if player.is_on_floor() and hazard and held == 0:
			Input.action_press("jump")
			held = 12
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		await physics_frame
	_release()
	print("route ", stage_index, " phase=", session.phase, " x=", game.route.player.position.x,
		" y=", game.route.player.position.y, " reason=", session.death_reason)
	if session.phase == "dead":
		for enemy: TrailEnemy in game.route.enemies:
			if is_instance_valid(enemy):
				print("enemy ", enemy.kind, " ", enemy.mode, " ", enemy.position)
	_check(session.phase == ("stage_clear" if stage_index == 0 else "complete"),
		"ステージ %d を入力だけで始点からゴールまで走破" % (stage_index + 1))
	_check(game.route.camera.position.x <= game.route.camera.limit_right - 640,
		"カメラは右端で停止")
