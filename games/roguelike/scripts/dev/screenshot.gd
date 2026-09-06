extends SceneTree
## 実際の画面・全キャラの連続姿勢・演出途中を、保存データを変更せず撮影する。

const UI := preload("res://scripts/ui.gd")
const Actor := preload("res://scripts/actor_view.gd")
const Data := preload("res://scripts/game_data.gd")
const CHARACTERS: Array[String] = [
	"hero", "chaser", "archer", "splitter", "sleeper", "swift", "boss"
]
const ACTIONS: Dictionary = {
	"idle": "待機", "move": "移動", "attack": "攻撃",
	"hurt": "被弾", "death": "消滅", "appear": "登場"
}

var main: Node
var run: Node


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_run.call_deferred()


## 撮影と時間進行は一度だけ実行し、失敗時も音声を終了してから閉じる。
func _run() -> void:
	run = root.get_node("RunState")
	run.save_enabled = false
	root.get_node("Sound").set_muted(true)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var succeeded: bool = await _capture_scenes()
	main.return_title()
	await root.get_node("Sound").shutdown()
	main.queue_free()
	await process_frame
	quit(0 if succeeded else 1)


func _capture_scenes() -> bool:
	for capture: Callable in [
		_capture_opening, _capture_menus, _capture_floors, _capture_effects, _capture_results
	]:
		if not await capture.call():
			return false
	main.hide()
	var succeeded: bool = await _capture_animations()
	main.show()
	return succeeded


func _capture_opening() -> bool:
	await create_timer(0.5).timeout
	if not await _capture("title"):
		return false
	main._open_help()
	if not await _capture("help"):
		return false
	main._close_modal()
	main.start_new(609)
	await create_timer(0.55).timeout
	# この一枚は fixture を使わず、通常の開始直後の視界を記録する。
	if not await _capture("play"):
		return false
	return true


func _capture_menus() -> bool:
	# 容量上限・全種類と未識別表示を同時に点検するための持ち物 fixture。
	run.inventory.assign([
		"blade", "sunblade", "shield", "ironshield", "herb", "food",
		"fire", "warp", "wand", "herb", "food", "wand"
	])
	main._open_inventory()
	if not await _capture("inventory"):
		return false
	main._select_item(6)
	if not await _capture("item-unknown"):
		return false
	run.identified["fire"] = true
	main._select_item(6)
	if not await _capture("item"):
		return false
	main._close_modal()
	main._open_pause()
	if not await _capture("pause"):
		return false
	main._close_modal()
	main.board.map_open = true
	main.board.queue_redraw()
	if not await _capture("map"):
		return false
	main.board.map_open = false
	main.board.queue_redraw()
	return true


func _capture_floors() -> bool:
	for depth: int in range(1, 6):
		_floor_fixture(depth)
		await create_timer(0.6).timeout
		if not await _capture("floor-%d" % depth):
			return false
	# 5階 fixture は番人と最深階の通常敵を同じ視界へ置く。
	if not await _capture("boss"):
		return false
	return true


## 同じ階番号・seed から毎回同じ撮影用配置を作り直す。
func _floor_fixture(depth: int) -> void:
	run.floor_number = depth
	run._generate_floor()
	var room: Rect2i = run.dungeon.rooms[0]
	run.player_pos = room.position + Vector2i(1, 1)
	run.enemies.clear()
	var choices: Array = Data.FLOOR_ENEMIES[depth - 1]
	var places: Array[Vector2i] = [
		run.player_pos + Vector2i(1, 0),
		run.player_pos + Vector2i(0, 1),
		run.player_pos + Vector2i(1, 1)
	]
	for index: int in range(places.size()):
		var kind: String = "boss" if depth == 5 and index == 0 else str(choices[index])
		run._spawn_enemy(kind, places[index])
	run.ground_items.assign([
		{"kind": "herb", "pos": room.position},
		{"kind": "food", "pos": room.position + Vector2i(1, 0)}
	])
	run.dungeon.update_visibility(run.player_pos)
	run.changed.emit()


