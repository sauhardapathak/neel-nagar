extends Node

signal game_saved
signal game_loaded

const SAVE_PATH: String = "user://neon_harbor_save.json"

var player_position: Vector3 = Vector3.ZERO
var player_health: int = 100
var player_cash: int = 0
var wanted_level: int = 0
var completed_missions: Array[String] = []
var current_time_of_day: float = 12.0
var npc_positions: Array[Vector3] = []


func save_game() -> void:
	var save_data: Dictionary = get_save_data()
	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: Could not open file for writing. Error: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(json_string)
	file.close()
	game_saved.emit()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("SaveGame: No save file found at %s." % SAVE_PATH)
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveGame: Could not open file for reading. Error: %s" % error_string(FileAccess.get_open_error()))
		return
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("SaveGame: Failed to parse save file. Error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	var save_data: Variant = json.data
	if not save_data is Dictionary:
		push_error("SaveGame: Save data is not a valid Dictionary.")
		return
	var data: Dictionary = save_data as Dictionary
	player_position = _vector3_from_dict(data.get("player_position", {}))
	player_health = int(data.get("player_health", 100))
	player_cash = int(data.get("player_cash", 0))
	wanted_level = int(data.get("wanted_level", 0))
	completed_missions = _string_array_from_variant(data.get("completed_missions", []))
	current_time_of_day = float(data.get("current_time_of_day", 12.0))
	npc_positions = _vector3_array_from_variant(data.get("npc_positions", []))
	game_loaded.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func get_save_data() -> Dictionary:
	return {
		"player_position": _vector3_to_dict(player_position),
		"player_health": player_health,
		"player_cash": player_cash,
		"wanted_level": wanted_level,
		"completed_missions": completed_missions.duplicate(),
		"current_time_of_day": current_time_of_day,
		"npc_positions": _npc_positions_to_array()
	}


func on_mission_completed(mission_id: String) -> void:
	if mission_id not in completed_missions:
		completed_missions.append(mission_id)
	save_game()


func _vector3_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func _vector3_from_dict(d: Dictionary) -> Vector3:
	return Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 0.0)),
		float(d.get("z", 0.0))
	)


func _vector3_array_from_variant(arr: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if arr is Array:
		for item in arr:
			if item is Dictionary:
				result.append(_vector3_from_dict(item))
	return result


func _npc_positions_to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pos in npc_positions:
		result.append(_vector3_to_dict(pos))
	return result


func _string_array_from_variant(arr: Variant) -> Array[String]:
	var result: Array[String] = []
	if arr is Array:
		for item in arr:
			if item is String:
				result.append(item)
	return result
