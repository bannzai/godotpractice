extends Node
## シーンをまたぐ決闘状態の唯一の所有者。

const Duel = preload("res://scripts/duel_state.gd")
var duel: RefCounted = Duel.new()
var selected_deck: int = 0


func start(deck_index: int, seed_value: int) -> void:
	selected_deck = deck_index
	duel.start(deck_index, seed_value)
