extends Control
## ゲームイベントと時間更新はプレイを進めるため非冪等。再開は start_run で初期化する。

const Stage = preload("res://scripts/stage_data.gd")
const View = preload("res://scripts/flight_view.gd")
const FIELD: Rect2 = Rect2(320, 0, 640, 720)

var player: Vector2 = Vector2(640, 600)
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var items: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var wave_index: int = 0
var boss_hp: int = 0
var boss_position: Vector2 = Vector2(640, 125)
var boss_active: bool = false
var boss_timer: float = 0.0
var shot_timer: float = 0.0
var invulnerable: float = 0.0
var flash: float = 0.0
var animation_time: float = 0.0
var paused: bool = false
var automatic: bool = true
var view: Node2D
var music: AudioStreamPlayer
var sounds: Dictionary = {}
var buttons: Array[Button] = []
var previous_mode: int = -1


func _ready() -> void:
	view = View.new()
	view.game = self
	add_child(view)
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	add_child(music)
	for sound: String in ["shot", "explosion", "item", "bomb"]:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.stream = load("res://assets/audio/%s.wav" % sound)
		voice.volume_db = -19.0 if sound == "shot" else -9.0
		add_child(voice)
		sounds[sound] = voice
	_sync_menu()
	print("shooter boot")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and GameState.mode == GameState.Mode.PLAYING:
		paused = not paused
		music.stream_paused = paused
		_sync_menu()
	elif event.is_action_pressed("start") and GameState.mode != GameState.Mode.PLAYING:
		start_run()
	elif event.is_action_pressed("bomb") and not paused:
		trigger_bomb()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if GameState.mode == GameState.Mode.PLAYING:
			paused = true
			music.stream_paused = true
			_sync_menu()


func _process(delta: float) -> void:
	if automatic:
		advance(delta)
	if previous_mode != GameState.mode:
		_sync_menu()
	view.queue_redraw()


func start_run() -> void:
	GameState.reset_run()
	player = Vector2(640, 600)
	enemies.clear()
	bullets.clear()
	items.clear()
	effects.clear()
	waves = Stage.waves()
	wave_index = 0
	boss_hp = 0
	boss_active = false
	boss_timer = 0.0
	shot_timer = 0.0
	invulnerable = 2.0
	flash = 0.0
	paused = false
	_play_music("stage")
	_sync_menu()


func return_title() -> void:
	GameState.show_title()
	paused = false
	music.stop()
	_sync_menu()


func resume_run() -> void:
	paused = false
	music.stream_paused = false
	_sync_menu()


func advance(delta: float) -> void:
	if paused:
		return
	animation_time += delta
	flash = maxf(0.0, flash - delta)
	for effect: Dictionary in effects:
		effect.age += delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.age < 0.7)
	if GameState.mode != GameState.Mode.PLAYING:
		return
	GameState.elapsed += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player += direction * 340.0 * delta
	player = player.clamp(Vector2(342, 36), Vector2(938, 687))
	shot_timer -= delta
	if Input.is_action_pressed("shoot") and shot_timer <= 0.0:
		fire_player()
	while wave_index < waves.size() and float(waves[wave_index].time) <= GameState.elapsed:
		spawn_enemy(waves[wave_index])
		wave_index += 1
	if GameState.elapsed >= Stage.BOSS_TIME and not boss_active:
		boss_active = true
		boss_hp = Stage.BOSS_HP
		bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.friendly)
		_play_music("boss")
	_update_enemies(delta)
	_update_boss(delta)
	_update_bullets(delta)
	_update_items(delta)


func fire_player() -> void:
	shot_timer = 0.13
	for index: int in range(GameState.power):
		var offset: float = (index - (GameState.power - 1) / 2.0) * 17.0
		bullets.append(
			{
				"position": player + Vector2(offset, -28),
				"velocity": Vector2(offset * 2.0, -760),
				"friendly": true
			}
		)
	_sound("shot")


func spawn_enemy(wave: Dictionary) -> void:
	var stats: Dictionary = Stage.enemy_stats(wave.kind)
	enemies.append(
		{
			"position": Vector2(wave.x, -36),
			"origin_x": float(wave.x),
			"kind": wave.kind,
			"hp": stats.hp,
			"age": 0.0,
			"timer": 1.0,
			"drop": wave.drop
		}
	)


func trigger_bomb() -> void:
	if GameState.mode != GameState.Mode.PLAYING or not GameState.use_bomb():
		return
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.friendly)
	for enemy: Dictionary in enemies.duplicate():
		_destroy_enemy(enemy)
	if boss_active and boss_hp > 0:
		damage_boss(85)
	invulnerable = maxf(invulnerable, 1.8)
	flash = 0.65
	effects.append({"position": player, "age": 0.0, "large": true})
	_sound("bomb")


func hit_player() -> void:
	if invulnerable > 0.0 or GameState.mode != GameState.Mode.PLAYING:
		return
	effects.append({"position": player, "age": 0.0, "large": false})
	GameState.take_hit()
	invulnerable = 2.5
	flash = 0.2
	_sound("explosion")
	if GameState.mode == GameState.Mode.RESULT:
		music.stop()


