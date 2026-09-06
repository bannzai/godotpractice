extends Node2D
## 状態を参照して描く。描画そのものはゲーム状態を変更しない。

const INK: Color = Color("dcebf1")
const MUTED: Color = Color("90adbd")
const MINT: Color = Color("79f5d4")
const ORANGE: Color = Color("ffb46c")
const Stage = preload("res://scripts/stage_data.gd")

var game: Control
var font: Font
var textures: Dictionary = {}


func _ready() -> void:
	var variation: FontVariation = FontVariation.new()
	variation.base_font = load("res://assets/fonts/NotoSansJP.ttf")
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): 450.0
	}
	variation.variation_embolden = 0.6
	font = variation
	for name: String in [
		"player",
		"enemy_scout",
		"enemy_fighter",
		"enemy_carrier",
		"boss",
		"bullet_player",
		"bullet_enemy",
		"item_power",
		"item_bomb"
	]:
		textures[name] = load("res://assets/sprites/%s.svg" % name)
	textures["space"] = load("res://assets/backgrounds/space.svg")
	textures["panel"] = load("res://assets/ui/panel.svg")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("122537"))
	if GameState.mode == GameState.Mode.TITLE:
		_draw_title()
	else:
		_draw_field()
		_draw_hud()
		if GameState.mode == GameState.Mode.RESULT:
			_draw_result()
		elif game.paused:
			_overlay()
			_label("飛行を一時停止", Vector2(486, 318), 34, INK)
			_label("準備ができたら、もう一度。", Vector2(484, 352), 18, MUTED)


func _draw_title() -> void:
	draw_texture_rect(textures.space, Rect2(615, -70, 665, 887), false)
	draw_rect(Rect2(0, 0, 615, 720), Color("142c40"))
	draw_line(Vector2(615, 0), Vector2(615, 720), Color("31546a"), 1.0)
	for index: int in range(4):
		draw_arc(
			Vector2(965, 363), 120 + index * 61, 0, TAU, 80, Color(0.35, 0.85, 0.86, 0.1), 1.0, true
		)
	_label("第 07 軌道域 / 防衛作戦", Vector2(104, 119), 18, MINT)
	_label("星環防衛線", Vector2(98, 225), 64, INK)
	_label("最後の航路を、守り抜け。", Vector2(105, 275), 25, MUTED)
	draw_line(Vector2(106, 317), Vector2(477, 317), Color("416075"), 1.0)
	_label("敵編隊を突破し、巨大母艦を撃破する。", Vector2(106, 358), 19, INK)
	_label("約3分の出撃。回避とボムが生還の鍵。", Vector2(106, 391), 19, MUTED)
	_label("最高記録  %07d" % GameState.high_score, Vector2(107, 438), 18, MINT)
	_label("移動  WASD / 矢印 / 左スティック", Vector2(106, 566), 17, MUTED)
	_label("連射  Z / Space / A     ボム  X / B", Vector2(106, 599), 17, MUTED)
	_label("一時停止  Esc / Start     全画面  F11", Vector2(106, 632), 17, MUTED)
	_label("残機が尽きても、すぐに再出撃できます。", Vector2(106, 686), 13, MUTED)
	_ship("boss", Vector2(957, 146), Vector2(274, 151), Color(1, 1, 1, 0.7))
	_ship("enemy_fighter", Vector2(805, 298), Vector2(55, 55))
	_ship("enemy_carrier", Vector2(1114, 315), Vector2(68, 68))
	for index: int in range(3):
		var y: float = 355 + fmod(game.animation_time * -100 + index * 65, 150.0)
		draw_line(Vector2(940, y), Vector2(940, y - 20), MINT, 3.0)
		draw_line(Vector2(978, y), Vector2(978, y - 20), MINT, 3.0)
	_ship("player", Vector2(957, 462 + sin(game.animation_time * 2) * 8), Vector2(153, 179))
	_label("単機で挑む、星の向こうへ。", Vector2(803, 650), 20, INK)


