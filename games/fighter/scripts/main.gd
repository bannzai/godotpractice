extends Control
## 入力・演出の更新は時間とイベントを消費するため非冪等。画面の構築は毎回再生成する。

const EFFECT: Script = preload("res://scripts/combat_effect.gd")
const BODY: Script = preload("res://scripts/combatant.gd")
const COMMAND: Script = preload("res://scripts/command_buffer.gd")
const NAMES: Array[String] = ["蒼 / ソウ", "燈 / トウ"]
const COLORS: Array[Color] = [Color("59e2d2"), Color("ffb45b")]
const INK: Color = Color("112631")
const PAPER: Color = Color("f7efdb")

var player: FighterBody
var cpu: FighterBody
var commands: FighterCommand = COMMAND.new()
var font: FontVariation = FontVariation.new()
var background_layers: Array[Texture2D] = [
	preload("res://assets/stage/sky.svg"), preload("res://assets/stage/city.svg"),
	preload("res://assets/stage/arena.svg"), preload("res://assets/stage/haze.svg")
]
var title_logo: Texture2D = preload("res://assets/ui/title-logo.svg")
var health_frame: Texture2D = preload("res://assets/ui/health-frame.svg")
var round_medal: Texture2D = preload("res://assets/ui/round-medal.svg")
var emblem: Texture2D = preload("res://assets/emblem.svg")
var portraits: Array[Texture2D] = [
	preload("res://assets/portrait-teal.svg"), preload("res://assets/portrait-amber.svg")
]
var buttons: Control
var bgm: AudioStreamPlayer
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


func _ready() -> void:
	print("fighter boot")
	font.base_font = preload("res://assets/fonts/font.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
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
	screen_cover.color = Color("0c1b2d")
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
	embers.texture = preload("res://assets/effects/spark.svg")
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


func start_match() -> void:
	Match.reset_match(Match.selected)
	paused = false
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
	player.struck.connect(_on_struck)
	cpu.struck.connect(_on_struck)
	player.special_cast.connect(_on_special)
	cpu.special_cast.connect(_on_special)
	commands.reset()
	health_display.assign([1000.0, 1000.0])
	health_trail.assign([1000.0, 1000.0])
	health_observed.assign([1000, 1000])
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
	elif Match.screen == Match.Screen.FIGHT and event.is_action_pressed("pause"):
		paused = not paused
		_rebuild_buttons()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		if Match.screen == Match.Screen.TITLE:
			show_select()
		elif Match.screen == Match.Screen.SELECT:
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
	cpu.enabled = active
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


func _on_struck(at: Vector2, blocked: bool) -> void:
	_play_sound("guard" if blocked else "hit")
	_spawn_effect(at, blocked, COLORS[0] if blocked else Color("fff1b4"))
	shake_time = 0.05 if blocked else 0.13
	if not blocked:
		_flash(0.08)
	feedback = "ガード" if blocked else "命中！"
	feedback_time = 0.6


func _on_special() -> void:
	_play_sound("special")
	feedback = "必殺・燈波"
	feedback_time = 0.9


func _update_effects(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)



func _rebuild_buttons() -> void:
	for button: Node in buttons.get_children():
		buttons.remove_child(button)
		button.queue_free()
	match Match.screen:
		Match.Screen.TITLE:
			_button("闘技場へ   →", Rect2(82, 490, 350, 66), show_select)
		Match.Screen.SELECT:
			_button("蒼を選ぶ", Rect2(190, 466, 370, 54), _choose.bind(0))
			_button("燈を選ぶ", Rect2(720, 466, 370, 54), _choose.bind(1))
			_button("対戦開始   →", Rect2(470, 575, 340, 58), start_match)
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
	var focus: float = sin(elapsed * 0.12) * 9.0
	if is_instance_valid(player) and is_instance_valid(cpu):
		focus = ((player.position.x + cpu.position.x) * 0.5 - 640) * 0.055
	for layer: int in range(background_layers.size()):
		var offset: float = focus * [0.1, 0.5, 0.0, 0.85][layer]
		draw_texture_rect(background_layers[layer], Rect2(-18 - offset, 0, 1316, 720), false)
	match Match.screen:
		Match.Screen.TITLE:
			_draw_title()
		Match.Screen.SELECT:
			_draw_select()
		Match.Screen.FIGHT:
			_draw_fight()
		Match.Screen.RESULT:
			_draw_result()
	_draw_footer()


func _text(at: Vector2, text: String, size_px: int = 24, color: Color = PAPER) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _center(y: float, text: String, size_px: int, color: Color = PAPER) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(Vector2((1280 - width) * 0.5, y), text, size_px, color)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.05, 0.11, 0.28))
	draw_circle(Vector2(962, 352), 228, Color(0.98, 0.7, 0.38, 0.07))
	draw_arc(Vector2(962, 352), 228, 0, TAU, 80, Color(0.98, 0.76, 0.48, 0.35), 2, true)
	draw_texture_rect(portraits[1], Rect2(836, 157, 385, 430), false)
	draw_texture_rect(portraits[0], Rect2(592, 244, 410, 420), false)
	draw_style_box(theme.get_stylebox("normal", "Button"), Rect2(56, 147, 530, 430))
	_text(Vector2(82, 191), "黄昏の街に、拳の灯を。", 23, COLORS[0])
	draw_texture_rect(title_logo, Rect2(77, 233, 485, 112), false)
	_text(Vector2(84, 397), "距離を読み、守りを崩せ。", 29)
	_text(Vector2(84, 444), "対ＣＰＵ   /   ９９秒   /   ２本先取", 20, Color("b6c9d0"))
	draw_texture_rect(emblem, Rect2(64, 45, 52, 52), false)
	_text(Vector2(134, 80), "燈環競技連盟   /   黄昏闘技場", 20)
	_text(Vector2(927, 599), "重装の燈", 20, COLORS[1])
	_text(Vector2(667, 630), "疾風の蒼", 20, COLORS[0])
	_text(Vector2(84, 623), "決定：Ｅｎｔｅｒ / パッド南ボタン", 18, Color("b6c9d0"))


