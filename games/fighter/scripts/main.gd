extends Control
## 入力・演出の更新は時間とイベントを消費するため非冪等。画面の構築は毎回再生成する。

const EFFECT: Script = preload("res://scripts/combat_effect.gd")
const BODY: Script = preload("res://scripts/combatant.gd")
const COMMAND: Script = preload("res://scripts/command_buffer.gd")
const NAMES: Array[String] = ["蒼電 / ソウデン", "紅蓮 / グレン"]
const COLORS: Array[Color] = [Color("23e8df"), Color("ff3b91")]
const INK: Color = Color("09051f")
const PAPER: Color = Color("fff1a8")
const STAGE_NAMES: Array[String] = ["東京 // ネオン市場", "ソウル // 天空リング", "リオ // 夕陽埠頭"]
const STAGE_DETAILS: Array[String] = [
	"観客熱狂度  MAX  /  路面は標準",
	"高所の強風  /  青い照明",
	"夕陽と波音  /  橙の照明",
]
const STAGE_POINTS: Array[Vector2] = [Vector2(690, 238), Vector2(650, 198), Vector2(260, 442)]

var player: FighterBody
var cpu: FighterBody
var commands: FighterCommand = COMMAND.new()
var font: FontVariation = FontVariation.new()
var stage_textures: Array[Texture2D] = [
	preload("res://assets/stage/tokyo.png"), preload("res://assets/stage/seoul.png"),
	preload("res://assets/stage/rio.png")
]
var world_map: Texture2D = preload("res://assets/stage/world-map.png")
var title_logo: Texture2D = preload("res://assets/ui/title-logo.png")
var health_frame: Texture2D = preload("res://assets/ui/health-frame.png")
var round_medal: Texture2D = preload("res://assets/ui/round-medal.png")
var emblem: Texture2D = preload("res://assets/ui/emblem.png")
var portraits: Array[Texture2D] = [
	preload("res://assets/portrait-teal.png"), preload("res://assets/portrait-amber.png")
]
var buttons: Control
var bgm: AudioStreamPlayer
var ambience: AudioStreamPlayer
var sounds: Dictionary = {}
var elapsed: float = 0.0
var intro: float = 0.0
var outro: float = 0.0
var ai_time: float = 0.0
var ai_direction: Vector2 = Vector2.ZERO
var ai_step: int = 0
var paused: bool = false
var previewing: bool = false
var last_screen: int = -1
var feedback: String = ""
var feedback_time: float = 0.0
var suppress_attacks: bool = false
var music_start_pending: bool = true
var music_name: String = ""
var music_tween: Tween
var transition_tween: Tween
var screen_cover: ColorRect
var flash_cover: ColorRect
var presentation: Control
var health_display: Array[float] = [1000.0, 1000.0]
var health_trail: Array[float] = [1000.0, 1000.0]
var health_observed: Array[int] = [1000, 1000]
var shake_time: float = 0.0
var round_effect_played: bool = false
var closing: bool = false
var stage_index: int = 0
var plane_position: Vector2 = STAGE_POINTS[0]
var tutorial_seen: bool = false
var tutorial_active: bool = false
var tutorial_step: int = 0
var combo_count: int = 0
var combo_time: float = 0.0


