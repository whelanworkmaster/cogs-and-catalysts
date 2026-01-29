extends Resource

class_name Clock

@export var name: String = "Clock"
@export var segments: int = 4
@export var progress: int = 0

func tick(steps: int = 1) -> void:
	if steps <= 0:
		return
	progress = clamp(progress + steps, 0, segments)

func reset() -> void:
	progress = 0

func is_full() -> bool:
	return progress >= segments

func to_display() -> String:
	return "%s: %s/%s" % [name, progress, segments]
