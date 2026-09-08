extends SceneTree
## 実際の冒険シーンを使い、入力と進行の境界条件を再現する検証。
var world: Node
var journey: Node
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("失敗: ", label)

# 状態を変えるゲーム操作を順番に実行するため、この検証自体は非冪等。
func run() -> void:
	journey = root.get_node("Journey")
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.music.stop()
	# 音声そのものは描画付き検証で扱い、ここでは高速な操作列の音声予約を抑える。
	world.effects.clear()
	world.new_game()
	verify(world.mode == "play" and journey.room == 0 and journey.health == 6, "開始時の部屋と体力")
	combat()
	progression()
	exits()
	world.queue_free()
	world = null
	for frame: int in range(5):
		await physics_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("全 %d 項目成功: 戦闘・進行・出口・衝突" % checks)
		quit(0)
	else:
		printerr("%d / %d 項目失敗" % [failures.size(), checks])
		quit(1)

func fixture(room: int) -> void:
	world.load_room(room, world.center(Vector2i(10, 5)))
	world.mode = "play"
	world.hurt = 0.0
	world.attack_cooldown = 0.0
	world.dash = 0.0
	world.dash_cooldown = 0.0
	world.push_cooldown = 0.0
	world.facing = Vector2.RIGHT

func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	world._unhandled_input(event)

func combat() -> void:
	fixture(1)
	world.player = world.center(Vector2i(10, 5))
	world.enemies[0].pos = world.player + Vector2(25, 0)
	world.enemies[1].pos = world.player + Vector2(-25, 0)
	world.enemies[2].pos = world.player + Vector2(60, 0)
	world.swing()
	verify(world.enemies[0].hp == 2, "前方の剣が命中")
	verify(world.enemies[1].hp == 3, "背面の敵は剣の範囲外")
	verify(world.enemies[2].hp == 3, "遠方の敵は剣の範囲外")
	world.swing()
	verify(world.enemies[0].hp == 2, "剣の連続呼び出しは冷却中に無効")
	world._physics_process(0.33)
	verify(world.attack_cooldown == 0, "剣の冷却時間が経過")
	journey.health = 6
	world.hurt = 0.0
	world.damage_player(world.player - Vector2(20, 0))
	verify(journey.health == 5 and world.hurt > 0, "被弾で体力減少と無敵開始")
	world.damage_player(world.player - Vector2(20, 0))
	verify(journey.health == 5, "被弾直後の連続ダメージ防止")
	world.hurt = 0.0
	key(KEY_SPACE)
	verify(world.dash > 0 and world.dash_cooldown > 0, "回避入力で回避開始")
	world.damage_player(world.player - Vector2(20, 0))
	verify(journey.health == 5, "回避中は被弾無効")
	world.dash = 0.0
	key(KEY_SPACE)
	verify(world.dash == 0, "回避の冷却中は再回避不可")
	journey.health = 1
	world.damage_player(world.player - Vector2(20, 0))
	verify(journey.health == 0 and world.mode == "dead", "体力ゼロで死亡")
	journey.key_found = true
	key(KEY_ENTER)
	verify(world.mode == "play" and journey.health == 6 and journey.key_found, "死亡再開は取得物を保持")
	journey.reset()
	fixture(1)
	world.damage_enemy(world.enemies[0], 3)
	world.remove_defeated()
	verify(world.enemies.size() == 2 and journey.defeated.has("1:0"), "討伐結果が記録される")
	fixture(0)
	fixture(1)
	verify(world.enemies.size() == 2, "部屋往復で討伐済みの敵は復活しない")
	world.enemies.clear()
	journey.ember = true
	world.tool_cooldown = 0.0
	world.interact()
	verify(world.bolts.size() == 1, "灯火で飛び道具を発射")
	world.interact()
	verify(world.bolts.size() == 1, "飛び道具の連射制限")

