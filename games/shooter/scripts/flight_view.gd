extends Node2D
## 描画は進行状態を参照する。表示値の補間とアニメーション時間だけは非冪等。

const INK: Color = Color("e5eff5")
const MUTED: Color = Color("8aa6bc")
const MINT: Color = Color("79f5d4")
const ORANGE: Color = Color("ffb46c")
const Stage = preload("res://scripts/stage_data.gd")
const Ship = preload("res://scripts/ship_sprite.gd")

var game: Control
var font: Font
var textures: Dictionary = {}
var background: Node2D
var actors: Node2D
var ships: Dictionary = {}
var display_score: float = 0.0
var display_hp: float = 0.0
var display_lives: float = 3.0
var last_mode: int = -1


func _ready() -> void:
	font = load("res://assets/ui/flight_theme.tres").default_font
	for name: String in [
		"player",
		"enemy_scout",
		"enemy_fighter",
		"enemy_carrier",
		"boss",
		"bullet_player",
		"bullet_enemy",
		"item_power",
		"item_bomb",
		"item_score"
	]:
		textures[name] = load("res://assets/sprites/%s.svg" % name)
	for name: String in ["space", "nebula", "stars_far", "stars_near", "orbital", "title_keyart"]:
		textures[name] = load("res://assets/backgrounds/%s.svg" % name)
	for name: String in ["panel", "hud_frame", "emblem", "title_logo", "life", "bomb", "power"]:
		textures[name] = load("res://assets/ui/%s.svg" % name)
	background = Node2D.new()
	background.z_index = -3
	add_child(background)
	background.draw.connect(_draw_background)
	actors = Node2D.new()
	actors.z_index = -2
	add_child(actors)


func _process(delta: float) -> void:
	if last_mode != GameState.mode:
		last_mode = GameState.mode
		if GameState.mode == GameState.Mode.PLAYING:
			display_score = 0
			display_lives = GameState.lives
	var weight: float = 1.0 - exp(-delta * 8.0)
	display_score = lerpf(display_score, GameState.score, weight)
	display_hp = lerpf(display_hp, game.boss_hp, weight)
	display_lives = move_toward(display_lives, GameState.lives, delta * 4.0)
	_sync_actors()
	background.queue_redraw()
	queue_redraw()


func _sync_actors() -> void:
	var visible_ids: Array[String] = []
	actors.position = game.shake_offset
	if GameState.mode == GameState.Mode.TITLE:
		actors.position = Vector2.ZERO
	elif GameState.mode == GameState.Mode.PLAYING or not game.effects.is_empty():
		if GameState.lives > 0 and GameState.mode == GameState.Mode.PLAYING:
			var ship: AnimatedSprite2D = _actor(
				"player", "player", game.player_pose, game.player, 0.5, visible_ids
			)
			ship.modulate.a = (
				0.5 if game.invulnerable > 0 and fmod(game.animation_time, 0.16) < 0.08 else 1.0
			)
		for enemy: Dictionary in game.enemies:
			_actor(
				"enemy-%s" % enemy.get("visual_id", 0),
				enemy.kind,
				enemy.get("pose", "move"),
				enemy.position,
				0.58,
				visible_ids
			)
		if game.boss_active and game.boss_hp > 0:
			_actor("boss", "boss", game.boss_pose, game.boss_position, 1.18, visible_ids)
		for effect: Dictionary in game.effects:
			if effect.get("kind", "") == "death":
				var id: String = "death-%s-%s" % [effect.actor, effect.visual_id]
				var size: float = 1.18 if effect.actor == "boss" else 0.58
				var ship: AnimatedSprite2D = _actor(
					id, effect.actor, "death", effect.position, size, visible_ids
				)
				ship.set_frame_and_progress(mini(3, int(effect.age / 0.18)), 0)
	for id: String in ships.keys():
		if not visible_ids.has(id):
			ships[id].queue_free()
			ships.erase(id)


func _actor(
	id: String, kind: String, pose: String, at: Vector2, size: float, visible_ids: Array[String]
) -> AnimatedSprite2D:
	if not ships.has(id):
		var ship: AnimatedSprite2D = Ship.new()
		actors.add_child(ship)
		ship.setup(kind)
		ships[id] = ship
	var sprite: AnimatedSprite2D = ships[id]
	sprite.position = at
	sprite.scale = Vector2.ONE * size
	sprite.set_pose(pose)
	sprite.speed_scale = 0.0 if game.paused else 1.0
	visible_ids.append(id)
	return sprite


