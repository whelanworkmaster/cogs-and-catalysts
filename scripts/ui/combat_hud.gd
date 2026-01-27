extends CanvasLayer

@onready var mode_label: Label = $MarginContainer/VBoxContainer/ModeLabel
@onready var actor_label: Label = $MarginContainer/VBoxContainer/ActorLabel
@onready var ap_label: Label = $MarginContainer/VBoxContainer/APLabel

func _ready() -> void:
	_refresh_mode()
	_refresh_actor()
	if GameMode:
		GameMode.mode_changed.connect(_on_mode_changed)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_changed)
		CombatManager.turn_ended.connect(_on_turn_changed)
		CombatManager.combat_started.connect(_on_combat_started)
		CombatManager.combat_ended.connect(_on_combat_ended)

func _process(_delta: float) -> void:
	_refresh_ap()

func _on_mode_changed(_new_mode: int, _previous_mode: int) -> void:
	_refresh_mode()

func _on_combat_started(_actors: Array) -> void:
	_refresh_actor()

func _on_combat_ended() -> void:
	_refresh_actor()
	_refresh_ap()

func _on_turn_changed(_actor: Node) -> void:
	_refresh_actor()
	_refresh_ap()

func _refresh_mode() -> void:
	var mode_name := "Unknown"
	if GameMode:
		mode_name = str(GameMode.Mode.find_key(GameMode.current_mode))
	mode_label.text = "Mode: %s" % mode_name

func _refresh_actor() -> void:
	var actor := CombatManager.get_current_actor() if CombatManager else null
	actor_label.text = "Turn: %s" % (actor.name if actor else "None")

func _refresh_ap() -> void:
	var actor := CombatManager.get_current_actor() if CombatManager else null
	if actor and actor.has_method("get_current_ap"):
		ap_label.text = "AP: %s" % str(actor.get_current_ap())
	else:
		ap_label.text = "AP: -"
