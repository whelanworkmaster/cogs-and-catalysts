extends RefCounted

class_name AIState

func enter(_owner: Node) -> void:
	pass

func exit(_owner: Node) -> void:
	pass

func on_turn_started(_owner: Node) -> void:
	pass

func tick(_owner: Node, _delta: float) -> void:
	pass
