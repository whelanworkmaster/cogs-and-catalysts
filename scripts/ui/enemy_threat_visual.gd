extends MeshInstance3D

class_name EnemyThreatVisual

@export var ring_color: Color = Color(1.0, 0.4, 0.4, 0.25)
@export var ring_segments: int = 48

var _mat: StandardMaterial3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = ring_color
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	material_override = _mat

func _process(_delta: float) -> void:
	var enemy := get_parent()
	if enemy == null:
		return
	if not CombatManager or not CombatManager.active_combat:
		mesh = null
		return
	if not enemy.has_method("get_attack_contact_distance"):
		mesh = null
		return
	var radius: float = float(enemy.get_attack_contact_distance())
	_rebuild_ring(radius)

func _rebuild_ring(radius: float) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(ring_segments + 1):
		var angle := TAU * float(i) / float(ring_segments)
		im.surface_add_vertex(Vector3(cos(angle) * radius, 0.5, sin(angle) * radius))
	im.surface_end()
	mesh = im
