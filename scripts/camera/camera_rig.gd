extends Node3D

class_name CameraRig

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 60.0
@export var initial_zoom: float = 30.0
@export var pitch_deg: float = -30.0
@export var initial_yaw_deg: float = -30.0
@export var follow_target: NodePath = ""
@export var follow_smoothing: float = 8.0
@export var pan_speed: float = 600.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 0.0
var _is_orbiting: bool = false

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_ensure_camera_actions()
	_yaw = deg_to_rad(initial_yaw_deg)
	_pitch = deg_to_rad(pitch_deg)
	_zoom = initial_zoom
	if not _camera:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_camera.projection = 1  # PROJECTION_ORTHOGRAPHIC
	_camera.size = _zoom
	_update_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = minf(max_zoom, _zoom + zoom_speed)
			_camera.size = _zoom
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxf(min_zoom, _zoom - zoom_speed)
			_camera.size = _zoom
	elif event is InputEventMouseMotion and _is_orbiting:
		var motion := event as InputEventMouseMotion
		# Only allow yaw rotation (horizontal), pitch is locked
		_yaw += motion.relative.x * orbit_speed

func _process(delta: float) -> void:
	var is_panning := _handle_manual_pan(delta)
	if is_panning:
		# Manual pan takes camera control away from character follow until reselected.
		follow_target = NodePath("")
	if not follow_target.is_empty():
		var target := get_node_or_null(follow_target)
		if target and target is Node3D:
			var target_pos: Vector3 = (target as Node3D).global_position
			global_position = global_position.lerp(target_pos, follow_smoothing * delta)
	_update_camera_transform()

func _handle_manual_pan(delta: float) -> bool:
	var input := Vector2.ZERO
	if Input.is_action_pressed("camera_pan_right"):
		input.x -= 1.0
	if Input.is_action_pressed("camera_pan_left"):
		input.x += 1.0
	if Input.is_action_pressed("camera_pan_down"):
		input.y -= 1.0
	if Input.is_action_pressed("camera_pan_up"):
		input.y += 1.0
	if input.length_squared() <= 0.0:
		return false
	input = input.normalized()
	var forward := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
	forward.y = 0.0
	forward = forward.normalized()
	var right := Vector3.RIGHT.rotated(Vector3.UP, _yaw)
	right.y = 0.0
	right = right.normalized()
	var move_dir := (right * input.x) + (forward * input.y)
	global_position += move_dir * pan_speed * delta
	return true

func _ensure_camera_actions() -> void:
	_add_key_action("camera_pan_up", KEY_W)
	_add_key_action("camera_pan_down", KEY_S)
	_add_key_action("camera_pan_left", KEY_A)
	_add_key_action("camera_pan_right", KEY_D)

func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action_name, event):
		InputMap.action_add_event(action_name, event)

func _update_camera_transform() -> void:
	if not _camera:
		return
	# Distance must scale with ortho size so the bottom of the view stays above ground
	var distance := _zoom * 1.0

	# Use spherical coordinates to position camera in orbit
	# The pitch is locked at 45 degrees down, yaw rotates around
	var pitch_from_horizontal := absf(_pitch)  # 45 degrees
	var height := distance * sin(pitch_from_horizontal)
	var radius := distance * cos(pitch_from_horizontal)

	# Start behind the origin (positive Z), then rotate by yaw around Y axis
	var base_position := Vector3(0, height, radius)
	var camera_offset := base_position.rotated(Vector3.UP, _yaw)

	_camera.position = camera_offset

	# Manually construct camera rotation to avoid look_at issues
	# Calculate direction from camera to target (forward)
	var to_target := (Vector3.ZERO - camera_offset).normalized()
	# Calculate right vector (perpendicular to forward and world up)
	var camera_right := Vector3.UP.cross(to_target).normalized()
	# Calculate up vector (perpendicular to forward and right, ensures no roll)
	var camera_up := to_target.cross(camera_right).normalized()
	# Construct basis (camera looks along -Z, so Z axis is opposite of forward)
	_camera.basis = Basis(camera_right, camera_up, -to_target)
