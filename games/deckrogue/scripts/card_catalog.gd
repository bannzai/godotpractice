extends RefCounted
## コスト・効果・レアリティはこのデータから処理と表示の両方に使う。

const CARDS: Dictionary = {
	"strike": {"name": "火花斬り", "type": "attack", "cost": 1,
		"rarity": "基本", "effects": {"damage": 7}},
	"guard": {"name": "構え", "type": "skill", "cost": 1,
		"rarity": "基本", "effects": {"block": 6}},
	"fracture": {"name": "砕く一撃", "type": "attack", "cost": 2,
		"rarity": "基本", "effects": {"damage": 10, "vulnerable": 2}},
	"quick": {"name": "瞬撃", "type": "attack", "cost": 0,
		"rarity": "通常", "effects": {"damage": 4}},
	"heavy": {"name": "落雷", "type": "attack", "cost": 2,
		"rarity": "通常", "effects": {"damage": 17}},
	"siphon": {"name": "命の火", "type": "attack", "cost": 1,
		"rarity": "希少", "effects": {"damage": 6, "heal": 3}},
	"feint": {"name": "霞斬り", "type": "attack", "cost": 1,
		"rarity": "通常", "effects": {"damage": 5, "weak": 2}},
	"flow": {"name": "流れる刃", "type": "attack", "cost": 1,
		"rarity": "通常", "effects": {"damage": 6, "draw": 1}},
	"fortress": {"name": "石の壁", "type": "skill", "cost": 2,
		"rarity": "通常", "effects": {"block": 16}},
	"insight": {"name": "先読み", "type": "skill", "cost": 0,
		"rarity": "通常", "effects": {"draw": 2}, "exhaust": true},
	"renew": {"name": "再生の光", "type": "skill", "cost": 1,
		"rarity": "希少", "effects": {"heal": 9}, "exhaust": true},
	"charge": {"name": "火をくべる", "type": "skill", "cost": 0,
		"rarity": "希少", "effects": {"energy": 2}, "exhaust": true},
	"smoke": {"name": "煙幕", "type": "skill", "cost": 1,
		"rarity": "通常", "effects": {"block": 5, "weak": 2}},
	"expose": {"name": "綻び", "type": "skill", "cost": 0,
		"rarity": "通常", "effects": {"vulnerable": 2}},
	"fervor": {"name": "消えない炎", "type": "power", "cost": 1,
		"rarity": "希少", "effects": {"strength": 3}},
	"aegis": {"name": "護りの灯", "type": "power", "cost": 1,
		"rarity": "希少", "effects": {"armor": 4}},
	"focus": {"name": "澄んだ心", "type": "power", "cost": 1,
		"rarity": "希少", "effects": {"draw_bonus": 1}},
	"bash": {"name": "盾打ち", "type": "attack", "cost": 1,
		"rarity": "通常", "effects": {"damage": 5, "block": 5}},
}
const TYPES: Dictionary = {"attack": "攻撃", "skill": "スキル", "power": "パワー"}
const RELICS: Dictionary = {
	"ember": {"name": "熾火の石", "text": "戦闘開始時、筋力 +2。", "strength": 2},
	"shell": {"name": "琥珀の殻", "text": "毎ターン、ブロック +3。", "armor": 3},
	"seed": {"name": "芽吹きの種", "text": "戦闘勝利時、HP を6回復。", "heal": 6},
}
const ENEMIES: Dictionary = {
	"moth": {"name": "灰羽の蛾", "hp": 30,
		"moves": [{"kind": "attack", "amount": 7}, {"kind": "weak", "amount": 2},
			{"kind": "attack", "amount": 11}]},
	"sentinel": {"name": "苔の番人", "hp": 36,
		"moves": [{"kind": "block", "amount": 9}, {"kind": "attack", "amount": 10},
			{"kind": "strength", "amount": 2}]},
	"brute": {"name": "岩角の獣", "hp": 40,
		"moves": [{"kind": "attack", "amount": 9}, {"kind": "strength", "amount": 2},
			{"kind": "attack", "amount": 13}]},
	"boss": {"name": "夜を抱く巨像", "hp": 105,
		"moves": [{"kind": "attack", "amount": 12}, {"kind": "vulnerable", "amount": 2},
			{"kind": "attack", "amount": 18}, {"kind": "strength", "amount": 3}]},
}
const EFFECT_LABELS: Dictionary = {
	"damage": "ダメージ %d", "block": "ブロック %d", "draw": "%d枚ドロー",
	"heal": "HP %d回復", "energy": "エネルギー +%d", "weak": "敵に弱体 %d",
	"vulnerable": "敵に脆弱 %d", "strength": "戦闘中、筋力 +%d",
	"armor": "毎ターン、ブロック +%d", "draw_bonus": "毎ターン、ドロー +%d",
}


static func card_text(id: String) -> String:
	var card: Dictionary = CARDS[id]
	var lines: PackedStringArray = []
	var effects: Dictionary = card.effects
	for key: String in effects:
		lines.append(EFFECT_LABELS[key] % int(effects[key]))
	if card.get("exhaust", false):
		lines.append("廃棄（再使用不可）")
	if card.type == "power":
		lines.append("廃棄・戦闘中持続")
	return "\n".join(lines)