func _ready() -> void:
	print("fighter boot")
	font.base_font = preload("res://assets/fonts/DelaGothicOne-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = preload("res://assets/ui/fighter-theme.tres")
	_build_audio()
	_build_presentation()
	get_tree().auto_accept_quit = false
	buttons = Control.new()
	buttons.z_index = 60
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	show_title()
	if OS.is_debug_build() and OS.get_environment("FIGHTER_VERIFY_RUN") == "1":
		_verify_run.call_deferred()


## 通常起動の描画を保存し、開発時の自動確認だけを終了する。
func _verify_run() -> void:
	await get_tree().create_timer(0.5).timeout
	if DisplayServer.get_name() == "headless" or get_tree().current_scene != self:
		push_error("通常のゲームウィンドウで起動していない")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var status: Error = get_viewport().get_texture().get_image().save_png("res://tmp/run-title.png")
	stop_audio()
	await get_tree().create_timer(0.2).timeout
	if status != OK:
		push_error("通常起動の撮影に失敗: " + error_string(status))
	else:
		print("fighter run OK")
	get_tree().quit(0 if status == OK else 1)


func _exit_tree() -> void:
	stop_audio()
	# --quit-afterは終了通知もスクリプト引数も通らない。終了時は別スレッドのミキサー解放を待つ。
	if not OS.has_feature("web"):
		OS.delay_msec(250)


func stop_audio() -> void:
	music_start_pending = false
	closing = true
	if is_instance_valid(music_tween):
		music_tween.kill()
	if is_instance_valid(bgm):
		bgm.stop()
		bgm.stream = null
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
	for sound: AudioStreamPlayer in sounds.values():
		sound.stop()
		sound.stream = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing:
		_quit_cleanly()


## 終了要求は一度だけ消費し、音声ミキサーの解放が終わるまで待つ。
func _quit_cleanly() -> void:
	stop_audio()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _build_audio() -> void:
	bgm = AudioStreamPlayer.new()
	bgm.volume_db = -13.0
	add_child(bgm)
	ambience = AudioStreamPlayer.new()
	ambience.stream = load("res://assets/audio/crowd.wav")
	ambience.volume_db = -22.0
	add_child(ambience)
	for sound: String in ["hit", "guard", "special", "confirm", "ko"]:
		var audio: AudioStreamPlayer = AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/%s.wav" % sound)
		audio.volume_db = -9.0
		add_child(audio)
		sounds[sound] = audio


func _play_sound(sound: String) -> void:
	if not closing:
		sounds[sound].play()


func _set_music() -> void:
	if closing or music_start_pending:
		return
	var in_venue: bool = Match.screen in [Match.Screen.STAGE, Match.Screen.FIGHT]
	if in_venue and not ambience.playing:
		ambience.play()
	elif not in_venue and ambience.playing:
		ambience.stop()
	var next_music: String = "title"
	if Match.screen == Match.Screen.FIGHT:
		next_music = "final" if Match.wins.max() >= 1 else "arena"
	elif Match.screen == Match.Screen.RESULT:
		next_music = "result"
	if next_music == music_name:
		return
	music_name = next_music
	if is_instance_valid(music_tween):
		music_tween.kill()
	bgm.stop()
	bgm.stream = load("res://assets/audio/%s.wav" % next_music)
	bgm.volume_db = -28.0
	bgm.play()
	music_tween = create_tween()
	music_tween.tween_property(bgm, "volume_db", -11.0, 0.6)


func _build_presentation() -> void:
	presentation = Control.new()
	presentation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.z_index = 35
	add_child(presentation)
	var vignette: ColorRect = ColorRect.new()
	vignette.size = Vector2(1280, 720)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade: ShaderMaterial = ShaderMaterial.new()
	shade.shader = preload("res://assets/effects/vignette.gdshader")
	vignette.material = shade
	presentation.add_child(vignette)
	flash_cover = ColorRect.new()
	flash_cover.color = Color("fff1cc")
	flash_cover.modulate.a = 0.0
	flash_cover.size = Vector2(1280, 720)
	flash_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	presentation.add_child(flash_cover)
	screen_cover = ColorRect.new()
	screen_cover.color = Color("08031d")
	screen_cover.modulate.a = 0.0
	screen_cover.size = Vector2(1280, 720)
	screen_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_cover.z_index = 100
	add_child(screen_cover)
	var embers: CPUParticles2D = CPUParticles2D.new()
	embers.position = Vector2(640, 620)
	embers.amount = 36
	embers.lifetime = 7.0
	embers.preprocess = 3.0
	embers.texture = preload("res://assets/effects/spark.png")
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(620, 35)
	embers.direction = Vector2(-0.15, -1)
	embers.spread = 22.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 40.0
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.09
	embers.color = Color(1, 0.77, 0.48, 0.32)
	add_child(embers)


func _transition() -> void:
	if is_instance_valid(transition_tween):
		transition_tween.kill()
	screen_cover.modulate.a = 0.85
	buttons.position.y = 14.0
	transition_tween = create_tween().set_parallel(true)
	transition_tween.tween_property(screen_cover, "modulate:a", 0.0, 0.38)
	transition_tween.tween_property(buttons, "position:y", 0.0, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func show_title() -> void:
	_clear_arena()
	Match.screen = Match.Screen.TITLE
	paused = false
	_rebuild_buttons()
	queue_redraw()


func show_select() -> void:
	_clear_arena()
	Match.screen = Match.Screen.SELECT
	_rebuild_buttons()
	queue_redraw()


func show_stage() -> void:
	_clear_arena()
	Match.screen = Match.Screen.STAGE
	plane_position = STAGE_POINTS[stage_index]
	_rebuild_buttons()
	queue_redraw()


func start_match() -> void:
	Match.reset_match(Match.selected)
	paused = false
	tutorial_active = not tutorial_seen
	tutorial_step = 0
	_spawn_round()
	_rebuild_buttons()


func _spawn_round() -> void:
	_clear_arena()
	player = BODY.new()
	cpu = BODY.new()
	player.configure(Match.selected, false)
	cpu.configure(1 - Match.selected, true)
	add_child(player)
	add_child(cpu)
	player.opponent = cpu
	cpu.opponent = player
	player.reset_fighter(Vector2(390, 570))
	cpu.reset_fighter(Vector2(890, 570))
	cpu.facing = -1.0
	player.struck.connect(_on_struck.bind(false))
	cpu.struck.connect(_on_struck.bind(true))
	player.special_cast.connect(_on_special)
	cpu.special_cast.connect(_on_special)
	commands.reset()
	health_display.assign([1000.0, 1000.0])
	health_trail.assign([1000.0, 1000.0])
	health_observed.assign([1000, 1000])
	combo_count = 0
	combo_time = 0.0
	round_effect_played = false
	intro = 1.8
	outro = 0.0
	ai_time = 0.0
	ai_step = 0
	feedback = ""
	buttons.move_to_front()


func _clear_arena() -> void:
	for body: FighterBody in [player, cpu]:
		if is_instance_valid(body):
			body.enabled = false
			body.queue_free()
	player = null
	cpu = null
	for projectile: Node in get_tree().get_nodes_in_group("projectiles"):
		projectile.queue_free()
	for effect: Node in get_tree().get_nodes_in_group("combat_effects"):
		effect.queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	if event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
	if previewing or event.is_echo():
		return
	if Match.screen == Match.Screen.SELECT:
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
			Match.selected = 1 - Match.selected
			_rebuild_buttons()
		if event.is_action_pressed("back"):
			show_title()
	elif Match.screen == Match.Screen.STAGE:
		if event.is_action_pressed("move_left"):
			_choose_stage(wrapi(stage_index - 1, 0, STAGE_NAMES.size()))
		elif event.is_action_pressed("move_right"):
			_choose_stage(wrapi(stage_index + 1, 0, STAGE_NAMES.size()))
		if event.is_action_pressed("back"):
			show_select()
	elif Match.screen == Match.Screen.FIGHT and tutorial_active and (
		event.is_action_pressed("confirm") or event.is_action_pressed("back")
	):
		_finish_tutorial(true)
		get_viewport().set_input_as_handled()
		return
	elif Match.screen == Match.Screen.FIGHT and event.is_action_pressed("pause"):
		paused = not paused
		_rebuild_buttons()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		if Match.screen == Match.Screen.TITLE:
			show_select()
		elif Match.screen == Match.Screen.SELECT:
			show_stage()
		elif Match.screen == Match.Screen.STAGE:
			start_match()
		elif Match.screen == Match.Screen.RESULT:
			start_match()
		elif Match.screen == Match.Screen.FIGHT and paused:
			_resume()
		get_viewport().set_input_as_handled()
	elif Match.screen == Match.Screen.RESULT and event.is_action_pressed("back"):
		show_title()


func _physics_process(delta: float) -> void:
	# ウィンドウの初期描画が終わるまで音声再生を待つ。
	if music_start_pending and Engine.get_process_frames() >= 3:
		music_start_pending = false
		_set_music()
	elapsed += delta
	if Match.screen == Match.Screen.STAGE:
		plane_position = plane_position.move_toward(STAGE_POINTS[stage_index], delta * 420.0)
	if not previewing:
		_update_effects(delta)
		if Match.screen == Match.Screen.FIGHT:
			_update_fight(delta)
	if last_screen != Match.screen:
		last_screen = Match.screen
		_rebuild_buttons()
		_transition()
	_set_music()
	_update_presentation(delta)
	queue_redraw()


func _update_fight(delta: float) -> void:
	var active: bool = not paused and not Match.round_over and intro <= 0.0
	player.enabled = active
	cpu.enabled = active and not tutorial_active
	player.visible = not paused
	cpu.visible = not paused
	for projectile: Node in get_tree().get_nodes_in_group("projectiles"):
		projectile.set_physics_process(active)
		projectile.visible = not paused
	if paused:
		return
	if intro > 0.0:
		intro = maxf(0.0, intro - delta)
		return
	if Match.round_over:
		if not round_effect_played:
			round_effect_played = true
			player.hit_flash = 0.0
			cpu.hit_flash = 0.0
			player.guard_flash = 0.0
			cpu.guard_flash = 0.0
			_play_sound("ko")
			_flash(0.28)
			shake_time = 0.38
			for index: int in range(6):
				_spawn_effect(Vector2(330 + index * 125, 350), false, COLORS[index % 2], 1.7)
		outro += delta
		if outro >= 2.8:
			Match.advance_round()
			if Match.screen == Match.Screen.RESULT:
				_clear_arena()
			else:
				_spawn_round()
		return
	var direction: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down")
	)
	direction = Vector2(signf(direction.x), signf(direction.y))
	commands.push(direction, player.facing, delta)
	var attack: String = ""
	for kind: String in ["lp", "hp", "lk", "hk"]:
		if not suppress_attacks and Input.is_action_just_pressed(kind):
			attack = kind
			break
	if attack in ["lp", "hp"] and commands.consume():
		attack = "special"
	if suppress_attacks:
		suppress_attacks = ["lp", "hp", "lk", "hk"].any(
			func(kind: String) -> bool: return Input.is_action_pressed(kind)
		)
	player.control(direction, attack)
	_advance_tutorial(direction, attack)
	if tutorial_active:
		cpu.control(Vector2.ZERO)
		return
	_update_cpu(delta)
	if player.hitstop <= 0.0 and cpu.hitstop <= 0.0:
		Match.tick(delta, player.health, cpu.health)


func _update_cpu(delta: float) -> void:
	ai_time -= delta
	var attack: String = ""
	if ai_time <= 0.0:
		ai_time = 0.22
		ai_step += 1
		var distance: float = absf(player.position.x - cpu.position.x)
		var toward: float = signf(player.position.x - cpu.position.x)
		if distance > 300.0:
			ai_direction = Vector2(toward, 0)
			if ai_step % 7 == 0:
				attack = "special"
		elif ai_step % 5 == 0 or (not player.action.is_empty() and ai_step % 3 == 0):
			ai_direction = Vector2(-toward, 1 if player.crouching else 0)
		elif distance > 115.0:
			ai_direction = Vector2(toward, -1 if ai_step % 13 == 0 else 0)
		else:
			ai_direction = Vector2(0, 1 if ai_step % 4 == 0 else 0)
			attack = ["lp", "hk", "lk", "hp"][ai_step % 4]
	cpu.control(ai_direction, attack)


func _on_struck(at: Vector2, blocked: bool, player_scored: bool = false) -> void:
	_play_sound("guard" if blocked else "hit")
	_spawn_effect(at, blocked, COLORS[0] if blocked else Color("fff1b4"))
	shake_time = 0.05 if blocked else 0.13
	if not blocked:
		_flash(0.08)
		if player_scored:
			combo_count = combo_count + 1 if combo_time > 0.0 else 1
			combo_time = 1.05
	feedback = "ガード" if blocked else "命中！"
	feedback_time = 0.6


func _on_special() -> void:
	_play_sound("special")
	feedback = "必殺・燈波"
	feedback_time = 0.9


func _update_effects(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	combo_time = maxf(0.0, combo_time - delta)
	if combo_time <= 0.0:
		combo_count = 0


func _advance_tutorial(direction: Vector2, attack: String) -> void:
	if not tutorial_active:
		return
	if tutorial_step == 0 and direction.x != 0.0:
		tutorial_step = 1
		feedback = "MOVE OK!"
		feedback_time = 0.7
	elif tutorial_step == 1 and not attack.is_empty() and attack != "special":
		tutorial_step = 2
		feedback = "STRIKE OK!"
		feedback_time = 0.7
	elif tutorial_step == 2 and attack == "special":
		_finish_tutorial(false)


func _finish_tutorial(skipped: bool) -> void:
	tutorial_active = false
	tutorial_seen = true
	tutorial_step = 3
	suppress_attacks = skipped
	feedback = "SKIP  /  FIGHT!" if skipped else "TRAINING CLEAR  /  FIGHT!"
	feedback_time = 1.4



func _rebuild_buttons() -> void:
	for button: Node in buttons.get_children():
		buttons.remove_child(button)
		button.queue_free()
	match Match.screen:
		Match.Screen.TITLE:
			_button("INSERT COIN  /  決定", Rect2(82, 518, 390, 66), show_select)
		Match.Screen.SELECT:
			_button("蒼電を選ぶ", Rect2(72, 453, 344, 52), _choose.bind(0))
			_button("紅蓮を選ぶ", Rect2(454, 453, 344, 52), _choose.bind(1))
			_button("世界地図へ  →", Rect2(854, 548, 352, 62), show_stage)
		Match.Screen.STAGE:
			for index: int in range(STAGE_POINTS.size()):
				_button(
					["TOKYO", "SEOUL", "RIO"][index],
					Rect2(STAGE_POINTS[index] + Vector2(-58, 26), Vector2(116, 38)),
					_choose_stage.bind(index)
				)
			_button("この会場へ  →", Rect2(870, 546, 338, 62), start_match)
		Match.Screen.FIGHT:
			if paused:
				_button("対戦を続ける", Rect2(470, 353, 340, 60), _resume)
				_button("タイトルへ戻る", Rect2(470, 434, 340, 60), show_title)
		Match.Screen.RESULT:
			_button("もう一度対戦", Rect2(265, 538, 360, 62), start_match)
			_button("タイトルへ戻る", Rect2(655, 538, 360, 62), show_title)


func _choose(index: int) -> void:
	Match.selected = index
	queue_redraw()


func _choose_stage(index: int) -> void:
	stage_index = clampi(index, 0, STAGE_NAMES.size() - 1)
	_rebuild_buttons()
	queue_redraw()


func _resume() -> void:
	paused = false
	suppress_attacks = true
	_rebuild_buttons()


func _button(text: String, rect: Rect2, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.pivot_offset = rect.size * 0.5
	button.mouse_entered.connect(_animate_button.bind(button, Vector2.ONE * 1.025))
	button.mouse_exited.connect(_animate_button.bind(button, Vector2.ONE))
	button.button_down.connect(_animate_button.bind(button, Vector2.ONE * 0.97))
	button.button_up.connect(_animate_button.bind(button, Vector2.ONE))
	button.pressed.connect(_play_sound.bind("confirm"))
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	buttons.add_child(button)


func _animate_button(button: Button, target_scale: Vector2) -> void:
	if button.has_meta("motion"):
		var previous: Tween = button.get_meta("motion")
		if is_instance_valid(previous):
			previous.kill()
	var motion: Tween = button.create_tween()
	button.set_meta("motion", motion)
	motion.tween_property(button, "scale", target_scale, 0.12).set_trans(Tween.TRANS_QUAD)


func _spawn_effect(at: Vector2, blocked: bool, tint: Color, strength: float = 1.0) -> void:
	var effect: FighterEffect = EFFECT.new()
	effect.position = at
	effect.blocked = blocked
	effect.tint = tint
	effect.strength = strength
	effect.add_to_group("combat_effects")
	add_child(effect)


func _flash(amount: float) -> void:
	flash_cover.modulate.a = amount
	create_tween().tween_property(flash_cover, "modulate:a", 0.0, 0.22)


func _update_presentation(delta: float) -> void:
	shake_time = maxf(0.0, shake_time - delta)
	position = Vector2(sin(elapsed * 125), cos(elapsed * 97)) * minf(5.0, shake_time * 32)
	if Match.screen != Match.Screen.FIGHT or not is_instance_valid(player):
		return
	for index: int in range(2):
		var body: FighterBody = player if index == 0 else cpu
		if body.health < health_observed[index]:
			_pop_damage(body.position + Vector2(0, -190), health_observed[index] - body.health)
		health_observed[index] = body.health
		health_display[index] = 0.0 if body.health == 0 else \
			move_toward(health_display[index], body.health, delta * 650)
		health_trail[index] = 0.0 if body.health == 0 else \
			move_toward(health_trail[index], body.health, delta * 185)


func _pop_damage(at: Vector2, damage: int) -> void:
	var label: Label = Label.new()
	label.text = str(damage)
	label.position = at - Vector2(24, 0)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color("fff1bf"))
	label.add_theme_color_override("font_outline_color", Color("10243b"))
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_to_group("combat_effects")
	presentation.add_child(label)
	var motion: Tween = label.create_tween().set_parallel(true)
	motion.tween_property(label, "position:y", at.y - 58, 0.65).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	motion.tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.4)
	motion.chain().tween_callback(label.queue_free)


func _draw() -> void:
	match Match.screen:
		Match.Screen.TITLE:
			draw_texture_rect(stage_textures[0], Rect2(0, 0, 1280, 720), false)
			_draw_title()
		Match.Screen.SELECT:
			draw_texture_rect(stage_textures[stage_index], Rect2(0, 0, 1280, 720), false)
			_draw_select()
		Match.Screen.STAGE:
			draw_texture_rect(world_map, Rect2(0, 0, 840, 720), false)
			_draw_stage_select()
		Match.Screen.FIGHT:
			draw_texture_rect(stage_textures[stage_index], Rect2(0, 0, 1280, 720), false)
			_draw_fight()
		Match.Screen.RESULT:
			draw_texture_rect(stage_textures[stage_index], Rect2(0, 0, 1280, 720), false)
			_draw_result()


func _text(at: Vector2, text: String, size_px: int = 24, color: Color = PAPER) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _center(y: float, text: String, size_px: int, color: Color = PAPER) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(Vector2((1280 - width) * 0.5, y), text, size_px, color)


func _panel(rect: Rect2, accent: Color, fill: Color = Color("09051fe8")) -> void:
	draw_rect(Rect2(rect.position + Vector2(8, 8), rect.size), Color("00000088"))
	draw_rect(rect, fill)
	draw_rect(rect, accent, false, 4)
	draw_line(rect.position + Vector2(10, 10), rect.position + Vector2(rect.size.x - 10, 10), PAPER, 2)


func _text_shadow(at: Vector2, text: String, size_px: int, color: Color) -> void:
	for offset: Vector2 in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
		_text(at + offset, text, size_px, INK)
	_text(at, text, size_px, color)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.005, 0.08, 0.56))
	for x: int in range(0, 1280, 80):
		draw_rect(Rect2(x, 0, 38, 9), COLORS[int(x / 80.0) % 2])
	draw_texture_rect(emblem, Rect2(36, 28, 64, 64), false)
	_text(Vector2(116, 69), "WORLD COMBAT CIRCUIT // 199X", 20, PAPER)
	draw_texture_rect(title_logo, Rect2(38, 92, 640, 184), false)
	_text_shadow(Vector2(66, 326), "世界を巡り、頂点を奪え。", 31, Color("ffffff"))
	_panel(Rect2(54, 365, 448, 132), COLORS[0])
	_text(Vector2(78, 400), "ARCADE MODE", 24, COLORS[1])
	_text(Vector2(78, 437), "1P VS CPU  /  99 SEC  /  FIRST TO 2", 18)
	_text(Vector2(78, 471), "NEXT  >>  挑戦者を選ぶ", 20, COLORS[0])
	draw_texture_rect(portraits[0], Rect2(602, 202, 350, 350), false)
	draw_texture_rect(portraits[1], Rect2(879, 169, 350, 350), false)
	_text_shadow(Vector2(676, 562), "蒼電", 28, COLORS[0])
	_text_shadow(Vector2(1012, 534), "紅蓮", 28, COLORS[1])
	_text(Vector2(86, 626), "決定: ENTER / SPACE / PAD A", 18, PAPER)
	_text(Vector2(930, 685), "F11 FULLSCREEN  /  M SOUND", 15, Color("b8afd9"))


