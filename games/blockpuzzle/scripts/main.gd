extends Node2D

const ORIGIN: Vector2 = Vector2(402, 134)
const CELL: float = 46.0
const COLORS: Array[Color] = [Color("68e1c1"), Color("ffb65e"), Color("bda0ff"), Color("ff778c")]
const INK: Color = Color("e4f3ed")
const MUTED: Color = Color("849ca8")
const ICON: Texture2D = preload("res://assets/crystal.svg")
var font: SystemFont = SystemFont.new()
var clock: float = 0.0
var particles: Array[Dictionary] = []
var burst_time: float = 0.0
var sound: AudioStreamPlayer = AudioStreamPlayer.new()
var music: AudioStreamPlayer = AudioStreamPlayer.new()
var muted: bool = false
var held_direction: int = 0
var repeat_time: float = 0.0
var soft_time: float = 0.0
var pause_on_focus_loss: bool = true

# シグナルと音声ノードは起動時に一度だけ登録する。
func _ready() -> void:
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "Yu Gothic", "sans-serif"])
	add_child(sound)
	add_child(music)
	music.stream = make_music()
	music.volume_db = -20
	music.play()
	Session.cleared_group.connect(on_clear)
	Session.landed.connect(func() -> void: play_tone(180.0, 0.09))
	Session.ended.connect(func() -> void: play_tone(100.0, 0.5))
	queue_redraw()

# フレーム時間に従うアニメーションと入力リピートなので非冪等。
func _process(delta: float) -> void:
	clock += delta
	burst_time = maxf(0.0, burst_time - delta)
	if Session.phase == "playing":
		var direction: int = int(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
		if direction != held_direction:
			held_direction = direction
			repeat_time = 0.18
		elif direction != 0:
			repeat_time -= delta
			if repeat_time <= 0.0:
				Session.move(direction)
				repeat_time = 0.075
		if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
			soft_time -= delta
			if soft_time <= 0:
				Session.step()
				soft_time = 0.055
	Session.tick(delta)
	for particle: Dictionary in particles:
		particle["position"] += particle["velocity"] * delta
		particle["velocity"] += Vector2(0, 270) * delta
		particle["life"] -= delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0)
	queue_redraw()

# 入力イベントごとにプレイ状態を進めるため非冪等。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER:
				if Session.phase in ["ready", "over"]: Session.start()
				elif Session.phase == "paused": Session.toggle_pause()
			KEY_ESCAPE, KEY_P: Session.toggle_pause()
			KEY_M: toggle_sound()
			KEY_LEFT, KEY_A: Session.move(-1)
			KEY_RIGHT, KEY_D: Session.move(1)
			KEY_UP, KEY_X, KEY_W:
				if Session.rotate_piece(1): play_tone(500, 0.045)
			KEY_Z:
				if Session.rotate_piece(-1): play_tone(420, 0.045)
			KEY_SPACE: Session.drop()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_mouse_position()
		if Rect2(448, 430, 184, 52).has_point(point):
			if Session.phase in ["ready", "over"]: Session.start()
			elif Session.phase == "paused": Session.toggle_pause()
		if Rect2(748, 608, 250, 38).has_point(point): Session.toggle_pause()
		if Rect2(748, 660, 250, 38).has_point(point): toggle_sound()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and pause_on_focus_loss and Session.phase in ["playing", "clearing"]:
		Session.toggle_pause()

# ユーザーの切替操作を一度反映するため非冪等。
func toggle_sound() -> void:
	muted = not muted
	music.volume_db = -80 if muted else -20
	sound.volume_db = -80 if muted else -12

func text_at(value: String, point: Vector2, size: int = 18, color: Color = INK) -> void:
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = INK) -> void:
	text_at(value, Vector2(540 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, y), size, color)

func crystal(center: Vector2, kind: int, scale_value: float = 1.0, alpha: float = 1.0) -> void:
	var color: Color = COLORS[kind]
	color.a = alpha
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(6):
		points.append(center + Vector2.from_angle(PI / 3 * index - PI / 6) * 20 * scale_value)
	draw_colored_polygon(points, color.darkened(0.17))
	var inner: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points: inner.append(center + (point - center) * 0.78)
	draw_colored_polygon(inner, color)
	draw_line(points[4], points[5], Color(1, 1, 1, alpha * 0.7), 2, true)
	var mark: Color = Color(0.04, 0.12, 0.19, alpha * 0.75)
	match kind:
		0: draw_circle(center, 4 * scale_value, mark, false, 2, true)
		1:
			draw_line(center + Vector2(-5, 0) * scale_value, center + Vector2(5, 0) * scale_value, mark, 2)
			draw_line(center + Vector2(0, -5) * scale_value, center + Vector2(0, 5) * scale_value, mark, 2)
		2: draw_rect(Rect2(center - Vector2.ONE * 4 * scale_value, Vector2.ONE * 8 * scale_value), mark, false, 2)
		3: draw_colored_polygon(PackedVector2Array([center + Vector2(0, -5) * scale_value, center + Vector2(5, 4) * scale_value, center + Vector2(-5, 4) * scale_value]), mark)

