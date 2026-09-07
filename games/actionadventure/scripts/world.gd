extends Node2D
## 入力・部屋の物理・戦闘・描画を管理する、画面切り替え式の小さな冒険。

const TILE: int = 32
const TOP: int = 48
const SPEED: float = 112.0
const CREAM: Color = Color("f4e4b9")
const GOLD: Color = Color("eab963")
const INK: Color = Color("14282d")
var player: Vector2 = Vector2(176, 224)
var facing: Vector2 = Vector2.RIGHT
var enemies: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var block: Vector2i = Vector2i(8, 5)
var attack: float = 0.0
var attack_cooldown: float = 0.0
var hurt: float = 0.0
var dash: float = 0.0
var dash_cooldown: float = 0.0
var tool_cooldown: float = 0.0
var push_cooldown: float = 0.0
var clock: float = 0.0
var banner_time: float = 0.0
var message: String = ""
var message_time: float = 0.0
var mode: String = "title"
var atlas: Texture2D
var font: SystemFont = SystemFont.new()
var music: AudioStreamPlayer = AudioStreamPlayer.new()
var effects: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var muted: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans CJK JP", "sans-serif"])
	atlas = load("res://assets/atlas.png") as Texture2D
	for sound: String in ["swing", "hit", "chime"]:
		sounds[sound] = load("res://assets/" + sound + ".wav")
	add_child(music)
	music.stream = load("res://assets/ambient.wav")
	music.volume_db = -17
	music.finished.connect(music.play)
	if DisplayServer.get_name() != "headless":
		music.play()
	for index: int in range(6):
		var effect: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(effect)
		effects.append(effect)
	load_room(0, player)

func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(16, TOP + 16)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori((point.y - TOP) / TILE))

func solid(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x > 19 or cell.y < 0 or cell.y > 10:
		return false
	if cell.x == 0 or cell.x == 19:
		return cell.y != 5 or Journey.destination(Vector2i(-1 if cell.x == 0 else 1, 0)) < 0
	if cell.y == 0 or cell.y == 10:
		if cell.x != 10:
			return true
		if Journey.destination(Vector2i(0, -1 if cell.y == 0 else 1)) < 0:
			return true
		if cell.y == 0 and Journey.room == 1 and not Journey.shrine_open:
			return true
		if cell.y == 0 and Journey.room == 3 and Journey.braziers.size() < 2:
			return true
	if Journey.room == 0:
		return (cell.x in [2, 3, 4] and cell.y in [2, 3, 7, 8]) or (cell.x >= 13 and cell.x <= 16 and cell.y >= 7)
	if Journey.room == 1:
		return (cell.x in [4, 5, 14, 15] and cell.y in [2, 3, 7, 8]) or cell == Vector2i(8, 3)
	if Journey.room == 2:
		return cell in [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 6), Vector2i(5, 7), Vector2i(14, 3), Vector2i(14, 7)]
	if Journey.room == 3:
		return cell.x in [5, 14] and cell.y in [3, 4, 6, 7]
	return cell in [Vector2i(4, 3), Vector2i(15, 3), Vector2i(4, 7), Vector2i(15, 7)]

func can_stand(point: Vector2, include_block: bool = true) -> bool:
	for offset: Vector2 in [Vector2(-8, -6), Vector2(8, -6), Vector2(-8, 7), Vector2(8, 7)]:
		var cell: Vector2i = cell_at(point + offset)
		if solid(cell) or (include_block and Journey.room == 2 and cell == block):
			return false
	return true

