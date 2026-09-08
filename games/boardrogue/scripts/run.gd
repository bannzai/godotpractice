extends Node

const Battle = preload("res://scripts/battle.gd")
const STARTER: Array[String] = ["scout", "scout", "blade", "blade", "spear", "archer", "bulwark", "mender"]
const GENERALS: Array[String] = ["灯守の旅団", "霧渡りの将", "赤松の軍師", "鉄扇の将軍", "月蝕の主"]
var battle: RefCounted
var screen: String = "title"
var stage: int = 0
var health: int = 10
var deck: Array[String] = []
var elite: bool = false
var rewards: Array[String] = []
var seed_value: int = 0
var victories: int = 0
var saved: Dictionary = {}
var save_error: String = ""
var save_path: String = "user://expedition.json"

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			save_path = argument.trim_prefix("--save-path=")
	load_checkpoint()

# 新しい遠征を開始する操作だけが乱数の種を更新する。
func new_run() -> void:
	seed_value = int(Time.get_unix_time_from_system())
	stage = 0
	health = 10
	victories = 0
	deck.assign(STARTER)
	screen = "map"
	checkpoint()

func resume_run() -> void:
	if saved.is_empty():
		return
	stage = int(saved.stage)
	health = int(saved.health)
	seed_value = int(saved.seed)
	victories = int(saved.victories)
	deck.assign(saved.deck)
	screen = "map"

# 道の選択によって一度だけ新たな戦闘を生成する。
func choose_route(dangerous: bool) -> void:
	if screen != "map":
		return
	elite = dangerous or stage == 4
	var opposition: Array[String] = ["scout", "blade", "spear", "scout", "archer", "bulwark"]
	if stage > 0:
		opposition.append("knight")
	if elite:
		opposition.append("champion")
		opposition.append("sentinel")
	if stage == 4:
		opposition.append("dragon")
	battle = Battle.new()
	battle.setup(5 if elite else 3, deck, opposition, seed_value + stage * 173 + int(elite), health)
	screen = "battle"

# 勝敗の反映は戦闘画面からの遷移時だけ行い、二重報酬を防ぐ。
func finish_battle() -> void:
	if screen != "battle" or battle.winner == -1:
		return
	health = battle.hp[0]
	if battle.winner != 0:
		screen = "defeat"
		checkpoint()
		return
	victories += 1
	if stage == 4:
		screen = "victory"
		checkpoint()
		return
	health = mini(10, health + 2)
	var pool: Array[String] = []
	for id: String in Battle.CARDS:
		if bool(Battle.CARDS[id].rare) == elite:
			pool.append(id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value + stage
	rewards.clear()
	while rewards.size() < 3 and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		rewards.append(pool.pop_at(index))
	screen = "reward"

# 選択した札を一枚獲得するため非冪等。画面の条件で重複入力を拒否する。
func take_reward(index: int) -> void:
	if screen != "reward" or index < 0 or index >= rewards.size():
		return
	deck.append(rewards[index])
	stage += 1
	screen = "map"
	checkpoint()

func checkpoint() -> void:
	var data: Dictionary = {}
	if screen == "map":
		data = {"version": 1, "stage": stage, "health": health, "seed": seed_value, "victories": victories, "deck": deck}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		save_error = "遠征を保存できませんでした。空き容量と書き込み権限を確認してください"
		return
	file.store_string(JSON.stringify(data))
	file.flush()
	if file.get_error() != OK:
		save_error = "遠征の保存に失敗しました"
		return
	saved = data.duplicate(true)
	save_error = ""

func load_checkpoint() -> void:
	saved = {}
	if not FileAccess.file_exists(save_path):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not value is Dictionary or value.is_empty():
		return
	for key: String in ["version", "stage", "health", "seed", "victories", "deck"]:
		if not value.has(key):
			return
	for key: String in ["version", "stage", "health", "seed", "victories"]:
		if not (value[key] is float or value[key] is int):
			return
		if float(value[key]) != floor(float(value[key])):
			return
	if int(value.version) != 1 or int(value.stage) < 0 or int(value.stage) > 4 or int(value.health) < 1 or int(value.health) > 10:
		return
	if int(value.victories) != int(value.stage):
		return
	if not value.deck is Array or value.deck.size() != STARTER.size() + int(value.stage):
		return
	for id: Variant in value.deck:
		if not id is String or not Battle.CARDS.has(id):
			return
	saved = value
