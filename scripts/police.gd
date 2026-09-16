extends Node
class_name PoliceSystem

signal wanted_level_changed(level: int)
signal police_spawned()
signal police_removed()

const POLICE_VEHICLE_SCENE: PackedScene = preload("res://addons/M.A.V.S/Vehicle/AI_Vehicles/AI_TRG.tscn")
var SIREN_SOUND: AudioStream = null

const HEAT_DECAY_RATE: float = 2.0
const HEAT_HIT_NPC: float = 15.0
const HEAT_STEAL_VEHICLE: float = 25.0
const HEAT_HIT_POLICE: float = 40.0

const LEVEL_THRESHOLDS: Array[float] = [0.0, 20.0, 45.0, 70.0, 90.0]
const MAX_WANTED_LEVEL: int = 4

const POLICE_MAX_SPEED: Array[float] = [0.0, 18.0, 28.0, 32.0, 40.0]
const POLICE_ACCELERATION: Array[float] = [0.0, 6.0, 10.0, 12.0, 16.0]

const SPAWN_DISTANCE_MIN: float = 80.0
const SPAWN_DISTANCE_MAX: float = 150.0
const DESPAWN_DISTANCE: float = 250.0
const PURSUIT_DISTANCE: float = 200.0

const LIGHT_FLASH_INTERVAL: float = 0.15

var heat_value: float = 0.0
var current_wanted_level: int = 0
var is_crimetime_active: bool = false

var police_vehicles: Array[Node3D] = []
var _player: Node3D = null
var _light_timers: Array[float] = []
var _light_states: Array[bool] = []
var _siren_players: Array[AudioStreamPlayer3D] = []
var _target_levels: Array[Vector3] = []
var _circle_timers: Array[float] = []
var _circle_sides: Array[int] = []
var _brake_check_timers: Array[float] = []
var _is_brake_checking: Array[bool] = []

var _crime_cooldown: float = 0.0
const CRIME_COOLDOWN_TIME: float = 0.3

func _ready() -> void:
	if ResourceLoader.exists("res://sounds/siren.wav"):
		SIREN_SOUND = load("res://sounds/siren.wav")
	set_process(true)

func _process(delta: float) -> void:
	if _crime_cooldown > 0.0:
		_crime_cooldown -= delta

	decay_heat(delta)
	update_wanted_level()
	update_police_spawning()
	update_police_pursuit(delta)
	update_police_lights(delta)

func add_heat(amount: float) -> void:
	if _crime_cooldown > 0.0:
		return
	heat_value = clampf(heat_value + amount, 0.0, 100.0)
	_crime_cooldown = CRIME_COOLDOWN_TIME

func register_npc_hit() -> void:
	add_heat(HEAT_HIT_NPC)

func register_vehicle_theft() -> void:
	add_heat(HEAT_STEAL_VEHICLE)

func register_police_hit() -> void:
	add_heat(HEAT_HIT_POLICE)

func get_wanted_level() -> int:
	return current_wanted_level

func get_heat() -> float:
	return heat_value

func is_pursuing() -> bool:
	return current_wanted_level > 0

func clear_wanted() -> void:
	heat_value = 0.0
	current_wanted_level = 0
	remove_all_police()
	wanted_level_changed.emit(0)

func set_player(player: Node3D) -> void:
	_player = player

func decay_heat(delta: float) -> void:
	if heat_value > 0.0 and _crime_cooldown <= 0.0:
		heat_value = clampf(heat_value - HEAT_DECAY_RATE * delta, 0.0, 100.0)

func update_wanted_level() -> void:
	var new_level: int = 0
	for i in range(LEVEL_THRESHOLDS.size() - 1, -1, -1):
		if heat_value >= LEVEL_THRESHOLDS[i]:
			new_level = i
			break

	if new_level != current_wanted_level:
		var old_level: int = current_wanted_level
		current_wanted_level = new_level
		wanted_level_changed.emit(current_wanted_level)

		if current_wanted_level == 0:
			remove_all_police()

