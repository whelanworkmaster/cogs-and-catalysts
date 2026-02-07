extends CanvasLayer

const RUN_STATE_IDLE := 0
const RUN_STATE_DEPLOY := 1
const RUN_STATE_ENCOUNTER := 2
const RUN_STATE_EXTRACTION := 3
const RUN_STATE_RESULTS := 4

@onready var status_line_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLineLabel
@onready var pressure_line_label: Label = $MarginContainer/PanelContainer/VBoxContainer/PressureLineLabel
@onready var squad_list: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/SquadList
@onready var notice_label: Label = $NoticeMargin/NoticePanel/NoticeLabel
var _notice_time_remaining: float = 0.0

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
	var squad_manager := _get_squad_manager()
	if squad_manager:
		squad_manager.squad_changed.connect(_on_squad_changed)
		squad_manager.active_vessel_changed.connect(_on_active_vessel_changed)
	_rebuild_squad_panel()
	_refresh_lines()

func _process(_delta: float) -> void:
	_refresh_lines()
	_update_notice(_delta)

func _on_state_changed(_a: Variant, _b: Variant) -> void:
	_refresh_lines()

func _on_turn_changed(_actor: Node) -> void:
	_refresh_lines()

func _on_combat_changed(_actors: Array = []) -> void:
	_refresh_lines()

func _on_squad_changed(_vessels: Array) -> void:
	_rebuild_squad_panel()
	_refresh_lines()

func _on_active_vessel_changed(_vessel: Node) -> void:
	_refresh_lines()

func _refresh_lines() -> void:
	_refresh_status_line()
	_refresh_pressure_line()
	_refresh_squad_buttons()

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

	var active_text := "Active:-"
	var hp_text := "HP:-"
	var cells_text := "Cells:-"
	var active_vessel := _get_active_vessel()
	if active_vessel:
		active_text = "Active:%s" % active_vessel.name
		if active_vessel.has_method("get_current_ap"):
			ap_text = "AP:%s" % active_vessel.get_current_ap()
		if active_vessel.has_method("get_current_hp") and active_vessel.has_method("get_max_hp"):
			hp_text = "HP:%s/%s" % [active_vessel.get_current_hp(), active_vessel.get_max_hp()]
		if active_vessel.has_method("get_mutagenic_cells"):
			cells_text = "Cells:%s" % active_vessel.get_mutagenic_cells()

	var threat_text := "Threat:-"
	var enemy := _get_nearest_enemy(active_vessel)
	if enemy and enemy.has_method("get_current_hp") and enemy.has_method("get_max_hp"):
		threat_text = "Threat:%s/%s" % [enemy.get_current_hp(), enemy.get_max_hp()]
		if active_vessel:
			var distance: float = Vector2(active_vessel.global_position.x, active_vessel.global_position.z).distance_to(
				Vector2(enemy.global_position.x, enemy.global_position.z)
			)
			threat_text += " @%.0f" % distance

	status_line_label.text = "%s | %s | %s | %s | %s | %s | %s" % [run_text, turn_text, active_text, ap_text, hp_text, cells_text, threat_text]

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

func _get_nearest_enemy(vessel: Node) -> Node:
	if vessel == null:
		return null
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_target: Node = null
	var best_distance := INF
	for enemy in enemies:
		if enemy == null:
			continue
		var distance: float = vessel.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = enemy
	return best_target

func _rebuild_squad_panel() -> void:
	if squad_list == null:
		return
	for child in squad_list.get_children():
		child.queue_free()
	var squad_manager := _get_squad_manager()
	if squad_manager == null:
		return
	var vessels: Array = squad_manager.get_living_vessels()
	for vessel in vessels:
		if vessel == null:
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.pressed.connect(_on_vessel_button_pressed.bind(vessel))
		button.set_meta("vessel", vessel)
		squad_list.add_child(button)
	_refresh_squad_buttons()

func _refresh_squad_buttons() -> void:
	if squad_list == null:
		return
	var active_vessel := _get_active_vessel()
	var current_actor := CombatManager.get_current_actor() if CombatManager else null
	for child in squad_list.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var vessel: Node = button.get_meta("vessel", null) as Node
		if vessel == null or not is_instance_valid(vessel):
			button.disabled = true
			button.text = "Unavailable"
			button.button_pressed = false
			continue
		button.disabled = false
		button.text = _format_vessel_button_text(vessel, vessel == current_actor)
		button.button_pressed = vessel == active_vessel

func _format_vessel_button_text(vessel: Node, is_turn_actor: bool) -> String:
	var hp_text := "-"
	var ap_text := "-"
	if vessel.has_method("get_current_hp") and vessel.has_method("get_max_hp"):
		hp_text = "%s/%s" % [vessel.get_current_hp(), vessel.get_max_hp()]
	if vessel.has_method("get_current_ap"):
		ap_text = str(vessel.get_current_ap())
	var turn_marker := ">" if is_turn_actor else " "
	return "%s %s  HP:%s  AP:%s" % [turn_marker, vessel.name, hp_text, ap_text]

func _on_vessel_button_pressed(vessel: Node) -> void:
	if vessel == null or not is_instance_valid(vessel):
		return
	var squad_manager := _get_squad_manager()
	if squad_manager == null:
		return
	var in_combat := CombatManager and CombatManager.active_combat
	if in_combat:
		var current_actor := CombatManager.get_current_actor()
		if current_actor == null or not current_actor.is_in_group("player"):
			return
		if not CombatManager.handoff_turn_to(vessel):
			show_notice("Cannot swap right now.", 1.2)
			return
	squad_manager.set_active_vessel(vessel)
	_focus_camera_on_vessel(vessel)
	_refresh_lines()

func show_notice(message: String, duration: float = 1.5) -> void:
	if notice_label == null:
		return
	notice_label.text = message
	notice_label.visible = not message.is_empty()
	_notice_time_remaining = maxf(duration, 0.0)

func _update_notice(delta: float) -> void:
	if notice_label == null:
		return
	if _notice_time_remaining <= 0.0:
		return
	_notice_time_remaining = maxf(_notice_time_remaining - delta, 0.0)
	if _notice_time_remaining <= 0.0:
		notice_label.visible = false
		notice_label.text = ""

func _get_run_controller() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.root.get_node_or_null("RunController")

func _get_squad_manager() -> Node:
	var tree := get_tree()
	if not tree:
		return null
	return tree.root.get_node_or_null("SquadManager")

func _get_active_vessel() -> Node:
	var squad_manager := _get_squad_manager()
	if squad_manager:
		return squad_manager.get_active_vessel()
	return null

func _focus_camera_on_vessel(vessel: Node) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var camera_rig := scene.get_node_or_null("CameraRig")
	if camera_rig == null:
		return
	if "follow_target" in camera_rig:
		camera_rig.follow_target = camera_rig.get_path_to(vessel)

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