func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2.ONE * CELL / 2

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1100, 820), Color("09131e"))
	for i: int in range(36):
		var p: Vector2 = Vector2(fmod(i * 137.4, 1080), fmod(i * 83.7 + clock * (3 + i % 3), 820))
		draw_circle(p, 1.0 + i % 2, Color(0.42, 0.73, 0.7, 0.12))
	draw_line(Vector2(62, 100), Vector2(1038, 100), Color("28404b"), 1)
	draw_texture_rect(ICON, Rect2(64, 34, 46, 46), false)
	text_at("結晶の庭", Vector2(127, 68), 28)
	text_at("色をつなぐ、連鎖が咲く。", Vector2(764, 65), 18, MUTED)
	text_at("今回のスコア", Vector2(72, 166), 17, MUTED)
	text_at("%06d" % Session.score, Vector2(68, 228), 46)
	draw_line(Vector2(72, 253), Vector2(312, 253), Color("28404b"), 1)
	text_at("レベル", Vector2(72, 295), 16, MUTED)
	text_at("%02d" % Session.level, Vector2(72, 338), 32, COLORS[0])
	text_at("消した結晶", Vector2(203, 295), 16, MUTED)
	text_at(str(Session.cleared), Vector2(203, 338), 32)
	text_at("最高連鎖", Vector2(72, 397), 16, MUTED)
	text_at("%d 連鎖" % Session.best_chain, Vector2(72, 440), 30, COLORS[1])
	text_at("最高スコア  %d" % Session.best_score, Vector2(72, 481), 16, MUTED)
	text_at("つなげるコツ", Vector2(72, 541), 18, COLORS[0])
	text_at("同じ色を、縦と横に4つ。", Vector2(72, 580), 16, MUTED)
	text_at("消えたあとに落ちる結晶が", Vector2(72, 610), 16, MUTED)
	text_at("つながると、連鎖！", Vector2(72, 640), 16, MUTED)
	for i: int in range(4): crystal(Vector2(94 + i * 55, 701), i, 0.75)
	draw_rect(Rect2(ORIGIN - Vector2(9, 9), Vector2(294, 570)), Color("223c46"))
	draw_rect(Rect2(ORIGIN - Vector2(3, 3), Vector2(282, 558)), Color("050d16"))
	for row: int in range(12):
		for col: int in range(6):
			var c: Vector2i = Vector2i(col, row)
			draw_rect(Rect2(ORIGIN + Vector2(c) * CELL + Vector2.ONE, Vector2.ONE * (CELL - 2)), Color("101f2a") if (col + row) % 2 == 0 else Color("11212b"))
			if row < Session.board.size() and Session.board[row][col] >= 0:
				var flashing: bool = c in Session.pending
				crystal(cell_center(c), Session.board[row][col], 1 + sin(clock * 28) * 0.12 if flashing else 1.0, 0.6 + 0.4 * sin(clock * 22) if flashing else 1)
	if Session.phase in ["playing", "paused"]:
		var ghost: Array[Vector2i] = Session.ghost_cells()
		for index: int in range(ghost.size()):
			if ghost[index].y >= 0: crystal(cell_center(ghost[index]), Session.pair[index], 0.88, 0.19)
		var active: Array[Vector2i] = Session.cells()
		for index: int in range(active.size()):
			if active[index].y >= 0: crystal(cell_center(active[index]), Session.pair[index])
	draw_line(ORIGIN + Vector2(0, CELL * 2), ORIGIN + Vector2(276, CELL * 2), Color(1, 0.45, 0.5, 0.35), 1)
	text_at("ここまで積むと、あと少し", Vector2(417, 728), 14, MUTED)
	text_at("次の結晶", Vector2(748, 163), 18, MUTED)
	draw_rect(Rect2(748, 183, 250, 110), Color("12242e"))
	if Session.next_pair.size() == 2:
		crystal(Vector2(851, 235), Session.next_pair[0], 1.25)
		crystal(Vector2(900, 235), Session.next_pair[1], 1.25)
	text_at("操作", Vector2(748, 351), 18, COLORS[0])
	text_at("← →  /  A D", Vector2(748, 393), 17)
	text_at("左右に動かす", Vector2(748, 421), 15, MUTED)
	text_at("↑ X  /  Z", Vector2(748, 462), 17)
	text_at("右回転 / 左回転", Vector2(748, 490), 15, MUTED)
	text_at("↓  早く落とす", Vector2(748, 531), 17)
	text_at("SPACE  一気に落とす", Vector2(748, 567), 17)
	button(Rect2(748, 608, 250, 38), "P / ESC   再開" if Session.phase == "paused" else "P / ESC   一時停止", false)
	button(Rect2(748, 660, 250, 38), "M   音：オフ" if muted else "M   音：オン", false)
	text_at("急がず、次の連鎖を育てよう", Vector2(400, 782), 15, MUTED)
	for particle: Dictionary in particles:
		var color: Color = particle["color"]
		color.a = clampf(particle["life"], 0, 1)
		draw_circle(particle["position"], 3, color)
	if burst_time > 0 and Session.phase in ["playing", "clearing"]:
		centered("%d 連鎖！" % Session.chains, 340, 44, COLORS[1])
	if Session.phase in ["ready", "paused", "over"]:
		draw_rect(Rect2(ORIGIN, Vector2(276, 552)), Color(0.02, 0.06, 0.1, 0.92))
		draw_texture_rect(ICON, Rect2(509, 250, 62, 62), false)
		centered({"ready": "結晶を育てよう", "paused": "ひとやすみ", "over": "庭がいっぱい"}[Session.phase], 359, 24)
		centered("同じ色を4つつなげる" if Session.phase == "ready" else ("続きは、いつでも" if Session.phase == "paused" else "%d 点  /  最高 %d 連鎖" % [Session.score, Session.best_chain]), 397, 16, MUTED)
		button(Rect2(448, 430, 184, 52), "再開する" if Session.phase == "paused" else ("もう一度" if Session.phase == "over" else "はじめる"), true)
		centered("ENTER キーでも決定", 513, 14, MUTED)

