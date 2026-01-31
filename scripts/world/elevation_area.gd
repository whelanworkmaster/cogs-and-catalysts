extends Area2D

class_name ElevationArea

@export var elevation_level: int = 0
@export var elevation_height: float = 24.0
@export var shadow_offset: Vector2 = Vector2(6.0, 8.0)
@export var shadow_alpha: float = 0.32
@export var shadow_scale: Vector2 = Vector2.ONE
@export var underhang_alpha: float = 0.5
@export var top_tint: Color = Color(0.28, 0.9, 1.0, 1.0)
@export var side_tint: Color = Color(0.1, 0.5, 0.7, 0.95)
@export var right_face_tint: Color = Color(0.08, 0.38, 0.55, 0.85)
@export var right_face_offset_scale: Vector2 = Vector2(0.55, 0.35)

func _ready() -> void:
	_apply_depth_styling()

func _apply_depth_styling() -> void:
	if elevation_height == 0.0:
		return
	var zone_visual := get_node_or_null("ZoneVisual")
	if zone_visual and zone_visual is Node2D:
		zone_visual.position.y -= elevation_height
		if zone_visual is Polygon2D:
			(zone_visual as Polygon2D).color = top_tint
	var zone_side := get_node_or_null("ZoneSide")
	if zone_side and zone_side is Node2D:
		zone_side.position.y -= elevation_height
		if zone_side is Polygon2D:
			(zone_side as Polygon2D).color = side_tint
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
	_apply_underhang()
	_apply_right_face()

func _apply_underhang() -> void:
	var zone_visual := get_node_or_null("ZoneVisual")
	if not (zone_visual and zone_visual is Polygon2D):
		return
	var poly := zone_visual as Polygon2D
	if poly.polygon.size() < 2:
		return
	var bottom_y: float = poly.polygon[0].y
	var min_x: float = poly.polygon[0].x
	var max_x: float = poly.polygon[0].x
	for point in poly.polygon:
		if point.y > bottom_y:
			bottom_y = point.y
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	var band_height: float = maxf(6.0, elevation_height * 0.25)
	var band := Polygon2D.new()
	band.name = "Underhang"
	band.color = Color(0.0, 0.0, 0.0, underhang_alpha)
	band.polygon = PackedVector2Array([
		Vector2(min_x, bottom_y - band_height),
		Vector2(max_x, bottom_y - band_height),
		Vector2(max_x, bottom_y),
		Vector2(min_x, bottom_y)
	])
	zone_visual.add_child(band)

func _apply_right_face() -> void:
	var zone_visual := get_node_or_null("ZoneVisual")
	if not (zone_visual and zone_visual is Polygon2D):
		return
	var poly := zone_visual as Polygon2D
	if poly.polygon.size() < 2:
		return
	var top_y: float = poly.polygon[0].y
	var bottom_y: float = poly.polygon[0].y
	var max_x: float = poly.polygon[0].x
	for point in poly.polygon:
		if point.y < top_y:
			top_y = point.y
		if point.y > bottom_y:
			bottom_y = point.y
		if point.x > max_x:
			max_x = point.x
	var offset := Vector2(elevation_height * right_face_offset_scale.x, elevation_height * right_face_offset_scale.y)
	var face := Polygon2D.new()
	face.name = "RightFace"
	face.color = right_face_tint
	face.polygon = PackedVector2Array([
		Vector2(max_x, top_y),
		Vector2(max_x, bottom_y),
		Vector2(max_x + offset.x, bottom_y + offset.y),
		Vector2(max_x + offset.x, top_y + offset.y)
	])
	zone_visual.add_child(face)