# 部屋への入場は敵と飛び道具を再構築するイベントであり、移動のたびに呼ぶ。
func load_room(index: int, spawn: Vector2) -> void:
	Journey.room = index
	if not Journey.visited.has(index):
		Journey.visited.append(index)
	player = spawn
	bolts.clear()
	sparks.clear()
	enemies.clear()
	block = Vector2i(11, 5) if Journey.solved else Vector2i(8, 5)
	attack = 0
	dash = 0
	hurt = 0.6
	banner_time = 2.4
	message_time = 0
	var placements: Array[Vector2i] = []
	if index == 1:
		placements = [Vector2i(8, 5), Vector2i(12, 7), Vector2i(13, 3)]
	elif index == 3:
		placements = [Vector2i(8, 4), Vector2i(12, 7)]
	elif index == 4:
		placements = [Vector2i(10, 4)]
	for i: int in range(placements.size()):
		var id: String = "%d:%d" % [index, i]
		if not Journey.defeated.has(id):
			enemies.append({"id": id, "pos": center(placements[i]), "hp": 14 if index == 4 else 3, "max": 14 if index == 4 else 3, "boss": index == 4, "phase": 0.0, "flash": 0.0, "target": player})

# 攻撃や移動は時間を進めるため非冪等。delta を一度だけ適用する。
func _physics_process(delta: float) -> void:
	clock += delta
	queue_redraw()
	if mode != "play":
		return
	attack = maxf(0, attack - delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	hurt = maxf(0, hurt - delta)
	dash = maxf(0, dash - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	tool_cooldown = maxf(0, tool_cooldown - delta)
	push_cooldown = maxf(0, push_cooldown - delta)
	banner_time = maxf(0, banner_time - delta)
	message_time = maxf(0, message_time - delta)
	var movement: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).normalized()
	if movement != Vector2.ZERO and dash <= 0:
		facing = movement
	if dash > 0:
		movement = facing
	move_player(movement * (290.0 if dash > 0 else SPEED) * delta)
	check_exit()
	update_enemies(delta)
	update_bolts(delta)
	for spark: Dictionary in sparks:
		spark.life -= delta
		spark.pos += spark.velocity * delta
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s.life > 0)
	if Journey.room == 2 and block == Vector2i(11, 5) and not Journey.solved:
		Journey.solved = true
		notify_player("石の灯が目覚めた。北の祭壇へ", "chime")
	if Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z):
		swing()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
	if mode == "title" and key in [KEY_ENTER, KEY_SPACE]:
		new_game()
	elif mode in ["dead", "ending"] and key == KEY_ENTER:
		if mode == "dead":
			Journey.health = 6
			load_room(Journey.room, center(Vector2i(10, 8)))
			mode = "play"
		else:
			new_game()
	elif key in [KEY_ESCAPE, KEY_TAB] and mode in ["play", "map"]:
		mode = "map" if mode == "play" else "play"
	elif mode == "play":
		if key in [KEY_SPACE, KEY_K] and dash_cooldown <= 0:
			dash = 0.16
			dash_cooldown = 0.8
			play_sound("swing", 0.7)
		if key in [KEY_E, KEY_X]:
			interact()
		if key in [KEY_J, KEY_Z]:
			swing()

func new_game() -> void:
	Journey.reset()
	mode = "play"
	attack_cooldown = 0
	dash_cooldown = 0
	tool_cooldown = 0
	load_room(0, center(Vector2i(6, 5)))
	notify_player("東の森へ。J で剣、Space で回避", "chime")

func move_player(motion: Vector2) -> void:
	for axis: Vector2 in [Vector2(motion.x, 0), Vector2(0, motion.y)]:
		if axis == Vector2.ZERO:
			continue
		var next: Vector2 = player + axis
		if can_stand(next):
			player = next
		elif Journey.room == 2 and push_cooldown <= 0 and dash <= 0:
			var direction: Vector2i = Vector2i(signi(int(axis.x * 1000)), signi(int(axis.y * 1000)))
			if cell_at(player + Vector2(direction) * 22) == block and not solid(block + direction):
				var target: Vector2i = block + direction
				if target.x > 1 and target.x < 18 and target.y > 1 and target.y < 9 and not Journey.solved:
					block = target
					push_cooldown = 0.24
					play_sound("hit", 0.5)

