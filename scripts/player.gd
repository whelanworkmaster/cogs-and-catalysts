extends CharacterBody2D

class_name Player

const DamagePopup = preload("res://scripts/ui/damage_popup.gd")

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
@export var max_hp: int = 12
var current_hp: int = 0
var last_damage_taken: int = 0
var last_damage_source: String = "-"
var mutagenic_cells: int = 0
var _hit_tween: Tween

enum Stance { NEUTRAL, GUARD, AGGRESS, EVADE }
@export var stance_ap_cost: int = 1
@export var disengage_ap_cost: int = 1
var current_stance: int = Stance.NEUTRAL
var disengage_active: bool = false

# Elevation tracking
var current_elevation: int = 0
@onready var elevation_detector: Area2D = $ElevationDetector
@onready var attack_area: Area2D = $AttackArea

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
	current_hp = max_hp
	add_to_group("player")
	_ensure_input_actions()
	elevation_detector.area_entered.connect(_on_elevation_area_entered)
	elevation_detector.area_exited.connect(_on_elevation_area_exited)
	_configure_attack_area()
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)
		CombatManager.combat_started.connect(_on_combat_started)
		CombatManager.combat_ended.connect(_on_combat_ended)
	# Create a basic visual representation
	create_player_sprite()

func _physics_process(delta):
	handle_stance_input()
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
				var step_distance: float = combat_step_distance
				var next_position: Vector2 = global_position + input_direction * step_distance
				_attempt_reaction_attack(next_position)
				global_position = next_position
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
		var damage := attack_damage + _get_attack_damage_bonus()
		damage = max(damage, 0)
		target.take_damage(damage, self)
		last_damage_dealt = damage
		last_attack_result = "Hit for %s" % damage
		print("Attack hit for ", damage)
		if current_stance == Stance.AGGRESS:
			_tick_detection()
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
	if not attack_area:
		return null
	var bodies := attack_area.get_overlapping_bodies()
	var best_target: Node = null
	var best_distance := INF
	for body in bodies:
		if body == null or not body.is_in_group("enemy"):
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance < best_distance:
			best_distance = distance
			best_target = body
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
	var reduced_amount: int = int(max(amount - _get_damage_reduction(), 0))
	current_hp = max(current_hp - reduced_amount, 0)
	last_damage_taken = reduced_amount
	last_damage_source = source.name if source else "-"
	print("%s took %s damage. HP: %s/%s" % [name, reduced_amount, current_hp, max_hp])
	_spawn_damage_popup(reduced_amount, Color(1.0, 0.8, 0.2))
	_play_hit_feedback()
	if CombatManager:
		CombatManager.tick_toxicity(1)
	if current_hp <= 0:
		print("%s is down." % name)

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
	if not InputMap.has_action("stance_cycle"):
		InputMap.add_action("stance_cycle")
		var stance_event := InputEventKey.new()
		stance_event.keycode = KEY_Q
		stance_event.physical_keycode = KEY_Q
		InputMap.action_add_event("stance_cycle", stance_event)
	if not InputMap.has_action("disengage"):
		InputMap.add_action("disengage")
		var disengage_event := InputEventKey.new()
		disengage_event.keycode = KEY_E
		disengage_event.physical_keycode = KEY_E
		InputMap.action_add_event("disengage", disengage_event)

func _on_turn_started(actor: Node) -> void:
	if actor == self:
		reset_ap()
		last_attack_result = "Ready"
		disengage_active = false

func _on_combat_started(_actors: Array) -> void:
	last_attack_result = "Ready"

func _on_combat_ended() -> void:
	last_attack_result = "Not in combat"
	disengage_active = false

func get_current_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return max_hp

func get_last_damage_taken() -> int:
	return last_damage_taken

func get_last_damage_source() -> String:
	return last_damage_source

func get_mutagenic_cells() -> int:
	return mutagenic_cells

func add_mutagenic_cells(amount: int) -> void:
	if amount <= 0:
		return
	mutagenic_cells += amount
	print("Collected %s Mutagenic Cells. Total: %s" % [amount, mutagenic_cells])

func get_stance_name() -> String:
	match current_stance:
		Stance.GUARD:
			return "Guard"
		Stance.AGGRESS:
			return "Aggress"
		Stance.EVADE:
			return "Evade"
		_:
			return "Neutral"

func is_disengage_active() -> bool:
	return disengage_active

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

func _configure_attack_area() -> void:
	if not attack_area:
		return
	attack_area.monitoring = true
	var shape_node := attack_area.get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape and shape_node.shape is CircleShape2D:
		shape_node.shape.radius = attack_contact_distance

func _get_attack_damage_bonus() -> int:
	if current_stance == Stance.AGGRESS:
		return 1
	return 0

func _get_damage_reduction() -> int:
	if current_stance == Stance.GUARD:
		return 1
	return 0

func handle_stance_input() -> void:
	if not CombatManager or not CombatManager.active_combat:
		return
	if CombatManager.get_current_actor() != self:
		return
	if Input.is_action_just_pressed("stance_cycle"):
		if spend_ap(stance_ap_cost):
			var next_stance: int = int((current_stance + 1) % Stance.size())
			current_stance = next_stance
			print("Stance changed to ", get_stance_name())
	if Input.is_action_just_pressed("disengage"):
		if spend_ap(disengage_ap_cost):
			disengage_active = true
			print("Disengage active for this turn.")

func _attempt_reaction_attack(next_position: Vector2) -> void:
	if current_stance == Stance.EVADE:
		return
	if disengage_active:
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	var attacker: Node = null
	var best_distance: float = INF
	for enemy in enemies:
		var enemy_node: Node = enemy
		if enemy_node == null or not enemy_node.has_method("get_attack_contact_distance"):
			continue
		var threat_distance: float = float(enemy_node.get_attack_contact_distance())
		var in_threat_now: bool = global_position.distance_to(enemy_node.global_position) <= threat_distance
		var in_threat_next: bool = next_position.distance_to(enemy_node.global_position) <= threat_distance
		if in_threat_now and not in_threat_next:
			var distance_now: float = global_position.distance_to(enemy_node.global_position)
			if distance_now < best_distance:
				best_distance = distance_now
				attacker = enemy_node
	if attacker and attacker.has_method("attack"):
		attacker.attack(self)
		print("Reaction attack triggered.")

func _play_hit_feedback() -> void:
	if not has_node("Sprite2D"):
		return
	var sprite := $Sprite2D
	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(sprite, "scale", Vector2(1.08, 0.92), 0.06)
	_hit_tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	if sprite.get_child_count() > 0:
		var rect := sprite.get_child(0)
		if rect is ColorRect:
			var base_color: Color = rect.color
			_hit_tween.parallel().tween_property(rect, "color", Color(1.0, 1.0, 1.0), 0.05)
			_hit_tween.tween_property(rect, "color", base_color, 0.08)

func _spawn_damage_popup(amount: int, color: Color) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var popup := DamagePopup.new()
	popup.amount = amount
	popup.color = color
	popup.global_position = global_position + Vector2(0, -20)
	scene.add_child(popup)
