class_name BoardCatalog
extends RefCounted
## 札・相手の能力と文言の正。

const CARDS: Dictionary = {
	"reed": {"name": "葦の番兵", "atk": 1, "rarity": 0, "effect": "anchor",
		"text": "敗れたとき、勝者を自分のマスへ移動させない。"},
	"blade": {"name": "朱の剣客", "atk": 3, "rarity": 0, "effect": "duelist",
		"text": "表向きの札への攻撃時、攻撃力が1上がる。"},
	"veil": {"name": "夜渡り", "atk": 2, "rarity": 0, "effect": "infiltrate",
		"text": "表向きなら、配置換えで隣接する敵札とも入れ替えられる。"},
	"bow": {"name": "月弦の射手", "atk": 2, "rarity": 0, "effect": "ranged",
		"text": "上下左右の2マス先にも攻撃できる。間の札を飛び越す。"},
	"oracle": {"name": "星読み", "atk": 1, "rarity": 1, "effect": "reveal",
		"text": "各自ターン1回、潜伏中の敵札1枚を登場させる。"},
	"wraith": {"name": "泥の亡霊", "atk": -1, "rarity": 1, "effect": "revenge",
		"text": "潜伏中に攻撃されたら、攻撃した札とともに捨て場へ。"},
	"shield": {"name": "鉄傘の衛士", "atk": 1, "rarity": 0, "effect": "guard",
		"text": "攻撃を受けるとき、攻撃力が2上がる。"},
	"lancer": {"name": "暁の槍手", "atk": 3, "rarity": 1, "effect": "siege",
		"text": "王に与えるダメージが1増える。"},
	"monk": {"name": "灯守", "atk": 1, "rarity": 1, "effect": "heal",
		"text": "各自ターン1回、自分の王を1回復する。上限10。"},
	"drummer": {"name": "陣太鼓", "atk": 1, "rarity": 1, "effect": "aura",
		"text": "表向きの間、隣接する味方札の攻撃力が1上がる。"},
	"fox": {"name": "白面の使い", "atk": 2, "rarity": 2, "effect": "insight",
		"text": "自分の操作で登場したとき、札を1枚引く。"},
	"dragon": {"name": "墨龍", "atk": 5, "rarity": 2, "effect": "terror",
		"text": "攻撃で敵札を倒したとき、敵の王に1ダメージ。"},
}
const STARTER: Array[String] = ["reed", "reed", "blade", "blade", "bow", "veil", "shield", "oracle"]
const RARITY_NAMES: Array[String] = ["並", "上", "稀"]
const PRICES: Array[int] = [24, 40, 65]
const ENEMIES: Dictionary = {
	"scout": {"name": "霧路の斥候", "title": "街道の先陣", "deck":
		["reed", "reed", "reed", "shield", "veil", "bow", "monk", "reed"], "lines": {
		"start": "この霧の先へは通さぬ。札を見せてみろ。",
		"attack": "そこが空いたな。踏み込むぞ！", "hurt": "王を狙うか……油断ならぬ。",
		"lost": "倒れても、道は譲らぬ。", "defeat": "見事だ。この先には将が待つ。"}},
	"duelist": {"name": "雨衣の剣将", "title": "濡れた刃", "deck":
		["blade", "reed", "bow", "veil", "shield", "oracle", "reed", "lancer"], "lines": {
		"start": "一手のためらいが、命を分ける。", "attack": "受けてみよ、この一閃。",
		"hurt": "よい読みだ。だが、まだ終わらぬ。", "lost": "刃を折っても意地は折れぬ。",
		"defeat": "その一手、胸に刻んだ。先へ行け。"}},
	"general": {"name": "黒陣の大将", "title": "影を率いる者", "deck":
		["wraith", "veil", "drummer", "blade", "shield", "fox", "lancer", "wraith"], "lines": {
		"start": "表の強さだけで、勝てると思うな。", "attack": "伏せた影が牙をむく。",
		"hurt": "わしの陣を抜いたか。面白い。", "lost": "一枚失おうと、策は尽きぬ。",
		"defeat": "わしの秘札を持て。天守への道は険しいぞ。"}},
	"final": {"name": "白灰の城主", "title": "最後の天守", "deck":
		["dragon", "wraith", "veil", "shield", "blade", "oracle", "drummer", "lancer"], "lines": {
		"start": "幾つの道を越え、ここへ来た。最後の一局を始めよう。",
		"attack": "城の影は、お前の王まで届く。", "hurt": "この天守に傷をつけるとはな。",
		"lost": "散る墨も、次の手の糧となる。", "defeat": "夜は明けた。この道の先は、お前が描け。"}},
}


static func card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})


static func valid_cards(cards: Variant, minimum: int = 0, maximum: int = 80) -> bool:
	if not cards is Array or cards.size() < minimum or cards.size() > maximum:
		return false
	for card_id: Variant in cards:
		if not card_id is String or not CARDS.has(card_id):
			return false
	return true