func check_exit() -> void:
	var direction: Vector2i = Vector2i.ZERO
	var spawn: Vector2 = player
	if player.x < 0:
		direction = Vector2i.LEFT
		spawn.x = 604
	elif player.x > 640:
		direction = Vector2i.RIGHT
		spawn.x = 36
	elif player.y < TOP:
		direction = Vector2i.UP
		spawn.y = 368
	elif player.y > 400:
		direction = Vector2i.DOWN
		spawn.y = 80
	if direction != Vector2i.ZERO:
		var destination: int = Journey.destination(direction)
		if destination >= 0:
			load_room(destination, spawn)

func swing() -> void:
	if attack_cooldown > 0:
		return
	attack = 0.19
	attack_cooldown = 0.32
	play_sound("swing")
	for enemy: Dictionary in enemies:
		var offset: Vector2 = enemy.pos - player
		if offset.length() < (65 if enemy.boss else 51) and facing.dot(offset.normalized()) > -0.25:
			damage_enemy(enemy, 1)
	remove_defeated()

func damage_enemy(enemy: Dictionary, amount: int) -> void:
	enemy.hp -= amount
	enemy.flash = 0.15
	burst(enemy.pos, GOLD)
	play_sound("hit")
	if not enemy.boss:
		var knockback: Vector2 = enemy.pos + (enemy.pos - player).normalized() * 16
		if can_stand(knockback):
			enemy.pos = knockback

func remove_defeated() -> void:
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0:
			if not Journey.defeated.has(enemy.id):
				Journey.defeated.append(enemy.id)
			Journey.health = mini(6, Journey.health + 1)
			if enemy.boss:
				bolts.clear()
				notify_player("守護者は眠りについた。灯台へ灯火を", "chime")
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)

func update_enemies(delta: float) -> void:
	for enemy: Dictionary in enemies:
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.phase += delta
		var offset: Vector2 = player - Vector2(enemy.pos)
		if enemy.boss:
			var period: float = 2.2 if enemy.hp > 7 else 1.55
			if enemy.phase >= period:
				enemy.phase = 0.0
				for index: int in range(8):
					var direction: Vector2 = Vector2.RIGHT.rotated(index * TAU / 8 + clock * 0.1)
					bolts.append({"pos": Vector2(enemy.pos), "vel": direction * 105, "life": 4.0, "hostile": true})
				play_sound("hit", 0.6)
			if enemy.phase < period - 0.55:
				var next: Vector2 = enemy.pos + offset.normalized() * delta * 25
				if can_stand(next):
					enemy.pos = next
		else:
			var cycle: float = fmod(enemy.phase, 2.4)
			if cycle < 1.35:
				enemy.target = player
			if cycle < 1.35 or cycle > 1.85:
				var next: Vector2 = enemy.pos + (Vector2(enemy.target) - Vector2(enemy.pos)).normalized() * delta * (47 if cycle < 1.35 else 130)
				if can_stand(next) and Rect2(32, 80, 576, 288).has_point(next):
					enemy.pos = next
		if offset.length() < (29 if enemy.boss else 21):
			damage_player(enemy.pos)

func damage_player(source: Vector2) -> void:
	if hurt > 0 or dash > 0 or mode != "play":
		return
	Journey.health = maxi(0, Journey.health - 1)
	hurt = 1.15
	burst(player, Color("de795e"))
	play_sound("hit", 0.65)
	var next: Vector2 = player + (player - source).normalized() * 18
	if can_stand(next):
		player = next
	if Journey.health == 0:
		mode = "dead"

func update_bolts(delta: float) -> void:
	for bolt: Dictionary in bolts:
		bolt.life -= delta
		bolt.pos += bolt.vel * delta
		if not Rect2(0, TOP, 640, 352).has_point(bolt.pos) or solid(cell_at(bolt.pos)):
			bolt.life = 0
		if bolt.hostile:
			if Vector2(bolt.pos).distance_to(player) < 13:
				damage_player(bolt.pos)
				bolt.life = 0
		else:
			for enemy: Dictionary in enemies:
				if Vector2(bolt.pos).distance_to(enemy.pos) < (28 if enemy.boss else 18) and bolt.life > 0:
					damage_enemy(enemy, 2)
					bolt.life = 0
			if Journey.room == 3:
				for index: int in range(2):
					if Vector2(bolt.pos).distance_to(center(Vector2i(8 + index * 4, 2))) < 22:
						light_brazier(index)
						bolt.life = 0
	bolts = bolts.filter(func(b: Dictionary) -> bool: return b.life > 0)
	remove_defeated()

func light_brazier(index: int) -> void:
	if not Journey.ember or Journey.braziers.has(index):
		return
	Journey.braziers.append(index)
	notify_player("封印が解けた。北の灯台へ" if Journey.braziers.size() == 2 else "あと一つの燭台へ", "chime")

func interact() -> void:
	if Journey.room == 0 and player.distance_to(center(Vector2i(6, 3))) < 52:
		Journey.health = 6
		notify_player("泉の灯りで、体力が回復した", "chime")
		return
	if Journey.room == 1:
		if player.distance_to(center(Vector2i(10, 1))) < 53 and not Journey.shrine_open:
			if Journey.key_found:
				Journey.shrine_open = true
				notify_player("祠の扉が開いた", "chime")
			else:
				notify_player("森の魔物を鎮め、宝箱の鍵を手に入れよう")
			return
		if player.distance_to(center(Vector2i(16, 5))) < 48 and not Journey.key_found:
			if enemies.is_empty():
				Journey.key_found = true
				notify_player("祠の鍵を手に入れた。森の北の扉へ", "chime")
			else:
				notify_player("宝箱は魔物の気配で閉ざされている")
			return
	if Journey.room == 2:
		if player.distance_to(center(Vector2i(10, 2))) < 49 and not Journey.ember:
			if Journey.solved:
				Journey.ember = true
				Journey.health = 6
				notify_player("灯火を手に入れた！ E で炎を放つ", "chime")
			else:
				notify_player("石を右の金色の床へ押すと、祭壇が目覚める")
			return
		if player.distance_to(center(Vector2i(3, 5))) < 46 and not Journey.solved:
			block = Vector2i(8, 5)
			notify_player("石を元の位置に戻した")
			return
	if Journey.room == 3:
		for index: int in range(2):
			if player.distance_to(center(Vector2i(8 + index * 4, 2))) < 44:
				if Journey.ember:
					light_brazier(index)
				else:
					notify_player("火が必要だ。森の北に、灯火の祠がある")
				return
	if Journey.room == 4 and enemies.is_empty() and player.distance_to(center(Vector2i(10, 2))) < 48:
		if Journey.ember:
			Journey.won = true
			mode = "ending"
			play_sound("chime")
		return
	if Journey.ember and tool_cooldown <= 0:
		tool_cooldown = 0.65
		bolts.append({"pos": player + facing * 18, "vel": facing * 235, "life": 1.6, "hostile": false})
		play_sound("swing", 1.3)

func notify_player(text: String, sound: String = "") -> void:
	message = text
	message_time = 3.2
	if not sound.is_empty():
		play_sound(sound)

# SE の再生と粒子発生は同じ呼び出しでも新しい演出を発生させる。
func play_sound(sound: String, pitch: float = 1.0) -> void:
	# 描画なしの高速検証では、実時間の音声スレッドに再生を予約しない。
	if DisplayServer.get_name() == "headless":
		return
	for effect: AudioStreamPlayer in effects:
		if not effect.playing:
			effect.stream = sounds.get(sound)
			effect.pitch_scale = pitch
			effect.volume_db = -13
			effect.play()
			return

func burst(point: Vector2, color: Color) -> void:
	for index: int in range(9):
		sparks.append({"pos": point, "velocity": Vector2.RIGHT.rotated(index * TAU / 9) * (28 + index * 5), "life": 0.32, "color": color})

func sprite(index: int, point: Vector2, scale_factor: float = 2.0, tint: Color = Color.WHITE) -> void:
	if atlas:
		draw_texture_rect_region(atlas, Rect2(point - Vector2.ONE * 8 * scale_factor, Vector2.ONE * 16 * scale_factor), Rect2(index * 16, 0, 16, 16), tint)

