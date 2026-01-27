extends AIState

func on_turn_started(owner: Node) -> void:
	if owner.has_method("get_ai"):
		var ai = owner.get_ai()
		if ai and ai.has_method("has_player") and ai.has_player():
			ai.set_state("seek")
