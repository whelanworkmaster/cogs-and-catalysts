extends Area3D

class_name SteamVent

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
	var mesh := CSGBox3D.new()
	mesh.name = "VentMesh"
	mesh.size = vent_size
	mesh.transform.origin = Vector3(0, vent_size.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = vent_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	add_child(mesh)

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
			CombatManager.tick_toxicity(toxicity_ticks)
