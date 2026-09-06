extends Control
## 入力を状態の公開操作へ渡し、演出の終了後に最新の盤面を描く。

const Catalog = preload("res://scripts/core/catalog.gd")
const Views = preload("res://scripts/ui/views.gd")
const UI = preload("res://scripts/ui/widgets.gd")
const Backdrop = preload("res://scripts/visual/backdrop.gd")
const Effects = preload("res://scripts/visual/effects.gd")
const Sound = preload("res://scripts/visual/sound.gd")

var run: Node
var content: Control
var backdrop: Control
var effects: Control
var sound: Node
var enemy_actor: Node2D
var hero_actor: Node2D
var first_focus: Control
var cell_nodes: Dictionary = {}
var hand_nodes: Array[Control] = []
var selected_uid: int = -1
var selected_hand: int = -1
var mode: String = "select"
var busy: bool = false
var overlay: String = ""
var note: String = "手札を選び、自陣の空きマスに潜伏させよう。"
var speech: String = ""
var last_stage: String = ""
var seed_input: LineEdit
var hand_page: int = 0
var result_count: float = 0
var detail_id: String = ""
var _quitting: bool = false
var _last_focus: String = ""


func _ready() -> void:
	print("boardrogue boot")
	DisplayServer.window_set_title("墨将紀 ― 霧の九峠 ―")
	run = get_node("/root/Run")
	theme = UI.theme_resource()
	get_tree().auto_accept_quit = false
	backdrop = Backdrop.new()
	add_child(backdrop)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	effects = Effects.new()
	add_child(effects)
	sound = Sound.new()
	add_child(sound)
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _quitting:
		_quit_game()


func stop_audio() -> void:
	if is_instance_valid(sound):
		sound.stop_audio()


# 通常終了は音声スレッドが参照を解放するまで待つため非冪等。
func _quit_game() -> void:
	_quitting = true
	if run.stage != "title" and not _save_progress():
		_quitting = false
		_render()
		return
	await sound.shutdown()
	get_tree().quit()


func _render() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and content.is_ancestor_of(focused):
		_last_focus = str(focused.name)
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	cell_nodes.clear()
	hand_nodes.clear()
	first_focus = null
	enemy_actor = null
	hero_actor = null
	var changed: bool = last_stage != run.stage
	if changed:
		backdrop.setup(run.stage)
		var music: String = run.stage
		if run.stage == "battle":
			music = "boss" if run.battle.enemy_id in ["general", "final"] else "battle"
		elif run.stage == "result":
			music = "result_win" if run.won else "result_loss"
		elif run.stage != "title":
			music = "map"
		sound.play_music(music)
		last_stage = run.stage
		content.modulate.a = 0.0
		create_tween().tween_property(content, "modulate:a", 1.0, 0.28)
	Views.render(self)
	if not overlay.is_empty():
		Views.modal(self, overlay)
	if not run.save_error.is_empty():
		UI.panel(content, Rect2(333, 613, 600, 60), Color("5d2b22"))
		UI.paragraph(content, run.save_error, Rect2(344, 621, 581, 48), 16)
	var restore: Node = (
		null if _last_focus.is_empty() else content.find_child(_last_focus, true, false)
	)
	if not changed and overlay.is_empty() and restore is Control and restore.is_visible_in_tree():
		restore.grab_focus()
	elif is_instance_valid(first_focus):
		first_focus.grab_focus()


# 新しい旅の開始という入力ごとにseedを決めるため非冪等。
func start_run() -> void:
	var chosen_seed: int = int(Time.get_unix_time_from_system()) % 1000000
	if is_instance_valid(seed_input) and seed_input.text.is_valid_int():
		chosen_seed = int(seed_input.text)
	run.new_run(chosen_seed)
	_save_progress()
	speech = ""
	_clear_selection()
	_render()


func resume_run() -> void:
	if run.load_run():
		if run.stage == "battle" and run.battle.phase == "over":
			run.resolve_battle()
			_save_progress()
		_clear_selection()
		if run.stage == "battle":
			speech = Catalog.ENEMIES[run.battle.enemy_id].lines.start
		_render()
		if run.stage == "battle" and run.battle.turn == 1:
			busy = true
			_enemy_turn()
	else:
		note = "保存を読めませんでした。新しい旅を始められます。"
		_render()


# ノード選択で一度だけ旅路を進めるため非冪等。
func choose_node(index: int) -> void:
	if busy:
		return
	if not run.choose_node(index):
		return
	_save_progress()
	_clear_selection()
	if run.stage == "battle":
		speech = Catalog.ENEMIES[run.battle.enemy_id].lines.start
		note = "手札 → 自陣の空きマス。選んだ伏せ札は「登場」で表に。"
	_render()
	if run.stage == "battle" and run.battle.enemy_id in ["general", "final"]:
		busy = true
		sound.play_sfx("drum")
		effects.spawn("boss", Vector2(640, 300))
		await get_tree().create_timer(0.9).timeout
		busy = false