func text_line(text: String, point: Vector2, size: int = 12, color: Color = CREAM) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(text: String, y: float, size: int = 16, color: Color = CREAM) -> void:
	text_line(text, Vector2((640 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func _draw() -> void:
	draw_rect(Rect2(0, TOP, 640, 352), Color("334b3c"))
	var indoor: bool = Journey.room in [2, 4]
	for y: int in range(11):
		for x: int in range(20):
			var cell: Vector2i = Vector2i(x, y)
			var p: Vector2 = center(cell)
			var tint: Color = Color("c7d5b6") if Journey.room == 1 else Color.WHITE
			if indoor:
				tint = Color("acbab4") if Journey.room == 4 else Color("d1c5ab")
			sprite(1 if indoor or x in [9, 10] or y == 5 else 0, p, 2, tint)
			if not indoor and not solid(cell) and (x * 7 + y * 13) % 19 == 0:
				sprite(13, p + Vector2(3, 1))
			if solid(cell):
				if Journey.room == 0 and x >= 13 and x <= 16 and y >= 7:
					sprite(2, p, 2, Color(0.8, 0.95, 1, 0.85 + sin(clock * 2 + x) * 0.1))
				else:
					draw_shadow(p + Vector2(3, 12), Vector2(17, 6), Color(0, 0, 0, 0.2))
					sprite(4 if indoor or Journey.room == 3 else 3, p, 2, tint)
	if Journey.room == 0:
		sprite(10, center(Vector2i(6, 3)), 2.5)
		glow(center(Vector2i(6, 3)) - Vector2(0, 8), 18)
		world_label("E 休息", center(Vector2i(6, 3)) + Vector2(0, -30))
		world_label("木霊の森 →", Vector2(546, 196))
	elif Journey.room == 1:
		sprite(9, center(Vector2i(16, 5)), 2, Color("a8b4a3") if Journey.key_found else Color.WHITE)
		world_label("開いた宝箱" if Journey.key_found else ("E 宝箱" if enemies.is_empty() else "魔物を鎮める"), center(Vector2i(16, 5)) - Vector2(0, 24))
		if not Journey.shrine_open:
			draw_rect(Rect2(320, TOP, 32, 24), GOLD)
		world_label("↑ 灯火の祠" if Journey.shrine_open else "E 鍵で開く", Vector2(336, 109))
		world_label("封印の庭 →", Vector2(554, 266))
	elif Journey.room == 2:
		sprite(11, center(Vector2i(11, 5)))
		draw_rect(Rect2(center(Vector2i(11, 5)) - Vector2(14, 14), Vector2(28, 28)), GOLD, false, 2)
		sprite(12, center(block))
		sprite(10, center(Vector2i(10, 2)), 2.5)
		if Journey.solved:
			glow(center(Vector2i(10, 2)), 25)
		if not Journey.ember:
			world_label("E 灯火を受け取る" if Journey.solved else "石を金色の床へ →", Vector2(336, 110))
		sprite(11, center(Vector2i(3, 5)))
		world_label("E 石を戻す", center(Vector2i(3, 5)) - Vector2(0, 22))
	elif Journey.room == 3:
		for index: int in range(2):
			var p: Vector2 = center(Vector2i(8 + index * 4, 2))
			sprite(10, p)
			if Journey.braziers.has(index):
				glow(p - Vector2(0, 10), 22)
				sprite(15, p - Vector2(0, 13), 1.6)
			else:
				world_label("E 灯す", p - Vector2(0, 23))
		if Journey.braziers.size() < 2:
			draw_rect(Rect2(321, TOP, 30, 30), Color("bd795b"))
		world_label("↑ 最後の灯台", Vector2(336, 114))
	elif Journey.room == 4:
		draw_arc(center(Vector2i(10, 5)), 105, 0, TAU, 48, Color("607671"), 2)
		draw_arc(center(Vector2i(10, 5)), 113, 0, TAU, 48, Color("465e59"), 1)
		sprite(10, center(Vector2i(10, 2)), 3)
		if enemies.is_empty():
			glow(center(Vector2i(10, 2)), 35)
			world_label("E 最後の灯りを灯す", Vector2(336, 107))
	for enemy: Dictionary in enemies:
		var p: Vector2 = enemy.pos
		var warning: bool = enemy.phase > (1.65 if enemy.hp > 7 else 1.0) if enemy.boss else fmod(enemy.phase, 2.4) > 1.35 and fmod(enemy.phase, 2.4) < 1.85
		if warning:
			draw_arc(p, 30 if enemy.boss else 23, 0, TAU, 24, Color("f3a36b"), 2)
			if not enemy.boss:
				draw_line(p, enemy.target, Color(1, 0.55, 0.3, 0.4), 2)
		draw_shadow(p + Vector2(0, 12), Vector2(20 if enemy.boss else 12, 5), Color(0, 0, 0, 0.3))
		sprite(8 if enemy.boss else (7 if Journey.room == 3 else 6), p + Vector2(0, sin(clock * 7) * 2), 3.5 if enemy.boss else 2, Color("ffe4a4") if enemy.flash > 0 else Color.WHITE)
		draw_rect(Rect2(p + Vector2(-13, -25 if not enemy.boss else -37), Vector2(26, 3)), INK)
		draw_rect(Rect2(p + Vector2(-13, -25 if not enemy.boss else -37), Vector2(26.0 * enemy.hp / enemy.max, 3)), Color("e79a6b"))
	draw_shadow(player + Vector2(0, 12), Vector2(11, 4), Color(0, 0, 0, 0.35))
	if dash > 0:
		for index: int in range(1, 4):
			sprite(5, player - facing * index * 10, 2, Color(1, 0.9, 0.6, 0.3 / index))
	if hurt <= 0 or int(clock * 16) % 2 == 0:
		sprite(5, player + Vector2(0, sin(clock * 10) * 0.8))
	draw_line(player + facing * 11, player + facing * 16, CREAM, 2)
	if attack > 0:
		var angle: float = facing.angle()
		draw_arc(player, 34, angle - 1.3, angle + 1.3, 16, CREAM, 5)
		draw_arc(player, 39, angle - 1.15, angle + 1.15, 16, GOLD, 2)
	for bolt: Dictionary in bolts:
		var p: Vector2 = bolt.pos
		draw_circle(p, 7, Color("cc684f") if bolt.hostile else GOLD)
		draw_circle(p, 3, CREAM)
	for spark: Dictionary in sparks:
		draw_rect(Rect2(spark.pos, Vector2(3, 3)), spark.color)
	for index: int in range(18):
		var p: Vector2 = Vector2(fmod(index * 97.0 + clock * 7, 640), TOP + fmod(index * 43.0 + sin(clock + index) * 6, 350))
		draw_circle(p, 1, Color(0.95, 0.86, 0.55, 0.22 + sin(clock * 1.5 + index) * 0.18))
	draw_hud()
	if mode == "play":
		if message_time > 0:
			draw_rect(Rect2(48, 367, 544, 26), Color(0.06, 0.12, 0.13, 0.94))
			centered(message, 385, 12)
		elif banner_time > 0:
			world_label(Journey.ROOM_NAMES[Journey.room], Vector2(320, 348))
	elif mode == "title":
		draw_title()
	elif mode == "map":
		draw_map()
	elif mode in ["dead", "ending"]:
		draw_rect(Rect2(0, 0, 640, 416), Color(0.025, 0.08, 0.09, 0.87))
		centered("森に、灯りが帰る" if mode == "ending" else "灯火は、まだ消えない", 174, 27)
		centered("あなたの残り火が、明日への道を照らした" if mode == "ending" else "手に入れた道具を持って、この部屋から再開", 210, 13, GOLD)
		centered("Enter  はじめから" if mode == "ending" else "Enter  もう一度", 265, 16)

func draw_shadow(point: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(point, 0, radius)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)

func glow(point: Vector2, radius: float) -> void:
	for index: int in range(4, 0, -1):
		draw_circle(point, radius * index / 3.0 + sin(clock * 3) * 2, Color(1, 0.69, 0.25, 0.035))

func world_label(text: String, point: Vector2) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_rect(Rect2(point - Vector2(width / 2 + 5, 13), Vector2(width + 10, 19)), Color(0.055, 0.11, 0.12, 0.88))
	text_line(text, point - Vector2(width / 2, 0), 11, CREAM)

func draw_hud() -> void:
	draw_rect(Rect2(0, 0, 640, 48), INK)
	draw_line(Vector2(0, 47), Vector2(640, 47), Color("697452"))
	for index: int in range(6):
		var x: float = 17 + index * 15
		var color: Color = Color("e08867") if index < Journey.health else Color("405454")
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 15), Vector2(x - 2, 11), Vector2(x, 13), Vector2(x + 2, 11), Vector2(x + 5, 15), Vector2(x, 21)]), color)
	text_line(Journey.ROOM_NAMES[Journey.room], Vector2(120, 21), 14)
	text_line(Journey.objective(), Vector2(16, 39), 10, Color("b5c2a8"))
	text_line("鍵 ●" if Journey.key_found else "鍵 —", Vector2(414, 21), 11, GOLD)
	text_line("灯火 ●" if Journey.ember else "灯火 —", Vector2(465, 21), 11, GOLD)
	text_line("Tab 地図", Vector2(565, 21), 11)
	draw_rect(Rect2(565, 31, 58, 3), Color("405454"))
	draw_rect(Rect2(565, 31, 58 * (1 - dash_cooldown / 0.8), 3), GOLD)
	draw_rect(Rect2(0, 400, 640, 16), INK)
	text_line("残り火の森", Vector2(12, 412), 9, Color("8fa893"))
	text_line("J 剣    E 調べる / 灯火    Space 回避    M 消音", Vector2(345, 412), 9, Color("8fa893"))