func update_police_spawning() -> void:
	if not is_instance_valid(_player):
		return

	var required_count: int = 0
	match current_wanted_level:
		0:
			required_count = 0
		1:
			required_count = 1
		2:
			required_count = 2
		3:
			required_count = 3
		4:
			required_count = 4

	var player_pos: Vector3 = _player.global_position

	for i in range(police_vehicles.size() - 1, -1, -1):
		if not is_instance_valid(police_vehicles[i]):
			police_vehicles.remove_at(i)
			_light_timers.remove_at(i)
			_light_states.remove_at(i)
			_siren_players.remove_at(i)
			_target_levels.remove_at(i)
			_circle_timers.remove_at(i)
			_circle_sides.remove_at(i)
			_brake_check_timers.remove_at(i)
			_is_brake_checking.remove_at(i)
			police_removed.emit()
			continue

		var dist: float = police_vehicles[i].global_position.distance_to(player_pos)
		if dist > DESPAWN_DISTANCE and current_wanted_level > 0:
			remove_police_at(i)
		elif dist > DESPAWN_DISTANCE and current_wanted_level == 0:
			remove_police_at(i)

	while police_vehicles.size() < required_count:
		spawn_police_vehicle()
		police_spawned.emit()

	while police_vehicles.size() > required_count:
		remove_police_at(police_vehicles.size() - 1)

func spawn_police_vehicle() -> void:
	if not is_instance_valid(_player):
		return

	var spawn_pos: Vector3 = get_spawn_position()
	var vehicle: Node3D = POLICE_VEHICLE_SCENE.instantiate() as Node3D
	if not vehicle:
		return

	get_tree().current_scene.add_child(vehicle)
	vehicle.global_position = spawn_pos
	vehicle.global_rotation = _player.global_rotation

	setup_police_vehicle_lights(vehicle)
	setup_police_vehicle_siren(vehicle)

	police_vehicles.append(vehicle)
	_light_timers.append(0.0)
	_light_states.append(false)
	_circle_timers.append(0.0)
	_circle_sides.append(1)
	_brake_check_timers.append(randf_range(3.0, 8.0))
	_is_brake_checking.append(false)

func setup_police_vehicle_lights(vehicle: Node3D) -> void:
	var light_bar: OmniLight3D = OmniLight3D.new()
	light_bar.name = "LightBar"
	light_bar.light_color = Color.RED
	light_bar.light_energy = 3.0
	light_bar.omni_range = 20.0
	light_bar.omni_attenuation = 0.5
	light_bar.visible = false
	vehicle.add_child(light_bar)

	var light_bar_2: OmniLight3D = OmniLight3D.new()
	light_bar_2.name = "LightBarBlue"
	light_bar_2.light_color = Color.BLUE
	light_bar_2.light_energy = 3.0
	light_bar_2.omni_range = 20.0
	light_bar_2.omni_attenuation = 0.5
	light_bar_2.visible = false
	light_bar_2.position = Vector3(0.5, 0, 0)
	vehicle.add_child(light_bar_2)

func setup_police_vehicle_siren(vehicle: Node3D) -> void:
	var siren: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	siren.name = "Siren"
	siren.max_distance = 80.0
	siren.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if SIREN_SOUND:
		siren.stream = SIREN_SOUND
	vehicle.add_child(siren)
	_siren_players.append(siren)

func remove_police_at(index: int) -> void:
	if index < 0 or index >= police_vehicles.size():
		return

	if is_instance_valid(police_vehicles[index]):
		police_vehicles[index].queue_free()

	police_vehicles.remove_at(index)
	_light_timers.remove_at(index)
	_light_states.remove_at(index)
	_siren_players.remove_at(index)
	_target_levels.remove_at(index)
	_circle_timers.remove_at(index)
	_circle_sides.remove_at(index)
	_brake_check_timers.remove_at(index)
	_is_brake_checking.remove_at(index)
	police_removed.emit()

func remove_all_police() -> void:
	while police_vehicles.size() > 0:
		remove_police_at(police_vehicles.size() - 1)

func get_spawn_position() -> Vector3:
	if not is_instance_valid(_player):
		return Vector3.ZERO

	var player_pos: Vector3 = _player.global_position
	var angle: float = randf() * TAU
	var dist: float = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	var offset: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	var spawn_pos: Vector3 = player_pos + offset

	spawn_pos.y = get_ground_height(spawn_pos)
	return spawn_pos