func _clear_selection() -> void:
	selected_uid = -1
	selected_hand = -1
	detail_id = ""
	mode = "select"
	hand_page = 0


func _select_hand(index: int) -> void:
	if not _player_ready() or run.battle.phase != "standby":
		return
	selected_hand = index
	selected_uid = -1
	mode = "select"
	detail_id = str(run.battle.hands[0][index])
	note = "「%s」を潜伏させる自陣の空きマスを選択。" % Catalog.CARDS[detail_id].name
	_render()


# 入力イベントから公開操作を一度実行するため非冪等。
func _click_cell(pos: Vector2i) -> void:
	if not _player_ready():
		return
	var unit: Dictionary = run.battle.unit_at(pos)
	if selected_hand >= 0:
		var event: Dictionary = run.battle.deploy(selected_hand, pos)
		if event.ok:
			selected_hand = -1
			selected_uid = event.uid
			detail_id = event.card
			_apply_event(event)
		else:
			_invalid("潜伏できるのは、自陣の空きマスです。")
		return
	if selected_uid >= 0 and mode == "move":
		_apply_event(run.battle.move_unit(selected_uid, pos))
		return
	if selected_uid >= 0 and not unit.is_empty():
		if mode == "swap":
			_apply_event(run.battle.swap_units(selected_uid, unit.uid))
			return
		if mode == "effect":
			_apply_event(run.battle.use_effect(selected_uid, unit.uid))
			return
		if run.battle.phase == "battle" and unit.side == 1:
			_apply_event(run.battle.attack(selected_uid, unit.uid))
			return
	if unit.is_empty():
		selected_uid = -1
		detail_id = ""
	else:
		selected_uid = unit.uid if unit.side == 0 else -1
		detail_id = unit.card if unit.side == 0 or unit.face else ""
		note = "敵の伏せ札は攻撃するまで分かりません。" if detail_id.is_empty() else "札を選択しました。左側の説明と操作を確認してください。"
	mode = "select"
	_render()


func _drag_card(data: Dictionary, pos: Vector2i) -> void:
	if not _player_ready():
		return
	selected_hand = int(data.hand)
	selected_uid = int(data.uid)
	mode = "move" if selected_uid >= 0 else "select"
	_click_cell(pos)


func _select_mode(next_mode: String) -> void:
	if not _player_ready() or selected_uid < 0:
		return
	mode = next_mode
	note = (
		{
			"move": "上下左右の空きマスへ移動。移動した札はこのターン攻撃できません。",
			"swap": "隣接する札を選んで配置換え。一組だけ入れ替えられます。",
			"effect": "効果の対象となる敵の伏せ札を選んでください。"
		}
		. get(mode, "札を選択。")
	)
	_render()


func _reveal_selected() -> void:
	if _player_ready() and selected_uid >= 0:
		_apply_event(run.battle.reveal(selected_uid))


func _effect_selected() -> void:
	if not _player_ready() or selected_uid < 0:
		return
	var unit: Dictionary = run.battle.unit_by_id(selected_uid)
	if not unit.is_empty() and Catalog.CARDS[unit.card].effect == "reveal":
		_select_mode("effect")
	else:
		_apply_event(run.battle.use_effect(selected_uid))


func _attack_king() -> void:
	if _player_ready() and selected_uid >= 0:
		_apply_event(run.battle.attack(selected_uid))


func _advance_phase() -> void:
	if not _player_ready():
		return
	if run.battle.phase == "standby":
		_apply_event(run.battle.begin_battle())
	else:
		_apply_event(run.battle.end_turn())


func _player_ready() -> bool:
	return not busy and overlay.is_empty() and run.stage == "battle" and run.battle.turn == 0


func _invalid(message: String) -> void:
	note = message
	_render()


# 操作の結果と演出を同期するため、入力単位で時間を進める非冪等な処理。
func _apply_event(event: Dictionary) -> void:
	if not event.get("ok", false):
		_invalid("その操作はできません。フェーズ・隣接・行動済みの状態を確認してください。")
		return
	busy = true
	await _animate_event(event)
	if _quitting:
		return
	mode = "select"
	if run.battle.phase == "over":
		run.resolve_battle()
		_save_progress()
		_clear_selection()
		sound.play_sfx("reward")
		note = "次の道へ持っていく札を、一枚選んでください。"
	else:
		_save_progress()
	_render()
	if run.stage == "battle" and run.battle.turn == 1:
		await _enemy_turn()
	else:
		busy = false


