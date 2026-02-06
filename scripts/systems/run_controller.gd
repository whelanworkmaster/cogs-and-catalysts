extends Node

signal run_started()
signal run_state_changed(new_state: int, previous_state: int)
signal run_completed(success: bool, reason: String)

enum RunState {
	IDLE,
	DEPLOY,
	ENCOUNTER,
	EXTRACTION,
	RESULTS
}

var current_state: int = RunState.IDLE
var run_active: bool = false
var encounter_index: int = 0
var last_result_reason: String = ""
var last_result_success: bool = false

func _ready() -> void:
	if CombatManager:
		CombatManager.combat_ended.connect(_on_combat_ended)

func start_new_run() -> void:
	run_active = true
	encounter_index = 0
	last_result_reason = ""
	last_result_success = false
	if CombatManager:
		CombatManager.reset_pressure_systems()
	_set_state(RunState.DEPLOY)
	run_started.emit()

func begin_encounter() -> void:
	if not run_active:
		return
	encounter_index += 1
	_set_state(RunState.ENCOUNTER)

func begin_extraction() -> void:
	if not run_active:
		return
	_set_state(RunState.EXTRACTION)

func complete_run(success: bool, reason: String = "") -> void:
	if not run_active and current_state == RunState.RESULTS:
		return
	run_active = false
	last_result_success = success
	last_result_reason = reason
	_set_state(RunState.RESULTS)
	run_completed.emit(success, reason)

func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	var previous := current_state
	current_state = new_state
	run_state_changed.emit(current_state, previous)

func _on_combat_ended() -> void:
	if current_state != RunState.ENCOUNTER:
		return
	var player := get_tree().get_first_node_in_group("player")
	var player_alive := true
	if player and player.has_method("get_current_hp"):
		player_alive = player.get_current_hp() > 0
	if not player_alive:
		complete_run(false, "Squad eliminated")
		return
	begin_extraction()
