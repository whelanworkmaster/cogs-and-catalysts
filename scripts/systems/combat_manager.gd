extends Node

signal combat_started(actors: Array)
signal combat_ended()
signal turn_started(actor: Node)
signal turn_ended(actor: Node)

var active_combat: bool = false
var actors: Array = []
var current_actor_index: int = -1

func start_combat(combat_actors: Array) -> void:
	if active_combat:
		return
	active_combat = true
	actors = combat_actors
	current_actor_index = -1
	GameMode.set_mode(GameMode.Mode.TURN_COMBAT)
	combat_started.emit(actors)
	_next_turn()

func end_combat() -> void:
	if not active_combat:
		return
	active_combat = false
	actors = []
	current_actor_index = -1
	GameMode.set_mode(GameMode.Mode.EXPLORATION)
	combat_ended.emit()

func end_turn() -> void:
	if not active_combat or current_actor_index < 0 or current_actor_index >= actors.size():
		return
	var actor: Node = actors[current_actor_index] as Node
	turn_ended.emit(actor)
	_next_turn()

func get_current_actor() -> Node:
	if current_actor_index < 0 or current_actor_index >= actors.size():
		return null
	return actors[current_actor_index]

func _next_turn() -> void:
	if actors.is_empty():
		end_combat()
		return
	current_actor_index = (current_actor_index + 1) % actors.size()
	var actor: Node = actors[current_actor_index] as Node
	turn_started.emit(actor)