func get_ground_height(pos: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = get_viewport().find_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pos + Vector3(0, 50, 0),
		pos + Vector3(0, -50, 0)
	)
	query.collision_mask = 1
	var result: Dictionary = space.intersect_ray(query)
	if result.size() > 0:
		return result["position"].y
	return pos.y

func update_police_pursuit(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var player_pos: Vector3 = _player.global_position
	var player_vel: Vector3 = Vector3.ZERO
	if _player is VehicleBody3D:
		player_vel = _player.linear_velocity
	elif "velocity" in _player:
		player_vel = _player.velocity

	for i in range(police_vehicles.size()):
		if not is_instance_valid(police_vehicles[i]):
			continue

		var vehicle: Node3D = police_vehicles[i]
		var dist: float = vehicle.global_position.distance_to(player_pos)

		if dist > PURSUIT_DISTANCE:
			perform_chase(vehicle, player_pos, player_vel, delta, i)
		else:
			decide_close_behavior(vehicle, player_pos, delta, i)

		manage_siren(i, dist)

func perform_chase(vehicle: Node3D, target_pos: Vector3, target_vel: Vector3, delta: float, index: int) -> void:
	var to_player: Vector3 = target_pos - vehicle.global_position
	var flat_to_player: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	var direction: Vector3 = flat_to_player.normalized()

	var speed_idx: int = mini(current_wanted_level, MAX_WANTED_LEVEL)
	var max_speed: float = POLICE_MAX_SPEED[speed_idx]
	var accel: float = POLICE_ACCELERATION[speed_idx]

	if vehicle is VehicleBody3D:
		var steer_target: float = atan2(direction.x, direction.z) - vehicle.rotation.y
		steer_target = wrapf(steer_target, -PI, PI)
		vehicle.steering = clampf(steer_target * 2.0, -0.8, 0.8)

		var current_speed: float = vehicle.linear_velocity.length()
		if current_speed < max_speed:
			vehicle.engine_force = accel * vehicle.mass
		else:
			vehicle.engine_force = 0.0

		vehicle.brake = 0.0
	elif vehicle.has_method("set_velocity"):
		vehicle.set_velocity(direction * max_speed)
	elif "velocity" in vehicle:
		vehicle.velocity = direction * max_speed

	var look_target: Vector3 = target_pos
	look_target.y = vehicle.global_position.y
	vehicle.look_at(look_target, Vector3.UP)

func decide_close_behavior(vehicle: Node3D, target_pos: Vector3, delta: float, index: int) -> void:
	_brake_check_timers[index] -= delta

	if _is_brake_checking[index]:
		perform_brake_check(vehicle, target_pos, delta, index)
		return

	if _brake_check_timers[index] <= 0.0:
		_is_brake_checking[index] = true
		_brake_check_timers[index] = randf_range(1.5, 3.0)
		return

	var dist_to_player: float = vehicle.global_position.distance_to(target_pos)

	if dist_to_player > 15.0:
		perform_circle_behavior(vehicle, target_pos, delta, index)
	else:
		perform_brake_check(vehicle, target_pos, delta, index)

func perform_circle_behavior(vehicle: Node3D, target_pos: Vector3, delta: float, index: int) -> void:
	_circle_timers[index] += delta

	var circle_radius: float = 20.0
	var circle_speed: float = 1.2
	var angle: float = _circle_timers[index] * circle_speed * _circle_sides[index]

	if _circle_timers[index] > TAU:
		_circle_timers[index] = 0.0
		_circle_sides[index] *= -1

	var offset: Vector3 = Vector3(
		cos(angle) * circle_radius,
		0.0,
		sin(angle) * circle_radius
	)
	var circle_target: Vector3 = target_pos + offset

	var to_circle: Vector3 = circle_target - vehicle.global_position
	var flat_to_circle: Vector3 = Vector3(to_circle.x, 0.0, to_circle.z)
	var direction: Vector3 = flat_to_circle.normalized()

	var speed_idx: int = mini(current_wanted_level, MAX_WANTED_LEVEL)
	var max_speed: float = POLICE_MAX_SPEED[speed_idx] * 0.7
	var accel: float = POLICE_ACCELERATION[speed_idx]

	if vehicle is VehicleBody3D:
		var steer_target: float = atan2(direction.x, direction.z) - vehicle.rotation.y
		steer_target = wrapf(steer_target, -PI, PI)
		vehicle.steering = clampf(steer_target * 2.0, -0.8, 0.8)

		var current_speed: float = vehicle.linear_velocity.length()
		if current_speed < max_speed:
			vehicle.engine_force = accel * vehicle.mass
		else:
			vehicle.engine_force = 0.0

		vehicle.brake = 0.0

		var look_target: Vector3 = target_pos
		look_target.y = vehicle.global_position.y
		vehicle.look_at(look_target, Vector3.UP)

func perform_brake_check(vehicle: Node3D, target_pos: Vector3, delta: float, index: int) -> void:
	if not _is_brake_checking[index]:
		return

	var to_player: Vector3 = target_pos - vehicle.global_position
	var flat_to_player: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	var dist: float = flat_to_player.length()
	var direction: Vector3 = flat_to_player.normalized()

	var speed_idx: int = mini(current_wanted_level, MAX_WANTED_LEVEL)

	if vehicle is VehicleBody3D:
		if dist > 8.0:
			var max_speed: float = POLICE_MAX_SPEED[speed_idx]
			var accel: float = POLICE_ACCELERATION[speed_idx]
			var current_speed: float = vehicle.linear_velocity.length()
			if current_speed < max_speed:
				vehicle.engine_force = accel * vehicle.mass
			else:
				vehicle.engine_force = 0.0
			vehicle.steering = 0.0
		else:
			vehicle.engine_force = 0.0
			vehicle.brake = vehicle.mass * 15.0

		var look_target: Vector3 = target_pos
		look_target.y = vehicle.global_position.y
		vehicle.look_at(look_target, Vector3.UP)

	_brake_check_timers[index] -= delta
	if _brake_check_timers[index] <= 0.0:
		_is_brake_checking[index] = false
		_brake_check_timers[index] = randf_range(4.0, 10.0)
		_circle_timers[index] = 0.0

func manage_siren(index: int, distance: float) -> void:
	if index < _siren_players.size() and is_instance_valid(_siren_players[index]):
		if current_wanted_level >= 1 and distance < 100.0:
			if not _siren_players[index].playing:
				_siren_players[index].play()
		else:
			if _siren_players[index].playing:
				_siren_players[index].stop()

func update_police_lights(delta: float) -> void:
	for i in range(police_vehicles.size()):
		if not is_instance_valid(police_vehicles[i]):
			continue

		_light_timers[i] += delta
		if _light_timers[i] >= LIGHT_FLASH_INTERVAL:
			_light_timers[i] = 0.0
			_light_states[i] = not _light_states[i]

		var vehicle: Node3D = police_vehicles[i]
		var red_light: Node = vehicle.get_node_or_null("LightBar")
		var blue_light: Node = vehicle.get_node_or_null("LightBarBlue")

		if red_light and red_light is OmniLight3D:
			red_light.visible = _light_states[i] if current_wanted_level >= 1 else false
		if blue_light and blue_light is OmniLight3D:
			blue_light.visible = not _light_states[i] if current_wanted_level >= 1 else false

		if current_wanted_level >= 2:
			if red_light and red_light is OmniLight3D:
				red_light.light_energy = 5.0
				red_light.omni_range = 30.0
			if blue_light and blue_light is OmniLight3D:
				blue_light.light_energy = 5.0
				blue_light.omni_range = 30.0

func get_police_count() -> int:
	return police_vehicles.size()

func get_nearest_police_distance() -> float:
	if not is_instance_valid(_player) or police_vehicles.size() == 0:
		return INF

	var min_dist: float = INF
	var player_pos: Vector3 = _player.global_position
	for vehicle in police_vehicles:
		if is_instance_valid(vehicle):
			var dist: float = vehicle.global_position.distance_to(player_pos)
			if dist < min_dist:
				min_dist = dist
	return min_dist

func _on_player_collision(body: Node) -> void:
	if body.is_in_group("police"):
		register_police_hit()
	elif body.is_in_group("npc"):
		register_npc_hit()

func get_stats() -> Dictionary:
	return {
		"heat": heat_value,
		"wanted_level": current_wanted_level,
		"police_count": police_vehicles.size(),
		"is_pursuing": is_pursuing()
	}
