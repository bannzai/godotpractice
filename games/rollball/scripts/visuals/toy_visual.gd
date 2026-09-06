extends Node3D

var visual_state: String = "idle"

@onready var animation_player: AnimationPlayer = $AnimationPlayer


# シーン参加時だけ接続し、同じ種類の小物の揺れを配置に応じてずらす。
func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(visual_state)
	if visual_state == "idle":
		animation_player.seek(fposmod(global_position.x * 0.31 + global_position.z * 0.17,
			animation_player.get_animation("idle").length), true)


func play_state(state: String) -> void:
	if visual_state == state:
		return
	var player: AnimationPlayer = get_node("AnimationPlayer")
	if not player.has_animation(state):
		return
	visual_state = state
	if is_inside_tree():
		player.play(state, 0.08)


func _on_animation_finished(state: StringName) -> void:
	if state == &"collect" or state == &"bump":
		play_state("idle")
