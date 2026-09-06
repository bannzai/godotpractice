extends RefCounted
## ステージの形状と戦闘の定義はここを正とする。

const MAX_HP: int = 20
const START_GOLD: int = 270
const PATH: Array[Vector2] = [
	Vector2(35, 205), Vector2(265, 205), Vector2(265, 420), Vector2(500, 420),
	Vector2(500, 230), Vector2(720, 230), Vector2(720, 500), Vector2(925, 500),
]
const SITES: Array[Vector2] = [
	Vector2(150, 285), Vector2(180, 370), Vector2(355, 305), Vector2(380, 515),
	Vector2(595, 335), Vector2(620, 145), Vector2(815, 310), Vector2(825, 420),
	Vector2(595, 525), Vector2(125, 135),
]
const TOWERS: Dictionary = {
	"arrow": {"name": "梟の連弩", "role": "速射・対空", "cost": 80,
		"damage": 15.0, "interval": 0.45, "range": 153.0, "splash": 0.0,
		"slow": 1.0, "air": true, "color": Color("a5d477")},
	"mortar": {"name": "岩亀の臼砲", "role": "地上の範囲攻撃", "cost": 110,
		"damage": 43.0, "interval": 1.8, "range": 175.0, "splash": 66.0,
		"slow": 1.0, "air": false, "color": Color("e3a264")},
	"frost": {"name": "雪狐の氷晶", "role": "範囲減速・対空", "cost": 90,
		"damage": 7.0, "interval": 1.05, "range": 152.0, "splash": 64.0,
		"slow": 0.5, "air": true, "color": Color("84dbe8")},
	"sun": {"name": "鹿王の陽光", "role": "装甲貫通・対空", "cost": 140,
		"damage": 78.0, "interval": 1.65, "range": 182.0, "splash": 0.0,
		"slow": 1.0, "air": true, "color": Color("f4d67b")},
}
const ENEMIES: Dictionary = {
	"runner": {"name": "棘走り", "hp": 65.0, "speed": 91.0, "armor": 0.0,
		"reward": 9, "leak": 1, "color": Color("d4a1ab")},
	"armor": {"name": "鉄殻", "hp": 205.0, "speed": 49.0, "armor": 8.0,
		"reward": 17, "leak": 2, "color": Color("aba6ca")},
	"flyer": {"name": "宵羽", "hp": 85.0, "speed": 113.0, "armor": 0.0,
		"reward": 12, "leak": 1, "color": Color("ce9dde")},
	"swarm": {"name": "小茸", "hp": 38.0, "speed": 70.0, "armor": 0.0,
		"reward": 5, "leak": 1, "color": Color("e3b56a")},
	"boss": {"name": "朽木の巨獣", "hp": 2200.0, "speed": 34.0, "armor": 10.0,
		"reward": 160, "leak": 20, "color": Color("d58a99")},
}
const WAVES: Array[Dictionary] = [
	{"name": "森の気配", "groups": [{"kind": "runner", "count": 8}],
		"interval": 0.95, "reward": 45},
	{"name": "胞子の行列", "groups": [{"kind": "swarm", "count": 16}],
		"interval": 0.48, "reward": 45},
	{"name": "鉄殻の足音", "groups": [{"kind": "armor", "count": 5},
		{"kind": "runner", "count": 6}], "interval": 0.8, "reward": 50},
	{"name": "宵羽の襲来", "groups": [{"kind": "flyer", "count": 12}],
		"interval": 0.85, "reward": 50},
	{"name": "混ざり合う群れ", "groups": [{"kind": "swarm", "count": 16},
		{"kind": "armor", "count": 6}], "interval": 0.5, "reward": 55},
	{"name": "空と地の奔流", "groups": [{"kind": "runner", "count": 10},
		{"kind": "flyer", "count": 10}], "interval": 0.6, "reward": 55},
	{"name": "装甲の壁", "groups": [{"kind": "armor", "count": 12},
		{"kind": "swarm", "count": 12}], "interval": 0.55, "reward": 60},
	{"name": "紫の空", "groups": [{"kind": "flyer", "count": 18},
		{"kind": "runner", "count": 10}], "interval": 0.5, "reward": 65},
	{"name": "最後の防衛線", "groups": [{"kind": "armor", "count": 14},
		{"kind": "flyer", "count": 12}, {"kind": "swarm", "count": 15}],
		"interval": 0.42, "reward": 70},
	{"name": "朽木の巨獣", "groups": [{"kind": "armor", "count": 8},
		{"kind": "boss", "count": 1}, {"kind": "flyer", "count": 12},
		{"kind": "swarm", "count": 18}], "interval": 0.52, "reward": 100},
]


static func tower_stats(kind: String, level: int) -> Dictionary:
	if not TOWERS.has(kind) or level < 1 or level > 3:
		return {}
	var stats: Dictionary = TOWERS[kind].duplicate()
	stats.damage *= 1.0 + (level - 1) * 0.7
	stats.range += (level - 1) * 12.0
	stats.interval /= 1.0 + (level - 1) * 0.12
	stats.slow = maxf(0.3, float(stats.slow) - (level - 1) * 0.07) if kind == "frost" else 1.0
	return stats


static func upgrade_cost(kind: String, level: int) -> int:
	if not TOWERS.has(kind) or level < 1 or level >= 3:
		return 0
	return int(float(TOWERS[kind].cost) * (0.7 + (level - 1) * 0.45))


static func sell_value(kind: String, level: int) -> int:
	if not TOWERS.has(kind) or level < 1 or level > 3:
		return 0
	var spent: int = TOWERS[kind].cost
	for prior: int in range(1, level):
		spent += upgrade_cost(kind, prior)
	return int(spent * 0.7)


static func path_length() -> float:
	var length: float = 0.0
	for index: int in range(1, PATH.size()):
		length += PATH[index - 1].distance_to(PATH[index])
	return length


static func path_position(distance: float) -> Vector2:
	var remaining: float = maxf(0.0, distance)
	for index: int in range(1, PATH.size()):
		var length: float = PATH[index - 1].distance_to(PATH[index])
		if remaining <= length:
			return PATH[index - 1].lerp(PATH[index], remaining / length)
		remaining -= length
	return PATH[-1]
