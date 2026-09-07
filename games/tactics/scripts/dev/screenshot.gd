extends SceneTree
## 本番画面と全キャラの動作を描画して記録する。撮影専用の進行データを使う。
## 状態の投入・時間経過・ファイル出力を伴うので、一起動で一巡だけ実行する。

const UI := preload("res://scripts/ui.gd")
const Actor := preload("res://scripts/unit_actor.gd")
const KIND_NAMES: Dictionary = {
	"sword": "リオ・剣士", "lance": "セナ・槍騎士", "axe": "ガル・斧戦士",
	"bow": "ネリ・弓使い", "healer": "ルカ・祈り手", "raider": "敵・斧兵",
	"archer": "敵・弓兵", "boss": "灰の隊長",
	"enemy_sword": "敵・剣兵", "enemy_lance": "敵・槍兵"
}
const POSE_NAMES: Dictionary = {
	"idle": "待機", "select": "選択", "move": "移動", "attack": "攻撃",
	"hurt": "被弾", "dodge": "回避", "defeat": "撃破"
}

var main: Node
var campaign: Node
var failed: bool = false
var started_at: int = 0


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	started_at = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started_at > 90000:
		push_error("撮影が制限時間を超えました")
		quit(1)
	return false


func _run() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = "res://tmp/screenshot-campaign.json"
	await _capture_scenes()
	main.stop_audio()
	await create_timer(0.25).timeout
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _capture_scenes() -> void:
	var main_scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	main = load(main_scene_path).instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	await _capture("title")
	main.show_help()
	await _capture("help")
	main.start_game()
	await create_timer(0.5).timeout
	await _capture("story-1")
	main._begin_stage()
	await create_timer(1.0).timeout
	await _capture("tutorial")
	await _capture("stage-1")
	main.choose_cell(Vector2i(2, 5))
	await _capture("actionable-highlight")
	await _capture("movement")
	main.choose_cell(Vector2i(6, 7))
	await _capture("selection-unavailable")
	await main.choose_cell(Vector2i(4, 5))
	await create_timer(0.25).timeout
	await _capture("fan-menu")
	main.choose_cell(Vector2i(5, 5))
	await _capture("scroll-forecast")
	await _capture("forecast")
	main.confirm_attack()
	await create_timer(0.5).timeout
	await _capture("combat")
	while main.busy:
		await process_frame
	# 実戦で倒れた敵や消費済みの行動を演出 fixture へ持ち越さない。
	main.start_game()
	main.skip_tutorial()
	main._begin_stage()
	await create_timer(1.0).timeout
	await _capture_effects()
	await _capture_results()
	main.visible = false
	await _capture_actor_poses()


func _capture_effects() -> void:
	# 戦闘結果を撮影用に注入し、本番と同じイベント演出を個別に再生する。
	main.target = ""
	main.show_play()
	_fixture_label("演出確認用：戦闘イベントを個別に再生")
	var samples: Array[Dictionary] = [
		{"name": "heal", "event": {"kind": "heal", "actor": "healer", "target": "hero", "amount": 12}},
		{"name": "level", "event": {"kind": "level", "actor": "hero", "target": "hero", "amount": 2}},
		{"name": "hit", "event": {"kind": "hit", "actor": "e1", "target": "hero", "amount": 7}},
		{"name": "critical", "event": {"kind": "hit", "actor": "hero", "target": "e1",
			"amount": 21, "critical": true}},
	]
	for sample: Dictionary in samples:
		main._animate_events([sample.event])
		await create_timer(0.12 if sample.name != "critical" else 0.28).timeout
		await _capture("effect-" + sample.name)
		await create_timer(1.0).timeout
	main.effects.banner("敵軍フェーズ", UI.CORAL)
	await create_timer(0.28).timeout
	await _capture("enemy-phase")
	await create_timer(0.8).timeout
	main.effects.banner("自軍フェーズ  ·  第 2 ターン")
	await create_timer(0.28).timeout
	await _capture("player-phase")
	await create_timer(0.8).timeout


