extends SceneTree
## 実ユーザーの保存領域を使わず、戦闘と進行の境界を検証する。

const Game: Script = preload("res://scripts/run.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("不合格: " + message)
	else:
		print("合格: " + message)

func fresh() -> Game:
	var game: Game = Game.new()
	game.persistence = false
	game.start(8192)
	return game

func verify() -> void:
	verify_combat()
	verify_progression()
	verify_death()
	verify_upgrades()
	verify_seed()
	verify_complete_run()
	print("検証数=%d 不合格=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func verify_combat() -> void:
	var game: Game = fresh()
	game.foes.clear()
	game.obstacles.clear()
	game.player = Vector2(240, 416)
	game.spawn_foe(Vector2(290, 416), 0)
	game.spawn_foe(Vector2(350, 416), 0)
	game.spawn_foe(Vector2(200, 416), 0)
	game.swing()
	check(game.foes[0].health == 2, "正面の射程内の敵に剣のダメージ")
	check(game.foes[1].health == 4, "射程外の敵には当たらない")
	check(game.foes[2].health == 4, "背後の敵には当たらない")
	game.swing()
	check(game.foes[0].health == 2, "攻撃待ち時間中の二重入力を防ぐ")
	game.attack_wait = 0.0
	game.obstacles.append(Rect2(260, 380, 20, 80))
	game.swing()
	check(game.foes[0].health == 2, "壁越しの剣は敵に当たらない")
	check(game.move_actor(Vector2(240, 416), Vector2(200, 0)).x < 260, "大きい移動量でも壁を貫通しない")
	game.invulnerable = 0.0
	game.dash(Vector2.RIGHT)
	game.hurt(1)
	check(game.health == game.max_health, "回避中は被ダメージを無効化")
	game.invulnerable = 0.0
	game.dash_left = 0.0
	game.hurt(1)
	check(game.health == game.max_health - 1, "無敵終了後は被ダメージが成立")
	game.hurt(1)
	check(game.health == game.max_health - 1, "被弾直後の連続ダメージを防ぐ")
	game.free()

func verify_progression() -> void:
	var game: Game = fresh()
	game.player = Game.EXIT
	game.interact()
	check(game.phase == Game.Phase.PLAY and game.room == 1, "敵が残る部屋では出口が開かない")
	for foe: Game.Foe in game.foes:
		foe.health = 0
	game.remove_defeated()
	check(game.clear and game.shards == 11, "敵撃破と部屋制覇の報酬を加算")
	game.remove_defeated()
	check(game.shards == 11, "部屋制覇報酬の二重加算を防ぐ")
	game.player = Vector2(200, 416)
	game.interact()
	check(game.phase == Game.Phase.PLAY, "出口から離れた位置では遷移しない")
	game.player = Game.EXIT
	game.interact()
	check(game.phase == Game.Phase.CHOICE and game.choices.size() == 3, "出口で三択の強化を提示")
	check(game.choices[0] != game.choices[1] and game.choices[1] != game.choices[2] and game.choices[0] != game.choices[2], "提示した強化は重複しない")
	game.choose(-1)
	game.choose(3)
	check(game.phase == Game.Phase.CHOICE and game.taken.is_empty(), "無効な選択は進行を変えない")
	game.choose(0)
	check(game.room == 2 and game.phase == Game.Phase.PLAY and game.taken.size() == 1, "強化選択で次の部屋へ進む")
	game.choose(0)
	check(game.room == 2 and game.taken.size() == 1, "強化選択の二重入力を防ぐ")
	check(not game.clear and game.foes.size() == 5 and game.shots.is_empty(), "次室では敵と出口状態を初期化")
	game.free()

func verify_death() -> void:
	var game: Game = fresh()
	game.bank = 7
	game.shards = 13
	game.invulnerable = 0.0
	game.hurt(99)
	check(game.phase == Game.Phase.RESULT and game.health == 0, "致死ダメージで結果画面へ遷移")
	check(game.collected == 6 and game.bank == 13, "死亡時は欠片の半分を切り捨てて持ち帰る")
	game.hurt(99)
	game.finish("二重入力", true)
	check(game.bank == 13 and game.collected == 6, "死亡結果の二重確定でも欠片を重複加算しない")
	check(game.best == 0, "未制覇の部屋は最高到達数に含めない")
	game.camp()
	game.start(8192)
	check(game.shards == 0 and game.collected == 0 and game.health == game.max_health, "再挑戦で所持欠片と体力を初期化")
	check(game.bank == 13, "再挑戦でも持ち帰った欠片を保持")
	game.free()

func verify_upgrades() -> void:
	var game: Game = fresh()
	game.camp()
	check(game.upgrade_cost(0) == 8 and game.upgrade_cost(1) == 14, "恒久強化の初回費用")
	game.bank = 7
	check(not game.purchase(0) and game.bank == 7 and game.vitality == 0, "残高不足の購入は状態を変えない")
	game.bank = 1000
	check(not game.purchase(2) and game.bank == 1000, "不正な強化種別を購入できない")
	for level: int in range(5):
		check(game.upgrade_cost(0) == 8 * (level + 1), "体力強化レベル%dの費用" % (level + 1))
		check(game.purchase(0), "体力強化レベル%dを購入" % (level + 1))
	check(game.bank == 880 and game.vitality == 5 and not game.purchase(0), "体力強化の合計費用と上限")
	for level: int in range(3):
		check(game.upgrade_cost(1) == 14 * (level + 1), "攻撃強化レベル%dの費用" % (level + 1))
		check(game.purchase(1), "攻撃強化レベル%dを購入" % (level + 1))
	check(game.bank == 796 and game.mastery == 3 and not game.purchase(1), "攻撃強化の合計費用と上限")
	game.start(8192)
	check(game.max_health == 16 and game.health == 16 and game.power == 5, "恒久強化を再挑戦に反映")
	check(not game.purchase(0), "探索中は恒久強化を購入できない")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute("res://tmp")
	check(directory_error == OK, "検証専用の保存ディレクトリを準備")
	game.save_path = "res://tmp/selfcheck-progress.cfg"
	game.persistence = true
	game.best = 4
	check(game.save_progress(), "検証専用ファイルへ保存")
	var restored: Game = Game.new()
	restored.save_path = game.save_path
	restored.load_progress()
	check(restored.bank == 796 and restored.vitality == 5 and restored.mastery == 3 and restored.best == 4, "保存した欠片・恒久強化・最高到達数を再読込")
	restored.load_progress()
	check(restored.bank == 796, "保存再読込で欠片を重複加算しない")
	game.free()
	restored.free()

func verify_seed() -> void:
	var first: Game = fresh()
	var second: Game = fresh()
	for room_number: int in range(1, 7):
		var equal_room: bool = first.obstacles == second.obstacles and first.foes.size() == second.foes.size()
		for index: int in range(first.foes.size()):
			equal_room = equal_room and first.foes[index].kind == second.foes[index].kind and first.foes[index].position == second.foes[index].position and first.foes[index].timer == second.foes[index].timer
		check(equal_room, "同じseedで第%d室の配置と敵が再現" % room_number)
		first.clear = true
		second.clear = true
		first.player = Game.EXIT
		second.player = Game.EXIT
		first.interact()
		second.interact()
		check(first.choices == second.choices, "同じseedで第%d室の選択候補が再現" % room_number)
		if room_number < 6:
			first.choose(0)
			second.choose(0)
	first.free()
	second.free()

func verify_complete_run() -> void:
	var game: Game = fresh()
	for room_number: int in range(1, 7):
		check(game.room == room_number and not game.foes.is_empty(), "第%d室が敵を配置して開始" % room_number)
		var valid_spawn: bool = true
		for foe: Game.Foe in game.foes:
			valid_spawn = valid_spawn and game.can_stand(foe.position)
		check(valid_spawn, "第%d室の敵が壁と重ならず出現" % room_number)
		# 進行検証を敵AIの所要時間やプレイヤー操作精度から独立させる。
		game.power = 100
		while not game.foes.is_empty():
			game.player = Vector2(200, 416)
			game.foes[0].position = Vector2(250, 416)
			game.facing = Vector2.RIGHT
			game.attack_wait = 0.0
			game.swing()
		check(game.clear, "第%d室を攻撃で制覇" % room_number)
		game.player = Game.EXIT
		game.interact()
		if room_number < 6:
			game.choose(0)
	check(game.phase == Game.Phase.RESULT and game.best == 6, "6室踏破で勝利結果と最高到達数を記録")
	check(game.collected == game.shards and game.bank == game.shards and game.shards >= 90, "勝利時は全欠片を持ち帰る")
	game.finish("二重入力", true)
	check(game.bank == game.shards, "勝利結果の二重確定でも重複加算しない")
	game.free()
