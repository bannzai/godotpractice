extends Control

const Battle = preload("res://scripts/battle.gd")
const Sound = preload("res://scripts/audio.gd")
const INK: Color = Color("101e29")
const PAPER: Color = Color("ecdfba")
const GOLD: Color = Color("d7b66e")
const MUTED: Color = Color("99a7a6")
const RED: Color = Color("dc765e")
const JADE: Color = Color("76c3b2")
var font: Font
var textures: Dictionary = {}
var regions: Array[Dictionary] = []
var hand_index: int = -1
var selected: int = -1
var swap_mode: bool = false
var help_open: bool = false
var menu_open: bool = false
var deck_open: bool = false
var busy: bool = false
var elapsed: float = 0.0
var toast: String = ""
var toast_time: float = 0.0
var speech: String = "夜明けまでに、この道を越えられるか"
var focused_cell: int = 0
var hover: Vector2 = Vector2.ZERO
var effects: Array[Dictionary] = []
var sound: Node

func _ready() -> void:
	font = load("res://assets/font.ttf") as Font
	if font == null:
		font = ThemeDB.fallback_font
	for id: String in ["background", "portrait", "player", "card_back"]:
		textures[id] = load("res://assets/%s.svg" % id)
	for id: String in Battle.CARDS:
		textures[id] = load("res://assets/%s.svg" % id)
	sound = Sound.new()
	add_child(sound)
	sound.play_music()
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

# 描画の時間と短命な演出はフレームごとに進む。
func _process(delta: float) -> void:
	elapsed += delta
	toast_time = maxf(0.0, toast_time - delta)
	hover = get_local_mouse_position()
	for effect: Dictionary in effects:
		effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	queue_redraw()

func _draw() -> void:
	regions.clear()
	draw_rect(Rect2(0, 0, 1440, 900), INK)
	_picture("background", Rect2(0, 0, 1440, 900), Color(1, 1, 1, 0.65))
	if Run.screen == "battle":
		draw_rect(Rect2(35, 234, 256, 332), Color(0.035, 0.075, 0.09, 0.77))
		draw_rect(Rect2(1123, 280, 280, 76), Color(0.035, 0.075, 0.09, 0.77))
	match Run.screen:
		"title":
			_title()
		"map":
			_map()
		"battle":
			_battle()
		"reward":
			_reward()
		"victory", "defeat":
			_ending()
	if Run.screen != "title":
		_button(Rect2(1240, 24, 68, 34), "札帳", "deck", false, 16)
	_button(Rect2(1322, 24, 84, 34), "手ほどき", "help", false, 16)
	if Run.screen != "title":
		_button(Rect2(1315, 850, 91, 30), "メニュー", "menu", false, 15)
	if toast_time > 0.0:
		draw_rect(Rect2(330, 95, 780, 42), Color(0.03, 0.07, 0.1, 0.94))
		_text(toast, Vector2(720, 124), 20, PAPER, true)
	if not Run.save_error.is_empty():
		_text(Run.save_error, Vector2(720, 890), 17, RED, true)
	if menu_open or help_open or deck_open:
		_overlay()