func _capture_results() -> void:
	# 章と結果の表示確認専用 fixture。通常プレイの勝敗検証は integration / selfcheck が担う。
	campaign.outcome = "victory"
	main.show_result()
	_fixture_label("画面確認用：第１章クリアの状態を投入")
	await create_timer(0.6).timeout
	await _capture("victory")
	main.advance_stage()
	_fixture_label("画面確認用：第２章の絵巻")
	await create_timer(0.6).timeout
	await _capture("story-2")
	main._begin_stage()
	_fixture_label("画面確認用：第２章開始の状態を投入")
	await create_timer(1.0).timeout
	await _capture("stage-2")
	campaign.outcome = "victory"
	main.advance_stage()
	_fixture_label("画面確認用：第３章の絵巻")
	await create_timer(0.6).timeout
	await _capture("story-3")
	main._begin_stage()
	_fixture_label("画面確認用：第３章開始の状態を投入")
	await create_timer(1.0).timeout
	await _capture("stage-3")
	campaign.outcome = "defeat"
	main.show_result()
	_fixture_label("画面確認用：主人公敗北の状態を投入")
	await create_timer(0.6).timeout
	await _capture("defeat")
	campaign.outcome = "ending"
	main.show_result()
	_fixture_label("画面確認用：全３章踏破の状態を投入")
	await create_timer(0.6).timeout
	await _capture("ending")


func _fixture_label(text: String) -> void:
	UI.label(main.screen, text, Rect2(50, 0, 1170, 20), 13, UI.MUTED)


func _capture_actor_poses() -> void:
	for pose: String in Actor.POSES:
		var sheet := Control.new()
		sheet.theme = UI.make_theme()
		root.add_child(sheet)
		UI.panel(sheet, Rect2(0, 0, 1280, 720), UI.INK, Color.TRANSPARENT)
		UI.label(sheet, "キャラ別アニメーション  /  " + POSE_NAMES[pose],
			Rect2(40, 15, 1190, 55), 31, UI.GOLD)
		UI.label(sheet, "本番の AnimationPlayer を開始・途中・終了の時刻で停止して撮影",
			Rect2(40, 67, 1190, 32), 18, UI.PAPER)
		for column: int in range(Actor.KINDS.size()):
			var x: float = 45 + column * 120
			var title: Label = UI.label(sheet, KIND_NAMES[Actor.KINDS[column]],
				Rect2(x - 8, 107, 115, 32), 15)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			for row: int in range(3):
				_add_pose_cell(sheet, pose, column, row, x)
		await _capture("animation-" + pose)
		sheet.queue_free()
		await process_frame


func _add_pose_cell(sheet: Control, pose: String, column: int, row: int, x: float) -> void:
	var y: float = 155 + row * 183
	UI.panel(sheet, Rect2(x - 5, y, 110, 170), Color("1b3040"), Color("36505b"))
	var actor: Node2D = Actor.new()
	sheet.add_child(actor)
	actor.configure(Actor.KINDS[column], column >= 5)
	actor.position = Vector2(x + 47, y + 72)
	actor.scale = Vector2.ONE * 0.42
	actor.play_pose(pose)
	actor.animation_player.pause()
	var duration: float = actor.animation_player.get_animation(pose).length
	# 移動は 1/4 周期が浮き上がり最大なので、往復の変化が見える時刻を使う。
	var ratio: float = 0.25 if pose == "move" else 0.42
	var seconds: float = [0.0, duration * ratio, duration][row]
	actor.animation_player.seek(seconds, true)
	var phase_text: String = ["開始", "途中", "終了"][row]
	var label: Label = UI.label(sheet, "%s  %.2f 秒" % [phase_text, seconds],
		Rect2(x - 5, y + 139, 110, 27), 15, UI.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tmp/screenshot-%s.png" % name_value
	var status: Error = root.get_texture().get_image().save_png(path)
	if status != OK:
		push_error("スクリーンショット保存失敗: %s (%s)" % [path, error_string(status)])
		failed = true
		return
	print("screenshot: " + path)
