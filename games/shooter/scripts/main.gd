extends Control
## ゲームイベントと時間更新はプレイを進めるため非冪等。再開は start_run で初期化する。

const Stage = preload("res://scripts/stage_data.gd")
const View = preload("res://scripts/flight_view.gd")
const CombatEffects = preload("res://scripts/combat_effects.gd")
const FIELD: Rect2 = Rect2(320, 0, 640, 720)
const HIT_POSE_DURATION: float = 0.22
const HIT_POSE_INTERVAL: float = 0.6

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
var player_pose: String = "idle"
var player_pose_time: float = 0.0
var boss_pose: String = "idle"
var boss_pose_time: float = 0.0
var result_time: float = 0.0
var tutorial_step: int = 0
var tutorial_pulse: float = 0.0
var scan_timer: float = 0.4
var boss_chart_active: bool = false
var boss_chart_time: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var hitstop: float = 0.0
var combat_effects: Node2D
var _visual_id: int = 0
var _shake_strength: float = 0.0
var _transition: ColorRect
var _transition_tween: Tween
var _closing: bool = false
var _audio_closing: bool = false
var _boss_hit_cooldown: float = 0.0
var _boss_attack_time: float = 0.0
var _capture_frames: int = 0


func _ready() -> void:
	get_tree().auto_accept_quit = false
	_prepare_capture_exit()
	view = View.new()
	view.game = self
	add_child(view)
	combat_effects = CombatEffects.new()
	combat_effects.font = view.font
	combat_effects.z_index = -1
	add_child(combat_effects)
	music = AudioStreamPlayer.new()
	music.volume_db = -13.0
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(music)
	for sound: String in ["shot", "explosion", "item", "bomb", "scan"]:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.stream = load("res://assets/audio/%s.wav" % sound)
		voice.volume_db = -19.0 if sound == "shot" else -9.0
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		sounds[sound] = voice
	_transition = ColorRect.new()
	_transition.size = Vector2(1280, 720)
	_transition.color = Color("091624")
	_transition.modulate.a = 0.0
	_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition.z_index = 100
	add_child(_transition)
	_play_music("title")
	_sync_menu()
	print("shooter boot")


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("fullscreen"):
		var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
	elif GameState.mode == GameState.Mode.TUTORIAL:
		_handle_tutorial_input(event)
	elif event.is_action_pressed("pause") and GameState.mode == GameState.Mode.PLAYING:
		paused = not paused
		music.stream_paused = paused
		_sync_menu()
	elif event.is_action_pressed("start"):
		match GameState.mode:
			GameState.Mode.TITLE:
				show_navigation()
			GameState.Mode.NAVIGATION:
				confirm_route()
			GameState.Mode.RESULT:
				show_navigation()
	elif event.is_action_pressed("bomb") and not paused:
		trigger_bomb()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		request_close()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_pause_from_focus_loss.call_deferred()


func _process(delta: float) -> void:
	if _capture_frames > 0 and Engine.get_process_frames() >= maxi(0, _capture_frames - 12):
		stop_audio()
	_update_feedback(delta)
	if automatic:
		# 入力・HUD・Tweenは動かしたまま、戦闘の更新だけを短く止める。
		if hitstop > 0.0:
			hitstop = maxf(0.0, hitstop - delta)
		else:
			advance(delta)
	if previous_mode != GameState.mode:
		_sync_menu()
	tutorial_pulse += delta
	_update_scan_sound(delta)
	view.queue_redraw()


func start_run() -> void:
	GameState.reset_run()
	_reset_world()


func show_navigation() -> void:
	GameState.show_navigation()
	paused = false
	combat_effects.clear_effects()
	_play_music("title")
	_fade_transition()
	_sync_menu()


func confirm_route() -> void:
	GameState.prepare_run_with_tutorial()
	_reset_world()
	if GameState.mode == GameState.Mode.TUTORIAL:
		tutorial_step = 0
		_sync_menu()