func _draw_field() -> void:
	var scroll: float = fmod(game.animation_time * 45.0, 854.0)
	for index: int in range(-1, 2):
		draw_texture_rect(textures.space, Rect2(320, index * 854 + scroll, 640, 854), false)
	for bullet: Dictionary in game.bullets:
		var dimensions: Vector2 = Vector2(9, 24) if bullet.friendly else Vector2(16, 16)
		_ship("bullet_player" if bullet.friendly else "bullet_enemy", bullet.position, dimensions)
	for enemy: Dictionary in game.enemies:
		var names: Dictionary = {
			"scout": "enemy_scout", "aim": "enemy_fighter", "fan": "enemy_carrier"
		}
		_ship(names[enemy.kind], enemy.position, Vector2(52, 52))
	for item: Dictionary in game.items:
		var location: Vector2 = item.position
		draw_circle(location, 21 + sin(item.age * 7) * 2, Color(0.4, 0.9, 0.8, 0.15))
		if item.kind == "score":
			draw_circle(location, 13, ORANGE)
			_label("+", location + Vector2(-7, 7), 21, Color("193248"))
		else:
			_ship("item_" + item.kind, location, Vector2(29, 29))
	if game.boss_active and game.boss_hp > 0:
		_ship("boss", game.boss_position, Vector2(256, 141))
	if GameState.lives > 0:
		var tint: Color = Color.WHITE
		if game.invulnerable > 0:
			tint.a = 0.45 if fmod(game.animation_time, 0.16) < 0.08 else 1.0
			draw_arc(game.player, 30, 0, TAU, 40, Color(0.5, 1, 0.9, 0.6), 1.5, true)
		_ship("player", game.player, Vector2(46, 54), tint)
		draw_circle(game.player, 3, Color.WHITE)
	for effect: Dictionary in game.effects:
		_draw_explosion(effect)
	if game.flash > 0:
		draw_rect(Rect2(320, 0, 640, 720), Color(0.7, 1, 0.9, game.flash * 0.6))
	if GameState.elapsed >= Stage.BOSS_TIME - 3 and GameState.elapsed < Stage.BOSS_TIME:
		draw_rect(Rect2(320, 257, 640, 132), Color(0.35, 0.12, 0.14, 0.92))
		_label("警告  /  大型機接近", Vector2(416, 317), 35, ORANGE)
		_label("ボムを温存し、射線を見極めろ", Vector2(459, 360), 20, INK)
	if game.boss_active and game.boss_hp > 0:
		_label("敵旗艦  /  攻撃段階 %d" % Stage.boss_phase(game.boss_hp), Vector2(350, 35), 17, INK)
		draw_rect(Rect2(350, 49, 580, 7), Color("364558"))
		draw_rect(Rect2(350, 49, 580.0 * game.boss_hp / Stage.BOSS_HP, 7), ORANGE)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 320, 720), Color("142c40"))
	draw_rect(Rect2(960, 0, 320, 720), Color("142c40"))
	draw_line(Vector2(319, 0), Vector2(319, 720), Color("527589"), 2)
	draw_line(Vector2(961, 0), Vector2(961, 720), Color("527589"), 2)
	_label("星環防衛線", Vector2(39, 68), 29, INK)
	_label("第 07 軌道域", Vector2(41, 103), 16, MINT)
	_panel(Rect2(28, 143, 264, 115))
	_label("スコア", Vector2(46, 176), 16, MUTED)
	_label("%07d" % GameState.score, Vector2(43, 226), 40, INK)
	_label("ハイスコア", Vector2(43, 301), 16, MUTED)
	_label("%07d" % GameState.high_score, Vector2(43, 341), 29, MINT)
	_label("残機", Vector2(43, 410), 18, MUTED)
	for index: int in range(GameState.lives):
		_ship("player", Vector2(60.0 + index * 53, 449), Vector2(29, 34))
	_label("ボム   %d / 5" % GameState.bombs, Vector2(43, 514), 21, ORANGE)
	_label("ショット強化", Vector2(43, 568), 17, MUTED)
	for index: int in range(3):
		draw_rect(
			Rect2(44 + index * 76, 589, 65, 8), MINT if index < GameState.power else Color("365168")
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
	draw_rect(Rect2(1002, 150, 237, 5), Color("365168"))
	draw_rect(Rect2(1002, 150, 237 * progress, 5), MINT)
	_label("母艦との交戦" if game.boss_active else "敵編隊を突破", Vector2(1000, 194), 20, INK)
	_label("航路を確保せよ", Vector2(1000, 228), 17, MUTED)
	_panel(Rect2(989, 284, 266, 161))
	_label("補給アイテム", Vector2(1006, 315), 17, INK)
	_ship("item_power", Vector2(1020, 347), Vector2(24, 24))
	_label("ショットを強化", Vector2(1042, 353), 16, MUTED)
	_ship("item_bomb", Vector2(1020, 382), Vector2(24, 24))
	_label("ボムを1つ補充", Vector2(1042, 388), 16, MUTED)
	draw_circle(Vector2(1020, 416), 8, ORANGE)
	_label("スコアを獲得", Vector2(1042, 422), 16, MUTED)
	_label("移動  矢印 / スティック", Vector2(1000, 497), 16, MUTED)
	_label("連射  Z / Space / A", Vector2(1000, 532), 16, MUTED)
	_label("ボム  X / B", Vector2(1000, 567), 16, ORANGE)
	_label("停止  Esc / Start", Vector2(1000, 602), 16, MUTED)
	_label("全画面  F11", Vector2(1000, 637), 16, MUTED)


func _draw_result() -> void:
	_overlay()
	_label(
		"作戦完了" if GameState.cleared else "機体ロスト",
		Vector2(504, 249),
		43,
		MINT if GameState.cleared else ORANGE
	)
	_label("航路を守り抜いた。" if GameState.cleared else "次の出撃で、さらに先へ。", Vector2(488, 294), 22, INK)
	_label("スコア     %07d" % GameState.score, Vector2(490, 363), 25, INK)
	_label("最高記録  %07d" % GameState.high_score, Vector2(490, 410), 25, MINT)


func _overlay() -> void:
	draw_rect(Rect2(320, 0, 640, 720), Color(0.03, 0.08, 0.14, 0.8))
	draw_rect(Rect2(431, 182, 418, 429), Color("183348"))
	draw_rect(Rect2(431, 182, 418, 429), Color("638897"), false, 1)


func _draw_explosion(effect: Dictionary) -> void:
	var ratio: float = effect.age / 0.7
	var radius: float = (125.0 if effect.large else 36.0) * ratio + 6
	var location: Vector2 = effect.position
	draw_circle(location, radius * 0.5, Color(1.0, 0.78, 0.32, (1 - ratio) * 0.6))
	draw_arc(location, radius, 0, TAU, 40, Color(1, 0.65, 0.35, 1 - ratio), 3, true)
	for index: int in range(10):
		var direction: Vector2 = Vector2.from_angle(index * TAU / 10)
		draw_line(
			location + direction * radius * 0.65,
			location + direction * radius * 1.4,
			Color(1, 0.9, 0.65, 1 - ratio),
			2,
			true
		)


func _ship(name: String, center: Vector2, dimensions: Vector2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(textures[name], Rect2(center - dimensions / 2, dimensions), false, tint)


func _panel(rect: Rect2) -> void:
	draw_texture_rect(textures.panel, rect, false, Color(1, 1, 1, 0.65))


func _label(text: String, at: Vector2, size: int, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
