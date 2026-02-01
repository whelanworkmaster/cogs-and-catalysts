extends Area3D

class_name ElevationArea

@export var elevation_level: int = 0
@export var elevation_height: float = 24.0
@export var building_size: Vector3 = Vector3(128, 24, 96)
@export var building_color: Color = Color(0.2, 0.65, 0.8, 1.0)

func _ready() -> void:
	add_to_group("nav_obstacle")
	_build_visual()
	_build_blocker()
	_build_detection_shape()

func _build_visual() -> void:
	var mesh := CSGBox3D.new()
	mesh.name = "BuildingMesh"
	mesh.size = Vector3(building_size.x, elevation_height, building_size.z)
	mesh.transform.origin = Vector3(0, elevation_height * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = building_color
	mesh.material = mat
	add_child(mesh)

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