func complete_tutorial() -> void:
	if GameState.mode != GameState.Mode.TUTORIAL:
		return
	GameState.finish_tutorial()
	tutorial_step = 3
	_fade_transition(0.78)
	_sync_menu()


func _handle_tutorial_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		complete_tutorial()
		return
	if (
		tutorial_step == 0
		and (
			event.is_action_pressed("move_left")
			or event.is_action_pressed("move_right")
			or event.is_action_pressed("move_up")
			or event.is_action_pressed("move_down")
		)
	):
		tutorial_step = 1
		view.queue_redraw()
	elif tutorial_step == 1 and event.is_action_pressed("shoot"):
		tutorial_step = 2
		_sound("shot")
		view.queue_redraw()
	elif tutorial_step == 2 and event.is_action_pressed("bomb"):
		_sound("bomb")
		complete_tutorial()


func _reset_world() -> void:
	player = Vector2(640, 600)
	enemies.clear()
	bullets.clear()
	items.clear()
	effects.clear()
	waves = Stage.waves()
	wave_index = 0
	boss_hp = 0
	boss_active = false
	boss_chart_active = false
	boss_chart_time = 0.0
	boss_timer = 0.0
	shot_timer = 0.0
	invulnerable = 2.0
	flash = 0.0
	player_pose = "idle"
	player_pose_time = 0.0
	boss_pose = "idle"
	boss_pose_time = 0.0
	_boss_hit_cooldown = 0.0
	_boss_attack_time = 0.0
	result_time = 0.0
	scan_timer = 0.4
	_visual_id = 0
	hitstop = 0.0
	_shake_strength = 0.0
	shake_offset = Vector2.ZERO
	combat_effects.clear_effects()
	paused = false
	_play_music("stage")
	_fade_transition()
	_sync_menu()


func return_title() -> void:
	GameState.show_title()
	paused = false
	combat_effects.clear_effects()
	_play_music("title")
	_fade_transition()
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
	effects = effects.filter(
		func(effect: Dictionary) -> bool: return effect.age < float(effect.get("duration", 0.72))
	)
	player_pose_time += delta
	boss_pose_time += delta
	if GameState.mode == GameState.Mode.RESULT:
		result_time += delta
	if GameState.mode != GameState.Mode.PLAYING:
		return
	if boss_chart_active:
		boss_chart_time = maxf(0.0, boss_chart_time - delta)
		if boss_chart_time <= 0.0:
			_activate_boss()
		return
	GameState.elapsed += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if player_pose not in ["hit", "attack"] or player_pose_time >= 0.24:
		_set_player_pose("move" if direction.length_squared() > 0.0 else "idle")
	player += direction * 340.0 * delta
	player = player.clamp(Vector2(342, 36), Vector2(938, 687))
	shot_timer -= delta
	if Input.is_action_pressed("shoot") and shot_timer <= 0.0:
		fire_player()
	while wave_index < waves.size() and float(waves[wave_index].time) <= GameState.elapsed:
		spawn_enemy(waves[wave_index])
		wave_index += 1
	if GameState.elapsed >= Stage.BOSS_TIME and not boss_active:
		_begin_boss_chart()
		return
	_update_enemies(delta)
	_update_boss(delta)
	_update_bullets(delta)
	_update_items(delta)


func _begin_boss_chart() -> void:
	boss_chart_active = true
	boss_chart_time = 3.2
	enemies.clear()
	bullets.clear()
	items.clear()
	_play_music("boss")
	_shake_strength = 0.0
	shake_offset = Vector2.ZERO


func _activate_boss() -> void:
	boss_chart_active = false
	boss_active = true
	boss_hp = Stage.BOSS_HP
	boss_pose = "idle"
	boss_pose_time = 0.0
	_shake_strength = 3.0


