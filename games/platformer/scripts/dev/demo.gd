extends SceneTree
## 実キーイベントをフレームごとに投入して2ステージを走る。座標・無敵・残機は変更しない。

var game: DeliveryGame
var session: Node
var elapsed: float = 0.0
var jump_left: float = 0.0
var phase_age: float = 0.0
var previous_phase: String = ""
var finished: bool = false
var frame: int = 0


func _initialize() -> void:
	Input.use_accumulated_input = false
	_start.call_deferred()


func _start() -> void:
	session = root.get_node("Session")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _physics_process(delta: float) -> bool:
	if not is_instance_valid(game):
		return false
	elapsed += delta
	phase_age += delta
	if session.phase != previous_phase:
		previous_phase = session.phase
		phase_age = 0.0
		print("demo: %.2f 秒 %s" % [elapsed, session.phase])
	if session.phase == "title":
		_key(KEY_ENTER, phase_age > 0.6 and phase_age < 0.7)
	elif session.phase == "playing":
		_drive(delta)
	else:
		_release_movement()
		if session.phase == "stage_clear":
			_key(KEY_ENTER, phase_age > 0.55 and phase_age < 0.65)
		elif session.phase == "complete":
			finished = true
		elif session.phase in ["dead", "game_over"]:
			push_error("demo: 配達に失敗: %s (%s)" % [session.death_reason, game.route.player.position])
			game.stop_audio()
			quit(1)
	return false


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 884:
		_release_movement()
		game.stop_audio()
		if not finished:
			print("demo final: elapsed=", elapsed, " x=", game.route.player.position.x,
				" y=", game.route.player.position.y, " seconds=", session.seconds)
			push_error("demo: 30秒以内に2ステージを完走できない")
		else:
			print("demo OK: 2ステージを実キー入力だけで完走")
	if frame == 898:
		quit(0 if finished else 1)
	return false


func _drive(delta: float) -> void:
	_key(KEY_ENTER, false)
	_key(KEY_RIGHT, true)
	_key(KEY_SHIFT, true)
	var player: Courier = game.route.player
	var column: int = int((player.position.x + 85) / 48)
	var hazard: bool = game.route.is_gap(column) or player.is_on_wall()
	for enemy: TrailEnemy in game.route.enemies:
		if is_instance_valid(enemy) and enemy.mode != "dead":
			var distance: float = enemy.position.x - player.position.x
			if distance > 0 and distance < 155:
				hazard = true
	if player.is_on_floor() and hazard and jump_left <= 0:
		jump_left = 12.0 / Engine.physics_ticks_per_second
	_key(KEY_SPACE, jump_left > 0)
	jump_left = maxf(0, jump_left - delta)


func _release_movement() -> void:
	for key: Key in [KEY_RIGHT, KEY_SHIFT, KEY_SPACE]:
		_key(key, false)
	jump_left = 0.0


func _key(code: Key, pressed: bool) -> void:
	if Input.is_physical_key_pressed(code) == pressed:
		return
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
