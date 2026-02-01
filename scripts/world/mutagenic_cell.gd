extends Node3D

class_name MutagenicCell

@export var value: int = 1
var pickup_area: Area3D

func _ready() -> void:
	_create_visual()
	_create_pickup_area()
	_start_pulse()

func _create_visual() -> void:
	var mesh := CSGBox3D.new()
	mesh.name = "CellMesh"
	mesh.size = Vector3(12, 12, 12)
	mesh.transform.origin = Vector3(0, 6, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.95, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.95, 0.6)
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	add_child(mesh)

func _start_pulse() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.5)
	tween.tween_property(self, "scale", Vector3.ONE, 0.5)

func _create_pickup_area() -> void:
	pickup_area = Area3D.new()
	pickup_area.monitoring = true
	add_child(pickup_area)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 20.0
	shape.shape = sphere
	pickup_area.add_child(shape)
	pickup_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if body.has_method("add_mutagenic_cells"):
		body.add_mutagenic_cells(value)
	queue_free()