func fire_player() -> void:
	shot_timer = 0.13
	if player_pose != "hit" or player_pose_time >= 0.24:
		_set_player_pose("attack")
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
	_visual_id += 1
	enemies.append(
		{
			"position": Vector2(wave.x, -36),
			"origin_x": float(wave.x),
			"kind": wave.kind,
			"hp": stats.hp,
			"age": 0.0,
			"timer": 1.0,
			"drop": wave.drop,
			"visual_id": _visual_id,
			"pose": "idle",
			"pose_time": 0.0,
			"hit_cooldown": 0.0
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
	combat_effects.bomb(player)
	_impact(6.0, 0.065)
	_sound("bomb")


func hit_player() -> void:
	if invulnerable > 0.0 or GameState.mode != GameState.Mode.PLAYING:
		return
	_set_player_pose("hit")
	combat_effects.hit(player, 1, true)
	combat_effects.explosion(player)
	_impact(5.0, 0.045)
	GameState.take_hit()
	invulnerable = 2.5
	flash = 0.2
	_sound("explosion")
	if GameState.mode == GameState.Mode.RESULT:
		_set_player_pose("death")
		_death_effect("player", player, -1)
		_show_result()


func damage_boss(amount: int) -> void:
	if boss_hp <= 0:
		return
	boss_hp = maxi(0, boss_hp - amount)
	# 多段ショットでも被弾姿勢の経過を巻き戻さず、攻撃と移動が見える時間を残す。
	if _boss_hit_cooldown <= 0.0:
		_set_boss_pose("hit")
		_boss_hit_cooldown = HIT_POSE_INTERVAL
	combat_effects.hit(boss_position + Vector2(0, 40), amount)
	if boss_hp == 0:
		_set_boss_pose("death")
		_death_effect("boss", boss_position, -2, true)
		combat_effects.explosion(boss_position, true)
		_impact(8.0, 0.09)
		GameState.add_score(10000)
		GameState.finish_run(true)
		_sound("explosion")
		_show_result()


func _update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies.duplicate():
		var stats: Dictionary = Stage.enemy_stats(enemy.kind)
		enemy.age += delta
		enemy.pose_time = float(enemy.get("pose_time", 0.0)) + delta
		enemy.hit_cooldown = maxf(0.0, float(enemy.get("hit_cooldown", 0.0)) - delta)
		var pose_duration: float = HIT_POSE_DURATION if enemy.pose == "hit" else 0.26
		if enemy.get("pose", "idle") not in ["attack", "hit"] or enemy.pose_time >= pose_duration:
			_set_enemy_pose(enemy, "idle" if enemy.age < 0.35 else "move")
		enemy.position.y += float(stats.speed) * delta
		if enemy.kind == "fan":
			enemy.position.x = clampf(enemy.origin_x + sin(enemy.age * 2.3) * 65.0, 348, 932)
		enemy.timer -= delta
		if enemy.timer <= 0.0 and enemy.position.y > 20 and enemy.position.y < 540:
			var pattern: String = "straight" if enemy.kind == "scout" else enemy.kind
			_enemy_shot(pattern, enemy.position)
			if enemy.pose != "hit":
				_set_enemy_pose(enemy, "attack")
			enemy.timer = stats.shot_interval
		if enemy.position.distance_to(player) < 31:
			hit_player()
		if enemy.position.y > 760:
			enemies.erase(enemy)


func _update_boss(delta: float) -> void:
	if not boss_active or boss_hp <= 0:
		return
	_boss_hit_cooldown = maxf(0.0, _boss_hit_cooldown - delta)
	_boss_attack_time = maxf(0.0, _boss_attack_time - delta)
	boss_position.x = 640.0 + sin((GameState.elapsed - Stage.BOSS_TIME) * 0.65) * 165.0
	boss_timer -= delta
	if boss_timer <= 0.0:
		_enemy_shot("boss", boss_position + Vector2(0, 60), Stage.boss_phase(boss_hp))
		_boss_attack_time = 0.3
		boss_timer = 1.05 if Stage.boss_phase(boss_hp) == 1 else 0.68
	# 被弾の最中に撃った場合も、被弾終了後に残りの発砲動作を表示する。
	if boss_pose != "hit" or boss_pose_time >= HIT_POSE_DURATION:
		if _boss_attack_time > 0.0:
			_set_boss_pose("attack")
		else:
			var moving: bool = absf(cos((GameState.elapsed - Stage.BOSS_TIME) * 0.65)) > 0.3
			_set_boss_pose("move" if moving else "idle")
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
			if float(enemy.get("hit_cooldown", 0.0)) <= 0.0:
				_set_enemy_pose(enemy, "hit")
				enemy.hit_cooldown = HIT_POSE_INTERVAL
			combat_effects.hit(enemy.position)
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
	_death_effect(enemy.kind, enemy.position, int(enemy.get("visual_id", 0)))
	combat_effects.explosion(enemy.position)
	_impact(1.8, 0.018)
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
			combat_effects.collect(player, item.kind)
			items.erase(item)
			_sound("item")
		elif item.position.y > 760:
			items.erase(item)


func _segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))


