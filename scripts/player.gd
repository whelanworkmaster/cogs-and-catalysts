extends CharacterBody3D

class_name Player

const DamagePopup = preload("res://scripts/ui/damage_popup.gd")

# Movement variables
@export var speed: float = 750.0

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
var _death_tween: Tween
var _is_dead: bool = false

enum Stance { NEUTRAL, GUARD, AGGRESS, EVADE }
@export var stance_ap_cost: int = 1
@export var disengage_ap_cost: int = 1
var current_stance: int = Stance.NEUTRAL
var disengage_active: bool = false

# Elevation tracking
var current_elevation: int = 0
var current_elevation_height: float = 0.0
@onready var elevation_detector: Area3D = $ElevationDetector
@onready var attack_area: Area3D = $AttackArea
var _visual_root: Node3D
var _body_mesh: CSGBox3D
var _facing_indicator: CSGPolygon3D
var _facing_direction: Vector3 = Vector3.FORWARD

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
	_setup_visual()

func _setup_visual() -> void:
	_visual_root = $VisualRoot if has_node("VisualRoot") else null
	_body_mesh = $VisualRoot/BodyBox if has_node("VisualRoot/BodyBox") else null
	if _body_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.45, 1.0)
		_body_mesh.material = mat
	_create_facing_indicator()

func _create_facing_indicator() -> void:
	if not _visual_root:
		return
	_facing_indicator = CSGPolygon3D.new()
	_facing_indicator.name = "FacingIndicator"
	# Create arrow shape (triangle pointing forward)
	var arrow_points := PackedVector2Array([
		Vector2(0, 16),      # tip
		Vector2(-8, 0),      # left base
		Vector2(8, 0)        # right base
	])
	_facing_indicator.polygon = arrow_points
	_facing_indicator.depth = 4.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_facing_indicator.material = mat
	_visual_root.add_child(_facing_indicator)
	# Update position and rotation immediately
	_update_facing_indicator()

func _physics_process(delta):
	if _is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return
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
			velocity = Vector3.ZERO
			move_and_slide()
			return

	var input_direction = Vector3.ZERO

	# Get input for 8-way movement (mapped to XZ plane)
	if Input.is_action_pressed("ui_up"):
		input_direction.z -= 1
	if Input.is_action_pressed("ui_down"):
		input_direction.z += 1
	if Input.is_action_pressed("ui_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_direction.x += 1

	if input_direction != Vector3.ZERO:
		input_direction = input_direction.normalized()
		_facing_direction = input_direction
		_update_facing_indicator()

		var requires_ap := CombatManager and CombatManager.active_combat
		if requires_ap:
			if combat_move_cooldown_timer > 0.0:
				velocity = Vector3.ZERO
				move_and_slide()
				return
			if spend_ap(_get_ap_cost("move")):
				var step_distance: float = combat_step_distance
				var next_position: Vector3 = global_position + input_direction * step_distance
				var world := get_tree().current_scene
				if world and world.has_method("snap_to_grid"):
					next_position = world.snap_to_grid(next_position)
				_attempt_reaction_attack(next_position)
				global_position = next_position
				combat_move_cooldown_timer = combat_move_cooldown
				_tick_detection()
			else:
				print("Not enough AP to move!")
			velocity = Vector3.ZERO
		else:
			velocity = input_direction * speed
	else:
		velocity = Vector3.ZERO

	move_and_slide()

func handle_attack_input() -> void:
	if _is_dead:
		return
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

func spend_ap(amount: int) -> bool:
	if current_ap >= amount:
		current_ap -= amount
		print("Spent ", amount, " AP. Remaining: ", current_ap, "/", max_ap)
		return true
	else:
		print("Cannot spend ", amount, " AP. Only have ", current_ap, " available.")
		return false

func restore_ap(amount: int):
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
		if body.has_method("get_elevation_level") and body.get_elevation_level() != current_elevation:
			continue
		var distance := _xz_distance_to(body.global_position)
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
	if _is_dead:
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
		_die()

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	print("%s is down." % name)
	if CombatManager:
		CombatManager.end_combat()
	_play_death_effect()
	_show_game_over()

func _tick_detection() -> void:
	if CombatManager:
		CombatManager.tick_detection(1)

func _ensure_input_actions() -> void:
	# Add WASD to movement actions
	if InputMap.has_action("ui_up"):
		var w_key := InputEventKey.new()
		w_key.keycode = KEY_W
		w_key.physical_keycode = KEY_W
		if not InputMap.action_has_event("ui_up", w_key):
			InputMap.action_add_event("ui_up", w_key)
	if InputMap.has_action("ui_down"):
		var s_key := InputEventKey.new()
		s_key.keycode = KEY_S
		s_key.physical_keycode = KEY_S
		if not InputMap.action_has_event("ui_down", s_key):
			InputMap.action_add_event("ui_down", s_key)
	if InputMap.has_action("ui_left"):
		var a_key := InputEventKey.new()
		a_key.keycode = KEY_A
		a_key.physical_keycode = KEY_A
		if not InputMap.action_has_event("ui_left", a_key):
			InputMap.action_add_event("ui_left", a_key)
	if InputMap.has_action("ui_right"):
		var d_key := InputEventKey.new()
		d_key.keycode = KEY_D
		d_key.physical_keycode = KEY_D
		if not InputMap.action_has_event("ui_right", d_key):
			InputMap.action_add_event("ui_right", d_key)

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

func get_elevation_level() -> int:
	return current_elevation

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

func _on_elevation_area_entered(area: Area3D):
	if area.has_method("get") and "elevation_level" in area:
		current_elevation = area.elevation_level
		current_elevation_height = area.elevation_height
		_apply_elevation_visuals()
		print("Entered elevation ", current_elevation)

func _on_elevation_area_exited(area: Area3D):
	if area.has_method("get") and "elevation_level" in area:
		if area.elevation_level == current_elevation:
			current_elevation = 0
			current_elevation_height = 0.0
			_apply_elevation_visuals()
			print("Exited elevation; now ", current_elevation)

func _configure_attack_area() -> void:
	if not attack_area:
		return
	attack_area.monitoring = true
	var shape_node := attack_area.get_node_or_null("CollisionShape3D")
	if shape_node and shape_node is CollisionShape3D and shape_node.shape is SphereShape3D:
		(shape_node.shape as SphereShape3D).radius = attack_contact_distance

func _get_attack_damage_bonus() -> int:
	if current_stance == Stance.AGGRESS:
		return 1
	return 0

func _get_damage_reduction() -> int:
	if current_stance == Stance.GUARD:
		return 1
	return 0

func _apply_elevation_visuals() -> void:
	global_position.y = current_elevation_height

func _update_facing_indicator() -> void:
	if not _facing_indicator:
		return
	# Calculate angle from facing direction and update rotation while preserving X tilt
	var angle := atan2(_facing_direction.x, _facing_direction.z)
	_facing_indicator.rotation = Vector3(-PI/2, angle, 0)
	# Position the arrow in front of the character
	var offset := _facing_direction * 20.0  # 20 units in front
	_facing_indicator.position = Vector3(offset.x, 2, offset.z)

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

func _attempt_reaction_attack(next_position: Vector3) -> void:
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
		var in_threat_now: bool = _xz_distance_to(enemy_node.global_position) <= threat_distance
		var in_threat_next: bool = _xz_distance(next_position, enemy_node.global_position) <= threat_distance
		if in_threat_now and not in_threat_next:
			var distance_now: float = _xz_distance_to(enemy_node.global_position)
			if distance_now < best_distance:
				best_distance = distance_now
				attacker = enemy_node
	if attacker and attacker.has_method("attack"):
		attacker.attack(self)
		print("Reaction attack triggered.")

func _play_hit_feedback() -> void:
	if not _visual_root:
		return
	if _hit_tween and _hit_tween.is_running():
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(_visual_root, "scale", Vector3(1.08, 0.92, 1.08), 0.06)
	_hit_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.08)
	if _body_mesh and _body_mesh.material:
		var mat: StandardMaterial3D = _body_mesh.material as StandardMaterial3D
		if mat:
			var base_color: Color = mat.albedo_color
			_hit_tween.parallel().tween_property(mat, "albedo_color", Color(1.0, 1.0, 1.0), 0.05)
			_hit_tween.tween_property(mat, "albedo_color", base_color, 0.08)

func _play_death_effect() -> void:
	if not _visual_root:
		return
	if _death_tween and _death_tween.is_running():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(_visual_root, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	_death_tween.tween_property(_visual_root, "scale", Vector3(0.1, 0.1, 0.1), 0.2)

func _show_game_over() -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var overlay := scene.get_node_or_null("GameOver")
	if overlay and overlay.has_method("show_game_over"):
		overlay.show_game_over()

func _spawn_damage_popup(amount: int, color: Color) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if not scene:
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var world_pos := global_position + Vector3(0, 16, 0)
	var screen_pos := camera.unproject_position(world_pos)
	var popup := DamagePopup.new()
	popup.amount = amount
	popup.color = color
	popup.global_position = screen_pos
	scene.add_child(popup)

## Returns XZ-plane distance from this node to the given position (ignores Y).
func _xz_distance_to(target: Vector3) -> float:
	var a := Vector2(global_position.x, global_position.z)
	var b := Vector2(target.x, target.z)
	return a.distance_to(b)

## Returns XZ-plane distance between two positions (ignores Y).
static func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
