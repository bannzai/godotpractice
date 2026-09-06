extends Control
## 盤の選択・入力をSessionの合法手へ渡す。ゲームの数値を所有しない。

signal render_requested

const UI = preload("res://scripts/spirit_ui.gd")
const Catalog = preload("res://scripts/card_catalog.gd")
const Actor = preload("res://scripts/spirit_actor.gd")
const CardView = preload("res://scripts/spirit_card.gd")

var session: Node
var effects: Control
var sound: Node
var selected_hand: int = -1
var selected_cell: int = -1
var deploy_hidden: bool = false
var busy: bool = false
var cell_views: Dictionary = {}
var hand_views: Array[Button] = []
var message: Label
var detail: Label
var opponent: Control
var speech: Label
var confirmed_abandon: bool = false
var board_width: int = 3
var enemy_id: String = "ghost"


func setup(state: Node, effect_layer: Control, audio: Node) -> void:
	session = state
	effects = effect_layer
	sound = audio
	board_width = session.board.width
	enemy_id = session.board.enemy_id
	size = Vector2(1280, 660)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	redraw()
	if session.board.turn == 1:
		_resume_enemy.call_deferred()


func redraw() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	cell_views.clear()
	hand_views.clear()
	var board: RefCounted = session.board
	var enemy: Dictionary = Catalog.enemy(board.enemy_id)
	UI.panel(self, Rect2(32, 104, 214, 528), Color(0.055, 0.11, 0.13, 0.92))
	UI.label(self, str(enemy.name), Rect2(42, 119, 195, 40), 25, UI.GOLD, true)
	opponent = Actor.new()
	add_child(opponent)
	opponent.position = Vector2(42, 164)
	opponent.setup(str(enemy.art), Vector2(195, 247))
	speech = UI.label(self, str(enemy.lines.start), Rect2(48, 421, 181, 108), 20, UI.MUTED)
	UI.label(
		self,
		(
			"敵の手札 %d\n山札 %d　捨て場 %d"
			% [board.hands[1].size(), board.draw_piles[1].size(), board.discards[1].size()]
		),
		Rect2(49, 577, 184, 51),
		17,
		UI.MUTED
	)
	_draw_board()
	_draw_hand()
	_draw_actions()


func _draw_board() -> void:
	var board: RefCounted = session.board
	var width: int = board.width
	var grid: Rect2 = board_rect()
	UI.panel(
		self,
		Rect2(grid.position - Vector2(13, 9), grid.size + Vector2(26, 18)),
		Color(0.09, 0.17, 0.19, 0.95)
	)
	UI.label(self, "上二段：相手の陣", Rect2(270, 91, 226, 34), 18, UI.MUTED)
	var enemy_king: Button = UI.button(
		self,
		"敵の王   %d / %d" % [board.kings[1], board.max_kings[1]],
		Rect2(505, 94, 250, 43),
		_select_cell.bind(-2),
		"enemy-king"
	)
	enemy_king.add_theme_color_override("font_color", UI.RED)
	cell_views[-2] = enemy_king
	for pos: int in range(width * 4):
		var rect: Rect2 = cell_rect(pos)
		var unit: Dictionary = board.at(pos)
		var tile: Button
		if unit.is_empty():
			tile = UI.button(self, "", rect, _select_cell.bind(pos), "cell-%d" % pos)
			UI.label(
				tile,
				"＋" if board.can_deploy(pos) and selected_hand >= 0 else "·",
				Rect2(0, 21, rect.size.x, 49),
				30,
				UI.MUTED,
				true
			)
		else:
			tile = CardView.new()
			tile.position = rect.position
			tile.size = rect.size
			tile.card_id = str(unit.card)
			tile.face_down = not bool(unit.face)
			tile.compact = true
			tile.power = board.effective_atk(pos)
			tile.exhausted = bool(unit.moved) or bool(unit.attacked)
			tile.selected = selected_cell == pos
			tile.set_meta("tag", "cell-%d" % pos)
			add_child(tile)
			tile.pressed.connect(_select_cell.bind(pos))
			tile.mouse_entered.connect(_inspect.bind(pos))
			tile.focus_entered.connect(_inspect.bind(pos))
			if int(unit.side) == 1:
				UI.line(tile, Vector2(1, 1), Vector2(rect.size.x - 1, 1), UI.RED)
			else:
				UI.line(tile, Vector2(1, 1), Vector2(rect.size.x - 1, 1), UI.JADE)
		tile.set_drag_forwarding(_no_drag, _can_drop.bind(pos), _drop_card.bind(pos))
		cell_views[pos] = tile
		if selected_cell >= 0 and pos in board.legal_targets(selected_cell):
			tile.modulate = Color(1.3, 1.12, 0.8)
	UI.line(
		self,
		Vector2(grid.position.x - 10, grid.position.y + 2 * 94 - 4),
		Vector2(grid.end.x + 10, grid.position.y + 2 * 94 - 4),
		UI.GOLD
	)
	var own_king: Button = UI.button(
		self,
		"あなたの王   %d / %d" % [board.kings[0], board.max_kings[0]],
		Rect2(44, 526, 190, 40),
		_inspect.bind(-1),
		"own-king"
	)
	own_king.add_theme_color_override("font_color", UI.JADE)
	cell_views[-1] = own_king
	UI.label(self, "下二段：あなたの陣", Rect2(775, 91, 210, 34), 18, UI.MUTED)


func _draw_hand() -> void:
	var board: RefCounted = session.board
	var hand: Array = board.hands[0]
	var gap: float = minf(109.0, 682.0 / maxf(1.0, hand.size()))
	var card_width: float = minf(102, gap - 5)
	for index: int in hand.size():
		var card_id: String = str(hand[index])
		var card: Button = CardView.new()
		card.position = Vector2(273 + index * gap, 534)
		card.size = Vector2(card_width, 119)
		card.card_id = card_id
		card.selected = selected_hand == index
		card.power = int(Catalog.card(card_id).atk) + (1 if session.run.darkness >= 50 else 0)
		card.set_meta("tag", "hand-%d" % index)
		add_child(card)
		card.pressed.connect(_select_hand.bind(index))
		card.mouse_entered.connect(_inspect_hand.bind(index))
		card.focus_entered.connect(_inspect_hand.bind(index))
		card.set_drag_forwarding(_get_drag.bind(index), _reject_drag, _ignore_drag)
		hand_views.append(card)


func _draw_actions() -> void:
	var board: RefCounted = session.board
	UI.panel(self, Rect2(986, 104, 259, 535), Color(0.055, 0.11, 0.13, 0.96))
	UI.label(
		self, "準備の手" if board.phase == "prepare" else "戦闘の手", Rect2(1004, 119, 220, 40), 29, UI.GOLD
	)
	message = UI.label(self, session.last_message, Rect2(1005, 172, 220, 69), 18, UI.MUTED)
	detail = UI.label(self, "札を選ぶと、効果を読めます。", Rect2(1005, 244, 220, 105), 19)
	var hidden_button: Button = UI.button(
		self,
		"裏向きで置く：入" if deploy_hidden else "裏向きで置く：切",
		Rect2(1005, 352, 222, 40),
		_toggle_hidden,
		"hidden"
	)
	hidden_button.disabled = board.phase != "prepare"
	var flip_button: Button = UI.button(
		self, "登場 / 潜伏  [R / RB]", Rect2(1005, 402, 222, 40), _flip_selected, "flip"
	)
	flip_button.disabled = board.phase != "prepare"
	var battle_button: Button = UI.button(
		self, "戦闘へ  [B / X]", Rect2(1005, 452, 222, 43), _battle_phase, "battle"
	)
	battle_button.disabled = board.phase != "prepare"
	UI.button(self, "手を終える  [E / Y]", Rect2(1005, 505, 222, 47), _end_turn, "end-turn")
	UI.label(
		self,
		"山札 %d　捨て場 %d\n配置は各手1枚 / ドローは自動" % [board.draw_piles[0].size(), board.discards[0].size()],
		Rect2(1006, 565, 221, 54),
		16,
		UI.MUTED
	)
	UI.button(
		self,
		"本当に旅を終える" if confirmed_abandon else "旅を断念する",
		Rect2(41, 632, 197, 27),
		_abandon,
		"abandon"
	)