func _actor_for_uid(uid: int) -> Node2D:
	for card: Control in cell_nodes.values():
		if card.unit_uid == uid:
			return card.actor
	return null


func _card_for_uid(uid: int) -> Control:
	for card: Control in cell_nodes.values():
		if card.unit_uid == uid:
			return card
	return null


func _animate_event(event: Dictionary) -> void:
	var kind: String = event.type
	var acting: Node2D = _actor_for_uid(int(event.get("uid", -1)))
	var card_node: Control = _card_for_uid(int(event.get("uid", -1)))
	var center := Vector2(640, 300)
	if is_instance_valid(card_node):
		center = card_node.get_global_rect().get_center()
	match kind:
		"deploy":
			sound.play_sfx("card")
			center = board_center(event.to)
			effects.spawn("deploy", center)
			note = "札を潜伏させました。「登場」で表向きにできます。"
		"reveal":
			sound.play_sfx("card")
			effects.spawn("reveal", center)
			if is_instance_valid(card_node):
				var flip: Tween = create_tween()
				flip.tween_property(card_node, "scale:x", 0.04, 0.12)
				await flip.finished
				_scale_flip_card(card_node)
				create_tween().tween_property(card_node, "scale:x", 1.0, 0.12)
			note = "登場しました。移動せずバトルへ進めば、この札で攻撃できます。"
		"move", "swap":
			sound.play_sfx("card")
			if is_instance_valid(acting):
				acting.play_pose("move")
			if is_instance_valid(card_node) and event.has("to"):
				create_tween().tween_property(
					card_node, "global_position", board_center(event.to) - card_node.size / 2, 0.3
				)
			if kind == "swap":
				var other_card: Control = _card_for_uid(int(event.other))
				if is_instance_valid(other_card):
					if is_instance_valid(other_card.actor):
						other_card.actor.play_pose("move")
					create_tween().tween_property(
						other_card,
						"global_position",
						board_center(event.other_to) - other_card.size / 2,
						0.3
					)
			effects.spawn("move", center)
			note = "移動した札はこのターン攻撃できません。" if kind == "move" else "一組を配置換えしました。攻撃権は残ります。"
		"attack":
			await _animate_attack(event, acting, center)
		"effect":
			sound.play_sfx("reward")
			effects.spawn("heal", center)
			if is_instance_valid(acting):
				acting.play_pose("attack")
			note = "札の効果を発動しました。"
		"phase", "turn":
			sound.play_sfx("drum")
			note = "表向きの札 → 敵札または敵王で攻撃。終了は E / Y。"
	await get_tree().create_timer(0.30 if kind == "attack" else 0.16).timeout


func _scale_flip_card(card_node: Control) -> void:
	card_node.reveal_face()
	if is_instance_valid(card_node.actor):
		card_node.actor.play_pose("move")


func _animate_attack(event: Dictionary, acting: Node2D, center: Vector2) -> void:
	var target: Vector2 = board_center(event.get("to", Vector2i(1, 0)))
	var is_arrow: bool = event.get("card", "") == "bow"
	var target_node: Control = _card_for_uid(int(event.get("target", -1)))
	if is_instance_valid(target_node) and target_node.concealed:
		target_node.reveal_face()
		note = (
			"潜伏札「%s」が現れた。%s"
			% [Catalog.CARDS[target_node.card_id].name, Catalog.CARDS[target_node.card_id].text]
		)
		await get_tree().create_timer(0.35).timeout
	if run.battle.turn == 1 and is_instance_valid(enemy_actor):
		enemy_actor.play_pose("attack")
	sound.play_sfx("arrow" if is_arrow else "blade")
	if is_instance_valid(acting):
		acting.play_pose("attack")
		var original: Vector2 = acting.position
		var lunge: Tween = create_tween()
		lunge.tween_property(
			acting, "position", original + (target - center).normalized() * 20, 0.10
		)
		lunge.tween_interval(0.065)
		lunge.tween_property(acting, "position", original, 0.13)
	await get_tree().create_timer(0.10).timeout
	effects.spawn("arrow" if is_arrow else "hit", target)
	var struck: Node2D = _actor_for_uid(int(event.get("target", -1)))
	if is_instance_valid(struck):
		struck.play_pose("hurt")
	await get_tree().create_timer(0.065).timeout
	for fallen: Dictionary in event.get("defeated", []):
		var victim: Node2D = _actor_for_uid(fallen.uid)
		if is_instance_valid(victim):
			victim.play_pose("death")
			effects.spawn("death", board_center(Vector2i(fallen.x, fallen.y)))
	var opponent: Dictionary = Catalog.ENEMIES[run.battle.enemy_id]
	if event.get("damage", 0) > 0:
		var king_side: int = int(event.get("king_damage_side", 1 - run.battle.turn))
		var king_point: Vector2 = board_center(run.battle.king_position(king_side))
		effects.spawn("king", king_point)
		if king_side == 1 and is_instance_valid(enemy_actor):
			enemy_actor.play_pose("death" if run.battle.hp[1] <= 0 else "hurt")
		elif king_side == 0 and is_instance_valid(hero_actor):
			hero_actor.play_pose("death" if run.battle.hp[0] <= 0 else "hurt")
		_shake()
		_pop("−%d" % event.damage, king_point, UI.RED)
		speech = opponent.lines.hurt if run.battle.turn == 0 else opponent.lines.attack
	else:
		speech = opponent.lines.lost if run.battle.turn == 0 else opponent.lines.attack
	if run.battle.winner == 0:
		speech = opponent.lines.defeat
	UI.paragraph(content, speech, Rect2(980, 339, 255, 94), 18)
	await get_tree().create_timer(0.70).timeout


