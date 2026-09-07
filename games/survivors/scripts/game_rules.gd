extends RefCounted
## 時間による敵編成と成長の規則。描画や入力から独立して検証する。

const DURATION: float = 600.0
const MAX_ENEMIES: int = 360
const WEAPON_NAMES: Dictionary = {"bolt": "光の矢", "orbit": "衛星刃", "pulse": "波動環"}
const SPAWN_TABLE: Array[Dictionary] = [
	{"time": 0.0, "interval": 1.1, "count": 2, "kinds": [0]},
	{"time": 60.0, "interval": 0.85, "count": 3, "kinds": [0, 1]},
	{"time": 150.0, "interval": 0.65, "count": 4, "kinds": [0, 1, 2]},
	{"time": 300.0, "interval": 0.45, "count": 5, "kinds": [0, 1, 2]},
	{"time": 450.0, "interval": 0.3, "count": 6, "kinds": [0, 1, 2]},
	{"time": 570.0, "interval": 0.25, "count": 7, "kinds": [0, 1, 2]},
]
const ENEMY_STATS: Array[Dictionary] = [
	{"hp": 24.0, "speed": 57.0, "radius": 16.0, "damage": 9.0, "xp": 2},
	{"hp": 18.0, "speed": 112.0, "radius": 12.0, "damage": 7.0, "xp": 3},
	{"hp": 100.0, "speed": 40.0, "radius": 23.0, "damage": 16.0, "xp": 7},
	{"hp": 3500.0, "speed": 75.0, "radius": 50.0, "damage": 28.0, "xp": 100},
]


static func spawn_stage(seconds: float) -> Dictionary:
	var selected: Dictionary = SPAWN_TABLE[0]
	for stage: Dictionary in SPAWN_TABLE:
		if seconds < float(stage.time):
			break
		selected = stage
	return selected


static func enemy_stats(kind: int) -> Dictionary:
	return ENEMY_STATS[clampi(kind, 0, ENEMY_STATS.size() - 1)]


static func xp_needed(current_level: int) -> int:
	return 7 + current_level * 5


static func upgrade_name(id: String) -> String:
	return str(WEAPON_NAMES.get(id, {
		"tempo": "加速する鼓動", "power": "集中力", "speed": "軽やかな足", "health": "生命の器", "reach": "収集の輪"
	}.get(id, id)))


static func upgrade_description(id: String) -> String:
	return str({
		"bolt": "近くの敵へ自動射撃。強化で威力と発射数が上昇。",
		"orbit": "周囲を巡る刃。強化で刃の数と威力が上昇。",
		"pulse": "一定間隔で範囲攻撃。強化で範囲と威力が上昇。",
		"power": "すべての武器の威力 +15%",
		"tempo": "自動攻撃の速度 +8%",
		"speed": "移動速度 +12（最大 350）",
		"health": "最大 HP +20、HP を 35 回復",
		"reach": "経験値の収集範囲 +18（最大 220）",
	}.get(id, ""))
