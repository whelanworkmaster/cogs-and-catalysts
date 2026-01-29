extends Node2D

class_name CombatOverlay

@export var stance_radius: float = 22.0
@export var stance_width: float = 3.0
@export var disengage_radius: float = 28.0
@export var disengage_width: float = 2.0
@export var ap_pip_radius: float = 14.0
@export var ap_pip_size: float = 2.5
@export var clock_radius: float = 10.0
@export var clock_width: float = 2.0
@export var clock_offset: Vector2 = Vector2(0, -28)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var player := get_parent()
	if player == null:
		return
	_draw_stance_ring(player)
	_draw_disengage_ring(player)
	_draw_ap_pips(player)
	_draw_clocks()

func _draw_stance_ring(player: Node) -> void:
	if not player.has_method("get_stance_name"):
		return
	var stance_name: String = str(player.get_stance_name())
	var color: Color = Color(0.6, 0.6, 0.6, 0.7)
	match stance_name:
		"Guard":
			color = Color(0.2, 0.6, 1.0, 0.8)
		"Aggress":
			color = Color(1.0, 0.3, 0.3, 0.8)
		"Evade":
			color = Color(0.3, 1.0, 0.5, 0.8)
	draw_arc(Vector2.ZERO, stance_radius, 0.0, TAU, 32, color, stance_width)

func _draw_disengage_ring(player: Node) -> void:
	if not player.has_method("is_disengage_active"):
		return
	var active: bool = bool(player.is_disengage_active())
	if not active:
		return
	var color := Color(1.0, 1.0, 0.4, 0.8)
	var segments := 12
	var gap := TAU / float(segments)
	for i in range(segments):
		if i % 2 == 0:
			var start_angle := i * gap
			var end_angle := start_angle + gap * 0.6
			draw_arc(Vector2.ZERO, disengage_radius, start_angle, end_angle, 6, color, disengage_width)

func _draw_ap_pips(player: Node) -> void:
	if not player.has_method("get_current_ap") or not player.has_method("get_max_ap"):
		return
	var current_ap: int = int(player.get_current_ap())
	var max_ap: int = max(int(player.get_max_ap()), 1)
	for i in range(max_ap):
		var angle := -PI / 2 + TAU * (float(i) / float(max_ap))
		var pos := Vector2(cos(angle), sin(angle)) * ap_pip_radius
		var on := i < current_ap
		var color := Color(1.0, 1.0, 1.0, 0.9) if on else Color(0.3, 0.3, 0.3, 0.7)
		draw_circle(pos, ap_pip_size, color)

func _draw_clocks() -> void:
	if not CombatManager:
		return
	var offset: Vector2 = clock_offset
	if CombatManager.detection_clock:
		_draw_clock_ring(offset + Vector2(-12, 0), CombatManager.detection_clock.progress, CombatManager.detection_clock.segments, Color(1.0, 0.7, 0.2, 0.9))
	if CombatManager.toxicity_clock:
		_draw_clock_ring(offset + Vector2(12, 0), CombatManager.toxicity_clock.progress, CombatManager.toxicity_clock.segments, Color(0.6, 1.0, 0.4, 0.9))

func _draw_clock_ring(center: Vector2, progress: int, segments: int, color: Color) -> void:
	var safe_segments: int = int(max(segments, 1))
	draw_arc(center, clock_radius, 0.0, TAU, 32, Color(0.2, 0.2, 0.2, 0.7), clock_width)
	var ratio: float = clamp(float(progress) / float(safe_segments), 0.0, 1.0)
	draw_arc(center, clock_radius, -PI / 2, -PI / 2 + TAU * ratio, 32, color, clock_width)
