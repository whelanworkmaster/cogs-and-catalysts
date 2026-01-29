extends CharacterBody2D

class_name Player

const ElevationArea = preload("res://scripts/world/elevation_area.gd")

# Movement variables
@export var speed: float = 750.0
@export var isometric_factor: float = 0.577  # tan(30°) for isometric projection

# Action Points system
var current_ap: int = 10
@export var max_ap: int = 10
@export var ap_regen_per_second: float = 2.0
var ap_regen_accumulator: float = 0.0
@export var combat_step_distance: float = 32.0
@export var combat_move_cooldown: float = 0.2
var combat_move_cooldown_timer: float = 0.0
@export var attack_contact_distance: float = 40.0
@export var attack_damage: int = 3
var last_damage_dealt: int = 0
var last_attack_result: String = "-"

# Elevation tracking
var current_elevation: int = 0
@onready var elevation_detector: Area2D = $ElevationDetector

# Movement vectors for 8-way isometric movement
var movement_vectors = {
	"up": Vector2(0, -1),
	"down": Vector2(0, 1),
	"left": Vector2(-1, 0),
	"right": Vector2(1, 0),
	"up_left": Vector2(-1, -1),
	"up_right": Vector2(1, -1),
	"down_left": Vector2(-1, 1),
	"down_right": Vector2(1, 1)
}

func _ready():
	print("Player initialized with ", current_ap, " AP")
	add_to_group("player")
	_ensure_input_actions()
	elevation_detector.area_entered.connect(_on_elevation_area_entered)
	elevation_detector.area_exited.connect(_on_elevation_area_exited)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)
		CombatManager.combat_started.connect(_on_combat_started)
		CombatManager.combat_ended.connect(_on_combat_ended)
	# Create a basic visual representation
	create_player_sprite()

func _physics_process(delta):
	handle_turn_input()
	if combat_move_cooldown_timer > 0.0:
		combat_move_cooldown_timer = max(0.0, combat_move_cooldown_timer - delta)
	handle_movement()
	handle_attack_input()

func handle_turn_input():
	if not CombatManager:
		return
	if not CombatManager.active_combat:
		return
	if CombatManager.get_current_actor() != self:
		return
	if Input.is_action_just_pressed("end_turn") or Input.is_action_just_pressed("ui_accept"):
		CombatManager.end_turn()