func _sound(name: String) -> void:
	if not _audio_closing and sounds.has(name):
		sounds[name].play()


func _play_music(track: String) -> void:
	if _audio_closing:
		return
	music.stream = load("res://assets/audio/%s.ogg" % track)
	music.stream.loop = true
	music.stream_paused = false
	music.play()


func _sync_menu() -> void:
	if not is_inside_tree():
		return
	previous_mode = GameState.mode
	for button: Button in buttons:
		button.hide()
		button.queue_free()
	buttons.clear()
	if paused:
		_add_button("飛行を続ける", Vector2(495, 382), resume_run)
		_add_button("タイトルへ", Vector2(495, 447), return_title)
	elif GameState.mode == GameState.Mode.TITLE:
		_add_button("航路図を開く  ENTER / A", Vector2(82, 536), show_navigation)
	elif GameState.mode == GameState.Mode.NAVIGATION:
		_add_button("選択航路へ進む  ENTER / A", Vector2(842, 602), confirm_route)
	elif GameState.mode == GameState.Mode.TUTORIAL:
		_add_button("計器チェックを省略  ENTER / A", Vector2(835, 640), complete_tutorial)
	elif GameState.mode == GameState.Mode.RESULT:
		_add_button("航路を再設定", Vector2(495, 460), show_navigation)
		_add_button("タイトルへ", Vector2(495, 525), return_title)
	if not buttons.is_empty():
		buttons[0].grab_focus()