func _capture_effects() -> bool:
	for kind: String in ["attack", "hurt", "level", "stairs", "pickup", "death"]:
		var cell: Vector2i = run.player_pos
		if kind == "attack" or kind == "death":
			cell += Vector2i.RIGHT
		main._event(kind, cell, 18)
		await create_timer(0.07).timeout
		if not await _capture("effect-" + kind):
			return false
		await create_timer(0.8).timeout
	return true


func _capture_results() -> bool:
	# 勝利は実際の脱出遷移、敗北は実際の体力消失遷移を通す。
	run.player_pos = run.dungeon.stairs
	run.escape()
	await create_timer(1.1).timeout
	if not await _capture("won"):
		return false
	main.start_new(609)
	run._hurt_player(run.max_hp, "苔歩きに倒された")
	await create_timer(1.1).timeout
	if not await _capture("dead"):
		return false
	if not await _capture("result"):
		return false
	main.return_title()
	await create_timer(0.5).timeout
	return true


func _capture_animations() -> bool:
	for action: String in ACTIONS:
		var gallery: Control = _animation_gallery(action)
		if not await _capture("animation-" + action):
			gallery.queue_free()
			return false
		gallery.queue_free()
		await process_frame
	return true


## ノード生成は非冪等。各一覧は撮影後に破棄し、AnimationPlayer の時刻を固定する。
func _animation_gallery(action: String) -> Control:
	var gallery := Control.new()
	gallery.theme = UI.make_theme()
	root.add_child(gallery)
	var background := ColorRect.new()
	background.color = UI.INK
	background.size = Vector2(1280, 720)
	gallery.add_child(background)
	UI.label(gallery, "灯守りの深層  /  %sの連続姿勢" % ACTIONS[action],
		Rect2(36, 20, 1200, 55), 28, UI.GOLD)
	UI.label(gallery, "各キャラクター固有の再生時間に対し、同じ割合で時刻を停止しています。",
		Rect2(36, 76, 1200, 30), 17, UI.MUTED)
	var fractions: Array[float] = [0.0, 0.45, 0.95]
	var rows: Array[String] = ["開始 0%", "途中 45%", "終盤 95%"]
	for column: int in range(CHARACTERS.size()):
		var kind: String = CHARACTERS[column]
		var caption: String = "灯守り" if kind == "hero" else str(Data.ENEMIES[kind].name)
		UI.label(gallery, caption, Rect2(140 + column * 159, 114, 150, 32), 19, UI.TEAL)
		for row: int in range(fractions.size()):
			UI.panel(gallery, Rect2(136 + column * 159, 156 + row * 166, 151, 152))
			var actor: Node2D = Actor.new()
			gallery.add_child(actor)
			actor.setup(kind)
			actor.position = Vector2(211 + column * 159, 245 + row * 166)
			actor.scale = Vector2.ONE * 2.1
			actor.animate(action)
			var clip: Animation = actor.animation.get_animation(action)
			actor.animation.seek(clip.length * fractions[row], true)
			actor.animation.pause()
	for row: int in range(rows.size()):
		UI.label(gallery, rows[row], Rect2(22, 218 + row * 166, 110, 32), 19, UI.GOLD)
	UI.label(gallery, "登場の開始と消滅の終盤は、透明度の変化も撮影対象です。",
		Rect2(36, 678, 1200, 26), 16, UI.MUTED)
	return gallery


func _capture(name: String) -> bool:
	await process_frame
	# process_frame だけでは描画前のテクスチャを読み、前画面を保存し得る。
	await RenderingServer.frame_post_draw
	RenderingServer.force_draw(false)
	var path: String = "tmp/screenshot-%s.png" % name
	var status: Error = root.get_viewport().get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		return false
	print("screenshot: " + path)
	return true
