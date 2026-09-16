extends Node
class_name MissionSystem

signal mission_started(mission_name: String)
signal mission_objective_complete(objective_index: int)
signal mission_completed(mission_name: String)
signal mission_failed(mission_name: String)

var missions: Dictionary = {}
var current_mission: Dictionary = {}
var objective_index: int = 0
var mission_active: bool = false
var objective_markers: Array[MeshInstance3D] = []
var _timer: float = 0.0

const MARKER_HEIGHT: float = 10.0
const MARKER_RADIUS: float = 1.2
const MARKER_COLOR: Color = Color(1.0, 1.0, 0.0)

func _ready() -> void:
	_init_missions()


func _process(delta: float) -> void:
	if not mission_active:
		return
	if current_mission.get("type", "") == "collect":
		_timer -= delta
		if _timer <= 0.0:
			fail_current_mission()


func _init_missions() -> void:
	missions["Cold Run"] = {
		"name": "Cold Run",
		"description": "Deliver the package to the contact. Drive to the pickup, then reach the destination.",
		"type": "delivery",
		"start_position": Vector3(0, 0, 0),
		"objective_positions": [
			Vector3(50, 0, 30),
			Vector3(-40, 0, -60)
		],
		"reward_cash": 1500,
		"reward_health": 0
	}

	missions["Heat Sink"] = {
		"name": "Heat Sink",
		"description": "Collect 3 packages scattered around the city within 60 seconds.",
		"type": "collect",
		"start_position": Vector3(20, 0, 20),
		"objective_positions": [
			Vector3(80, 0, 10),
			Vector3(30, 0, -50),
			Vector3(-20, 0, 60)
		],
		"reward_cash": 2000,
		"reward_health": 25
	}

	missions["Ironworks Score"] = {
		"name": "Ironworks Score",
		"description": "Go to the ironworks and survive 3 waves of enemies, then escape.",
		"type": "survive",
		"start_position": Vector3(-60, 0, 40),
		"objective_positions": [
			Vector3(-80, 0, 80),
			Vector3(-80, 0, 80),
			Vector3(-80, 0, 80),
			Vector3(0, 0, 0)
		],
		"reward_cash": 5000,
		"reward_health": 50
	}


func get_available_missions() -> Array[String]:
	var available: Array[String] = []
	for key: String in missions:
		if not mission_active:
			available.append(key)
	return available


func start_mission(name: String) -> bool:
	if mission_active:
		return false
	if not missions.has(name):
		return false

	current_mission = missions[name].duplicate(true)
	objective_index = 0
	mission_active = true

	match current_mission["type"]:
		"collect":
			_timer = 60.0
		_:
			_timer = 0.0

	_spawn_marker(current_mission["start_position"])
	mission_started.emit(current_mission["name"])
	return true


func complete_current_objective() -> void:
	if not mission_active:
		return

	_clean_current_marker()
	objective_index += 1

	var positions: Array = current_mission["objective_positions"]
	if objective_index >= positions.size():
		_complete_mission()
	else:
		_spawn_marker(positions[objective_index])
		mission_objective_complete.emit(objective_index)


func fail_current_mission() -> void:
	if not mission_active:
		return
	var failed_name: String = current_mission["name"]
	_clean_all_markers()
	mission_active = false
	current_mission = {}
	objective_index = 0
	mission_failed.emit(failed_name)


func get_current_mission_info() -> Dictionary:
	if not mission_active:
		return {}
	return {
		"name": current_mission["name"],
		"description": current_mission["description"],
		"type": current_mission["type"],
		"objective_index": objective_index,
		"total_objectives": current_mission["objective_positions"].size(),
		"reward_cash": current_mission["reward_cash"],
		"reward_health": current_mission["reward_health"],
		"time_remaining": _timer if current_mission["type"] == "collect" else -1.0
	}


func _complete_mission() -> void:
	var completed_name: String = current_mission["name"]
	_clean_all_markers()
	mission_active = false
	current_mission = {}
	objective_index = 0
	mission_completed.emit(completed_name)


func _spawn_marker(pos: Vector3) -> void:
	var marker: MeshInstance3D = MeshInstance3D.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = MARKER_RADIUS
	cylinder.bottom_radius = MARKER_RADIUS
	cylinder.height = MARKER_HEIGHT
	marker.mesh = cylinder

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = MARKER_COLOR
	mat.emission_enabled = true
	mat.emission = MARKER_COLOR
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(MARKER_COLOR.r, MARKER_COLOR.g, MARKER_COLOR.b, 0.4)
	marker.material_override = mat

	marker.position = pos + Vector3(0, MARKER_HEIGHT * 0.5, 0)
	add_child(marker)
	objective_markers.append(marker)


func _clean_current_marker() -> void:
	if objective_markers.size() > 0:
		var marker: MeshInstance3D = objective_markers.pop_back()
		if is_instance_valid(marker):
			marker.queue_free()


func _clean_all_markers() -> void:
	for marker: MeshInstance3D in objective_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	objective_markers.clear()