func _draw_select() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.09, 0.13, 0.72))
	_center(72, "闘士を選択", 42)
	_center(110, "左右キー / 十字キーで選択  ・  決定で対戦開始", 19)
	for index: int in range(2):
		var x: float = 170.0 + index * 530.0
		draw_style_box(theme.get_stylebox("normal", "Button"), Rect2(x, 140, 410, 400))
		draw_rect(
			Rect2(x, 140, 410, 400),
			COLORS[index] if Match.selected == index else Color("53636a"),
			false,
			3
		)
		draw_texture_rect(portraits[index], Rect2(x + 95, 145, 220, 225), false)
		_text(Vector2(x + 30, 390), NAMES[index], 35, COLORS[index])
		_text(Vector2(x + 30, 430), "速い歩みと鋭い連打" if index == 0 else "長い間合いと重い一撃", 23)
	_center(563, "選択中：" + NAMES[Match.selected], 21, COLORS[Match.selected])


func _draw_fight() -> void:
	draw_rect(Rect2(0, 0, 1280, 132), Color(0.025, 0.055, 0.10, 0.95))
	draw_line(Vector2(0, 131), Vector2(1280, 131), Color("465b72"), 1)
	for index: int in range(2):
		var x: float = 58.0 if index == 0 else 730.0
		var character: int = Match.selected if index == 0 else 1 - Match.selected
		var body: FighterBody = player if index == 0 else cpu
		var fraction: float = clampf(body.health / 1000.0, 0, 1)
		var trail: float = clampf(health_trail[index] / 1000.0, 0, 1)
		_text(Vector2(x, 37), ("あなた   " if index == 0 else "ＣＰＵ   ") + NAMES[character], 23)
		draw_texture_rect(health_frame, Rect2(x - 3, 48, 496, 36), false)
		var trail_x: float = x if index == 0 else x + 484 * (1 - trail)
		draw_rect(Rect2(trail_x, 54, 484 * trail, 23), Color("cf775b"))
		var fill_x: float = x if index == 0 else x + 484 * (1 - fraction)
		draw_rect(Rect2(fill_x, 54, 484 * fraction, 23), COLORS[character])
		draw_rect(Rect2(fill_x, 54, 484 * fraction, 4), Color(1, 1, 0.9, 0.36))
		for tick: int in range(1, 10):
			draw_line(Vector2(x + tick * 48.4, 55), Vector2(x + tick * 48.4, 77),
				Color(0.02, 0.08, 0.14, 0.24), 1)
		for win: int in range(2):
			draw_texture_rect(round_medal, Rect2(x + win * 30, 91, 22, 22), false,
				Color.WHITE if Match.wins[index] > win else Color(0.25, 0.35, 0.44, 0.65))
		_text(Vector2(x + 359, 109), "%d / 1000" % ceili(health_display[index]), 17)
	_center(69, "%02d" % ceili(Match.remaining), 48)
	_center(112, "第%d戦" % Match.round_number, 19, COLORS[1])
	if feedback_time > 0.0:
		_center(185, feedback, 27, PAPER)
	if intro > 0.0:
		_banner("第%d戦" % Match.round_number if intro > 0.7 else "開始！", "９９秒・２本先取")
	elif Match.round_over:
		var detail: String = "引き分け・再ラウンド"
		if Match.round_winner >= 0:
			detail = "あなたのラウンド勝利" if Match.round_winner == 0 else "ＣＰＵのラウンド勝利"
		_banner(Match.reason, detail)
	if paused:
		draw_rect(Rect2(0, 132, 1280, 530), Color(0.02, 0.06, 0.1, 0.9))
		_center(280, "一時停止", 52)


func _banner(title: String, detail: String) -> void:
	draw_rect(Rect2(0, 248, 1280, 145), Color(0.04, 0.10, 0.14, 0.86))
	_center(316, title, 53, PAPER)
	_center(365, detail, 24, COLORS[1])


func _draw_result() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.09, 0.13, 0.83))
	var won: bool = Match.wins[0] >= 2
	var champion: int = Match.selected if won else 1 - Match.selected
	draw_texture_rect(portraits[champion], Rect2(160, 185, 280, 280), false)
	_text(Vector2(510, 214), "試合結果  /  黄昏闘技場", 24, COLORS[champion])
	_text(Vector2(506, 302), "あなたの勝利" if won else "再挑戦の時", 58)
	_text(Vector2(513, 375), "%d  対  %d" % [Match.wins[0], Match.wins[1]], 48)
	_text(Vector2(513, 432), "勝者：" + NAMES[champion], 26)
	_text(Vector2(513, 480), "その一撃が、街に灯をともす。" if won else "間合いを変えて、もう一度。", 23)


func _draw_footer() -> void:
	draw_rect(Rect2(0, 659, 1280, 61), INK)
	_text(Vector2(25, 682), "移動 ＷＡＳＤ / 矢印 / 左スティック　弱拳 Ｊ / 西　強拳 Ｋ / 北　弱蹴 Ｕ / 南　強蹴 Ｉ / 東", 17)
	_text(Vector2(25, 708), "守り：後ろ（下段は斜め下後ろ）　燈波：↓ ↘ → ＋ 拳（前向き基準）　停止 Ｅｓｃ / Ｓｔａｒｔ", 17)
	_text(Vector2(1050, 708), "Ｆ１１ 全画面  Ｍ 音", 16, COLORS[1])