func _add_button(text: String, location: Vector2, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.position = location
	button.size = Vector2(290, 52)
	button.pivot_offset = button.size * 0.5
	button.theme = load("res://assets/ui/flight_theme.tres")
	button.add_theme_font_override("font", view.font)
	button.add_theme_font_size_override("font_size", 21)
	button.mouse_entered.connect(_animate_button.bind(button, 1.035))
	button.mouse_exited.connect(_animate_button.bind(button, 1.0))
	button.focus_entered.connect(_animate_button.bind(button, 1.035))
	button.focus_exited.connect(_animate_button.bind(button, 1.0))
	button.button_down.connect(_animate_button.bind(button, 0.96))
	button.button_up.connect(_animate_button.bind(button, 1.035))
	if GameState.mode == GameState.Mode.RESULT and result_time < 0.65:
		button.modulate.a = 0.0
		var reveal: Tween = button.create_tween()
		reveal.tween_interval(0.65 - result_time)
		reveal.tween_property(button, "modulate:a", 1.0, 0.2)
	button.pressed.connect(action)
	add_child(button)
	buttons.append(button)


func _set_player_pose(pose: String) -> void:
	if player_pose != pose:
		player_pose = pose
		player_pose_time = 0.0


func _set_enemy_pose(enemy: Dictionary, pose: String) -> void:
	if enemy.get("pose", "idle") != pose:
		enemy.pose = pose
		enemy.pose_time = 0.0


func _set_boss_pose(pose: String) -> void:
	if boss_pose != pose:
		boss_pose = pose
		boss_pose_time = 0.0


# 撃破時の見た目を短時間残す。機体は戦闘配列から即座に除去し、重複衝突を防ぐ。
func _death_effect(actor: String, location: Vector2, visual_id: int, large: bool = false) -> void:
	effects.append(
		{
			"kind": "death",
			"actor": actor,
			"position": location,
			"visual_id": visual_id,
			"age": 0.0,
			"duration": 0.72,
			"large": large
		}
	)


func _impact(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	hitstop = maxf(hitstop, duration)


func _update_feedback(delta: float) -> void:
	if not paused:
		_shake_strength = move_toward(_shake_strength, 0.0, delta * 22.0)
		shake_offset = Vector2(sin(animation_time * 83), cos(animation_time * 71)) * _shake_strength
	combat_effects.visible = GameState.mode in [GameState.Mode.PLAYING, GameState.Mode.RESULT]
	combat_effects.set_presentation(shake_offset, boss_active, paused)


func _update_scan_sound(delta: float) -> void:
	if (
		GameState.mode not in [GameState.Mode.NAVIGATION, GameState.Mode.TUTORIAL]
		and not boss_chart_active
	):
		scan_timer = 0.4
		return
	scan_timer -= delta
	if scan_timer <= 0.0:
		_sound("scan")
		scan_timer = 1.8


func _pause_from_focus_loss() -> void:
	if _closing or not is_inside_tree() or GameState.mode != GameState.Mode.PLAYING:
		return
	paused = true
	music.stream_paused = true
	_sync_menu()


func _show_result() -> void:
	result_time = 0.0
	_play_music("result")
	_fade_transition(0.22)
	_sync_menu()


# 論理状態は同期して切り替え、画面だけを覆ってほどく。入力と保存を遅延させない。
func _fade_transition(opacity: float = 0.95) -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition.modulate.a = opacity
	_transition_tween = _transition.create_tween()
	(
		_transition_tween
		. tween_property(_transition, "modulate:a", 0.0, 0.38)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _animate_button(button: Button, target_scale: float) -> void:
	if button.is_queued_for_deletion():
		return
	if button.has_meta("scale_tween"):
		var previous: Tween = button.get_meta("scale_tween") as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var tween: Tween = button.create_tween()
	button.set_meta("scale_tween", tween)
	(
		tween
		. tween_property(button, "scale", Vector2.ONE * target_scale, 0.13)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


# stop直後にはAudioServerのミックス側に参照が残るので、終了前に呼び出す。
# https://github.com/godotengine/godot/issues/76745
func stop_audio() -> void:
	_audio_closing = true
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for voice: AudioStreamPlayer in sounds.values():
		voice.stop()
		voice.stream = null


func _prepare_capture_exit() -> void:
	# Movie Makerは描画フレームごとにmixするので、最終フレームより前に停止する。
	# --quit-afterはGodotが取り除くため、Makefileの同じフレーム数をuser argsで受け取る。
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-frames="):
			_capture_frames = maxi(0, int(argument.trim_prefix("--capture-frames=")))
	_audio_closing = _capture_frames > 0 and _capture_frames <= 12


func request_close() -> void:
	if _closing:
		return
	_closing = true
	paused = true
	GameState.save_high_score()
	stop_audio()
	await get_tree().create_timer(0.12, true, false, true).timeout
	await get_tree().process_frame
	get_tree().quit()


func _exit_tree() -> void:
	stop_audio()
	# --quit/--quit-afterはclose通知を送らず、ここではawaitも完了できない。
	# 音声スレッドの停止済み再生の回収を待つ。通常closeではすでに同じ待ちを済ませる。
	# Godotのget_cmdline_argsには上記エンジン引数が残らないため、分岐には使わない。
	if not _closing:
		OS.delay_msec(120)
