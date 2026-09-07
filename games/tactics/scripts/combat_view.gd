extends Control
## 判定された戦闘イベントを拡大して見せる短い戦闘画面。

const UI := preload("res://scripts/ui.gd")
const Actor := preload("res://scripts/unit_actor.gd")
const Board := preload("res://scripts/board.gd")
const Effects := preload("res://scripts/effects.gd")
var actors: Dictionary = {}
var health: Dictionary = {}
var numbers: Dictionary = {}
var bars: Dictionary = {}
var stage: Control
var effects: Control
var flash: ColorRect


func setup(campaign: Node, first: String, second: String, initial_hp: Dictionary) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 12
	theme = UI.make_theme()
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	UI.scroll_panel(stage, Rect2(70, 138, 720, 450))
	var landscape: TextureRect = UI.art_cover(
		stage, "generated/yamato-landscape.png", Rect2(84, 155, 692, 382)
	)
	landscape.modulate = Color(0.72, 0.67, 0.53, 0.48)
	UI.label(stage, "交 戦 絵 巻", Rect2(320, 165, 240, 40), 28, UI.CORAL)
	for index: int in range(2):
		var id: String = first if index == 0 else second
		var unit: Dictionary = campaign.unit_by_id(id)
		var actor: Node2D = Actor.new()
		stage.add_child(actor)
		actor.configure(Board.art_kind(unit), unit.team == "enemy")
		actor.position = Vector2(250 + index * 340, 353)
		actor.scale = Vector2(0.9 if index == 0 else -0.9, 0.9)
		actors[id] = actor
		health[id] = int(initial_hp.get(id, unit.hp))
		var left: float = 125 + index * 340
		UI.label(
			stage,
			unit.name,
			Rect2(left, 464, 260, 34),
			23,
			UI.JADE if unit.team == "player" else UI.CORAL
		)
		numbers[id] = UI.label(
			stage, "HP %d / %d" % [health[id], unit.max_hp], Rect2(left, 502, 260, 29), 19
		)
		bars[id] = UI.meter(stage, Rect2(left, 543, 250, 8), health[id], unit.max_hp)
	effects = Effects.new()
	stage.add_child(effects)
	flash = ColorRect.new()
	flash.position = Vector2(85, 154)
	flash.size = Vector2(672, 413)
	flash.color = Color(1.0, 0.86, 0.54, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(flash)
	modulate.a = 0.0
	stage.pivot_offset = Vector2(421, 360)
	stage.scale = Vector2.ONE * 0.92
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	tween.tween_property(stage, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_CUBIC)


# 一度確定したイベントに対応する姿勢と表示HPだけを更新する。
func present(event: Dictionary) -> void:
	var actor: Node2D = actors.get(str(event.get("actor", "")))
	var victim: Node2D = actors.get(str(event.get("target", "")))
	match event.kind:
		"attack":
			if actor != null:
				actor.play_pose("attack")
		"hit", "miss", "death":
			if victim != null:
				var pose: String = {"hit": "hurt", "miss": "dodge", "death": "defeat"}[event.kind]
				victim.play_pose(pose)
				var caption: String = {
					"hit": "−%d" % event.get("amount", 0), "miss": "回避", "death": "撃破"
				}[event.kind]
				effects.burst(
					victim.position, caption, UI.CORAL if event.kind == "hit" else UI.GOLD
				)
				if event.kind == "hit":
					_update_health(event.target, int(event.amount))
					_impact(victim, event.get("critical", false))
		"level":
			if actor != null:
				effects.burst(actor.position, "成長", UI.JADE)


func _update_health(id: String, damage: int) -> void:
	var previous: int = health[id]
	health[id] = maxi(0, previous - damage)
	var count: Label = numbers[id]
	var bar: ProgressBar = bars[id]
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(bar, "value", float(health[id]), 0.28)
	tween.tween_method(
		func(value: float) -> void: count.text = "HP %d / %d" % [roundi(value), int(bar.max_value)],
		float(previous),
		float(health[id]),
		0.28
	)


# 被弾に合わせた一度きりのフラッシュ、画面揺れ、短い静止。
func _impact(victim: Node2D, critical: bool) -> void:
	flash.color.a = 0.45 if critical else 0.17
	var blink: Tween = create_tween()
	blink.tween_property(flash, "color:a", 0.0, 0.2)
	victim.animation_player.speed_scale = 0.0
	var stop: Tween = create_tween()
	stop.tween_interval(0.13 if critical else 0.07)
	stop.tween_property(victim.animation_player, "speed_scale", 1.0, 0.01)
	var shake: Tween = create_tween()
	shake.tween_property(stage, "position:x", 8.0 if critical else 4.0, 0.03)
	shake.tween_property(stage, "position:x", -5.0, 0.04)
	shake.tween_property(stage, "position:x", 0.0, 0.06)
