extends CanvasLayer

class_name GameOverUI

@onready var title_label: Label = $ColorRect/TitleLabel
@onready var subtitle_label: Label = $ColorRect/SubtitleLabel

func _ready() -> void:
	visible = false

func show_game_over() -> void:
	visible = true
	if title_label:
		title_label.text = "GAME OVER"
	if subtitle_label:
		subtitle_label.text = "Press R to Retry"

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
