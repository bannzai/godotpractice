class_name SpiritCatalog
extends RefCounted
## 霊と対戦相手の定義。数値・表示文・画像名の正はこの表に集約する。

const EFFECTS: Array[String] = [
	"aura", "revenge", "veil", "heal", "siege", "ambush", "ward", "draw"
]
const RARITIES: Array[String] = ["常霊", "異霊", "伝承"]
const STARTER: Array[String] = [
	"lantern", "fox", "bell", "willow", "lantern", "fox", "bell", "crow"
]
const CARDS: Dictionary = {
	"lantern": {"name": "灯籠の童", "atk": 3, "rarity": 0, "effect": "heal",
		"description": "登場時、王の命を1回復。", "art": "lantern"},
	"fox": {"name": "灰尾の狐", "atk": 3, "rarity": 0, "effect": "ambush",
		"description": "裏向きで攻撃されると攻撃力+2。", "art": "fox"},
	"bell": {"name": "鈴守り", "atk": 2, "rarity": 0, "effect": "aura",
		"description": "表向きの間、隣接する味方の攻撃力+1。", "art": "bell"},
	"willow": {"name": "柳の女", "atk": 2, "rarity": 0, "effect": "revenge",
		"description": "裏向きで倒されると攻撃者を道連れ。", "art": "willow"},
	"crow": {"name": "墨羽", "atk": 3, "rarity": 0, "effect": "draw",
		"description": "登場時、山札から1枚引く。", "art": "crow"},
	"mask": {"name": "泣き面", "atk": 3, "rarity": 1, "effect": "veil",
		"description": "登場時、最も近い相手の霊を裏向きにする。", "art": "mask"},
	"spider": {"name": "糸繰り", "atk": 4, "rarity": 1, "effect": "ambush",
		"description": "裏向きで攻撃されると攻撃力+2。", "art": "spider"},
	"monk": {"name": "虚無僧", "atk": 3, "rarity": 1, "effect": "ward",
		"description": "自陣の最後列にいる間、攻撃力+1。", "art": "monk"},
	"hound": {"name": "骨犬", "atk": 4, "rarity": 1, "effect": "siege",
		"description": "王への直接攻撃で与える傷+1。", "art": "hound"},
	"dragon": {"name": "淵の龍", "atk": 5, "rarity": 2, "effect": "aura",
		"description": "表向きの間、隣接する味方の攻撃力+1。", "art": "dragon"},
	"empress": {"name": "白蓮の后", "atk": 5, "rarity": 2, "effect": "heal",
		"description": "登場時、王の命を1回復。", "art": "empress"},
	"reaper": {"name": "黄泉渡し", "atk": 5, "rarity": 2, "effect": "revenge",
		"description": "裏向きで倒されると攻撃者を道連れ。", "art": "reaper"}
}
const ENEMIES: Dictionary = {
	"ghost": {"name": "迷いの霊", "art": "ghost", "lines": {
		"start": "この先は、帰れぬ道。あなたにも聞こえるでしょう。",
		"attack": "その灯りを、わたしに。", "hurt": "まだ、消えたくない。",
		"reveal": "見つけてしまったのですね。", "defeat": "ようやく……夜が明ける。",
		"idle": "置き去りにされた名前を、覚えていますか。"}},
	"general": {"name": "朽ち鎧の将", "art": "general", "lines": {
		"start": "百年守った門だ。お前の業を見せてみよ。",
		"attack": "死者にも、退かぬ理由がある。", "hurt": "よい一手だ。だが門は開かぬ。",
		"reveal": "名乗りもせず、わしに挑むか。", "defeat": "進め。お前はまだ、人に戻れる。",
		"idle": "勝つために何を捨てる。"}},
	"police": {"name": "夜廻りの番人", "art": "police", "lines": {
		"start": "墓土の匂いがする。そこで足を止めろ。",
		"attack": "これ以上、夜を汚させはしない。", "hurt": "人の心まで失ったか。",
		"reveal": "隠しても無駄だ。", "defeat": "お前の影は……もう人の形ではない。",
		"idle": "今なら、まだ引き返せる。"}}
}


static func card(card_id: String) -> Dictionary:
	return CARDS.get(card_id, {})


static func enemy(enemy_id: String) -> Dictionary:
	return ENEMIES.get(enemy_id, ENEMIES.ghost)


static func ids_for_rarity(rarity: int) -> Array[String]:
	var ids: Array[String] = []
	for card_id: String in CARDS:
		if int(CARDS[card_id].rarity) == rarity:
			ids.append(card_id)
	return ids