func _draw_background() -> void:
	background.draw_rect(Rect2(0, 0, 1280, 720), Color("080f20"))
	var field: Rect2 = Rect2(320, 0, 640, 720)
	if GameState.mode == GameState.Mode.TITLE:
		background.draw_texture_rect(textures.title_keyart, Rect2(582, -105, 698, 931), false)
		field = Rect2(580, 0, 700, 720)
	else:
		background.draw_texture_rect(textures.space, field, false)
	for layer: Dictionary in [
		{"name": "nebula", "speed": 8.0, "alpha": 0.6},
		{"name": "stars_far", "speed": 24.0, "alpha": 0.65},
		{"name": "orbital", "speed": 42.0, "alpha": 0.18},
		{"name": "stars_near", "speed": 80.0, "alpha": 0.8}
	]:
		if GameState.mode == GameState.Mode.TITLE and layer.name in ["nebula", "orbital"]:
			continue
		var scroll: float = fmod(game.animation_time * layer.speed, 720.0)
		for index: int in range(-1, 1):
			background.draw_texture_rect(
				textures[layer.name],
				Rect2(field.position.x, index * 720 + scroll, field.size.x, 720),
				false,
				Color(1, 1, 1, layer.alpha)
			)


func _draw() -> void:
	if GameState.mode == GameState.Mode.TITLE:
		_draw_title()
	else:
		_draw_field()
		_draw_hud()
		if GameState.mode == GameState.Mode.RESULT and game.result_time >= 0.65:
			_draw_result()
		elif game.paused:
			_overlay()
			_label("飛行を一時停止", Vector2(486, 318), 34, INK)
			_label("準備ができたら、もう一度。", Vector2(484, 352), 18, MUTED)


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, 582, 720), Color("0d1b2c"))
	draw_line(Vector2(582, 0), Vector2(582, 720), Color("325063"), 1)
	_ship("emblem", Vector2(109, 85), Vector2(42, 42))
	_label("軌道防衛隊  /  第 07 航路", Vector2(143, 92), 17, MINT)
	_ship("title_logo", Vector2(507, 325), Vector2(78, 37))
	_label("星環防衛線", Vector2(87, 222), 63, INK)
	_label("最後の航路を、守り抜け。", Vector2(92, 275), 24, MUTED)
	draw_line(Vector2(94, 320), Vector2(474, 320), Color("335068"), 1)
	_label("敵編隊を突破し、巨大母艦を撃破する。", Vector2(94, 359), 18, INK)
	_label("約3分の出撃。回避とボムが生還の鍵。", Vector2(94, 393), 18, MUTED)
	_label("最高記録  %07d" % GameState.high_score, Vector2(95, 438), 18, MINT)
	_label("移動  WASD / 矢印 / 左スティック", Vector2(94, 566), 16, MUTED)
	_label("連射  Z / Space / A      ボム  X / B", Vector2(94, 599), 16, MUTED)
	_label("一時停止  Esc / Start     全画面  F11", Vector2(94, 632), 16, MUTED)
	_label("星環防衛隊  •  単機迎撃作戦", Vector2(94, 687), 13, MUTED)
	_label("防衛機  /  蒼翼", Vector2(810, 661), 20, INK)


