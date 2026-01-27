extends CharacterBody2D

class_name Player

# Movement variables
@export var speed: float = 750.0
@export var isometric_factor: float = 0.577  # tan(30°) for isometric projection

# Action Points system
var current_ap: int = 10
@export var max_ap: int = 10
@export var move_ap_cost: int = 1
@export var ap_regen_per_second: float = 2.0
var ap_regen_accumulator: float = 0.0

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
	# Create a basic visual representation
	create_player_sprite()

func _physics_process(delta):
	regen_ap(delta)
	handle_movement()

func handle_movement():
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
		
		# Check if move is legal (has enough AP)
		if spend_ap(move_ap_cost):
			velocity = input_direction * speed
		else:
			velocity = Vector2.ZERO
			print("Not enough AP to move!")
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

func create_player_sprite():
	"""Creates a basic colored rectangle as the player sprite."""
	var sprite = $Sprite2D
	# Create a simple colored rectangle using a ColorRect
	var color_rect = ColorRect.new()
	color_rect.size = Vector2(32, 32)
	color_rect.color = Color.BLUE
	color_rect.position = Vector2(-16, -16)  # Center the rectangle
	sprite.add_child(color_rect)