func board_rect() -> Rect2:
	var width: int = board_width
	return Rect2(630 - width * 63, 147, width * 126 - 8, 368)


func cell_rect(pos: int) -> Rect2:
	var width: int = board_width
	return Rect2(
		board_rect().position + Vector2(pos % width * 126, pos / width * 94), Vector2(118, 86)
	)


func _select_hand(index: int) -> void:
	if busy or session.board.phase != "prepare":
		return
	selected_hand = index
	selected_cell = -1
	redraw()
	hand_views[index].grab_focus()
	_inspect_hand(index)


func _select_cell(pos: int) -> void:
	if busy:
		return
	var board: RefCounted = session.board
	if selected_hand >= 0:
		_execute("deploy", selected_hand, pos, not deploy_hidden)
		return
	var target: Dictionary = board.at(pos)
	if selected_cell >= 0 and selected_cell != pos:
		if board.phase == "battle":
			_execute("attack", selected_cell, pos)
		else:
			_execute("move", selected_cell, pos)
		return
	if not target.is_empty() and int(target.side) == 0:
		selected_cell = pos
		selected_hand = -1
		redraw()
		cell_views[pos].grab_focus()
		_inspect(pos)
	else:
		_inspect(pos)


func cancel_selection() -> void:
	if busy:
		return
	selected_cell = -1
	selected_hand = -1
	confirmed_abandon = false
	redraw()
	if not hand_views.is_empty():
		hand_views[0].grab_focus()


func _toggle_hidden() -> void:
	if busy:
		return
	deploy_hidden = not deploy_hidden
	redraw()


func _flip_selected() -> void:
	if selected_cell >= 0:
		_execute("flip", selected_cell)
	elif not busy:
		message.text = "自分の霊を選んでから、登場・潜伏を選びます。"


func _battle_phase() -> void:
	_execute("battle")


# Sessionの一手とそのアニメーションを不可分に扱うため、完了まで次の入力を受けない。
func _execute(kind: String, from: int = -1, to: int = -1, face: bool = true) -> void:
	if busy:
		return
	busy = true
	var result: Dictionary = session.board_action(kind, from, to, face)
	if not bool(result.ok):
		message.text = str(result.text)
		busy = false
		return
	await _animate(result)
	busy = false
	render_requested.emit()


func _end_turn() -> void:
	if busy:
		return
	busy = true
	var result: Dictionary = session.begin_enemy_turn()
	await _animate(result)
	await _play_enemy()


func _resume_enemy() -> void:
	if busy:
		return
	busy = true
	await _play_enemy()


func _play_enemy() -> void:
	var steps: int = 0
	while session.screen == "battle" and session.board.turn == 1 and steps < 64:
		redraw()
		var result: Dictionary = session.step_enemy_turn()
		if not bool(result.get("ok", false)):
			break
		await _animate(result)
		steps += 1
	busy = false
	render_requested.emit()


