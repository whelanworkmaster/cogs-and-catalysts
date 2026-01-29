extends Area2D

class_name SteamVent

@export var damage_amount: int = 0
@export var toxicity_ticks: int = 1
@export var affect_player: bool = true
@export var affect_enemies: bool = false
@export var cooldown_seconds: float = 0.8

var _last_trigger_time: Dictionary = {}

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

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