func _draw_select() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.005, 0.075, 0.87))
	_text(Vector2(48, 63), "SELECT YOUR FIGHTER", 38, PAPER)
	_text(Vector2(51, 94), "← → で選択  /  決定すると世界地図へ", 17, Color("c7c0e8"))
	for index: int in range(2):
		var x: float = 50.0 + index * 384.0
		var card: Rect2 = Rect2(x, 120, 344, 404)
		_panel(card, COLORS[index] if Match.selected == index else Color("514675"))
		if Match.selected == index:
			draw_rect(card.grow(8 + sin(elapsed * 7.0) * 3.0), COLORS[index], false, 4)
		draw_texture_rect(portraits[index], Rect2(x + 22, 137, 300, 250), false)
		_text(Vector2(x + 22, 399), NAMES[index], 27, COLORS[index])
		_text(Vector2(x + 22, 431), "SPEED / COMBO" if index == 0 else "POWER / REACH", 16, PAPER)
		for stat: int in range(5):
			draw_rect(Rect2(x + 24 + stat * 46, 445, 34, 12),
				COLORS[index] if stat < (4 if index == 0 else 3) else Color("332b50"))
		_text(Vector2(x + 22, 490), "選択中" if Match.selected == index else "選択できる", 17,
			COLORS[index] if Match.selected == index else Color("9b93bd"))
	_panel(Rect2(830, 120, 400, 500), COLORS[Match.selected])
	_text(Vector2(858, 160), "COMMAND LIST", 26, COLORS[Match.selected])
	_text(Vector2(858, 202), "MOVE", 15, Color("aca3d0"))
	_text(Vector2(1002, 202), "A D / ← →", 18)
	_text(Vector2(858, 242), "JUMP / CROUCH", 15, Color("aca3d0"))
	_text(Vector2(1050, 242), "W / S", 18)
	_text(Vector2(858, 296), "PUNCH", 18, COLORS[0])
	_text(Vector2(1000, 296), "J  QUICK   K  HEAVY", 17)
	_text(Vector2(858, 336), "KICK", 18, COLORS[1])
	_text(Vector2(1000, 336), "U  QUICK   I  HEAVY", 17)
	draw_rect(Rect2(855, 360, 346, 4), COLORS[Match.selected])
	_text(Vector2(858, 399), "SPECIAL MOVE", 19, PAPER)
	_text_shadow(Vector2(858, 447), "↓  ↘  →  +  J / K", 29, COLORS[Match.selected])
	_text(Vector2(858, 483), "相手向きに入力 / ガードは後ろ", 15, Color("c7c0e8"))
	_text(Vector2(858, 528), "NEXT  >>  世界地図で会場を選ぶ", 17, PAPER)


