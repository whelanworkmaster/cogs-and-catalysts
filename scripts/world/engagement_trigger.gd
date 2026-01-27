extends Area2D

@export var one_shot: bool = true
@export var auto_start_combat: bool = true
@export var actor_paths: Array[NodePath] = []

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body is Player:
		_triggered = true
		if auto_start_combat:
			var actors: Array = [body]
			for path in actor_paths:
				var actor := get_node_or_null(path)
				if actor and actor != body:
					actors.append(actor)
			CombatManager.start_combat(actors)
		if one_shot:
			monitoring = false
			monitorable = false
