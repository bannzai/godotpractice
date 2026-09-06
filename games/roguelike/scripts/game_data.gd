class_name RogueData
extends RefCounted
## 戦闘と出現抽選に使う唯一の定義。

const LAST_FLOOR: int = 5
const PACK_LIMIT: int = 12
const ENEMIES: Dictionary = {
	"chaser": {"name": "苔歩き", "hp": 12, "attack": 5, "defense": 0, "xp": 7,
		"ai": "chase", "color": Color("96c989")},
	"archer": {"name": "灯射手", "hp": 15, "attack": 6, "defense": 1, "xp": 11,
		"ai": "ranged", "color": Color("e9ae68")},
	"splitter": {"name": "雫の群れ", "hp": 18, "attack": 5, "defense": 1, "xp": 10,
		"ai": "split", "color": Color("66c4dc")},
	"sleeper": {"name": "眠り石", "hp": 26, "attack": 9, "defense": 3, "xp": 17,
		"ai": "sleep", "color": Color("c9a6dd")},
	"swift": {"name": "影走り", "hp": 18, "attack": 7, "defense": 1, "xp": 15,
		"ai": "swift", "color": Color("ea8899")},
	"boss": {"name": "深淵の番人", "hp": 100, "attack": 13, "defense": 4, "xp": 80,
		"ai": "boss", "color": Color("f6cf7b")},
}
const FLOOR_ENEMIES: Array = [
	["chaser", "chaser", "sleeper"],
	["chaser", "archer", "splitter"],
	["archer", "splitter", "sleeper", "swift"],
	["splitter", "sleeper", "swift", "archer"],
	["sleeper", "swift", "archer"],
]
const ITEMS: Dictionary = {
	"blade": {"image": "weapon", "name": "旅人の剣", "type": "weapon", "power": 4,
		"description": "装備すると攻撃 +4。"},
	"sunblade": {"image": "weapon", "name": "暁の剣", "type": "weapon", "power": 8,
		"description": "装備すると攻撃 +8。"},
	"shield": {"image": "shield", "name": "木の盾", "type": "shield", "power": 2,
		"description": "装備すると防御 +2。"},
	"ironshield": {"image": "shield", "name": "古鉄の盾", "type": "shield", "power": 5,
		"description": "装備すると防御 +5。"},
	"herb": {"image": "herb", "name": "灯り草", "type": "heal", "power": 35,
		"description": "HP を 35 回復する。"},
	"food": {"image": "food", "name": "木の実パン", "type": "food", "power": 60,
		"description": "満腹度を 60 回復する。"},
	"fire": {"image": "scroll_fire", "name": "烈火の巻物", "unknown": "朱色の巻物",
		"type": "scroll", "power": 32,
		"description": "同じ部屋の敵全体に 32 ダメージ。"},
	"warp": {"image": "scroll_warp", "name": "帰路の巻物", "unknown": "藍色の巻物", "type": "scroll", "power": 0,
		"description": "この階の階段へワープする。"},
	"wand": {"image": "wand", "name": "突風の杖", "unknown": "曲がった杖", "type": "wand", "power": 24,
		"description": "向いている方向へ突風。敵に 24 ダメージと吹き飛ばし。"},
}
const LOOT: Array[String] = ["herb", "food", "herb", "fire", "warp", "wand"]
