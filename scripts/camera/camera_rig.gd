extends Node3D

class_name CameraRig

@export var orbit_speed: float = 0.005
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 60.0
@export var initial_zoom: float = 30.0
@export var initial_pitch_deg: float = -45.0
@export var initial_yaw_deg: float = -30.0
@export var min_pitch_deg: float = -80.0
@export var max_pitch_deg: float = -15.0
@export var follow_target: NodePath = ""
@export var follow_smoothing: float = 8.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _zoom: float = 0.0
var _is_orbiting: bool = false

@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_yaw = deg_to_rad(initial_yaw_deg)
	_pitch = deg_to_rad(initial_pitch_deg)
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
			_zoom = maxf(min_zoom, _zoom - zoom_speed)
			_camera.size = _zoom
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(max_zoom, _zoom + zoom_speed)
			_camera.size = _zoom
	elif event is InputEventMouseMotion and _is_orbiting:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * orbit_speed
		_pitch -= motion.relative.y * orbit_speed
		_pitch = clampf(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

func _process(delta: float) -> void:
	if not follow_target.is_empty():
		var target := get_node_or_null(follow_target)
		if target and target is Node3D:
			var target_pos: Vector3 = (target as Node3D).global_position
			global_position = global_position.lerp(target_pos, follow_smoothing * delta)
	_update_camera_transform()

func _update_camera_transform() -> void:
	if not _camera:
		return
	# Spherical coordinates: camera orbits around the rig origin
	var distance := 50.0
	var offset := Vector3.ZERO
	offset.x = distance * cos(_pitch) * sin(_yaw)
	offset.y = distance * -sin(_pitch)
	offset.z = distance * cos(_pitch) * cos(_yaw)
	_camera.position = offset
	_camera.look_at(Vector3.ZERO)