func _draw_field() -> void:
	draw_set_transform(game.shake_offset)
	for bullet: Dictionary in game.bullets:
		var dimensions: Vector2 = Vector2(10, 30) if bullet.friendly else Vector2(18, 18)
		_ship("bullet_player" if bullet.friendly else "bullet_enemy", bullet.position, dimensions)
	for item: Dictionary in game.items:
		var location: Vector2 = item.position + Vector2(0, sin(item.age * 5) * 4)
		_ship("item_" + item.kind, location, Vector2(34, 34))
	if GameState.lives > 0 and GameState.mode == GameState.Mode.PLAYING:
		if game.invulnerable > 0:
			draw_arc(game.player, 30, 0, TAU, 40, Color(0.5, 1, 0.9, 0.6), 1.5, true)
		draw_circle(game.player, 3, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if game.flash > 0:
		draw_rect(Rect2(320, 0, 640, 720), Color(0.7, 1, 0.9, game.flash * 0.3))
	if GameState.elapsed >= Stage.BOSS_TIME - 3 and GameState.elapsed < Stage.BOSS_TIME:
		draw_rect(Rect2(320, 258, 640, 131), Color(0.23, 0.06, 0.13, 0.94))
		draw_line(Vector2(320, 258), Vector2(960, 258), ORANGE, 2)
		_label("警告  /  大型機接近", Vector2(416, 317), 35, ORANGE)
		_label("ボムを温存し、射線を見極めろ", Vector2(459, 360), 20, INK)
	if game.boss_active and game.boss_hp > 0:
		_label("敵旗艦  /  攻撃段階 %d" % Stage.boss_phase(game.boss_hp), Vector2(350, 30), 16, INK)
		draw_rect(Rect2(350, 44, 580, 7), Color("364558"))
		draw_rect(Rect2(350, 44, 580.0 * display_hp / Stage.BOSS_HP, 7), ORANGE)
		_label("%03d" % int(round(display_hp)), Vector2(891, 72), 14, ORANGE)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 320, 720), Color("0d1b2c"))
	draw_rect(Rect2(960, 0, 320, 720), Color("0d1b2c"))
	draw_texture_rect(textures.hud_frame, Rect2(0, 0, 320, 720), false)
	draw_texture_rect(textures.hud_frame, Rect2(960, 0, 320, 720), false)
	_ship("emblem", Vector2(51, 52), Vector2(37, 37))
	_label("星環防衛線", Vector2(80, 62), 25, INK)
	_label("第 07 軌道域 / 単機迎撃", Vector2(39, 100), 15, MINT)
	_panel(Rect2(28, 133, 264, 124))
	_label("スコア", Vector2(46, 171), 15, MUTED)
	_label("%07d" % int(round(display_score)), Vector2(43, 226), 40, INK)
	_label("最高記録", Vector2(43, 301), 15, MUTED)
	_label("%07d" % GameState.high_score, Vector2(43, 340), 28, MINT)
	_label("残機", Vector2(43, 401), 16, MUTED)
	_label("%d" % int(ceil(display_lives)), Vector2(248, 401), 21, INK)
	for index: int in range(3):
		_ship(
			"life",
			Vector2(66.0 + index * 80, 439),
			Vector2(48, 38),
			Color.WHITE if index < GameState.lives else Color(0.25, 0.32, 0.38, 0.5)
		)
	_ship("bomb", Vector2(60, 503), Vector2(30, 30))
	_label("ボム   %d / 5" % GameState.bombs, Vector2(89, 511), 21, ORANGE)
	_label("ショット強化", Vector2(43, 565), 16, MUTED)
	for index: int in range(3):
		draw_rect(
			Rect2(44 + index * 76, 589, 65, 6), MINT if index < GameState.power else Color("263c51")
		)
	_label("自機中央の光点が当たり判定", Vector2(39, 673), 14, MUTED)
	_label("作戦進行", Vector2(1000, 69), 22, INK)
	_label(
		"%02d:%02d" % [int(GameState.elapsed) / 60, int(GameState.elapsed) % 60],
		Vector2(999, 125),
		38,
		MINT
	)
	var progress: float = minf(1.0, GameState.elapsed / Stage.BOSS_TIME)
	draw_rect(Rect2(1002, 150, 237, 5), Color("263c51"))
	draw_rect(Rect2(1002, 150, 237 * progress, 5), MINT)
	_label("母艦との交戦" if game.boss_active else "敵編隊を突破", Vector2(1000, 194), 20, INK)
	_label("航路を確保せよ", Vector2(1000, 228), 16, MUTED)
	_panel(Rect2(989, 284, 266, 161))
	_label("補給アイテム", Vector2(1006, 315), 16, INK)
	for entry: Array in [["power", "ショットを強化"], ["bomb", "ボムを1つ補充"], ["score", "スコアを獲得"]]:
		var row: int = ["power", "bomb", "score"].find(entry[0])
		_ship("item_" + entry[0], Vector2(1020, 347 + row * 35), Vector2(25, 25))
		_label(entry[1], Vector2(1042, 353 + row * 35), 15, MUTED)
	_label("移動  矢印 / スティック", Vector2(1000, 497), 16, MUTED)
	_label("連射  Z / Space / A", Vector2(1000, 532), 16, MUTED)
	_label("ボム  X / B", Vector2(1000, 567), 16, ORANGE)
	_label("停止  Esc / Start", Vector2(1000, 602), 16, MUTED)
	_label("残機とボムを、次の交戦へ。", Vector2(1000, 673), 14, MUTED)


func _draw_result() -> void:
	_overlay()
	_label(
		"作戦完了" if GameState.cleared else "機体ロスト",
		Vector2(504, 249),
		43,
		MINT if GameState.cleared else ORANGE
	)
	_label("航路を守り抜いた。" if GameState.cleared else "次の出撃で、さらに先へ。", Vector2(488, 294), 22, INK)
	_label("スコア     %07d" % int(round(display_score)), Vector2(490, 363), 25, INK)
	_label("最高記録  %07d" % GameState.high_score, Vector2(490, 410), 25, MINT)


func _overlay() -> void:
	draw_rect(Rect2(320, 0, 640, 720), Color(0.02, 0.05, 0.1, 0.76))
	_panel(Rect2(431, 182, 418, 429))


func _ship(name: String, center: Vector2, dimensions: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(textures[name], Rect2(center - dimensions / 2, dimensions), false, tint)


func _panel(rect: Rect2) -> void:
	draw_texture_rect(textures.panel, rect, false)


func _label(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
