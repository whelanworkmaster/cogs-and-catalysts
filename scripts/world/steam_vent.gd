extends Area3D

class_name SteamVent

const KAYKIT_CAN_SCENE := preload("res://addons/kaykit_prototype_bits/Assets/gltf/Can_A.gltf")
const KAYKIT_FLOOR_SCENE := preload("res://addons/kaykit_prototype_bits/Assets/gltf/Floor_Prototype.gltf")

@export var damage_amount: int = 0
@export var toxicity_ticks: int = 1
@export var affect_player: bool = true
@export var affect_enemies: bool = false
@export var cooldown_seconds: float = 0.8
@export var vent_size: Vector3 = Vector3(32, 4, 32)
@export var vent_color: Color = Color(0.7, 0.9, 0.3, 0.7)

var _last_trigger_time: Dictionary = {}

func _ready() -> void:
	add_to_group("steam_vent")
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visual()
	_build_detection_shape()

func _build_visual() -> void:
	var root := Node3D.new()
	root.name = "VentMesh"
	add_child(root)

	var grate := KAYKIT_FLOOR_SCENE.instantiate()
	if grate is Node3D:
		var grate_node := grate as Node3D
		grate_node.scale = Vector3(vent_size.x / 4.0, 1.0, vent_size.z / 4.0)
		root.add_child(grate_node)

	var can_offsets := [
		Vector3(vent_size.x * 0.25, 0.0, vent_size.z * 0.25),
		Vector3(-vent_size.x * 0.25, 0.0, vent_size.z * 0.25),
		Vector3(vent_size.x * 0.25, 0.0, -vent_size.z * 0.25),
		Vector3(-vent_size.x * 0.25, 0.0, -vent_size.z * 0.25)
	]
	for offset in can_offsets:
		var can := KAYKIT_CAN_SCENE.instantiate()
		if can is Node3D:
			var can_node := can as Node3D
			can_node.position = offset
			can_node.scale = Vector3(20.0, 20.0, 20.0)
			root.add_child(can_node)

	var glow := MeshInstance3D.new()
	glow.name = "VentGlow"
	var box := BoxMesh.new()
	box.size = vent_size
	glow.mesh = box
	glow.position = Vector3(0.0, vent_size.y * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vent_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.95, 0.4, 1.0)
	mat.emission_energy_multiplier = 0.35
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = mat
	root.add_child(glow)

func _build_detection_shape() -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(vent_size.x, vent_size.y + 32.0, vent_size.z)
	shape_node.shape = box
	shape_node.transform.origin = Vector3(0, (vent_size.y + 32.0) * 0.5, 0)
	add_child(shape_node)

func _on_body_entered(body: Node) -> void:
	if not _should_affect(body):
		return
	if _is_on_cooldown(body):
		return
	_apply_effect(body)
	_last_trigger_time[body] = Time.get_ticks_msec()

func _should_affect(body: Node) -> bool:
	if body.is_in_group("player"):
		return affect_player
	if body.is_in_group("enemy"):
		return affect_enemies
	return false

func _is_on_cooldown(body: Node) -> bool:
	if cooldown_seconds <= 0.0:
		return false
	if not _last_trigger_time.has(body):
		return false
	var last_time: int = int(_last_trigger_time[body])
	return (Time.get_ticks_msec() - last_time) < int(cooldown_seconds * 1000.0)

func _apply_effect(body: Node) -> void:
	if damage_amount > 0 and body.has_method("take_damage"):
		body.take_damage(damage_amount, self)
	if toxicity_ticks > 0 and CombatManager:
		if not (damage_amount > 0 and body.is_in_group("player")):
			CombatManager.tick_toxicity_load(toxicity_ticks)
