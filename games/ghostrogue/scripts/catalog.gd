extends RefCounted
## 霊・技・属性の定義は図鑑と戦闘で共有する。

const TYPES: Dictionary = {"grudge": "怨", "sorrow": "哀", "rage": "怒"}
const RARITIES: Dictionary = {1: "残響", 2: "異霊", 3: "大霊"}
const ADVANTAGE: Dictionary = {"grudge": "sorrow", "sorrow": "rage", "rage": "grudge"}
const MOVES: Dictionary = {
	"touch": {"name": "冷たい指", "power": 1.0, "cost": 0},
	"weep": {"name": "帰りたい声", "power": 1.9, "cost": 2},
	"slash": {"name": "錆びた刃", "power": 1.0, "cost": 0},
	"oath": {"name": "残月の誓い", "power": 2.0, "cost": 3},
	"ripple": {"name": "水の手", "power": 1.0, "cost": 0},
	"drown": {"name": "底なしの抱擁", "power": 1.8, "cost": 2},
	"claw": {"name": "爪痕", "power": 1.0, "cost": 0},
	"foxfire": {"name": "狐火の輪", "power": 1.8, "cost": 2},
	"cleave": {"name": "断ち切り", "power": 1.0, "cost": 0},
	"revenge": {"name": "首なき宣告", "power": 2.1, "cost": 3},
	"needle": {"name": "縫い針", "power": 1.0, "cost": 0},
	"curse": {"name": "身代わりの呪い", "power": 2.0, "cost": 3},
	"chant": {"name": "読経", "power": 1.0, "cost": 0},
	"sutra": {"name": "忘却の真言", "power": 1.8, "cost": 2},
	"wing": {"name": "羽音", "power": 1.0, "cost": 0},
	"dream": {"name": "悪夢の鱗粉", "power": 1.8, "cost": 2},
	"thread": {"name": "赤い糸", "power": 1.0, "cost": 0},
	"vow": {"name": "永遠の契り", "power": 2.1, "cost": 3},
	"beak": {"name": "黒い嘴", "power": 1.0, "cost": 0},
	"eclipse": {"name": "日蝕の群れ", "power": 2.0, "cost": 3},
	"chime": {"name": "弔いの音", "power": 1.0, "cost": 0},
	"toll": {"name": "最後の鐘", "power": 2.1, "cost": 3},
	"fang": {"name": "鋭い牙", "power": 1.0, "cost": 0},
	"howl": {"name": "山を裂く咆哮", "power": 2.0, "cost": 3},
	"seal": {"name": "封魂の札", "power": 1.0, "cost": 0},
	"judgment": {"name": "戒厳の鎖", "power": 1.5, "cost": 0},
	"shadow": {"name": "夜の爪", "power": 1.0, "cost": 0},
	"midnight": {"name": "真夜中の葬列", "power": 1.5, "cost": 0},
}
const SPIRITS: Dictionary = {
	"child": {
		"name": "迷い子", "type": "sorrow", "rarity": 1,
		"hp": 64, "attack": 12, "speed": 17, "moves": ["touch", "weep"],
		"lore": "迎えを待ち続ける子。あなたの妹の声に、少しだけ似ている。",
	},
	"warrior": {
		"name": "落武者", "type": "rage", "rarity": 1,
		"hp": 86, "attack": 15, "speed": 8, "moves": ["slash", "oath"],
		"lore": "名も残らなかった兵。護るべき人の名だけを覚えている。",
	},
	"water": {
		"name": "水底の女", "type": "grudge", "rarity": 1,
		"hp": 76, "attack": 13, "speed": 12, "moves": ["ripple", "drown"],
		"lore": "橋の下で待つ女。水面に映るのは生前の家の灯り。",
	},
	"fox": {
		"name": "灯狐", "type": "rage", "rarity": 1,
		"hp": 60, "attack": 14, "speed": 21, "moves": ["claw", "foxfire"],
		"lore": "古い祠に棲む小さな狐火。供物の油揚げを今も探す。",
	},
	"headless": {
		"name": "首なし番人", "type": "grudge", "rarity": 2,
		"hp": 102, "attack": 19, "speed": 9, "moves": ["cleave", "revenge"],
		"lore": "首を失っても門を護る。その忠義は、とうに呪いへ変わった。",
	},
	"doll": {
		"name": "縫い目の人形", "type": "sorrow", "rarity": 2,
		"hp": 80, "attack": 20, "speed": 13, "moves": ["needle", "curse"],
		"lore": "持ち主を失うたび、縫い目が一本ずつ増える人形。",
	},
	"monk": {
		"name": "無言の僧", "type": "sorrow", "rarity": 2,
		"hp": 112, "attack": 17, "speed": 7, "moves": ["chant", "sutra"],
		"lore": "救えなかった人々の数だけ、誰にも届かぬ経を唱える。",
	},
	"moth": {
		"name": "夢喰い蛾", "type": "grudge", "rarity": 2,
		"hp": 74, "attack": 19, "speed": 25, "moves": ["wing", "dream"],
		"lore": "眠る町に影を落とす。羽の模様に誰かの悪夢が浮かぶ。",
	},
	"bride": {
		"name": "紅衣の花嫁", "type": "grudge", "rarity": 3,
		"hp": 118, "attack": 26, "speed": 18, "moves": ["thread", "vow"],
		"lore": "約束の日を待ち続ける魂。生きた依代を断つ者だけに従う。",
	},
	"crow": {
		"name": "三眼の鴉", "type": "rage", "rarity": 3,
		"hp": 98, "attack": 27, "speed": 30, "moves": ["beak", "eclipse"],
		"lore": "夜明けを見抜く三つの目。まだ温かい命に繋がれている。",
	},
	"bell": {
		"name": "弔鐘の主", "type": "sorrow", "rarity": 3,
		"hp": 146, "attack": 25, "speed": 6, "moves": ["chime", "toll"],
		"lore": "鐘楼の生きた宿主に巣食う。最後の一打で世界を黙らせる。",
	},
	"beast": {
		"name": "山喰いの獣", "type": "rage", "rarity": 3,
		"hp": 132, "attack": 29, "speed": 15, "moves": ["fang", "howl"],
		"lore": "大きな獣の内に眠る古い霊。命を奪うことでしか姿を現さない。",
	},
}
const ENEMIES: Dictionary = {
	"police": {
		"name": "封魂警官", "type": "sorrow", "rarity": 2,
		"hp": 112, "attack": 17, "speed": 15, "moves": ["seal", "judgment"],
		"lore": "霊災を封じる夜間巡回隊。あなたの影の濃さを見ている。",
	},
	"boss": {
		"name": "夜葬の主", "type": "grudge", "rarity": 3,
		"hp": 310, "attack": 23, "speed": 14, "moves": ["shadow", "midnight"],
		"lore": "妹の声を奪い、町を終わらない夜に閉じ込めた大霊。",
	},
}
const NODE_LABELS: Dictionary = {
	"battle": "漂う霊", "grave": "忘れられた墓", "living": "生きた依代",
	"police": "夜間巡回", "rest": "灯りの祠", "story": "夜の記憶", "boss": "夜葬の門",
}


