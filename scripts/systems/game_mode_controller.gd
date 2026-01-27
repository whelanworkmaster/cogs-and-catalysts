extends Node

class_name GameModeController

signal mode_changed(new_mode: int, previous_mode: int)

enum Mode {
	EXPLORATION,
	ENGAGEMENT,
	TURN_COMBAT,
	CINEMATIC
}

var current_mode: int = Mode.EXPLORATION

func set_mode(new_mode: int) -> void:
	if current_mode == new_mode:
		return
	var previous_mode := current_mode
	current_mode = new_mode
	mode_changed.emit(current_mode, previous_mode)

func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION
