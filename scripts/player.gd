extends CharacterBody2D

class_name Player

const ElevationArea = preload("res://scripts/world/elevation_area.gd")

# Movement variables
@export var speed: float = 750.0
@export var isometric_factor: float = 0.577  # tan(30°) for isometric projection

# Action Points system
var current_ap: int = 10
@export var max_ap: int = 10
@export var move_ap_cost: int = 1
@export var ap_regen_per_second: float = 2.0
var ap_regen_accumulator: float = 0.0
@export var combat_step_distance: float = 32.0
@export var combat_move_cooldown: float = 0.2
var combat_move_cooldown_timer: float = 0.0

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
	elevation_detector.area_entered.connect(_on_elevation_area_entered)
	elevation_detector.area_exited.connect(_on_elevation_area_exited)
	if CombatManager:
		CombatManager.turn_started.connect(_on_turn_started)
	# Create a basic visual representation
	create_player_sprite()

func _physics_process(delta):
	handle_turn_input()
	if combat_move_cooldown_timer > 0.0:
		combat_move_cooldown_timer = max(0.0, combat_move_cooldown_timer - delta)
	handle_movement()

func handle_turn_input():
	if not CombatManager:
		return
	if not CombatManager.active_combat:
		return
	if CombatManager.get_current_actor() != self:
		return
	if Input.is_action_just_pressed("ui_accept"):
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
			if spend_ap(move_ap_cost):
				global_position += input_direction * combat_step_distance
				combat_move_cooldown_timer = combat_move_cooldown
			else:
				print("Not enough AP to move!")
			velocity = Vector2.ZERO
		else:
			velocity = input_direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

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

func _on_turn_started(actor: Node) -> void:
	if actor == self:
		reset_ap()

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