func handle_movement():
	if GameMode and not GameMode.is_exploration():
		if not CombatManager or not CombatManager.active_combat or CombatManager.get_current_actor() != self:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	var input_direction = Vector2.ZERO
	
	# Get input for 8-way movement
	if Input.is_action_pressed("ui_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_direction.y += 1
	if Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_direction.x += 1
	
		# Normalize diagonal movement
	if input_direction != Vector2.ZERO:
		input_direction = input_direction.normalized()
		
		var requires_ap := CombatManager and CombatManager.active_combat
		if requires_ap:
			if combat_move_cooldown_timer > 0.0:
				velocity = Vector2.ZERO
				move_and_slide()
				return
			# Check if move is legal (has enough AP)
			if spend_ap(_get_ap_cost("move")):
				global_position += input_direction * combat_step_distance
				combat_move_cooldown_timer = combat_move_cooldown
				_tick_detection()
			else:
				print("Not enough AP to move!")
			velocity = Vector2.ZERO
		else:
			velocity = input_direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func handle_attack_input() -> void:
	if not CombatManager:
		last_attack_result = "No CombatManager"
		return
	if not CombatManager.active_combat:
		last_attack_result = "Not in combat"
		return
	if CombatManager.get_current_actor() != self:
		last_attack_result = "Not your turn"
		return
	if not Input.is_action_just_pressed("attack"):
		return
	print("Attack input detected.")
	var target := _find_attack_target()
	if not target:
		last_attack_result = "No target in range"
		last_damage_dealt = 0
		print("Attack failed: no target in range.")
		return
	if not spend_ap(_get_ap_cost("attack")):
		last_attack_result = "Not enough AP"
		last_damage_dealt = 0
		print("Attack failed: not enough AP.")
		return
	if target.has_method("take_damage"):
		target.take_damage(attack_damage, self)
		last_damage_dealt = attack_damage
		last_attack_result = "Hit for %s" % attack_damage
		print("Attack hit for ", attack_damage)
		_tick_detection()

func apply_isometric_transform(direction: Vector2) -> Vector2:
	# Convert standard 2D movement to isometric projection
	var iso_x = direction.x - direction.y
	var iso_y = (direction.x + direction.y) * isometric_factor
	return Vector2(iso_x, iso_y)

func spend_ap(amount: int) -> bool:
	"""
	Spends Action Points if the move is legal.
	Returns true if AP was successfully spent, false otherwise.
	"""
	if current_ap >= amount:
		current_ap -= amount
		print("Spent ", amount, " AP. Remaining: ", current_ap, "/", max_ap)
		return true
	else:
		print("Cannot spend ", amount, " AP. Only have ", current_ap, " available.")
		return false

func restore_ap(amount: int):
	"""Restores Action Points, up to maximum."""
	current_ap = min(current_ap + amount, max_ap)
	print("Restored ", amount, " AP. Current: ", current_ap, "/", max_ap)

func regen_ap(delta: float):
	if current_ap >= max_ap:
		ap_regen_accumulator = 0.0
		return
	if ap_regen_per_second <= 0.0:
		return
	ap_regen_accumulator += delta * ap_regen_per_second
	if ap_regen_accumulator >= 1.0:
		var to_restore = int(floor(ap_regen_accumulator))
		ap_regen_accumulator -= float(to_restore)
		restore_ap(to_restore)

func reset_ap():
	"""Resets Action Points to maximum."""
	current_ap = max_ap
	print("AP reset to ", current_ap, "/", max_ap)

func get_current_ap() -> int:
	return current_ap

func get_max_ap() -> int:
	return max_ap

func _get_ap_cost(action: StringName) -> int:
	if CombatManager:
		return CombatManager.get_ap_cost(action)
	return 0

func _find_attack_target() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var best_target: Node = null
	var best_distance := attack_contact_distance + 0.01
	for enemy in enemies:
		if enemy == null:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= attack_contact_distance and distance < best_distance:
			best_distance = distance
			best_target = enemy
	return best_target

func get_last_damage_dealt() -> int:
	return last_damage_dealt

func get_attack_contact_distance() -> float:
	return attack_contact_distance

func get_last_attack_result() -> String:
	return last_attack_result

func take_damage(amount: int, source: Node = null) -> void:
	if amount <= 0:
		return
	print("%s took %s damage." % [name, amount])
	if CombatManager:
		CombatManager.tick_toxicity(1)

func _tick_detection() -> void:
	if CombatManager:
		CombatManager.tick_detection(1)

func _ensure_input_actions() -> void:
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var attack_key_event := InputEventKey.new()
	attack_key_event.keycode = KEY_F
	attack_key_event.physical_keycode = KEY_F
	if not InputMap.action_has_event("attack", attack_key_event):
		InputMap.action_add_event("attack", attack_key_event)
	var mouse_attack_event := InputEventMouseButton.new()
	mouse_attack_event.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("attack", mouse_attack_event):
		InputMap.action_add_event("attack", mouse_attack_event)
	if not InputMap.has_action("end_turn"):
		InputMap.add_action("end_turn")
		var end_turn_event := InputEventKey.new()
		end_turn_event.keycode = KEY_SPACE
		end_turn_event.physical_keycode = KEY_SPACE
		InputMap.action_add_event("end_turn", end_turn_event)

func _on_turn_started(actor: Node) -> void:
	if actor == self:
		reset_ap()
		last_attack_result = "Ready"

func _on_combat_started(_actors: Array) -> void:
	last_attack_result = "Ready"

func _on_combat_ended() -> void:
	last_attack_result = "Not in combat"

func create_player_sprite():
	"""Creates a basic colored rectangle as the player sprite."""
	var sprite = $Sprite2D
	# Create a simple colored rectangle using a ColorRect
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(32, 32)
	color_rect.color = Color.BLUE
	color_rect.position = Vector2(-16, -16)  # Center the rectangle
	sprite.add_child(color_rect)

func _on_elevation_area_entered(area: Area2D):
	if area is ElevationArea:
		current_elevation = area.elevation_level
		print("Entered elevation ", current_elevation)

func _on_elevation_area_exited(area: Area2D):
	if area is ElevationArea and area.elevation_level == current_elevation:
		current_elevation = 0
		print("Exited elevation; now ", current_elevation)