func _draw_stage_select() -> void:
	draw_rect(Rect2(0, 0, 840, 720), Color(0.01, 0.0, 0.07, 0.18))
	draw_rect(Rect2(840, 0, 440, 720), Color("070419f2"))
	_text(Vector2(40, 58), "WORLD TOUR // STAGE SELECT", 30, PAPER)
	_text(Vector2(42, 88), "← → で会場を選ぶ  /  飛行機が次の会場へ移動", 16, Color("b5acd7"))
	for index: int in range(STAGE_POINTS.size()):
		if index > 0:
			draw_dashed_line(STAGE_POINTS[index - 1], STAGE_POINTS[index], Color("fd3b91"), 3, 12)
		var selected: bool = index == stage_index
		var radius: float = 19.0 + (sin(elapsed * 8.0) * 4.0 if selected else 0.0)
		draw_circle(STAGE_POINTS[index], radius, COLORS[index % 2] if selected else Color("575079"))
		draw_circle(STAGE_POINTS[index], 8, PAPER)
	_draw_plane(plane_position)
	_panel(Rect2(860, 76, 394, 458), COLORS[stage_index % 2])
	_text(Vector2(886, 118), "DESTINATION %02d" % (stage_index + 1), 18, COLORS[stage_index % 2])
	draw_texture_rect(stage_textures[stage_index], Rect2(884, 139, 346, 195), false)
	draw_rect(Rect2(884, 139, 346, 195), PAPER, false, 3)
	_text(Vector2(884, 377), STAGE_NAMES[stage_index], 22, PAPER)
	_text(Vector2(884, 414), STAGE_DETAILS[stage_index], 15, Color("c6bddf"))
	_text(Vector2(884, 455), "この会場で CPU と対戦", 17, COLORS[stage_index % 2])
	_text(Vector2(884, 493), "選択可能  /  決定で出発", 17, Color("8dff96"))


