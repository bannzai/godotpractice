extends SceneTree
## 実入力イベントによる統合検証。各検査の開始位置と所持品は明示した fixture を使う。

var main: Control
var state: Node
var world: Node2D
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("AdventureState")
	world = main.world
	await _pause(0.1)
	_check(state.mode == "title", "タイトルから起動")
	await _key(KEY_ENTER)
	_check(state.mode == "play", "Enter で冒険開始")
	await _movement_and_menu()
	await _field_interactions()
	await _dungeon_gates()
	await _combat_and_results()
	main.stop_audio()
	await _pause(0.25)
	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("integration OK: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error("integration FAIL: " + failure)
		quit(1)


func _movement_and_menu() -> void:
	await _pause(0.45)
	var before: Vector2 = world.hero.position
	await _key(KEY_D, 0.15)
	_check(world.hero.position.x > before.x + 20, "D で右へ移動")
	before = world.hero.position
	await _pad(JOY_BUTTON_DPAD_DOWN, 0.15)
	_check(world.hero.position.y > before.y + 20, "パッド下で移動")
	await _key(KEY_J)
	_check(world.attack_time > 0, "J で剣を振る")
	await _pause(0.4)
	await _pad(JOY_BUTTON_X)
	_check(world.attack_time > 0, "パッド X で剣を振る")
	await _key(KEY_TAB)
	_check(state.mode == "menu", "Tab で持ち物を開く")
	before = world.hero.position
	await _key(KEY_D, 0.1)
	_check(world.hero.position == before, "メニュー表示中は移動停止")
	await _pad(JOY_BUTTON_START)
	_check(state.mode == "play", "Start で持ち物を閉じる")
	await _pad(JOY_BUTTON_START)
	_check(state.mode == "menu", "Start で持ち物を開く")
	await _key(KEY_ESCAPE)
	_check(state.mode == "play", "Esc で冒険へ戻る")


func _field_interactions() -> void:
	await _room(0, Vector2(400, 290))
	await _key(KEY_E)
	_check(state.mode == "dialogue" and main.dialogue_title == "灯守の長老", "村人との会話")
	await _pad(JOY_BUTTON_A)
	_check(state.mode == "play", "パッド A で会話を閉じる")
	await _room(0, Vector2(330, 240))
	world.facing = Vector2.RIGHT
	await _key(KEY_J)
	_check(state.has_flag("grass-0-0"), "剣で草刈り")
	_check(world.pickups.size() > 0, "草から琥珀貨が出る")
	await _room(0, Vector2(540, 384))
	await _key(KEY_E)
	_check(not _has_prop("rock"), "E で岩を持ち上げる")
	await _room(4, Vector2(830, 530))
	await _key(KEY_E)
	_check(state.max_hp == 4 and state.opened.has("field-heart"), "探索報酬で最大体力増加")
	await _key(KEY_E)
	_check(state.max_hp == 4, "同じ宝箱で体力上限は重複増加しない")
	state.coins = 30
	await _room(1, Vector2(450, 290))
	await _key(KEY_E)
	_check(state.mode == "dialogue" and main.shop_open, "店で購入画面を表示")
	await _button("回復薬", false)
	_check(state.coins == 15 and state.potions == 1, "購入ボタンで代金と在庫を更新")
	await _key(KEY_ESCAPE)
	state.damage(2)
	await _key(KEY_TAB)
	await _button("回復薬を使う", true)
	_check(state.hp == state.max_hp and state.potions == 0, "メニューから薬を消費して回復")
	for room_index: int in range(6):
		await _room(room_index, Vector2(1180, 384))
		await _key(KEY_D, 0.1)
		_check(state.room == (room_index + 1 if room_index < 5 else 5),
			"フィールド %d の右出口" % room_index)
	await _room(5, Vector2(640, 260))
	await _pad(JOY_BUTTON_A)
	_check(state.room == 6, "パッド A で遺跡入口に入る")


func _dungeon_gates() -> void:
	await _room(6, Vector2(440, 330))
	await _key(KEY_E)
	_check(state.boomerang_owned and state.tool == "boomerang", "宝箱から風の輪を取得")
	await _room(7, Vector2(600, 384))
	world.facing = Vector2.RIGHT
	await _key(KEY_D, 0.25)
	_check(world.hero.position.x < 622 and not state.has_flag("wind-bridge"), "風の輪なしでは対岸へ進めない")
	await _key(KEY_K)
	_check(world.boom_timer > 0, "K で風の輪を投げる")
	await _pause(0.6)
	_check(state.has_flag("wind-bridge") and world.barriers().is_empty(), "遠方のスイッチで橋を開通")
	await _room(8, Vector2(290, 300))
	await _pad(JOY_BUTTON_A)
	_check(state.bombs_owned and state.bombs == 5 and state.tool == "bomb", "爆弾袋を取得して装備")
	world.hero.position = Vector2(900, 384)
	world.facing = Vector2.RIGHT
	await _key(KEY_D, 0.2)
	_check(world.hero.position.x < 942 and not state.has_flag("broken-wall"), "壁が移動を阻む")
	await _pad(JOY_BUTTON_Y)
	_check(world.bomb_timer > 0 and state.bombs == 4, "パッド Y で爆弾を消費")
	await _pause(1.25)
	_check(state.has_flag("broken-wall") and world.barriers().is_empty(), "爆発で壁を破壊")
	await _room(9, Vector2(810, 300))
	await _key(KEY_E)
	_check(state.keys == 0 and not state.opened.has("small-key"), "押石を解く前は鍵を取得できない")
	world.hero.position = Vector2(1080, 384)
	await _key(KEY_E)
	_check(not state.unlocked.has("iron"), "鍵なしでは扉を開けられない")
	world.hero.position = Vector2(430, 384)
	await _key(KEY_D, 0.65)
	_check(state.has_flag("weight"), "移動で石を押し床スイッチを作動")
	world.hero.position = Vector2(810, 300)
	await _key(KEY_E)
	_check(state.keys == 1, "仕掛けを解いて小鍵を取得")
	world.hero.position = Vector2(1080, 384)
	await _pad(JOY_BUTTON_A)
	_check(state.unlocked.has("iron") and state.keys == 0, "パッド A で小鍵を消費して解錠")
	await _pad(JOY_BUTTON_A)
	_check(state.keys == 0, "解錠済みの扉は鍵を再消費しない")
	await _room(10, Vector2(370, 384))
	await _key(KEY_D, 0.2)
	_check(state.has_flag("star"), "踏むスイッチで東の道を開く")
	world.hero.position = Vector2(560, 240)
	world.invulnerable = 0
	var health: int = state.hp
	await _key(KEY_D, 0.2)
	_check(state.hp == health - 1 and world.hero.position.y == 384,
		"穴でダメージを受け安全な足場へ戻る")
	await _key(KEY_TAB)
	await _button("記録する", false)
	_check(state.has_save() and main.notice == "旅を記録しました。", "持ち物画面から保存")
	var saved: Dictionary = state.snapshot()
	await _key(KEY_TAB)
	await _button("タイトルへ", true)
	_check(state.mode == "title", "持ち物画面からタイトルへ")
	await _button("つづきから", false)
	_check(state.mode == "play" and state.room == saved.room, "タイトルから保存した部屋へ復帰")
	_check(state.bombs == saved.bombs and state.flags == saved.flags
		and state.unlocked == saved.unlocked,
		"道具・仕掛け・解錠を維持して復帰")


func _combat_and_results() -> void:
	await _room(2, Vector2(750, 390))
	world.facing = Vector2.RIGHT
	var enemy: Node2D = world.enemies[0]
	var health: int = enemy.hp
	await _key(KEY_J)
	_check(enemy.hp == health - 1, "剣が前方の敵に命中")
	await _pause(0.5)
	world.hero.position = enemy.position + Vector2(80, 0)
	world.facing = Vector2.RIGHT
	health = enemy.hp
	await _pad(JOY_BUTTON_X)
	_check(enemy.hp == health, "剣を背中側の敵へ当てない")
	await _room(3, Vector2(780, 400))
	world.facing = Vector2.RIGHT
	enemy = world.enemies[0]
	enemy.hp = 1
	await _key(KEY_J)
	_check(enemy.dead and world.enemies.size() == 4, "分裂する敵の撃破で小敵2体が出現")
	await _room(2, Vector2(750, 390))
	state.hp = 1
	world.invulnerable = 0
	world.hero.position = world.enemies[0].position - Vector2(30, 0)
	await _pause(0.75)
	_check(state.hp == 0 and state.mode == "gameover", "接触ダメージで体力ゼロと敗北画面")
	await _pad(JOY_BUTTON_A)
	_check(state.mode == "play" and state.room == 2 and state.hp == state.max_hp,
		"パッド A で直前の入口から再挑戦")
	await _room(11, Vector2(810, 384))
	world.facing = Vector2.RIGHT
	enemy = world.enemies[0]
	enemy.hp = 1
	await _key(KEY_J)
	_check(enemy.dead and state.has_flag("boss") and _has_prop("treasure"), "ボス撃破で宝が出現")
	world.hero.position = Vector2(840, 384)
	await _key(KEY_E)
	_check(state.mode == "ending" and state.has_flag("treasure"), "宝を調べて結末へ")
	await _key(KEY_ENTER)
	_check(state.mode == "play" and state.room == 0 and state.opened.is_empty(), "結末から新たな旅へ")
	await _key(KEY_TAB)
	await _button("タイトルへ", false)
	await _pad(JOY_BUTTON_A)
	_check(state.mode == "play", "パッド A でタイトルから開始")


func _room(index: int, at: Vector2) -> void:
	world.enter_room(index, at, false)
	await _pause(0.06)


func _has_prop(kind: String) -> bool:
	for prop: Dictionary in world.props:
		if prop.kind == kind:
			return true
	return false


func _button(prefix: String, controller: bool) -> void:
	var found: Button = null
	for child: Node in main.ui.get_node(".").find_children("*", "Button", true, false):
		if child.text.begins_with(prefix):
			found = child
			break
	_check(found != null and not found.disabled, "操作可能なボタン: " + prefix)
	if found == null or found.disabled:
		return
	found.grab_focus()
	if controller:
		await _pad(JOY_BUTTON_A)
	else:
		await _key(KEY_ENTER)


# 検証の入力系列を消費するため、入力送信と待機は非冪等。
func _key(code: Key, seconds: float = 0.06) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _pause(seconds)
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await _pause(0.04)


func _pad(button: JoyButton, seconds: float = 0.06) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _pause(seconds)
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await _pause(0.04)


func _pause(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
	else:
		print("確認: " + label)
