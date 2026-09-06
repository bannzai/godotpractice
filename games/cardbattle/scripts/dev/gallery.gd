extends RefCounted
## 全キャラの開始・途中・終了ポーズを同じ画面に並べ、実描画で比較する。

const Actor = preload("res://scripts/card_actor.gd")
const Catalog = preload("res://scripts/card_catalog.gd")
const LABELS: Dictionary = {
	"idle": "待機",
	"summon": "召喚",
	"attack": "攻撃",
	"hit": "被弾",
	"death": "死亡",
}


# 検証用ノードを順番に表示して PNG を出力するため非冪等。
static func capture_characters(tree: SceneTree, main: Control) -> bool:
	main.visible = false
	for card: Dictionary in Catalog.cards():
		if card.type != "monster":
			continue
		var page: Control = _page(main.theme, card.name + "  /  アニメーションの連続フレーム")
		tree.root.add_child(page)
		for row: int in Actor.ACTIONS.size():
			var action: String = Actor.ACTIONS[row]
			_text(page, LABELS[action], Vector2(35, 109 + row * 118), 23)
			for column: int in range(3):
				var actor := Actor.new()
				actor.position = Vector2(190 + column * 355, 91 + row * 118)
				page.add_child(actor)
				actor.setup(card.id, Vector2(320, 100))
				var ratio: float = [0.0, 0.45, 1.0][column]
				actor.seek_action(action, actor.animation_length(action) * ratio)
		if not await _save(tree, "character-" + card.id):
			page.queue_free()
			return false
		page.queue_free()
		await tree.process_frame
	main.visible = true
	return true


static func capture_cards(tree: SceneTree, main: Control) -> bool:
	main.visible = false
	for group: int in range(3):
		var page: Control = _page(
			main.theme, "カード固有イラスト  /  %d〜%d" % [group * 12 + 1, mini(30, group * 12 + 12)], false
		)
		tree.root.add_child(page)
		var cards: Array[Dictionary] = Catalog.cards()
		for offset: int in range(mini(12, cards.size() - group * 12)):
			var card: Dictionary = cards[group * 12 + offset]
			var origin := Vector2(30 + (offset % 4) * 313, 85 + int(offset / 4.0) * 207)
			var actor := Actor.new()
			actor.position = origin
			page.add_child(actor)
			actor.setup(card.id, Vector2(280, 159))
			actor.seek_action("idle", 0.0)
			_text(page, card.name, origin + Vector2(12, 166), 19)
		if not await _save(tree, "cards-%d" % group):
			page.queue_free()
			return false
		page.queue_free()
		await tree.process_frame
	main.visible = true
	return true


static func _page(theme: Theme, caption: String, columns: bool = true) -> Control:
	var page := Control.new()
	page.theme = theme
	page.size = Vector2(1280, 720)
	var background := ColorRect.new()
	background.color = Color("081420")
	background.size = page.size
	page.add_child(background)
	_text(page, caption, Vector2(32, 14), 25)
	if columns:
		for column: int in range(3):
			_text(page, ["開始", "途中", "終了"][column], Vector2(290 + column * 355, 61), 17)
	return page


static func _text(page: Control, text: String, position: Vector2, pixels: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", Color("e4ca8e"))
	page.add_child(label)


static func _save(tree: SceneTree, name: String) -> bool:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name
	var error: Error = tree.root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("連続フレームの保存失敗: " + path)
		return false
	print("screenshot: " + path)
	return true
