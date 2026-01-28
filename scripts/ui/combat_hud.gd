extends CanvasLayer

@onready var mode_label: Label = $MarginContainer/VBoxContainer/ModeLabel
@onready var actor_label: Label = $MarginContainer/VBoxContainer/ActorLabel
@onready var ap_label: Label = $MarginContainer/VBoxContainer/APLabel
@onready var control_label: Label = $MarginContainer/VBoxContainer/ControlLabel
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var enemy_hp_label: Label = $MarginContainer/VBoxContainer/EnemyHPLabel
@onready var damage_label: Label = $MarginContainer/VBoxContainer/DamageLabel
@onready var range_label: Label = $MarginContainer/VBoxContainer/RangeLabel
@onready var attack_label: Label = $MarginContainer/VBoxContainer/AttackLabel

func _ready() -> void:
	_refresh_mode()
	_refresh_actor()
	_refresh_controls()
	_refresh_state()
	if GameMode:
		GameMode.mode_changed.connect(_on_mode_changed)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_changed)
		CombatManager.turn_ended.connect(_on_turn_changed)
		CombatManager.combat_started.connect(_on_combat_started)
		CombatManager.combat_ended.connect(_on_combat_ended)

func _process(_delta: float) -> void:
	_refresh_ap()
	_refresh_state()
	_refresh_enemy_status()

func _on_mode_changed(_new_mode: int, _previous_mode: int) -> void:
	_refresh_mode()

func _on_combat_started(_actors: Array) -> void:
	_refresh_actor()
	_refresh_state()
	_refresh_enemy_status()

func _on_combat_ended() -> void:
	_refresh_actor()
	_refresh_ap()
	_refresh_state()
	_refresh_enemy_status()

func _on_turn_changed(_actor: Node) -> void:
	_refresh_actor()
	_refresh_ap()
	_refresh_state()
	_refresh_enemy_status()

func _refresh_mode() -> void:
	var mode_name := "Unknown"
	if GameMode:
		mode_name = str(GameMode.Mode.find_key(GameMode.current_mode))
	mode_label.text = "Mode: %s" % mode_name

func _refresh_actor() -> void:
	var actor: Node = CombatManager.get_current_actor() if CombatManager else null
	actor_label.text = "Turn: %s" % (actor.name if actor else "None")

func _refresh_ap() -> void:
	var actor: Node = CombatManager.get_current_actor() if CombatManager else null
	if actor and actor.has_method("get_current_ap"):
		ap_label.text = "AP: %s" % str(actor.get_current_ap())
	else:
		ap_label.text = "AP: -"

func _refresh_controls() -> void:
	var move_keys := "Move=Arrows/WASD"
	var attack_keys := "Attack=F/LMB"
	var end_turn_keys := "End Turn=Space"
	control_label.text = "Controls: %s  %s  %s" % [move_keys, attack_keys, end_turn_keys]

func _refresh_state() -> void:
	var actor: Node = CombatManager.get_current_actor() if CombatManager else null
	var combat_active: bool = CombatManager.active_combat if CombatManager else false
	var actor_name: String = actor.name if actor else "None"
	var ap_costs: String = ""
	if CombatManager:
		ap_costs = "AP Costs: Move %s | Attack %s | Ability %s" % [
			CombatManager.get_ap_cost("move"),
			CombatManager.get_ap_cost("attack"),
			CombatManager.get_ap_cost("ability")
		]
	var actor_state := "Actor: %s" % actor_name
	var combat_state := "Combat: %s" % ("Active" if combat_active else "Idle")
	state_label.text = "%s  %s  %s" % [combat_state, actor_state, ap_costs]

func _refresh_enemy_status() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	var enemy: Node = _get_nearest_enemy()
	if enemy and enemy.has_method("get_current_hp") and enemy.has_method("get_max_hp"):
		enemy_hp_label.text = "Enemy HP: %s/%s" % [enemy.get_current_hp(), enemy.get_max_hp()]
	else:
		enemy_hp_label.text = "Enemy HP: -"
	var actor: Node = CombatManager.get_current_actor() if CombatManager else null
	if actor and actor.has_method("get_last_damage_dealt"):
		damage_label.text = "Last Damage: %s" % actor.get_last_damage_dealt()
	else:
		damage_label.text = "Last Damage: -"
	if player and enemy:
		var distance: float = player.global_position.distance_to(enemy.global_position)
		var contact_distance: float = player.get_attack_contact_distance() if player.has_method("get_attack_contact_distance") else 0.0
		range_label.text = "Range: %.1f / %.1f" % [distance, contact_distance]
	else:
		range_label.text = "Range: -"
	if player and player.has_method("get_last_attack_result"):
		attack_label.text = "Attack: %s" % player.get_last_attack_result()
	else:
		attack_label.text = "Attack: -"

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
