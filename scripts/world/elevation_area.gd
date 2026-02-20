extends Area3D

class_name ElevationArea

enum BuildingVisualStyle {
	BASIC_BLOCK,
	ART_DECO
}

const KAYKIT_TEXTURE := preload("res://addons/kaykit_prototype_bits/Assets/textures/prototypebits_texture.png")

@export var elevation_level: int = 0
@export var elevation_height: float = 24.0
@export var building_size: Vector3 = Vector3(128, 24, 96)
@export var building_color: Color = Color(0.2, 0.65, 0.8, 1.0)
@export var visual_style: BuildingVisualStyle = BuildingVisualStyle.ART_DECO
@export var deco_base_color: Color = Color(0.31, 0.29, 0.26, 1.0)
@export var deco_trim_color: Color = Color(0.81, 0.68, 0.41, 1.0)
@export var deco_accent_color: Color = Color(0.55, 0.72, 0.75, 1.0)
@export var deco_rib_depth: float = 2.0

func _ready() -> void:
	add_to_group("nav_obstacle")
	_build_visual()
	_build_blocker()
	_build_detection_shape()

func _build_visual() -> void:
	var root := Node3D.new()
	root.name = "BuildingVisualRoot"
	add_child(root)
	match visual_style:
		BuildingVisualStyle.ART_DECO:
			_build_art_deco_visual(root)
		_:
			_build_basic_visual(root)

func _build_basic_visual(root: Node3D) -> void:
	_add_box_part(root, "BuildingMesh", Vector3(building_size.x, elevation_height, building_size.z), Vector3(0.0, elevation_height * 0.5, 0.0), building_color, 0.05, 0.92)

func _build_art_deco_visual(root: Node3D) -> void:
	var width := building_size.x
	var depth := building_size.z
	var levels := [
		{"height": elevation_height * 0.48, "shrink": 1.00, "color": deco_base_color},
		{"height": elevation_height * 0.30, "shrink": 0.82, "color": deco_base_color.lerp(deco_trim_color, 0.25)},
		{"height": elevation_height * 0.22, "shrink": 0.64, "color": deco_base_color.lerp(deco_trim_color, 0.45)}
	]
	var y_cursor := 0.0
	for i in range(levels.size()):
		var level_data: Dictionary = levels[i]
		var segment_height := float(level_data.get("height", 0.0))
		var shrink := float(level_data.get("shrink", 1.0))
		var segment_color := level_data.get("color", deco_base_color) as Color
		var segment_size := Vector3(maxf(width * shrink, 16.0), segment_height, maxf(depth * shrink, 16.0))
		var segment_center := Vector3(0.0, y_cursor + segment_height * 0.5, 0.0)
		_add_box_part(root, "DecoTier%s" % i, segment_size, segment_center, segment_color, 0.18, 0.48)
		if i == 0:
			_add_vertical_ribs(root, segment_size, y_cursor, segment_height)
		y_cursor += segment_height

	var crown_height := maxf(elevation_height * 0.14, 5.0)
	var crown_size := Vector3(maxf(width * 0.35, 10.0), crown_height, maxf(depth * 0.35, 10.0))
	_add_box_part(root, "DecoCrown", crown_size, Vector3(0.0, elevation_height + crown_height * 0.5, 0.0), deco_trim_color, 0.52, 0.28)

	var spire_height := maxf(elevation_height * 0.1, 4.0)
	var spire_size := Vector3(maxf(width * 0.08, 4.0), spire_height, maxf(depth * 0.08, 4.0))
	_add_box_part(root, "DecoSpire", spire_size, Vector3(0.0, elevation_height + crown_height + spire_height * 0.5, 0.0), deco_accent_color, 0.35, 0.36)

func _add_vertical_ribs(root: Node3D, tier_size: Vector3, tier_base_y: float, tier_height: float) -> void:
	var rib_height := tier_height * 0.9
	var rib_width := 2.4
	var side_depth := deco_rib_depth
	var horizontal_count := maxi(int(floor(tier_size.x / 20.0)), 2)
	var depth_count := maxi(int(floor(tier_size.z / 24.0)), 2)

	for i in range(horizontal_count):
		var t := 0.5 if horizontal_count == 1 else float(i) / float(horizontal_count - 1)
		var x := lerpf(-tier_size.x * 0.5 + 6.0, tier_size.x * 0.5 - 6.0, t)
		var y := tier_base_y + rib_height * 0.5
		_add_box_part(root, "RibNorth%s" % i, Vector3(rib_width, rib_height, side_depth), Vector3(x, y, -tier_size.z * 0.5 - side_depth * 0.5), deco_trim_color, 0.5, 0.34)
		_add_box_part(root, "RibSouth%s" % i, Vector3(rib_width, rib_height, side_depth), Vector3(x, y, tier_size.z * 0.5 + side_depth * 0.5), deco_trim_color, 0.5, 0.34)

	for i in range(depth_count):
		var t := 0.5 if depth_count == 1 else float(i) / float(depth_count - 1)
		var z := lerpf(-tier_size.z * 0.5 + 6.0, tier_size.z * 0.5 - 6.0, t)
		var y := tier_base_y + rib_height * 0.5
		_add_box_part(root, "RibWest%s" % i, Vector3(side_depth, rib_height, rib_width), Vector3(-tier_size.x * 0.5 - side_depth * 0.5, y, z), deco_trim_color, 0.5, 0.34)
		_add_box_part(root, "RibEast%s" % i, Vector3(side_depth, rib_height, rib_width), Vector3(tier_size.x * 0.5 + side_depth * 0.5, y, z), deco_trim_color, 0.5, 0.34)

func _add_box_part(root: Node3D, part_name: String, size: Vector3, local_pos: Vector3, albedo: Color, metallic: float, roughness: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.transform.origin = local_pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.albedo_texture = KAYKIT_TEXTURE
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.04, 0.04, 0.04)
	mat.metallic = metallic
	mat.roughness = roughness
	mesh.material_override = mat
	root.add_child(mesh)

func _build_blocker() -> void:
	var body := StaticBody3D.new()
	body.name = "ElevationBlocker"
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(building_size.x, elevation_height, building_size.z)
	shape_node.shape = box
	shape_node.transform.origin = Vector3(0, elevation_height * 0.5, 0)
	body.add_child(shape_node)
	add_child(body)

func _build_detection_shape() -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Detection area sits on the top surface of the building
	box.size = Vector3(building_size.x, 4.0, building_size.z)
	shape_node.shape = box
	shape_node.transform.origin = Vector3(0, elevation_height + 2.0, 0)
	add_child(shape_node)