func _text(value: String, at: Vector2, size_px: int = 22, color: Color = PAPER, centered: bool = false) -> void:
	var position_value: Vector2 = at
	if centered:
		position_value.x -= font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x / 2.0
	draw_string(font, position_value, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _paragraph(value: String, at: Vector2, width: float, size_px: int = 20, color: Color = MUTED) -> void:
	var line: String = ""
	var offset: float = 0.0
	for character: String in value:
		if character == "\n" or font.get_string_size(line + character, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > width:
			_text(line, at + Vector2(0, offset), size_px, color)
			offset += size_px * 1.55
			line = "" if character == "\n" else character
		else:
			line += character
	_text(line, at + Vector2(0, offset), size_px, color)

func _picture(id: String, rectangle: Rect2, tint: Color = Color.WHITE) -> void:
	if textures.get(id) != null:
		draw_texture_rect(textures[id], rectangle, false, tint)

func _button(rectangle: Rect2, label: String, action: String, primary: bool = false, size_px: int = 21, enabled: bool = true) -> void:
	var hovered: bool = rectangle.has_point(hover) and not busy
	var fill: Color = Color("a74938") if primary else Color("1c3037")
	if hovered and enabled:
		fill = fill.lightened(0.16)
	if not enabled:
		fill = Color("202a2e")
	draw_style_box(_box(fill, GOLD if enabled else Color("405051"), 1), rectangle)
	_text(label, rectangle.get_center() + Vector2(0, size_px * 0.36), size_px, PAPER if enabled else MUTED.darkened(0.25), true)
	if enabled:
		regions.append({"rect": rectangle, "action": action})

func _box(fill: Color, border: Color, line_width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(line_width)
	box.set_corner_radius_all(3)
	return box

func _title() -> void:
	_picture("portrait", Rect2(880, 130, 470, 580), Color(1, 1, 1, 0.75))
	draw_circle(Vector2(1120, 230), 106, Color(0.86, 0.71, 0.4, 0.12))
	_text("五つの夜を渡る、札と軍略の旅", Vector2(114, 210), 24, GOLD)
	_text("宵の陣", Vector2(102, 375), 140)
	draw_line(Vector2(115, 410), Vector2(670, 410), GOLD, 1)
	_paragraph("一枚を伏せ、敵の心を読む。\n王を守り、十の命を奪い合う。\n将軍の待つ険しい道には、まだ見ぬ札が眠る。", Vector2(117, 463), 650, 24)
	_button(Rect2(118, 625, 315, 66), "遠征をはじめる  →", "new", true, 25)
	if not Run.saved.is_empty():
		_button(Rect2(118, 712, 315, 52), "街道からつづける", "resume", false, 23)
	_text("札の配置 × 将棋の進軍 × 分岐する遠征", Vector2(117, 834), 18, MUTED)
	_text("マウスで操作  /  H 手ほどき  /  M 音", Vector2(1030, 842), 16, MUTED, true)

func _map() -> void:
	_text("夜を越える街道", Vector2(72, 92), 42)
	_text("第 %s 夜  /  全五夜" % _numeral(Run.stage + 1), Vector2(72, 139), 23, GOLD)
	_text("王の命  %d / 10     軍勢  %d 枚" % [Run.health, Run.deck.size()], Vector2(72, 181), 20, MUTED)
	var points: Array[Vector2] = [Vector2(175, 653), Vector2(423, 480), Vector2(697, 572), Vector2(955, 369), Vector2(1230, 240)]
	for i: int in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color("58645c"), 3, true)
	for i: int in range(points.size()):
		var at: Vector2 = points[i]
		draw_circle(at, 43, Color("142a31"))
		draw_arc(at, 43, 0, TAU, 64, JADE if i < Run.stage else GOLD, 2, true)
		_text("済" if i < Run.stage else _numeral(i + 1), at + Vector2(0, 12), 34, JADE if i < Run.stage else PAPER, true)
		_text(Run.GENERALS[i], at + Vector2(0, 77), 21, MUTED, true)
		if i == Run.stage:
			draw_arc(at, 53 + sin(elapsed * 2) * 3, 0, TAU, 64, GOLD, 1, true)
	_text("進む道を選ぶ", Vector2(780, 681), 26, GOLD, true)
	if Run.stage == 4:
		_button(Rect2(580, 718, 500, 65), "天守へ  ─  最後の決戦", "elite", true, 25)
	else:
		_button(Rect2(456, 718, 375, 65), "街道  ─  三列の陣", "normal", false, 24)
		_button(Rect2(857, 718, 375, 65), "将軍の道  ─  五列の陣", "elite", true, 24)
		_text("通常の札を獲得", Vector2(645, 818), 20, MUTED, true)
		_text("強敵に勝てば希少札を獲得", Vector2(1045, 818), 20, GOLD, true)
	_text("勝利で命を２回復  ·  道の選択時点から再開可能", Vector2(72, 860), 17, MUTED)

func _numeral(number: int) -> String:
	return ["零", "一", "二", "三", "四", "五"][clampi(number, 0, 5)]

func _cell_rect(index: int) -> Rect2:
	var width: int = Run.battle.width
	var size_value: Vector2 = Vector2(140, 170)
	var start: float = 720.0 - width * 76.0
	return Rect2(Vector2(start + (index % width) * 152, 244 + (index / width) * 184), size_value)

func _battle() -> void:
	var battle: RefCounted = Run.battle
	_text("宵 の 陣", Vector2(48, 66), 34, GOLD)
	_text("第%s夜　%s" % [_numeral(Run.stage + 1), "将軍の道" if Run.elite else "街道"], Vector2(48, 104), 18, MUTED)
	_picture("portrait", Rect2(1186, 70 + sin(elapsed * 1.5) * 2, 156, 175))
	_text(Run.GENERALS[Run.stage], Vector2(1264, 264), 23, GOLD, true)
	_paragraph("「%s」" % speech, Vector2(1132, 304), 260, 21, PAPER)
	var king_enabled: bool = selected >= 0 and battle.legal_targets(selected).has(-1) and not busy
	_button(Rect2(604, 138, 232, 71), "敵 王   %d / 10" % battle.hp[1], "king", king_enabled, 28, king_enabled)
	_text("同じ列を開けば、王へ届く", Vector2(720, 230), 17, MUTED, true)
	var targets: Array[int] = []
	if selected >= 0:
		targets = battle.legal_targets(selected)
	for index: int in range(battle.board.size()):
		var rect: Rect2 = _cell_rect(index)
		var unit: Dictionary = battle.board[index]
		var highlight: Color = Color("5a6258")
		if targets.has(index):
			highlight = RED
		elif hand_index >= 0 and index >= battle.width and unit.is_empty():
			highlight = JADE
		elif index == selected:
			highlight = GOLD
		draw_style_box(_box(Color(0.05, 0.11, 0.14, 0.85), highlight, 2), rect)
		if unit.is_empty():
			draw_line(rect.get_center() - Vector2(12, 0), rect.get_center() + Vector2(12, 0), Color("465754"), 1)
			draw_line(rect.get_center() - Vector2(0, 12), rect.get_center() + Vector2(0, 12), Color("465754"), 1)
			_text("自陣" if index >= battle.width else "敵陣", rect.position + Vector2(14, 26), 14, MUTED.darkened(0.3))
		else:
			_unit(unit, rect, index == selected)
		if targets.has(index):
			_text("攻撃", rect.position + Vector2(70, -8), 18, RED, true)
		if index == focused_cell:
			draw_line(rect.end + Vector2(-30, 6), rect.end + Vector2(0, 6), GOLD, 2)
		regions.append({"rect": rect, "action": "cell:%d" % index})
	_draw_selection()
	_picture("player", Rect2(66, 584, 123, 144))
	_text("あなたの王", Vector2(132, 754), 24, PAPER, true)
	_text("%d / 10" % battle.hp[0], Vector2(132, 800), 32, JADE, true)
	for i: int in range(10):
		draw_circle(Vector2(59 + i * 16, 827), 5, JADE if i < battle.hp[0] else Color("354347"))
	_text("敵の手札 %d  /  山札 %d" % [battle.hands[1].size(), battle.decks[1].size()], Vector2(355, 173), 16, MUTED)
	_text("手札から自陣へ", Vector2(288, 638), 22, GOLD)
	_text("山札 %d　捨て場 %d" % [battle.decks[0].size(), battle.discards[0].size()], Vector2(927, 638), 17, MUTED)
	var count: int = battle.hands[0].size()
	var spacing: float = minf(138.0, 814.0 / maxi(count, 1))
	for i: int in range(count):
		var rect: Rect2 = Rect2(286 + i * spacing, 666 - (12 if hand_index == i else 0), 125, 180)
		_card(battle.hands[0][i], rect, hand_index == i)
		_text(str(i + 1), rect.position + Vector2(10, 174), 13, INK)
		regions.append({"rect": rect, "action": "hand:%d" % i})
	_text("第 %d 手" % battle.round_number, Vector2(1254, 409), 19, MUTED, true)
	_text("敵の思案中" if busy else ("準 備" if battle.phase == "prepare" else "攻 め"), Vector2(1254, 454), 36, GOLD, true)
	_text("軍令  %d / 3" % battle.energy, Vector2(1254, 495), 23, JADE, true)
	_button(Rect2(1142, 527, 227, 68), "攻めに進む  →" if battle.phase == "prepare" else "手番を終える  →", "phase", true, 22, not busy)
	_paragraph("札を置く → 登場させる → 攻めへ" if battle.phase == "prepare" else "自分の表札を選び、朱色の敵か王を攻撃", Vector2(1150, 640), 227, 19, MUTED)
	_text(battle.log_text, Vector2(720, 881), 18, PAPER, true)
	for effect: Dictionary in effects:
		var alpha: float = clampf(effect.life / 0.65, 0.0, 1.0)
		if effect.has("id"):
			var position_value: Vector2 = effect.start.lerp(effect.at, sin((1.0 - alpha) * PI) * 0.74)
			_picture(effect.id, Rect2(position_value - Vector2(45, 55), Vector2(90, 110)), Color(1, 1, 1, alpha))
		draw_arc(effect.at, (1.0 - alpha) * 75.0 + 12, 0, TAU, 48, Color(RED, alpha), 5, true)
		draw_line(effect.at + Vector2(-35, 25) * (1 - alpha), effect.at + Vector2(40, -35) * (1 - alpha), Color(PAPER, alpha), 4, true)
		if effect.has("damage"):
			_text("−%d" % effect.damage, effect.at + Vector2(0, -35 - (1 - alpha) * 45), 42, Color(RED, alpha), true)

func _card(id: String, rectangle: Rect2, active: bool = false) -> void:
	var card: Dictionary = Battle.CARDS[id]
	draw_style_box(_box(PAPER if not card.rare else Color("e0c88f"), GOLD if active else Color("948266"), 3 if active else 1), rectangle)
	_picture(id, Rect2(rectangle.position + Vector2(4, 21), Vector2(rectangle.size.x - 8, rectangle.size.y - 57)))
	_text(card.name, rectangle.position + Vector2(rectangle.size.x / 2, 23), 19, INK, true)
	draw_circle(rectangle.position + Vector2(20, rectangle.size.y - 27), 15, INK)
	_text(str(card.power), rectangle.position + Vector2(20, rectangle.size.y - 21), 21, PAPER, true)
	_text("令 %d" % card.cost, rectangle.position + Vector2(rectangle.size.x - 43, rectangle.size.y - 20), 15, INK, true)

func _unit(unit: Dictionary, rectangle: Rect2, active: bool) -> void:
	var content: Rect2 = rectangle.grow(-5)
	if not unit.face and unit.side == 1:
		_picture("card_back", content)
		_text("潜伏", rectangle.get_center() + Vector2(0, 8), 25, PAPER, true)
	else:
		_card(unit.id, content, active)
		if not unit.face:
			draw_rect(Rect2(content.position + Vector2(0, 56), Vector2(content.size.x, 33)), Color(0.05, 0.14, 0.18, 0.92))
			_text("伏せ札", content.position + Vector2(content.size.x / 2, 80), 21, JADE, true)
	var marker: Color = JADE if unit.side == 0 else RED
	draw_rect(Rect2(rectangle.position + Vector2(0, rectangle.size.y - 4), Vector2(rectangle.size.x, 4)), marker)
	if unit.moved or unit.attacked:
		draw_rect(rectangle.grow(-4), Color(0.02, 0.07, 0.08, 0.36))
		_text("行動済", rectangle.get_center() + Vector2(0, 20), 22, PAPER, true)

func _draw_selection() -> void:
	var id: String = ""
	if hand_index >= 0 and hand_index < Run.battle.hands[0].size():
		id = Run.battle.hands[0][hand_index]
	elif selected >= 0 and not Run.battle.board[selected].is_empty():
		var unit: Dictionary = Run.battle.board[selected]
		if unit.side == 0 or unit.face:
			id = unit.id
	if id.is_empty():
		_text("次の一手", Vector2(57, 277), 29, GOLD)
		_paragraph("手札を選び、光る自陣に伏せる。\n\n盤上の伏せ札を選び「登場」で表にする。", Vector2(57, 324), 225, 22, PAPER)
		return
	var card: Dictionary = Battle.CARDS[id]
	_text(card.name, Vector2(57, 277), 34, GOLD)
	_text("攻 %d　軍令 %d" % [card.power, card.cost], Vector2(57, 317), 21, PAPER)
	_paragraph(card.text, Vector2(57, 356), 225, 21, MUTED)
	if selected >= 0 and Run.battle.board[selected].side == 0 and Run.battle.phase == "prepare":
		if not Run.battle.board[selected].face:
			_button(Rect2(57, 443, 214, 49), "登場させる  R", "reveal", true, 21, not busy)
		_button(Rect2(57, 507, 214, 45), "交換相手を選ぶ" if swap_mode else "配置換え  X", "swap", false, 19, not busy and not Run.battle.swapped)
	elif selected >= 0:
		_paragraph("移動した札は、この手番に攻撃できない" if Run.battle.board[selected].moved else "攻撃できる相手が朱色に光る", Vector2(57, 465), 220, 19, MUTED)

func _reward() -> void:
	_text("その一枚が、次の夜を変える", Vector2(720, 147), 43, PAPER, true)
	_text("将軍を破った。希少な札を一枚、軍勢に加える" if Run.elite else "戦利品から一枚、軍勢に加える", Vector2(720, 211), 24, GOLD, true)
	_text("王の命を２回復   現在 %d / 10" % Run.health, Vector2(720, 253), 21, JADE, true)
	for i: int in range(Run.rewards.size()):
		var rectangle: Rect2 = Rect2(330 + i * 280, 313, 220, 295)
		_card(Run.rewards[i], rectangle)
		_paragraph(Battle.CARDS[Run.rewards[i]].text, rectangle.position + Vector2(0, 335), 225, 22, PAPER)
		_button(Rect2(rectangle.position.x, 738, 220, 60), "この札を迎える", "reward:%d" % i, true, 22)

func _ending() -> void:
	var won: bool = Run.screen == "victory"
	_picture("player" if won else "portrait", Rect2(920, 183, 350, 425), Color(1, 1, 1, 0.72))
	_text("夜明けの陣" if won else "灯が消える", Vector2(129, 285), 91, PAPER)
	_paragraph("最後の王は倒れ、街道に朝が訪れた。\nあなたの軍略が、五つの夜を越えた。" if won else "王は討たれ、遠征はここで終わった。\n次の夜には、違う一手を。", Vector2(138, 380), 690, 28, GOLD)
	_text("勝利 %d 戦  ·  軍勢 %d 枚" % [Run.victories, Run.deck.size()], Vector2(140, 515), 25, MUTED)
	_button(Rect2(140, 619, 340, 70), "もう一度、街道へ", "new", true, 26)
	_button(Rect2(140, 718, 340, 52), "表紙へ戻る", "title", false, 23)

func _overlay() -> void:
	regions.clear()
	draw_rect(Rect2(0, 0, 1440, 900), Color(0.01, 0.03, 0.05, 0.91))
	if help_open:
		_text("軍略の手ほどき", Vector2(190, 133), 44, GOLD)
		var guide: Array[String] = ["一　手札を選び、自陣の空いたマスに伏せる。配置には軍令を使う", "二　盤上の自分の伏せ札を選び「登場」で表向きにする", "三　「攻めに進む」を押し、自分の表札 → 敵札の順に選んで攻撃", "四　攻撃力が高い札が勝ち、相手のマスへ前進。同じなら両方を失う", "五　同じ列の敵がいなければ敵王へ直接攻撃。命１０を削れば勝利"]
		for i: int in range(guide.size()):
			_text(guide[i], Vector2(190, 226 + i * 72), 25, PAPER)
		_paragraph("準備中は上下左右の空きマスへ移動できる。ただし移動した札はその手番に攻撃できない。配置換えは隣接する自分の札を一組だけ交換する。敵の伏せ札は攻撃するまで正体が見えない。", Vector2(190, 615), 1030, 22, MUTED)
		_text("数字：手札  /  矢印＋Enter：盤  /  K：王を攻撃  /  R：登場  /  X：交換  /  Space：次へ", Vector2(190, 748), 19, GOLD)
	elif deck_open:
		_text("軍勢の札帳", Vector2(130, 115), 39, GOLD)
		var counts: Dictionary = {}
		for id: String in Run.deck:
			counts[id] = int(counts.get(id, 0)) + 1
		var index: int = 0
		for id: String in counts:
			var column: int = index % 4
			var row: int = index / 4
			var at: Vector2 = Vector2(132 + column * 307, 181 + row * 187)
			_picture(id, Rect2(at, Vector2(81, 96)))
			_text("%s × %d" % [Battle.CARDS[id].name, counts[id]], at + Vector2(86, 27), 22, PAPER)
			_paragraph(Battle.CARDS[id].text, at + Vector2(86, 63), 203, 17, MUTED)
			index += 1
	else:
		_text("ひとときの休息", Vector2(720, 284), 47, PAPER, true)
		_text("遠征は街道の選択時点から再開できます", Vector2(720, 353), 22, MUTED, true)
		_button(Rect2(510, 405, 420, 61), "音を消す" if sound.enabled else "音を出す", "audio", false, 25)
		_button(Rect2(510, 494, 420, 61), "表紙へ戻る", "title", false, 25)
	_button(Rect2(566, 804, 308, 54), "閉じる  Esc", "close", true, 23)

# 入力イベントを一度だけ戦闘のコマンドへ配送する。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for i: int in range(regions.size() - 1, -1, -1):
			if regions[i].rect.has_point(event.position):
				activate(regions[i].action)
				accept_event()
				return

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if help_open or deck_open or menu_open:
			activate("close")
		else:
			activate("menu")
	elif event.keycode == KEY_H:
		activate("help")
	elif event.keycode == KEY_M:
		activate("audio")
	elif not (help_open or deck_open or menu_open) and Run.screen == "battle" and not busy:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			activate("hand:%d" % (event.keycode - KEY_1))
		elif event.keycode == KEY_SPACE:
			activate("phase")
		elif event.keycode == KEY_R:
			activate("reveal")
		elif event.keycode == KEY_X:
			activate("swap")
		elif event.keycode == KEY_ENTER:
			activate("cell:%d" % focused_cell)
		elif event.keycode == KEY_K:
			activate("king")
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var offset: int = -1 if event.keycode == KEY_LEFT else 1
			if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
				offset = Run.battle.width
			focused_cell = posmod(focused_cell + offset, Run.battle.board.size())

func activate(action: String) -> void:
	if action == "help":
		help_open = true
		return
	if action == "close":
		help_open = false
		menu_open = false
		deck_open = false
		return
	if action == "menu":
		menu_open = true
		return
	if action == "audio":
		sound.toggle()
		return
	if busy:
		return
	match action:
		"new":
			Run.new_run()
			_reset_selection()
		"resume":
			Run.resume_run()
		"title":
			Run.screen = "title"
			activate("close")
		"normal", "elite":
			Run.choose_route(action == "elite")
			speech = "少ない札ほど、一手が重い" if not Run.elite else "広い陣だ。守るべき列を見誤るな"
			_reset_selection()
		"deck":
			deck_open = true
		"phase":
			if Run.screen != "battle":
				return
			if Run.battle.phase == "prepare":
				Run.battle.begin_attack()
				_reset_selection()
			else:
				_enemy_turn()
		"reveal":
			if selected >= 0 and Run.battle.reveal(selected):
				sound.cue("place")
			else:
				_notice("準備中に、自分の伏せ札を選んでください")
		"swap":
			swap_mode = not swap_mode
		"king":
			if selected >= 0:
				_attack(-1)
	if action.begins_with("hand:") and Run.screen == "battle":
		var index: int = int(action.get_slice(":", 1))
		if index < Run.battle.hands[0].size():
			hand_index = index
			selected = -1
			swap_mode = false
	elif action.begins_with("cell:") and Run.screen == "battle":
		_click_cell(int(action.get_slice(":", 1)))
	elif action.begins_with("reward:"):
		Run.take_reward(int(action.get_slice(":", 1)))

func _click_cell(index: int) -> void:
	var battle: RefCounted = Run.battle
	focused_cell = index
	if hand_index >= 0:
		if battle.deploy(hand_index, index):
			hand_index = -1
			selected = index
			sound.cue("place")
		else:
			_notice("準備中に、軍令が足りる札を自陣の空きマスへ")
		return
	if selected >= 0 and selected != index:
		if battle.phase == "attack" and battle.legal_targets(selected).has(index):
			_attack(index)
			return
		if battle.phase == "prepare":
			var succeeded: bool = battle.swap_units(selected, index) if swap_mode else battle.move_unit(selected, index)
			if succeeded:
				selected = index
				swap_mode = false
				sound.cue("place")
				return
	if not battle.board[index].is_empty():
		selected = index
		swap_mode = false
	else:
		_reset_selection()

func _attack(target: int) -> void:
	var from: int = selected
	if Run.battle.attack(selected, target):
		sound.cue("attack")
		_attack_effect(from, target, Run.battle.events.back())
		speech = "王に刃が届いたか。まだ夜は終わらぬ" if target == -1 else "その札を切るか……面白い"
		_reset_selection()
		_finish_if_needed()
	else:
		_notice("攻めの番に、動いていない表札から届く相手を選んでください")

func _enemy_turn() -> void:
	if not Run.battle.end_turn():
		return
	busy = true
	_reset_selection()
	speech = "さて、次は私の一手だ"
	await _beat()
	var battle: RefCounted = Run.battle
	while battle.turn == 1 and battle.winner == -1:
		var event_count: int = battle.events.size()
		if not battle.enemy_step():
			break
		if battle.events.size() > event_count:
			var event: Dictionary = battle.events.back()
			if event.kind in ["king", "clash"]:
				_attack_effect(event.from, event.to, event)
				sound.cue("attack")
			else:
				sound.cue("place")
		await _beat()
	speech = "守るだけでは、夜は明けぬぞ" if Run.battle.hp[0] <= 5 else "空いた列に気をつけることだ"
	await get_tree().create_timer(0.4).timeout
	busy = false
	_finish_if_needed()

func _beat() -> void:
	await get_tree().create_timer(0.4).timeout
	while help_open or menu_open or deck_open:
		await get_tree().process_frame

func _attack_effect(from: int, target: int, event: Dictionary) -> void:
	var at: Vector2 = _cell_rect(target).get_center() if target >= 0 else (Vector2(720, 174) if event.side == 0 else Vector2(132, 785))
	var effect: Dictionary = {"at": at, "start": _cell_rect(from).get_center(), "life": 0.65}
	if not event.attacker.is_empty():
		effect.id = event.attacker.id
		if target == -1:
			effect.damage = Battle.CARDS[event.attacker.id].power
	if not event.defender.is_empty() and not event.defender.face:
		_notice("伏せ札は「%s」だった" % Battle.CARDS[event.defender.id].name)
	effects.append(effect)

func _finish_if_needed() -> void:
	if Run.battle.winner == -1:
		return
	busy = true
	sound.cue("victory" if Run.battle.winner == 0 else "defeat")
	await get_tree().create_timer(0.8).timeout
	Run.finish_battle()
	busy = false

func _reset_selection() -> void:
	hand_index = -1
	selected = -1
	swap_mode = false

func _notice(message: String) -> void:
	toast = message
	toast_time = 3.5