func _draw_plane(at: Vector2) -> void:
	draw_polygon(PackedVector2Array([
		at + Vector2(-31, -5), at + Vector2(-5, -9), at + Vector2(12, -25),
		at + Vector2(20, -23), at + Vector2(13, -8), at + Vector2(34, -3),
		at + Vector2(34, 4), at + Vector2(12, 6), at + Vector2(18, 20),
		at + Vector2(9, 20), at + Vector2(-6, 6), at + Vector2(-31, 5),
	]), PackedColorArray([PAPER]))
	draw_rect(Rect2(at + Vector2(-13, -5), Vector2(30, 10)), COLORS[stage_index % 2])


func _draw_fight() -> void:
	draw_rect(Rect2(0, 0, 1280, 126), Color("070318f5"))
	draw_rect(Rect2(0, 120, 1280, 6), COLORS[stage_index % 2])
	for index: int in range(2):
		var x: float = 40.0 if index == 0 else 744.0
		var character: int = Match.selected if index == 0 else 1 - Match.selected
		var body: FighterBody = player if index == 0 else cpu
		var fraction: float = clampf(body.health / 1000.0, 0, 1)
		var trail: float = clampf(health_trail[index] / 1000.0, 0, 1)
		_text(Vector2(x, 31), ("1P // " if index == 0 else "CPU // ") + NAMES[character], 19,
			COLORS[character])
		draw_texture_rect(health_frame, Rect2(x - 3, 39, 496, 36), false)
		var trail_x: float = x if index == 0 else x + 484 * (1 - trail)
		draw_rect(Rect2(trail_x, 45, 484 * trail, 23), Color("fff05e"))
		var fill_x: float = x if index == 0 else x + 484 * (1 - fraction)
		draw_rect(Rect2(fill_x, 45, 484 * fraction, 23), COLORS[character])
		draw_rect(Rect2(fill_x, 45, 484 * fraction, 5), Color(1, 1, 1, 0.62))
		for tick: int in range(1, 10):
			draw_line(Vector2(x + tick * 48.4, 46), Vector2(x + tick * 48.4, 67),
				Color(0.02, 0.08, 0.14, 0.24), 1)
		for win: int in range(2):
			draw_texture_rect(round_medal, Rect2(x + win * 31, 82, 24, 24), false,
				Color.WHITE if Match.wins[index] > win else Color(0.25, 0.35, 0.44, 0.65))
		_text(Vector2(x + 364, 103), "%04d" % ceili(health_display[index]), 16, PAPER)
	_panel(Rect2(586, 14, 108, 82), COLORS[stage_index % 2], Color("050313"))
	_center(70, "%02d" % ceili(Match.remaining), 42)
	_center(113, "ROUND %d  //  %s" % [Match.round_number, STAGE_NAMES[stage_index]], 15,
		Color("c8bee4"))
	if feedback_time > 0.0:
		_center(164, feedback, 22, PAPER)
	if combo_count > 0:
		_text_shadow(Vector2(48, 604), "%02d" % combo_count, 72, COLORS[0])
		_text_shadow(Vector2(158, 603), "HIT", 34, Color("fff04d"))
		_text(Vector2(52, 638), "COMBO", 18, COLORS[1])
	if intro > 0.0:
		_banner("ROUND %d" % Match.round_number if intro > 0.7 else "FIGHT!", "99 SEC  /  FIRST TO 2")
	elif Match.round_over:
		var detail: String = "引き分け・再ラウンド"
		if Match.round_winner >= 0:
			detail = "あなたのラウンド勝利" if Match.round_winner == 0 else "ＣＰＵのラウンド勝利"
		_banner("K.O." if Match.reason == "決着" else "TIME OVER", detail)
	elif tutorial_active:
		_draw_tutorial()
	if paused:
		draw_rect(Rect2(0, 126, 1280, 594), Color("050313e8"))
		_center(247, "PAUSE", 58, Color("fff04d"))
		_panel(Rect2(390, 274, 500, 244), COLORS[0])
		_text(Vector2(424, 316), "COMMAND", 20, COLORS[1])
		_text(Vector2(424, 358), "移動 A D / ← →    ジャンプ W", 18)
		_text(Vector2(424, 397), "拳 J K    蹴り U I    ガード 後ろ", 18)
		_text(Vector2(424, 437), "必殺技 ↓ ↘ → + J / K", 18, COLORS[0])
		_text(Vector2(424, 481), "決定で再開 / 下のボタンでタイトルへ", 15, Color("beb5dc"))


