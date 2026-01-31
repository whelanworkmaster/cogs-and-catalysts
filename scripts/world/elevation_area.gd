extends Area2D

class_name ElevationArea

@export var elevation_level: int = 0
@export var elevation_height: float = 24.0
@export var shadow_offset: Vector2 = Vector2(6.0, 8.0)
@export var shadow_alpha: float = 0.32
@export var shadow_scale: Vector2 = Vector2.ONE
@export var top_tint: Color = Color(0.28, 0.9, 1.0, 1.0)
@export var side_tint: Color = Color(0.1, 0.5, 0.7, 0.95)
@export var right_face_tint: Color = Color(0.08, 0.38, 0.55, 0.85)
@export var right_face_offset_scale: Vector2 = Vector2(0.55, 0.35)
@export var edge_highlight_alpha: float = 0.25

func _ready() -> void:
	_apply_depth_styling()

func _apply_depth_styling() -> void:
	if elevation_height == 0.0:
		return
	# Clean up any previously generated geometry (guards against duplicate() re-apply).
	_remove_generated_children()
	var zone_visual := get_node_or_null("ZoneVisual")
	if zone_visual and zone_visual is Node2D:
		# Reset position before applying lift so duplicated nodes don't double-shift.
		zone_visual.position.y = -elevation_height
		if zone_visual is Polygon2D:
			(zone_visual as Polygon2D).color = top_tint
	# ZoneSide is superseded by the generated FrontFace; hide it to avoid overlap.
	var zone_side := get_node_or_null("ZoneSide")
	if zone_side and zone_side is Node2D:
		zone_side.visible = false
	var zone_shadow := get_node_or_null("ZoneShadow")
	if zone_shadow and zone_shadow is Node2D:
		zone_shadow.z_index = -10
		zone_shadow.position = Vector2.ZERO
		if zone_shadow is Polygon2D and zone_visual and zone_visual is Polygon2D:
			(zone_shadow as Polygon2D).polygon = (zone_visual as Polygon2D).polygon
		var offset := shadow_offset
		offset.x = maxf(0.0, shadow_offset.x - elevation_height * 0.15)
		offset.y = maxf(0.0, shadow_offset.y - elevation_height * 0.2)
		zone_shadow.position = offset
		if zone_shadow is Polygon2D:
			var poly := zone_shadow as Polygon2D
			var c := poly.color
			poly.color = Color(c.r, c.g, c.b, shadow_alpha)
	var bounds := _get_polygon_bounds()
	if bounds.size == Vector2.ZERO:
		return
	_apply_front_face(bounds)
	_apply_right_face(bounds)
	_apply_edge_highlight(bounds)

func _remove_generated_children() -> void:
	for child_name in ["FrontFace", "RightFace", "EdgeHighlight"]:
		var existing := get_node_or_null(child_name)
		if existing:
			existing.queue_free()
	var zone_visual := get_node_or_null("ZoneVisual")
	if zone_visual:
		for name_to_remove in ["Underhang"]:
			var existing := zone_visual.get_node_or_null(name_to_remove)
			if existing:
				existing.queue_free()

## Returns Rect2 with polygon bounds (in ZoneVisual local space).
func _get_polygon_bounds() -> Rect2:
	var zone_visual := get_node_or_null("ZoneVisual")
	if not (zone_visual and zone_visual is Polygon2D):
		return Rect2()
	var poly := zone_visual as Polygon2D
	if poly.polygon.size() < 2:
		return Rect2()
	var min_x: float = poly.polygon[0].x
	var max_x: float = poly.polygon[0].x
	var top_y: float = poly.polygon[0].y
	var bottom_y: float = poly.polygon[0].y
	for point in poly.polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		top_y = minf(top_y, point.y)
		bottom_y = maxf(bottom_y, point.y)
	return Rect2(min_x, top_y, max_x - min_x, bottom_y - top_y)

func _apply_front_face(bounds: Rect2) -> void:
	var min_x: float = bounds.position.x
	var max_x: float = bounds.end.x
	var bottom_y: float = bounds.end.y
	# Front face fills the gap between the lifted top surface and the ground.
	# Overlap 2px into the top surface to prevent sub-pixel seams.
	var seam_overlap := 2.0
	var face := Polygon2D.new()
	face.name = "FrontFace"
	face.color = side_tint
	face.polygon = PackedVector2Array([
		Vector2(min_x, bottom_y - elevation_height - seam_overlap),
		Vector2(max_x, bottom_y - elevation_height - seam_overlap),
		Vector2(max_x, bottom_y),
		Vector2(min_x, bottom_y)
	])
	face.z_index = -1
	add_child(face)

func _apply_right_face(bounds: Rect2) -> void:
	var max_x: float = bounds.end.x
	var top_y: float = bounds.position.y
	var bottom_y: float = bounds.end.y
	var offset := Vector2(elevation_height * right_face_offset_scale.x, elevation_height * right_face_offset_scale.y)
	# Right face spans full height (top surface + front face) as a parallelogram.
	# Overlap 2px into the top/front to prevent sub-pixel seams at the shared edge.
	var seam_overlap := 2.0
	var face := Polygon2D.new()
	face.name = "RightFace"
	face.color = right_face_tint
	face.polygon = PackedVector2Array([
		Vector2(max_x - seam_overlap, top_y - elevation_height),
		Vector2(max_x - seam_overlap, bottom_y),
		Vector2(max_x + offset.x, bottom_y + offset.y),
		Vector2(max_x + offset.x, top_y - elevation_height + offset.y)
	])
	face.z_index = -1
	add_child(face)

func _apply_edge_highlight(bounds: Rect2) -> void:
	var min_x: float = bounds.position.x
	var max_x: float = bounds.end.x
	var bottom_y: float = bounds.end.y
	# Thin bright line at the top-front boundary to create a crisp edge.
	var edge := Polygon2D.new()
	edge.name = "EdgeHighlight"
	edge.color = Color(1.0, 1.0, 1.0, edge_highlight_alpha)
	var edge_thickness := 1.5
	var edge_y := bottom_y - elevation_height
	edge.polygon = PackedVector2Array([
		Vector2(min_x, edge_y - edge_thickness * 0.5),
		Vector2(max_x, edge_y - edge_thickness * 0.5),
		Vector2(max_x, edge_y + edge_thickness * 0.5),
		Vector2(min_x, edge_y + edge_thickness * 0.5)
	])
	edge.z_index = 1
	add_child(edge)