func damage_boss(amount: int) -> void:
	if boss_hp <= 0:
		return
	boss_hp = maxi(0, boss_hp - amount)
	if boss_hp == 0:
		effects.append({"position": boss_position, "age": 0.0, "large": true})
		GameState.add_score(10000)
		GameState.finish_run(true)
		_sound("explosion")
		music.stop()


func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies.duplicate():
		var stats: Dictionary = Stage.enemy_stats(enemy.kind)
		enemy.age += delta
		enemy.position.y += float(stats.speed) * delta
		if enemy.kind == "fan":
			enemy.position.x = clampf(enemy.origin_x + sin(enemy.age * 2.3) * 65.0, 348, 932)
		enemy.timer -= delta
		if enemy.timer <= 0.0 and enemy.position.y > 20 and enemy.position.y < 540:
			var pattern: String = "straight" if enemy.kind == "scout" else enemy.kind
			_enemy_shot(pattern, enemy.position)
			enemy.timer = stats.shot_interval
		if enemy.position.distance_to(player) < 31:
			hit_player()
		if enemy.position.y > 760:
			enemies.erase(enemy)


func _update_boss(delta: float) -> void:
	if not boss_active or boss_hp <= 0:
		return
	boss_position.x = 640.0 + sin((GameState.elapsed - Stage.BOSS_TIME) * 0.65) * 165.0
	boss_timer -= delta
	if boss_timer <= 0.0:
		_enemy_shot("boss", boss_position + Vector2(0, 60), Stage.boss_phase(boss_hp))
		boss_timer = 1.05 if Stage.boss_phase(boss_hp) == 1 else 0.68
	if absf(player.x - boss_position.x) < 105 and absf(player.y - boss_position.y) < 60:
		hit_player()


func _enemy_shot(pattern: String, origin: Vector2, phase: int = 1) -> void:
	for velocity: Vector2 in Stage.bullet_velocities(pattern, origin, player, phase):
		bullets.append({"position": origin, "velocity": velocity, "friendly": false})


func _update_bullets(delta: float) -> void:
	for bullet: Dictionary in bullets.duplicate():
		var before: Vector2 = bullet.position
		bullet.position += bullet.velocity * delta
		if bullet.friendly:
			_player_bullet_hit(bullet, before)
		elif _segment_distance(player, before, bullet.position) < 12:
			bullets.erase(bullet)
			hit_player()
		if not FIELD.grow(65).has_point(bullet.position):
			bullets.erase(bullet)


func _player_bullet_hit(bullet: Dictionary, before: Vector2) -> void:
	for enemy: Dictionary in enemies.duplicate():
		if _segment_distance(enemy.position, before, bullet.position) < 25:
			enemy.hp -= 1
			bullets.erase(bullet)
			if enemy.hp <= 0:
				_destroy_enemy(enemy)
			return
	if boss_active and boss_hp > 0:
		var hitbox: Rect2 = Rect2(boss_position - Vector2(108, 48), Vector2(216, 96))
		if hitbox.has_point(bullet.position):
			bullets.erase(bullet)
			damage_boss(1)


func _destroy_enemy(enemy: Dictionary) -> void:
	if not enemies.has(enemy):
		return
	GameState.add_score(int(Stage.enemy_stats(enemy.kind).score))
	effects.append({"position": enemy.position, "age": 0.0, "large": false})
	if not String(enemy.drop).is_empty():
		items.append({"position": enemy.position, "kind": enemy.drop, "age": 0.0})
	enemies.erase(enemy)
	_sound("explosion")


func _update_items(delta: float) -> void:
	for item: Dictionary in items.duplicate():
		item.age += delta
		item.position.y += 100.0 * delta
		if item.position.distance_to(player) < 32:
			GameState.collect_item(item.kind)
			items.erase(item)
			_sound("item")
		elif item.position.y > 760:
			items.erase(item)


func _segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))


func _sound(name: String) -> void:
	if sounds.has(name):
		sounds[name].play()


func _play_music(track: String) -> void:
	music.stream = load("res://assets/audio/%s.ogg" % track)
	music.stream.loop = true
	music.stream_paused = false
	music.play()


func _sync_menu() -> void:
	previous_mode = GameState.mode
	for button: Button in buttons:
		button.hide()
		button.queue_free()
	buttons.clear()
	if paused:
		_add_button("飛行を続ける", Vector2(495, 382), resume_run)
		_add_button("タイトルへ", Vector2(495, 447), return_title)
	elif GameState.mode == GameState.Mode.TITLE:
		_add_button("出撃する   ↵ / A", Vector2(104, 463), start_run)
	elif GameState.mode == GameState.Mode.RESULT:
		_add_button("もう一度出撃", Vector2(495, 460), start_run)
		_add_button("タイトルへ", Vector2(495, 525), return_title)
	if not buttons.is_empty():
		buttons[0].grab_focus()


func _add_button(text: String, location: Vector2, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.position = location
	button.size = Vector2(290, 52)
	button.add_theme_font_override("font", view.font)
	button.add_theme_font_size_override("font_size", 21)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("155568") if state == "normal" else Color("247f8c")
		style.border_color = Color("76f1d5")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(action)
	add_child(button)
	buttons.append(button)
