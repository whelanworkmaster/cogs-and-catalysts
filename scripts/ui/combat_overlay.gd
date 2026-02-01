extends MeshInstance3D

class_name CombatOverlay

@export var stance_radius: float = 22.0
@export var disengage_radius: float = 28.0
@export var ring_segments: int = 32

var _mat: StandardMaterial3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.vertex_color_use_as_albedo = true
	material_override = _mat

func _process(_delta: float) -> void:
	var player := get_parent()
	if player == null:
		mesh = null
		return
	if not CombatManager or not CombatManager.active_combat:
		mesh = null
		return
	_rebuild(player)

func _rebuild(player: Node) -> void:
	var im := ImmediateMesh.new()

	# Stance ring
	if player.has_method("get_stance_name"):
		var stance_name: String = str(player.get_stance_name())
		var color: Color = Color(0.6, 0.6, 0.6, 0.7)
		match stance_name:
			"Guard":
				color = Color(0.2, 0.6, 1.0, 0.8)
			"Aggress":
				color = Color(1.0, 0.3, 0.3, 0.8)
			"Evade":
				color = Color(0.3, 1.0, 0.5, 0.8)
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(ring_segments + 1):
			var angle := TAU * float(i) / float(ring_segments)
			im.surface_set_color(color)
			im.surface_add_vertex(Vector3(cos(angle) * stance_radius, 0.5, sin(angle) * stance_radius))
		im.surface_end()

	# Disengage ring (dashed)
	if player.has_method("is_disengage_active") and player.is_disengage_active():
		var color := Color(1.0, 1.0, 0.4, 0.8)
		var dash_segments := 12
		var gap := TAU / float(dash_segments)
		for j in range(dash_segments):
			if j % 2 == 0:
				im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
				var start_angle := j * gap
				var end_angle := start_angle + gap * 0.6
				var steps := 6
				for k in range(steps + 1):
					var angle := start_angle + (end_angle - start_angle) * float(k) / float(steps)
					im.surface_set_color(color)
					im.surface_add_vertex(Vector3(cos(angle) * disengage_radius, 0.5, sin(angle) * disengage_radius))
				im.surface_end()

	mesh = im