func _draw_tutorial() -> void:
	_panel(Rect2(36, 148, 440, 268), COLORS[tutorial_step % 2])
	_text(Vector2(62, 187), "FIRST MATCH // TRAINING", 19, Color("fff04d"))
	_text(Vector2(62, 220), "場面内で3つだけ試そう", 18, PAPER)
	var steps: Array[String] = [
		"1  A / D または ← / → で近づく",
		"2  J / U で素早い一撃",
		"3  ↓  ↘  →  +  J / K で必殺技",
	]
	for index: int in range(steps.size()):
		var color: Color = COLORS[index % 2] if tutorial_step == index else Color("77708f")
		var marker: String = ">>" if tutorial_step == index else ("OK" if tutorial_step > index else "--")
		_text(Vector2(62, 266 + index * 45), marker + "  " + steps[index], 16, color)
	_text(Vector2(62, 395), "SKIP: SPACE / ENTER / PAD A", 14, Color("bdb3d8"))


func _banner(title: String, detail: String) -> void:
	draw_rect(Rect2(0, 214, 1280, 244), Color("05020ee8"))
	draw_rect(Rect2(0, 214, 1280, 8), COLORS[0])
	draw_rect(Rect2(0, 450, 1280, 8), COLORS[1])
	_center(350, title, 104, Color("fff04d"))
	_center(404, detail, 22, PAPER)


