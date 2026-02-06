extends CanvasLayer

const RUN_STATE_IDLE := 0
const RUN_STATE_DEPLOY := 1
const RUN_STATE_ENCOUNTER := 2
const RUN_STATE_EXTRACTION := 3
const RUN_STATE_RESULTS := 4

@onready var status_line_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLineLabel
@onready var pressure_line_label: Label = $MarginContainer/PanelContainer/VBoxContainer/PressureLineLabel

func _ready() -> void:
	if GameMode:
		GameMode.mode_changed.connect(_on_state_changed)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_changed)
		CombatManager.turn_ended.connect(_on_turn_changed)
		CombatManager.combat_started.connect(_on_combat_changed)
		CombatManager.combat_ended.connect(_on_combat_changed)
	var run_controller := _get_run_controller()
	if run_controller:
		run_controller.run_state_changed.connect(_on_state_changed)
	_refresh_lines()

func _process(_delta: float) -> void:
	_refresh_lines()

func _on_state_changed(_a: Variant, _b: Variant) -> void:
	_refresh_lines()

func _on_turn_changed(_actor: Node) -> void:
	_refresh_lines()

func _on_combat_changed(_actors: Array = []) -> void:
	_refresh_lines()

func _refresh_lines() -> void:
	_refresh_status_line()
	_refresh_pressure_line()

func _refresh_status_line() -> void:
	var run_text := "Run:-"
	var run_controller := _get_run_controller()
	if run_controller:
		run_text = "Run:%s" % _run_state_to_text(int(run_controller.current_state))

	var turn_text := "Turn:-"
	var ap_text := "AP:-"
	var actor: Node = CombatManager.get_current_actor() if CombatManager else null
	if actor:
		turn_text = "Turn:%s" % actor.name
		if actor.has_method("get_current_ap"):
			ap_text = "AP:%s" % actor.get_current_ap()

	var hp_text := "HP:-"
	var cells_text := "Cells:-"
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_current_hp") and player.has_method("get_max_hp"):
		hp_text = "HP:%s/%s" % [player.get_current_hp(), player.get_max_hp()]
	if player and player.has_method("get_mutagenic_cells"):
		cells_text = "Cells:%s" % player.get_mutagenic_cells()

	var threat_text := "Threat:-"
	var enemy := _get_nearest_enemy()
	if enemy and enemy.has_method("get_current_hp") and enemy.has_method("get_max_hp"):
		threat_text = "Threat:%s/%s" % [enemy.get_current_hp(), enemy.get_max_hp()]
		if player:
			var distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(enemy.global_position.x, enemy.global_position.z)
			)
			threat_text += " @%.0f" % distance

	status_line_label.text = "%s | %s | %s | %s | %s | %s" % [run_text, turn_text, ap_text, hp_text, cells_text, threat_text]

func _refresh_pressure_line() -> void:
	if not CombatManager or not CombatManager.alert_level or not CombatManager.toxicity_load:
		pressure_line_label.text = "Alert:- | Toxicity:-"
		return

	var alert_effect := CombatManager.describe_next_alert_effect().replace("Next: ", "")
	var toxicity_effect := CombatManager.describe_next_toxicity_effect().replace("Next: ", "")
	pressure_line_label.text = "Alert:%s/%s (%s) | Toxicity:%s/%s (%s)" % [
		CombatManager.alert_level.progress,
		CombatManager.alert_level.segments,
		alert_effect,
		CombatManager.toxicity_load.progress,
		CombatManager.toxicity_load.segments,
		toxicity_effect
	]

func _get_nearest_enemy() -> Node:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return null
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_target: Node = null
	var best_distance := INF
	for enemy in enemies:
		if enemy == null:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = enemy
	return best_target

func _get_run_controller() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.root.get_node_or_null("RunController")

func _run_state_to_text(state: int) -> String:
	match state:
		RUN_STATE_IDLE:
			return "Idle"
		RUN_STATE_DEPLOY:
			return "Deploy"
		RUN_STATE_ENCOUNTER:
			return "Encounter"
		RUN_STATE_EXTRACTION:
			return "Extraction"
		RUN_STATE_RESULTS:
			return "Results"
		_:
			return "Unknown"
