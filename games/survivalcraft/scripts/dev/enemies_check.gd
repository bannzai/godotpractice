extends RefCounted
## 夜の出現・灯り・攻撃・朝の消滅を本番の敵制御で検証する。

const State := preload("res://scripts/survival_state.gd")
const Director := preload("res://scripts/enemies.gd")
const Data := preload("res://scripts/voxel_data.gd")
var failed: bool = false

func _require(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)

func run(tree: SceneTree) -> bool:
	var stage: Node3D = Node3D.new()
	tree.root.add_child(stage)
	var state: Node = State.new()
	stage.add_child(state)
	state.new_game()
	var effects: Node3D = load("res://scripts/effects.gd").new()
	stage.add_child(effects)
	var director: Node3D = Director.new()
	stage.add_child(director)
	director.configure(state, effects)
	var player: Node3D = Node3D.new()
	stage.add_child(player)
	player.position = state.data.spawn
	var point: Vector3 = Vector3(16.5, 7.0, 16.5)
	_require(Director.can_spawn(state.data, point), "地面の開放空間に出現可能")
	state.data.set_block(Vector3i(19, 7, 16), Data.TORCH)
	_require(not Director.can_spawn(state.data, point), "たいまつ半径内には出現しない")
	state.data.set_block(Vector3i(19, 7, 16), Data.AIR)
	state.day_time = 0.75
	director.step(0.016, player)
	_require(state.enemies.size() >= 2, "夜に敵が出現")
	var kinds: Array = []
	for enemy: Dictionary in state.enemies:
		kinds.append(enemy.kind)
	_require("mossling" in kinds and "wisp" in kinds, "夜に近接と遠隔の両方が出現")
	for i: int in range(9):
		director.step(12.0, player)
	_require(state.enemies.size() <= 6, "敵の最大数")
	state.day_time = 0.3
	director.step(0.1, player)
	for enemy: Dictionary in state.enemies:
		_require(enemy.dying, "朝に消滅アニメーションへ遷移")
	director.step(1.0, player)
	_require(state.enemies.is_empty(), "朝に敵を解放")
	_require(state.projectiles.is_empty(), "朝に弾を解放")
	director.reset()
	var enemy: Dictionary = {"id": 900, "kind": "mossling", "position": Vector3(16.5, 7, 14.5),
		"hp": 10.0, "cooldown": 1.0, "dying": false, "fade": 0.0}
	state.enemies.append(enemy)
	state.tool_level = 2
	_require(director.attack(Vector3(16.5, 8, 16.5), Vector3.FORWARD), "照準で敵を攻撃")
	_require(enemy.dying, "撃破で消滅")
	_require(int(state.inventory.get("meat", 0)) == 1, "撃破素材を獲得")
	director.reset()
	enemy = {"id": 901, "kind": "mossling", "position": Vector3(16.5, 7, 13.5),
		"hp": 30.0, "cooldown": 1.0, "dying": false, "fade": 0.0}
	state.enemies.append(enemy)
	state.data.set_block(Vector3i(16, 8, 15), Data.STONE)
	_require(not director.attack(Vector3(16.5, 8.2, 16.5), Vector3.FORWARD), "壁の向こうの敵には攻撃不可")
	_require(not Director.line_clear(state.data, Vector3(16.5, 8.2, 16.5),
		Vector3(16.5, 8.2, 13.5)), "弾の地形遮蔽")
	director.reset()
	director.reset()
	await tree.process_frame
	_require(director.views.is_empty(), "再開始の敵表示リセット")
	stage.queue_free()
	await tree.process_frame
	return not failed