func _shake() -> void:
	var tween: Tween = create_tween()
	for offset: Vector2 in [Vector2(6, -3), Vector2(-5, 3), Vector2(3, 1), Vector2.ZERO]:
		tween.tween_property(content, "position", offset, 0.045)


func _pop(value: String, point: Vector2, color: Color) -> void:
	var label: Label = UI.label(self, value, Rect2(point.x - 45, point.y - 20, 100, 50), 34, color)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", point.y - 72, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.finished.connect(label.queue_free)


func _enemy_turn() -> void:
	busy = true
	var steps: int = 0
	while run.stage == "battle" and run.battle.turn == 1 and run.battle.phase != "over":
		var event: Dictionary = run.battle.ai_step()
		if not event.get("ok", false):
			push_error("敵AIが合法な行動を返しませんでした")
			break
		await _animate_event(event)
		steps += 1
		if run.battle.phase == "over":
			run.resolve_battle()
			_clear_selection()
			_save_progress()
			_render()
			break
		_save_progress()
		_render()
		if steps > 80:
			push_error("敵の手番が終わりませんでした")
			break
	busy = false
	if run.stage == "battle":
		note = "あなたのドロー → 準備。配置・登場・移動・効果を選べます。"
		_render()


func board_center(pos: Vector2i) -> Vector2:
	if pos.y < 0 or pos.y > 3:
		return Vector2(640, 107 if pos.y < 0 else 501)
	var x_start: float = 640.0 - run.battle.width * 52.0
	return Vector2(x_start + pos.x * 104 + 52, 138 + pos.y * 84 + 42)


func _change_hand_page(delta: int) -> void:
	hand_page = maxi(0, hand_page + delta)
	_render()


func _show_overlay(value: String) -> void:
	if busy:
		return
	overlay = value
	_render()


func _close_overlay() -> void:
	overlay = ""
	_render()


func _to_title() -> void:
	if run.stage != "title" and not _save_progress():
		_render()
		return
	run.stage = "title"
	overlay = ""
	_clear_selection()
	_render()


# 降参はユーザーがメニューで選んだときだけ結果へ進める。
func _concede() -> void:
	run.abandon()
	_save_progress()
	overlay = ""
	_render()


func _take_reward(index: int) -> void:
	if run.take_reward(index):
		_save_progress()
		sound.play_sfx("reward")
		effects.spawn("reward", Vector2(640, 320))
		_render()


func _rest() -> void:
	if run.rest():
		_save_progress()
		sound.play_sfx("reward")
		effects.spawn("heal", Vector2(640, 300))
		_render()


func _buy_card(index: int) -> void:
	if run.buy_card(index):
		_save_progress()
		sound.play_sfx("reward")
		_pop("札を獲得", Vector2(640, 370), UI.GOLD)
		_render()


func _remove_card(index: int) -> void:
	if run.remove_card(index):
		_save_progress()
		sound.play_sfx("card")
		_render()


func _leave_node() -> void:
	run.leave_node()
	_save_progress()
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and not busy:
		if not overlay.is_empty():
			_close_overlay()
		elif selected_hand >= 0 or selected_uid >= 0:
			_clear_selection()
			_render()
		elif run.stage != "title":
			_show_overlay("pause")
		get_viewport().set_input_as_handled()
	elif not busy and overlay.is_empty():
		if event.is_action_pressed("phase"):
			_advance_phase()
		elif event.is_action_pressed("reveal"):
			_reveal_selected()
		elif event.is_action_pressed("move_card"):
			_select_mode("move")
		elif event.is_action_pressed("swap_card"):
			_select_mode("swap")
		elif event.is_action_pressed("effect"):
			_effect_selected()


func _save_progress() -> bool:
	var success: bool = run.save_run()
	if not success:
		note = run.save_error
	return success