static func spirit(id: String) -> Dictionary:
	return SPIRITS.get(id, ENEMIES.get(id, {}))


static func create_spirit(id: String, uid: int) -> Dictionary:
	if spirit(id).is_empty():
		return {}
	return {"uid": uid, "species": id, "hp": int(spirit(id).hp)}


static func matchup(attack_type: String, defense_type: String) -> float:
	if not TYPES.has(attack_type) or not TYPES.has(defense_type):
		return 1.0
	if attack_type == defense_type:
		return 1.0
	return 2.0 if ADVANTAGE[attack_type] == defense_type else 0.5


static func damage(attacker: Dictionary, defender: Dictionary, move_index: int,
		darkness: int = 0) -> int:
	var definition: Dictionary = spirit(attacker.species)
	var move: Dictionary = MOVES[definition.moves[clampi(move_index, 0, 1)]]
	var bonus: float = 1.25 if darkness >= 30 else 1.0
	return maxi(1, roundi(float(definition.attack) * float(move.power) * bonus
		* matchup(definition.type, spirit(defender.species).type)))


static func integer_between(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= low and value <= high and value == int(value)


static func valid_spirit(value: Variant, enemy: bool = false) -> bool:
	if not value is Dictionary or value.size() != 3:
		return false
	if not value.has_all(["uid", "species", "hp"]) or not value.species is String:
		return false
	if not SPIRITS.has(value.species) and not (enemy and ENEMIES.has(value.species)):
		return false
	return integer_between(value.uid, -100, 1000) and int(value.uid) != 0 \
		and integer_between(value.hp, 1, int(spirit(value.species).hp))