func draw_title() -> void:
	draw_rect(Rect2(0, 0, 640, 416), Color(0.035, 0.08, 0.09, 0.73))
	draw_rect(Rect2(91, 62, 458, 294), Color(0.05, 0.12, 0.13, 0.96))
	draw_rect(Rect2(98, 69, 444, 280), Color("778466"), false)
	centered("小さな灯りを、森の奥へ", 112, 13, GOLD)
	centered("残り火の森", 165, 42)
	centered("剣を携え、祠を巡り、眠れる灯台を目覚めさせる", 197, 12, Color("b8c4ac"))
	centered("Enter  旅に出る", 241, 18, GOLD)
	centered("WASD / 矢印  移動    J / Z  剣    Space  回避", 286, 12)
	centered("E / X  調べる・灯火    Tab / Esc  地図・一時停止", 308, 12)
	centered("音あり推奨  ·  M で消音", 334, 10, Color("8fa893"))

func draw_map() -> void:
	draw_rect(Rect2(0, 0, 640, 416), Color(0.03, 0.08, 0.09, 0.92))
	centered("森の道しるべ", 65, 25)
	centered(Journey.objective(), 92, 12, GOLD)
	for index: int in range(Journey.ROOM_MAP.size()):
		var cell: Vector2i = Journey.ROOM_MAP[index]
		var p: Vector2 = Vector2(153 + cell.x * 160, 147 + cell.y * 89)
		for next: int in range(index + 1, Journey.ROOM_MAP.size()):
			if Journey.connected(index, next):
				var q: Vector2 = Vector2(153 + Journey.ROOM_MAP[next].x * 160, 147 + Journey.ROOM_MAP[next].y * 89)
				draw_line(p, q, Color("607466"), 3)
		draw_rect(Rect2(p - Vector2(67, 27), Vector2(134, 54)), GOLD if index == Journey.room else Color("39564d"))
		var color: Color = INK if index == Journey.room else CREAM
		var name_text: String = Journey.ROOM_NAMES[index] if Journey.visited.has(index) else "未踏の地"
		text_line(name_text, p - Vector2(font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x / 2, -5), 13, color)
	centered("J / Z 剣  ·  Space / K 回避  ·  E / X 調べる・灯火", 322, 12)
	centered("Tab / Esc で戻る     M 消音：" + ("入" if muted else "切"), 354, 13, GOLD)
