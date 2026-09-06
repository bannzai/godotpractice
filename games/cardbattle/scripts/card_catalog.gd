class_name CardCatalog
extends RefCounted
## カード定義と構築済みデッキの唯一のデータ源。


static func cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var names: Array[String] = [
		"暁の剣士", "火花の斥候", "紅蓮の猟犬", "銅翼の騎士", "炎環の魔術師", "陽光の獅子",
		"熔岩の巨兵", "赤砂の槍使い", "夕焼けの竜", "火山の番人", "焔の戦乙女", "日輪の王",
		"月影の歩哨", "霧の案内人", "氷晶の狼", "銀翼の衛士", "星詠みの賢者", "夜空の梟",
		"深海の巨兵", "蒼霜の槍使い", "月光の竜", "結晶の番人", "雪の戦乙女", "星辰の王",
	]
	var attacks: Array[int] = [1600, 1200, 1800, 1700, 1400, 1900, 2100, 1500, 2300, 1100, 2000, 2400]
	var defenses: Array[int] = [1400, 1600, 1000, 1800, 1700, 1200, 1700, 2000, 1400, 2400, 1500, 1800]
	var attributes: Array[String] = [
		"炎", "風", "炎", "風", "炎", "炎", "炎", "風", "風", "炎", "炎", "炎",
		"土", "水", "水", "土", "水", "水", "水", "水", "水", "土", "水", "土",
	]
	for index: int in names.size():
		var solar: bool = index < 12
		var stat: int = index % 12
		result.append({
			"id": "m%02d" % index, "name": names[index], "type": "monster",
			"attack": attacks[stat] if solar else defenses[stat],
			"defense": defenses[stat] if solar else attacks[stat],
			"level": 3 + int(stat / 4.0), "attribute": attributes[index],
			"effect": "", "text": "通常召喚は１ターン１回。召喚したターンから攻撃できる。",
		})
	result.append(_effect("draw", "巡る星図", "spell", "draw", "自分のデッキから２枚引く。"))
	result.append(_effect("destroy", "崩落の光", "spell", "destroy", "相手のモンスター１体を破壊する。"))
	result.append(_effect("boost", "太陽の加護", "spell", "boost", "自分の１体の攻撃力をターン終了まで７００上げる。"))
	result.append(_effect("snare", "結晶の落とし穴", "trap", "destroy", "相手の攻撃時、攻撃モンスターを破壊する。"))
	result.append(_effect("mist", "夜霧の結界", "trap", "weaken", "相手の攻撃時、その攻撃力をターン終了まで８００下げる。"))
	result.append(_effect("spark", "反響する火花", "trap", "damage", "相手の攻撃時、相手に１０００のライフダメージ。"))
	return result


static func card(id: String) -> Dictionary:
	for entry: Dictionary in cards():
		if entry.id == id:
			return entry
	return {}


static func deck(index: int) -> Array[String]:
	var result: Array[String] = []
	for number: int in range(12):
		for _copy: int in range(2):
			result.append("m%02d" % (number + 12 * clampi(index, 0, 1)))
	for id: String in ["draw", "destroy", "boost", "spark"]:
		for _copy: int in range(3):
			result.append(id)
	for id: String in ["snare", "mist"]:
		result.append_array([id, id])
	return result


static func deck_name(index: int) -> String:
	return "日輪の軍勢" if index == 0 else "月影の守人"


static func _effect(
	id: String, title: String, kind: String, effect: String, detail: String
) -> Dictionary:
	return {
		"id": id, "name": title, "type": kind, "effect": effect, "text": detail,
		"attack": 0, "defense": 0, "level": 0, "attribute": "星",
	}