func _animate(result: Dictionary) -> void:
	var kind: String = str(result.type)
	message.text = str(result.get("text", ""))
	if kind in ["turn", "phase"]:
		await get_tree().create_timer(0.06).timeout
		return
	var destination: int = int(result.get("to", -2))
	var point: Vector2 = _point(destination)
	var card_id: String = str(result.get("card", ""))
	var actor: Control
	if not card_id.is_empty():
		actor = Actor.new()
		effects.add_child(actor)
		actor.setup(card_id, Vector2(118, 130))
		actor.position = _point(int(result.get("from", destination))) - Vector2(59, 65)
		actor.play_pose("move" if kind == "move" else "action")
		var travel: Tween = actor.create_tween()
		travel.tween_property(actor, "position", point - Vector2(59, 65), 0.19)
		sound.play_sfx("attack" if kind in ["attack", "king_hit"] else "card")
	await get_tree().create_timer(0.19).timeout
	if kind in ["attack", "king_hit"]:
		speech.text = str(
			Catalog.enemy(enemy_id).lines["hurt" if int(result.get("side", 0)) == 0 else "attack"]
		)
		opponent.play_pose("hit" if int(result.get("side", 0)) == 0 else "action")
		if kind == "king_hit" and destination == -2 and session.screen != "battle":
			speech.text = str(Catalog.enemy(enemy_id).lines.defeat)
			opponent.play_pose("vanish")
		if actor:
			actor.sprite.speed_scale = 0.0
		await get_tree().create_timer(0.065).timeout
		if actor:
			actor.sprite.speed_scale = 1.0
		if kind == "king_hit":
			effects.king_hit(get_parent(), point, int(result.damage))
		else:
			effects.burst(point, UI.GOLD, str(result.get("damage", "")))
		for removed: Dictionary in result.get("removed", []):
			var ghost: Control = Actor.new()
			effects.add_child(ghost)
			ghost.setup(str(removed.card), Vector2(118, 130))
			ghost.position = _point(int(removed.pos)) - Vector2(59, 65)
			ghost.play_pose("vanish")
			get_tree().create_timer(0.62).timeout.connect(ghost.queue_free)
	elif kind == "deploy":
		effects.burst(point, UI.JADE)
	elif kind == "flip":
		if cell_views.has(destination):
			var tile: Control = cell_views[destination]
			tile.pivot_offset = tile.size * 0.5
			var flip: Tween = tile.create_tween()
			flip.tween_property(tile, "scale:x", 0.05, 0.10)
			flip.tween_property(tile, "scale:x", 1.0, 0.10)
	await get_tree().create_timer(0.38).timeout
	if is_instance_valid(actor):
		actor.queue_free()


func _point(pos: int) -> Vector2:
	if pos < 0:
		return Vector2(630, 550 if pos == -1 else 116)
	return cell_rect(pos).get_center()


func _inspect(pos: int) -> void:
	if not is_instance_valid(detail):
		return
	if pos < 0:
		detail.text = "最奥列の中央に進み、隣接して王を攻撃する。命を0にすれば勝利。"
		return
	var unit: Dictionary = session.board.at(pos)
	if unit.is_empty():
		detail.text = "空きマス。準備中は、手札の配置や隣からの移動ができます。"
	elif not bool(unit.face) and int(unit.side) == 1:
		detail.text = "潜伏している霊。攻撃するまで正体と攻撃力はわからない。"
	else:
		var info: Dictionary = Catalog.card(str(unit.card))
		detail.text = (
			"%s　攻撃 %d\n%s" % [info.name, session.board.effective_atk(pos), info.description]
		)


func _inspect_hand(index: int) -> void:
	if not is_instance_valid(detail) or index >= session.board.hands[0].size():
		return
	var info: Dictionary = Catalog.card(str(session.board.hands[0][index]))
	detail.text = "%s　攻撃 %d\n%s" % [info.name, info.atk, info.description]


func _get_drag(_at: Vector2, index: int) -> Variant:
	if busy or session.board.phase != "prepare":
		return null
	selected_hand = index
	selected_cell = -1
	var preview: TextureRect = TextureRect.new()
	preview.texture = load("res://assets/art/%s.svg" % session.board.hands[0][index])
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(90, 112)
	hand_views[index].set_drag_preview(preview)
	return {"hand": index}


func _can_drop(_at: Vector2, data: Variant, pos: int) -> bool:
	return not busy and data is Dictionary and data.has("hand") and session.board.can_deploy(pos)


func _drop_card(_at: Vector2, data: Variant, pos: int) -> void:
	_execute("deploy", int(data.hand), pos, not deploy_hidden)


func _no_drag(_at: Vector2) -> Variant:
	return null


func _reject_drag(_at: Vector2, _data: Variant) -> bool:
	return false


func _ignore_drag(_at: Vector2, _data: Variant) -> void:
	pass


func _abandon() -> void:
	if busy:
		return
	if confirmed_abandon:
		session.abandon_run()
	else:
		confirmed_abandon = true
		redraw()


func _unhandled_input(input_event: InputEvent) -> void:
	if busy:
		return
	if input_event.is_action_pressed("end_turn"):
		_end_turn()
	elif input_event.is_action_pressed("battle_phase"):
		_battle_phase()
	elif input_event.is_action_pressed("flip_card"):
		_flip_selected()
	else:
		return
	get_viewport().set_input_as_handled()