func button(rect: Rect2, label: String, primary: bool) -> void:
	draw_rect(rect, COLORS[0] if primary else Color("1a303a"))
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	text_at(label, Vector2(rect.get_center().x - width / 2, rect.get_center().y + 6), 16, Color("0a2529") if primary else INK)

# 消去イベントのたびに演出粒子と音を追加するため非冪等。
func on_clear(cells_value: Array[Vector2i], chain: int) -> void:
	burst_time = 0.9
	play_tone(440.0 * pow(1.25, mini(chain, 8)), 0.24)
	for cell: Vector2i in cells_value:
		for i: int in range(8):
			particles.append({"position": cell_center(cell), "velocity": Vector2.from_angle(i * TAU / 8) * 90, "life": 0.8, "color": COLORS[(cell.x + cell.y) % 4]})

# 音声再生を開始するイベントなので非冪等。
func play_tone(frequency: float, duration: float) -> void:
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(22050 * duration) * 2)
	for i: int in range(data.size() / 2):
		var t: float = float(i) / 22050
		var sample: float = sin(TAU * frequency * t) * exp(-t * 15) * minf(t * 150, 1)
		data.encode_s16(i * 2, int(sample * 18000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	sound.stream = stream
	sound.volume_db = -80 if muted else -12
	sound.play()

func make_music() -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	var notes: Array[float] = [261.63, 329.63, 392.0, 493.88, 293.66, 349.23, 440.0, 523.25, 220.0, 261.63, 329.63, 392.0, 196.0, 246.94, 293.66, 392.0]
	data.resize(22050 * 8 * 2)
	for i: int in range(22050 * 8):
		var t: float = float(i) / 22050
		var beat: int = int(t * 2)
		var local: float = fmod(t, 0.5)
		var sample: float = sin(TAU * notes[beat] * local) * exp(-local * 7) * minf(local * 90, 1)
		sample += sin(TAU * notes[(beat / 4) * 4] * 0.5 * t) * 0.22 * sin(PI * fmod(t, 2) / 2)
		data.encode_s16(i * 2, int(sample * 13000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 22050 * 8
	return stream
