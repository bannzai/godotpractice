extends SceneTree
## 実レンダラで画面・演出途中・キャラ別の連続フレームを撮影する。
## 状態の設定は撮影専用。ゲームの進行や実入力は demo.gd / input_check.gd で別途検証する。

const Actor = preload("res://scripts/actor_visual.gd")
const MOTIONS: Array[String] = ["idle", "move", "attack", "hurt", "death"]
const MOTION_NAMES: Array[String] = ["待機", "移動", "攻撃", "被弾", "死亡"]
const ACTOR_NAMES: Array[String] = [
	"ネオンランナー", "グリッチモス", "データハウンド", "センチネル", "エクリプス"
]

var main: Node
var state: Node
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


# 時間を進めて順番に撮影する一回限りの検証なので非冪等。
func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	root.size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	state = root.get_node("RunState")
	await _capture_scenes()
	await _capture_actors()
	main.audio.shutdown()
	main.queue_free()
	await process_frame
	await process_frame
	if not failed:
		print("screenshot OK")
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	await create_timer(0.7).timeout
	await _capture("title")
	state.start_run(77)
	await create_timer(0.12).timeout
	await _capture("transition-title-play-middle")
	await create_timer(0.65).timeout
	await _capture("transition-title-play-end")
	await _capture_tutorial()
	state.start_run(77)
	state.elapsed = 470.0
	state.player_pos = Vector2(1_000_000, -1_000_000)
	main.set_process(false)
	await create_timer(0.15).timeout
	await _capture("infinite-grid")
	main.set_process(true)
	state.start_run(77)
	_prepare_battle()
	await create_timer(0.15).timeout
	main.set_process(false)
	main.shown_hp = state.hp
	main.shown_kills = state.kills
	await _capture("play")
	await _capture_effects()
	state.gain_xp(400)
	main.call("_refresh_screen")
	await create_timer(0.6).timeout
	await _capture("upgrade")
	main.upgrade_focus = 1
	await _capture("upgrade-highlight")
	# 代表の強化画面を撮った後、残る経験値を解消して各画面を独立に撮る。
	while state.phase == "upgrade":
		state.choose_upgrade(0)
	state.toggle_pause()
	main.call("_refresh_screen")
	await create_timer(0.6).timeout
	await _capture("paused")
	state.toggle_pause()
	state.invulnerable = 0.0
	state.take_damage(1000)
	main.set_process(true)
	main.call("_refresh_screen")
	await create_timer(0.12).timeout
	await _capture("transition-play-result-middle")
	await create_timer(1.5).timeout
	await _capture("defeat")
	await _capture_endings()


func _capture_tutorial() -> void:
	main.tutorial_active = true
	main.tutorial_seen = false
	for step: int in range(3):
		main.tutorial_step = step
		main.tutorial_timer = 0.0
		if step == 1 and state.gems.is_empty():
			state.gems.append({"pos": state.player_pos + Vector2(170, 90), "value": 2})
		main.call("_refresh_screen")
		await create_timer(0.12).timeout
		await _capture("tutorial-%s" % ["move", "collect", "level"][step])
	main.call("_finish_tutorial")
	main.call("_refresh_screen")


# 再現可能な撮影状態を既存の戦場に設定するため、撮影シーケンス内で一回だけ実行する。
func _prepare_battle() -> void:
	state.weapons = {"bolt": 3, "orbit": 3, "pulse": 3}
	state.elapsed = 315.0
	state.level = 18
	state.kills = 426
	state.hp = 74.0
	for index: int in range(48):
		var at: Vector2 = Vector2.from_angle(index * 2.399) * (145 + index * 6)
		state.spawn_enemy(index % 3, at)
	for index: int in range(24):
		state.gems.append({"pos": Vector2.from_angle(index * 2.399) * (120 + index * 9),
			"value": 2})
	state.items.append({"pos": Vector2(150, 50), "kind": "heal"})
	state.items.append({"pos": Vector2(-170, 70), "kind": "magnet"})


func _capture_effects() -> void:
	var kinds: Array[String] = ["pulse", "hit", "heal", "level", "death", "magnet"]
	var captions: Array[String] = ["", "42", "+30 HP", "レベルアップ", "", "吸い寄せ"]
	for index: int in range(kinds.size()):
		await create_timer(0.9).timeout
		main.effects_layer.emit_effect(Vector2(640, 392), kinds[index], captions[index], 220.0)
		await create_timer(0.2).timeout
		await _capture("effect-%s-middle" % kinds[index])


func _capture_endings() -> void:
	state.start_run(77)
	state.elapsed = 575.0
	state.boss_spawned = true
	state.spawn_enemy(3, Vector2(200, -30))
	main.set_process(true)
	await create_timer(0.7).timeout
	main.set_process(false)
	await _capture("boss")
	state.elapsed = 600.0
	state.kills = 1306
	state.level = 32
	state.finish_run(true)
	main.set_process(true)
	main.call("_refresh_screen")
	await create_timer(0.75).timeout
	await _capture("clear")
	state.return_title()
	main.call("_refresh_screen")
	await create_timer(0.12).timeout
	await _capture("transition-result-title-middle")
	await create_timer(0.65).timeout
	await _capture("transition-result-title-end")


func _capture_actors() -> void:
	main.hide()
	for kind: int in range(-1, 4):
		var sheet := Control.new()
		root.add_child(sheet)
		var background := ColorRect.new()
		background.color = Color("09051c")
		background.size = Vector2(1280, 720)
		sheet.add_child(background)
		_label(sheet, ACTOR_NAMES[kind + 1] + " — アニメーション連続フレーム", Vector2(60, 30), 28)
		_label(sheet, "開始", Vector2(392, 89), 20)
		_label(sheet, "途中", Vector2(672, 89), 20)
		_label(sheet, "終了", Vector2(952, 89), 20)
		for row: int in range(MOTIONS.size()):
			_label(sheet, MOTION_NAMES[row], Vector2(90, 157 + row * 110), 24)
			for column: int in range(3):
				_add_frame(sheet, kind, row, column)
		await _capture("actor-%s-animations" % ("player" if kind == -1 else str(kind)))
		sheet.queue_free()
		await process_frame
	main.show()


func _add_frame(sheet: Control, kind: int, row: int, column: int) -> void:
	var actor: Node2D = Actor.new()
	sheet.add_child(actor)
	actor.setup(kind)
	actor.position = Vector2(420 + column * 280, 175 + row * 110)
	actor.scale = Vector2.ONE * 0.67
	actor.set_motion(MOTIONS[row])
	var sprite: AnimatedSprite2D = actor.sprite
	var last: int = sprite.sprite_frames.get_frame_count(MOTIONS[row]) - 1
	sprite.pause()
	sprite.frame = [0, int(last / 2), last][column]
	_label(sheet, "%d / %d" % [sprite.frame + 1, last + 1],
		Vector2(470 + column * 280, 171 + row * 110), 15)


func _label(parent: Node, value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_override("font", load("res://assets/fonts/RocknRollOne-Regular.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f8f4ff"))
	parent.add_child(label)


func _capture(label: String) -> void:
	main.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "tmp/screenshot-%s.png" % label
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		failed = true
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
	else:
		print("screenshot: " + path)