func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("050313d8"))
	var won: bool = Match.wins[0] >= 2
	var champion: int = Match.selected if won else 1 - Match.selected
	for x: int in range(0, 1280, 80):
		draw_rect(Rect2(x, 16, 42, 8), COLORS[int(x / 80.0) % 2])
	_panel(Rect2(56, 72, 1168, 478), COLORS[champion])
	_text(Vector2(91, 118), "WORLD CIRCUIT // MATCH RESULT", 21, COLORS[champion])
	draw_texture_rect(portraits[champion], Rect2(80, 154, 370, 350), false)
	_text_shadow(Vector2(478, 218), "YOU WIN!" if won else "TRY AGAIN", 67,
		Color("fff04d") if won else COLORS[1])
	_text(Vector2(487, 273), STAGE_NAMES[stage_index], 18, Color("bbb2d6"))
	_text_shadow(Vector2(487, 361), "%d  -  %d" % [Match.wins[0], Match.wins[1]], 64, PAPER)
	_text(Vector2(492, 415), "CHAMPION  //  " + NAMES[champion], 22, COLORS[champion])
	_text(Vector2(492, 468), "もう一度対戦するか、タイトルへ戻る", 18, PAPER)
	_text(Vector2(492, 508), "下のボタンを選択  /  SPACE・A で再戦", 15, Color("b9b0d3"))