func progression() -> void:
	journey.reset()
	fixture(1)
	world.player = world.center(Vector2i(16, 5))
	world.interact()
	verify(not journey.key_found, "未討伐では宝箱の鍵を取得できない")
	world.player = world.center(Vector2i(10, 1))
	world.interact()
	verify(not journey.shrine_open and world.solid(Vector2i(10, 0)), "鍵なしでは祠の扉が閉じる")
	for enemy: Dictionary in world.enemies:
		world.damage_enemy(enemy, 3)
	world.remove_defeated()
	world.player = world.center(Vector2i(16, 5))
	world.interact()
	verify(journey.key_found, "全討伐後に鍵を取得")
	world.player = world.center(Vector2i(10, 1))
	world.interact()
	verify(journey.shrine_open and not world.solid(Vector2i(10, 0)), "鍵で祠の扉を解錠")
	fixture(2)
	world.player = world.center(Vector2i(10, 2))
	world.interact()
	verify(not journey.ember, "石の謎解き前は祭壇を取得不可")
	world.player = world.center(Vector2i(7, 5)) + Vector2(10, 0)
	world.move_player(Vector2(8, 0))
	verify(world.block == Vector2i(9, 5), "接触移動で石を一マス押す")
	world.player = world.center(Vector2i(3, 5))
	world.interact()
	verify(world.block == Vector2i(8, 5), "装置で石を初期位置へ戻す")
	for x: int in range(7, 10):
		world.player = world.center(Vector2i(x, 5)) + Vector2(10, 0)
		world.push_cooldown = 0.0
		world.move_player(Vector2(8, 0))
	world._physics_process(0.01)
	verify(world.block == Vector2i(11, 5) and journey.solved, "石が金色の床に到着して謎解き成立")
	world.player = world.center(Vector2i(10, 2))
	world.interact()
	verify(journey.ember, "謎解き後に祭壇の灯火を取得")
	fixture(1)
	fixture(2)
	verify(world.block == Vector2i(11, 5), "往復後も石の謎解きを保持")
	verify(journey.destination(Vector2i.RIGHT) == -1, "祠から灯台へ封印を迂回できない")
	fixture(3)
	journey.ember = false
	world.light_brazier(0)
	verify(journey.braziers.is_empty(), "灯火なしでは燭台に点灯不可")
	journey.ember = true
	world.player = world.center(Vector2i(8, 2))
	world.interact()
	world.interact()
	verify(journey.braziers.size() == 1 and world.solid(Vector2i(10, 0)), "重複点灯は一つで封印維持")
	world.player = world.center(Vector2i(12, 2))
	world.interact()
	verify(journey.braziers.size() == 2 and not world.solid(Vector2i(10, 0)), "二本点灯で灯台の封印解除")
	fixture(4)
	world.player = world.center(Vector2i(10, 2))
	world.interact()
	verify(not journey.won, "守護者の討伐前は勝利しない")
	world.damage_enemy(world.enemies[0], 14)
	world.remove_defeated()
	world.interact()
	verify(journey.won and world.mode == "ending", "守護者討伐後に灯台を灯して勝利")
	key(KEY_ENTER)
	verify(world.mode == "play" and journey.room == 0 and not journey.won and not journey.ember and not journey.key_found and journey.defeated.is_empty() and journey.braziers.is_empty(), "勝利後の再開は進行を初期化")

func exits() -> void:
	journey.shrine_open = true
	journey.braziers.assign([0, 1])
	for room: int in range(5):
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			fixture(room)
			var destination: int = journey.destination(direction)
			var exit_cell: Vector2i = Vector2i(0 if direction.x < 0 else 19, 5) if direction.x != 0 else Vector2i(10, 0 if direction.y < 0 else 10)
			verify(world.solid(exit_cell) == (destination < 0), "部屋 %d・出口 %s の開閉" % [room, direction])
			if destination >= 0:
				world.player = world.center(exit_cell) - Vector2(direction) * 32
				for step: int in range(80):
					world.move_player(Vector2(direction) * 2)
					world.check_exit()
					if journey.room != room:
						break
				verify(journey.room == destination, "部屋 %d から %d への実移動" % [room, destination])
		fixture(room)
		world.player = world.center(Vector2i(1, 1))
		for step: int in range(30):
			world.move_player(Vector2(-2, 0))
		verify(world.player.x >= 40 and world.can_stand(world.player), "部屋 %d の左壁を貫通しない" % room)
