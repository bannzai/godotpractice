extends SceneTree
## フレーム再生・死亡の終了・演出の解放・遷移の終了を実時間で検査する。
## 見た目の品質そのものは screenshot と movie-play の画像・動画で別途確認する。

const Actor = preload("res://scripts/actor_visual.gd")
const Effects = preload("res://scripts/effects_layer.gd")

var failed: bool = false
var actors: Array[Node2D] = []
var completed: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


# アニメーションと Tween の時間経過を一回ずつ観測するため非冪等。
func _run() -> void:
	for kind: int in range(-1, 4):
		var actor: Node2D = Actor.new()
		root.add_child(actor)
		actor.setup(kind)
		actor.motion_finished.connect(_completed.bind(kind))
		actors.append(actor)
		_check_frames(actor, kind)
	for motion: String in ["idle", "move", "attack", "hurt", "death"]:
		for actor: Node2D in actors:
			actor.set_motion(motion)
		await create_timer(0.18).timeout
		for actor: Node2D in actors:
			_check(actor.sprite.frame > 0, motion + " のフレームが時間で進む")
			var before: int = actor.sprite.frame
			actor.set_motion(motion)
			_check(actor.sprite.frame == before, "同じ動作を設定しても先頭へ戻らない")
		await create_timer(0.6).timeout
		if motion in ["attack", "hurt", "death"]:
			for kind: int in range(-1, 4):
				_check(completed.has("%d:%s" % [kind, motion]), motion + " の完了通知")
	for actor: Node2D in actors:
		actor.set_motion("idle")
		_check(actor.sprite.animation == "death" and actor.sprite.frame == Actor.FRAME_COUNT - 1,
			"死亡は最終フレームを保持し、待機指示で復活しない")
		actor.reset_motion()
		_check(actor.sprite.animation == "idle", "明示的な再開始で待機へ戻る")
		actor.queue_free()
	actors.clear()
	await _check_effect_cleanup()
	await _check_transitions()
	await process_frame
	await process_frame
	if not failed:
		print("visualcheck OK")
	quit(1 if failed else 0)


func _check_frames(actor: Node2D, kind: int) -> void:
	var frames: SpriteFrames = actor.sprite.sprite_frames
	for animation: String in Actor.ANIMATIONS:
		_check(frames.has_animation(animation), "各キャラが " + animation + " を持つ")
		_check(frames.get_frame_count(animation) == Actor.FRAME_COUNT, "各動作が6フレームを持つ")
		var poses: Array[Vector4] = []
		for index: int in range(Actor.FRAME_COUNT):
			var texture: Texture2D = frames.get_frame_texture(animation, index)
			_check(texture == Actor.SHEETS[kind + 1], "画像生成したキャラ固有の素材を使用する")
			var pose: Vector4 = actor.pose_signature(animation, index)
			_check(not poses.has(pose), "各フレームは異なるポーズ変形を使う")
			poses.append(pose)
	actor.setup(kind)
	_check(actor.sprite.sprite_frames == frames, "同じキャラの setup は素材を作り直さない")


func _check_effect_cleanup() -> void:
	var effects: Node2D = Effects.new()
	effects.face = load("res://assets/fonts/RocknRollOne-Regular.ttf")
	root.add_child(effects)
	for kind: String in ["hit", "death", "pulse", "heal", "level", "magnet"]:
		effects.emit_effect(Vector2(400, 300), kind, "24", 150.0)
	_check(effects.get_child_count() == 6, "各演出を生成する")
	for effect: Node in effects.get_children():
		_check(not effect.find_children("*", "CPUParticles2D", false, false).is_empty(),
			"各演出にパーティクルがある")
		_check(not effect.find_children("*", "Label", false, false).is_empty(),
			"各演出に数値がある")
	await create_timer(0.52).timeout
	for kind: String in ["pulse", "heal", "level", "magnet"]:
		var rings: Array[Node] = effects.get_node(kind).find_children("*", "Line2D", false, false)
		_check(rings.size() == 1, "範囲を示す輪がある")
		if rings.size() == 1:
			var ring: Line2D = rings[0]
			for point: Vector2 in ring.points:
				_check(is_equal_approx((point * ring.scale).length(), 150.0),
					"輪の拡大終了半径が指定した範囲に一致する")
	await create_timer(1.7).timeout
	_check(effects.get_child_count() == 0, "演出が終了するとノードを解放する")
	effects.queue_free()
	await process_frame


func _check_transitions() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state: Node = root.get_node("RunState")
	await create_timer(0.7).timeout
	state.start_run(51)
	await create_timer(0.12).timeout
	_check(main.transition.color.a > 0, "タイトルから探索へのフェード途中")
	await create_timer(0.6).timeout
	_check(is_zero_approx(main.transition.color.a), "探索へのフェードが終了する")
	_check_crowded_effects(main, state)
	state.invulnerable = 0.0
	state.take_damage(1000)
	await create_timer(1.5).timeout
	_check(main.arena.player.sprite.animation == "death", "敗北で主人公が死亡動作になる")
	_check(is_zero_approx(main.transition.color.a), "結果へのフェードが終了する")
	state.start_run(51)
	await create_timer(0.7).timeout
	_check(main.arena.player.sprite.animation != "death", "再挑戦で死亡動作から復帰する")
	state.return_title()
	await create_timer(0.7).timeout
	_check(is_zero_approx(main.transition.color.a), "タイトルへのフェードが終了する")
	_check(is_equal_approx(main.controls.modulate.a, 1.0), "遷移後の操作ボタンが見える")
	main.shutdown()
	main.queue_free()
	await process_frame


func _check_crowded_effects(main: Node, state: Node) -> void:
	state.start_run(60)
	state.level = 100
	state.weapons = {"bolt": 1, "orbit": 0, "pulse": 3}
	main.effects_layer.clear_effects()
	for index: int in range(60):
		state.spawn_enemy(0, Vector2(100 + index % 5, 0))
	state.step(1.0 / 60.0, Vector2.ZERO)
	_check(state.kills >= 60, "範囲攻撃で60体を一斉撃破する")
	_check(main.effects_layer.has_node("pulse"), "一斉撃破後も範囲攻撃の輪を生成する")
	if main.effects_layer.has_node("pulse"):
		var rings: Array[Node] = main.effects_layer.get_node("pulse").find_children(
			"*", "Line2D", false, false)
		_check(not rings.is_empty(), "範囲攻撃の輪が存在する")
		if not rings.is_empty():
			var ring: Line2D = rings[0]
			_check(is_equal_approx(ring.points[0].length(), state.pulse_radius()),
				"輪の終端座標に攻撃判定の半径を渡す")
	for kind: String in ["heal", "level", "boss"]:
		state.call("_add_effect", state.player_pos, kind, "重要演出")
		_check(main.effects_layer.has_node(kind), "混雑時にも " + kind + " を生成する")
	_check(main.effects_layer.get_child_count() <= 64, "演出ノード数が上限以内に収まる")


func _completed(animation: String, kind: int) -> void:
	completed["%d:%s" % [kind, animation]] = true


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error("visualcheck FAIL: " + label)
