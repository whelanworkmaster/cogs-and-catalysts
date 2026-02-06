extends Node

signal squad_changed(vessels: Array)
signal active_vessel_changed(vessel: Node)

var _vessels: Array[Node] = []
var _active_vessel: Node = null

func register_vessel(vessel: Node) -> void:
	if vessel == null:
		return
	if _vessels.has(vessel):
		return
	_vessels.append(vessel)
	if _active_vessel == null:
		_active_vessel = vessel
		active_vessel_changed.emit(_active_vessel)
	squad_changed.emit(get_vessels())

func unregister_vessel(vessel: Node) -> void:
	if vessel == null:
		return
	var index := _vessels.find(vessel)
	if index == -1:
		return
	_vessels.remove_at(index)
	if _active_vessel == vessel:
		_active_vessel = get_primary_vessel()
		active_vessel_changed.emit(_active_vessel)
	squad_changed.emit(get_vessels())

func set_active_vessel(vessel: Node) -> void:
	if vessel == null:
		return
	if not _vessels.has(vessel):
		return
	if _active_vessel == vessel:
		return
	_active_vessel = vessel
	active_vessel_changed.emit(_active_vessel)

func get_active_vessel() -> Node:
	if _is_vessel_playable(_active_vessel):
		return _active_vessel
	_active_vessel = get_primary_vessel()
	return _active_vessel

func get_primary_vessel() -> Node:
	for vessel in _vessels:
		if _is_vessel_playable(vessel):
			return vessel
	return null

func get_vessels() -> Array:
	var result: Array = []
	for vessel in _vessels:
		if vessel != null and is_instance_valid(vessel):
			result.append(vessel)
	return result

func get_living_vessels() -> Array:
	var result: Array = []
	for vessel in _vessels:
		if _is_vessel_playable(vessel):
			result.append(vessel)
	return result

func get_next_living_vessel(current: Node) -> Node:
	var living := get_living_vessels()
	if living.is_empty():
		return null
	if current == null:
		return living[0]
	var index := living.find(current)
	if index == -1:
		return living[0]
	return living[(index + 1) % living.size()]

func clear() -> void:
	_vessels.clear()
	_active_vessel = null
	squad_changed.emit([])
	active_vessel_changed.emit(null)

func _is_vessel_playable(vessel: Node) -> bool:
	if vessel == null or not is_instance_valid(vessel):
		return false
	if vessel.is_queued_for_deletion():
		return false
	if vessel.has_method("get_current_hp") and vessel.get_current_hp() <= 0:
		return false
	return true
