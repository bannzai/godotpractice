class_name BattleEffects
extends Node
## 一度の戦闘イベントに対応する演出。進行の値を変更しない。

const PAPER := Color("9bbc0f")
const ACCENT := Color("c3423f")

var screen: Control


func setup(parent: Control) -> void:
	screen = parent


## 発生のたびに粒を放出するため非冪等。親画面の破棄時に全粒子も解放する。
func burst(at: Vector2, _kind: String, amount: int = 28) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.texture = load("res://assets/pixel/effects/spark.png")
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.amount = amount
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 80)
	particles.initial_velocity_min = 70
	particles.initial_velocity_max = 210
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 0.5
	particles.color = Color.WHITE
	screen.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true
	return particles


## 攻撃・被弾・ヒットストップ・揺れは一度の入力に対する時間演出なので非冪等。
func attack(attacker: QuestActor, target: QuestActor, event: Dictionary) -> void:
	var element: String = event.element
	var start: Vector2 = attacker.position
	var direction: float = signf(target.position.x - start.x)
	var destination: Vector2 = target.position + target.size * Vector2(0.5, 0.5)
	attacker.set_action("attack")
	var windup: Tween = screen.create_tween()
	windup.tween_property(attacker, "position:x", start.x - 12 * direction, 0.12)
	windup.tween_property(attacker, "position:x", start.x + 22 * direction, 0.12)
	await windup.finished
	var bolt := _image("effects/projectile_" + element, Vector2(64, 64))
	bolt.position = attacker.position + attacker.size / 2.0 - bolt.size / 2.0
	var flight: Tween = screen.create_tween()
	flight.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(bolt, "position", destination - bolt.size / 2.0, 0.18)
	await flight.finished
	bolt.queue_free()
	attacker.sprite.pause()
	target.set_action("hurt")
	target.sprite.pause()
	burst(destination, element, 40 if event.effectiveness > 1.0 else 24)
	flash(ACCENT)
	pop(destination - Vector2(40, 100), "−%d" % event.damage, ACCENT)
	await get_tree().create_timer(0.065).timeout
	attacker.sprite.play()
	target.sprite.play()
	var impact: Tween = screen.create_tween()
	for displacement: float in [5.0, -4.0, 3.0, -2.0, 0.0]:
		impact.tween_property(screen, "position:x", displacement, 0.035)
	impact.parallel().tween_callback(func() -> void: target.visible = false)
	impact.tween_interval(0.065)
	impact.tween_callback(func() -> void: target.visible = true)
	impact.parallel().tween_property(attacker, "position", start, 0.20)
	await impact.finished
	await get_tree().create_timer(0.14).timeout
	attacker.set_action("idle")
	target.set_action("idle")


## ボールの投擲・揺れ・開放を順に再生するため非冪等。
func capture(target: QuestActor, success: bool) -> void:
	var ball := _image("ui/capture_ball", Vector2(64, 64))
	ball.pivot_offset = ball.size / 2.0
	ball.position = Vector2(360, 410)
	var center: Vector2 = target.position + target.size / 2.0
	var throw_ball: Tween = screen.create_tween()
	throw_ball.tween_property(ball, "position", center - Vector2(36, 96), 0.32)
	throw_ball.parallel().tween_property(ball, "rotation", TAU, 0.32)
	throw_ball.tween_property(ball, "position:y", center.y + 30, 0.18)
	throw_ball.tween_callback(func() -> void: target.visible = false)
	await throw_ball.finished
	burst(center, "level")
	var shake: Tween = screen.create_tween()
	for angle: float in [-0.25, 0.25, -0.18, 0.18, 0.0]:
		shake.tween_property(ball, "rotation", TAU + angle, 0.11)
	await shake.finished
	burst(ball.position + ball.size / 2.0, "level" if success else "water", 40)
	pop(center - Vector2(88, 70), "仲間になった！" if success else "飛び出した！", ACCENT)
	if not success:
		target.visible = true
		target.set_action("attack")
	await get_tree().create_timer(0.6).timeout
	ball.queue_free()
	target.set_action("idle")


## 回復・成長の一回分の演出なので非冪等。
func celebrate(actor: QuestActor, kind: String, text: String) -> void:
	var center: Vector2 = actor.position + actor.size / 2.0
	burst(center, kind, 42)
	pop(center - Vector2(66, 88), text, ACCENT)
	for visible: bool in [false, true, false, true]:
		actor.visible = visible
		await get_tree().create_timer(0.12).timeout


func _image(path: String, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://assets/pixel/%s.png" % path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.size = dimensions
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(node)
	return node


## 表示を発生時刻から動かすため非冪等。
func pop(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", PAPER)
	label.add_theme_constant_override("outline_size", 7)
	screen.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "position:y", at.y - 60, 0.75).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(label.queue_free)


## 一瞬の発光を追加して時間経過で取り除くため非冪等。
func flash(color: Color) -> void:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.size = Vector2(1280, 486)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(overlay)
	var tween: Tween = overlay.create_tween()
	tween.tween_interval(0.04)
	tween.tween_callback(overlay.queue_free)
