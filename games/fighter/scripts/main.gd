extends Control
## 入力・演出の更新は時間とイベントを消費するため非冪等。画面の構築は毎回再生成する。

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
var stage: Texture2D = preload("res://assets/stage.svg")
var emblem: Texture2D = preload("res://assets/emblem.svg")
var portraits: Array[Texture2D] = [
	preload("res://assets/portrait-teal.svg"), preload("res://assets/portrait-amber.svg")
]
var buttons: Control
var bgm: AudioStreamPlayer
var sounds: Dictionary = {}
var effects: Array[Dictionary] = []
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


func _ready() -> void:
	print("fighter boot")
	font.base_font = preload("res://assets/fonts/font.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600.0}
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_audio()
	buttons = Control.new()
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


func stop_audio() -> void:
	music_start_pending = false
	bgm.stop()
	for sound: AudioStreamPlayer in sounds.values():
		sound.stop()


func _build_audio() -> void:
	bgm = AudioStreamPlayer.new()
	bgm.stream = preload("res://assets/audio/arena.wav")
	bgm.volume_db = -13.0
	add_child(bgm)
	for sound: String in ["hit", "guard", "special"]:
		var audio: AudioStreamPlayer = AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/%s.wav" % sound)
		audio.volume_db = -9.0
		add_child(audio)
		sounds[sound] = audio


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
	effects.clear()


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
		bgm.play()
	elapsed += delta
	if not previewing:
		_update_effects(delta)
		if Match.screen == Match.Screen.FIGHT:
			_update_fight(delta)
	if last_screen != Match.screen:
		last_screen = Match.screen
		_rebuild_buttons()
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
	effects.append({"at": at, "life": 0.26, "blocked": blocked})
	sounds["guard" if blocked else "hit"].play()
	feedback = "ガード" if blocked else "命中！"
	feedback_time = 0.6


func _on_special() -> void:
	sounds["special"].play()
	feedback = "必殺・燈波"
	feedback_time = 0.9


func _update_effects(delta: float) -> void:
	feedback_time = maxf(0.0, feedback_time - delta)
	for i: int in range(effects.size() - 1, -1, -1):
		effects[i]["life"] -= delta
		if effects[i]["life"] <= 0.0:
			effects.remove_at(i)


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
			_button("もう一度対戦   ↵", Rect2(265, 538, 360, 62), start_match)
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
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", INK)
	for style: String in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = PAPER if style == "normal" else COLORS[Match.selected]
		box.border_color = COLORS[Match.selected]
		box.set_border_width_all(2)
		box.corner_radius_top_left = 6
		box.corner_radius_bottom_right = 6
		button.add_theme_stylebox_override(style, box)
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	buttons.add_child(button)


func _draw() -> void:
	draw_texture_rect(stage, Rect2(0, 0, 1280, 720), false)
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
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.09, 0.13, 0.25))
	draw_texture_rect(portraits[1], Rect2(755, 157, 390, 390), false, Color(1, 1, 1, 0.9))
	draw_texture_rect(portraits[0], Rect2(593, 270, 330, 330), false)
	draw_rect(Rect2(56, 125, 538, 470), Color(0.04, 0.10, 0.14, 0.92))
	draw_rect(Rect2(56, 125, 6, 470), COLORS[0])
	_text(Vector2(82, 170), "黄昏の街に、拳の灯を。", 23, COLORS[0])
	_text(Vector2(78, 284), "燈環闘技", 90)
	_text(Vector2(84, 341), "蒼と燈、ふたつの闘志。", 28)
	_text(Vector2(84, 399), "対ＣＰＵ  /  ９９秒  /  ２本先取", 22)
	_text(Vector2(84, 445), "距離を読み、守りを崩し、燈波を放て。", 20)
	draw_texture_rect(emblem, Rect2(79, 42, 54, 54), false)
	_text(Vector2(150, 80), "燈環競技連盟  /  黄昏闘技場", 21, PAPER)
	_text(Vector2(858, 612), "拳で刻む、次の一手。", 25)
	_text(Vector2(84, 638), "決定：Ｅｎｔｅｒ / パッド南ボタン", 19)


func _draw_select() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.09, 0.13, 0.72))
	_center(72, "闘士を選択", 42)
	_center(110, "左右キー / 十字キーで選択  ・  決定で対戦開始", 19)
	for index: int in range(2):
		var x: float = 170.0 + index * 530.0
		draw_rect(Rect2(x, 140, 410, 400), INK)
		draw_rect(
			Rect2(x, 140, 410, 400),
			COLORS[index] if Match.selected == index else Color("53636a"),
			false,
			3
		)
		draw_texture_rect(portraits[index], Rect2(x + 105, 153, 200, 200), false)
		_text(Vector2(x + 30, 390), NAMES[index], 35, COLORS[index])
		_text(Vector2(x + 30, 430), "速い歩みと鋭い連打" if index == 0 else "長い間合いと重い一撃", 23)
	_center(563, "選択中：" + NAMES[Match.selected], 21, COLORS[Match.selected])


func _draw_fight() -> void:
	draw_rect(Rect2(0, 0, 1280, 132), Color(0.035, 0.08, 0.12, 0.93))
	for index: int in range(2):
		var x: float = 58.0 if index == 0 else 730.0
		var body: FighterBody = player if index == 0 else cpu
		var character: int = Match.selected if index == 0 else 1 - Match.selected
		var fraction: float = clampf(body.health / 1000.0, 0, 1)
		_text(Vector2(x, 38), ("あなた  " if index == 0 else "ＣＰＵ  ") + NAMES[character], 24)
		draw_rect(Rect2(x, 51, 490, 28), Color("34444e"))
		var fill_x: float = x if index == 0 else x + 490 * (1 - fraction)
		draw_rect(Rect2(fill_x, 51, 490 * fraction, 28), COLORS[character])
		draw_rect(Rect2(x, 51, 490, 28), PAPER, false, 2)
		for win: int in range(2):
			draw_circle(
				Vector2(x + 12 + win * 28, 102),
				8,
				COLORS[character] if Match.wins[index] > win else Color("495862")
			)
		_text(Vector2(x + 350, 109), "%d / 1000" % body.health, 18)
	_center(69, "%02d" % ceili(Match.remaining), 48)
	_center(112, "第%d戦" % Match.round_number, 19, COLORS[1])
	if feedback_time > 0.0:
		_center(185, feedback, 27, PAPER)
	for effect: Dictionary in effects:
		var at: Vector2 = effect["at"]
		var progress: float = 1.0 - float(effect["life"]) / 0.26
		var color: Color = COLORS[0] if effect["blocked"] else Color("fff1ab")
		draw_arc(at, 24 + progress * 55, 0, TAU, 32, color, 5, true)
		for ray: int in range(8):
			var direction: Vector2 = Vector2.from_angle(ray * TAU / 8 + progress)
			draw_line(at + direction * 12, at + direction * (55 + progress * 32), color, 4, true)
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
