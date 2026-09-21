extends CharacterBody3D

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const JUMP_VELOCITY := 5.0
const GRAVITY := 9.8
const WORLD_SEED := 20240
const STUCK_TIMEOUT := 1.5

var target_position: Vector3 = Vector3.ZERO
var is_walking := false
var wander_timer := 0.0
var walk_direction := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var stuck_timer := 0.0
var last_pos := Vector3.ZERO

func _ready() -> void:
	var idx := int(get_meta("spawn_index", 0))
	rng.seed = WORLD_SEED + idx * 101
	target_position = _random_wander_point()
	wander_timer = rng.randf_range(3.0, 8.0)
	last_pos = global_position

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	wander_timer -= delta
	if wander_timer <= 0.0:
		target_position = _random_wander_point()
		wander_timer = rng.randf_range(3.0, 8.0)

	var to_target := target_position - global_position
	to_target.y = 0
	if to_target.length() < 1.0:
		is_walking = false
		velocity.x = 0
		velocity.z = 0
	else:
		is_walking = true
		walk_direction = to_target.normalized()
		velocity.x = walk_direction.x * WALK_SPEED
		velocity.z = walk_direction.z * WALK_SPEED
		if walk_direction.length_squared() > 0.01:
			look_at(global_position + walk_direction, Vector3.UP)

	move_and_slide()

	# Stuck detection: barely moving while trying to walk -> repick target.
	var frame_move := global_position.distance_to(last_pos)
	last_pos = global_position
	if is_walking:
		if frame_move < 0.01:
			stuck_timer += delta
			if stuck_timer > STUCK_TIMEOUT:
				target_position = _random_wander_point()
				wander_timer = rng.randf_range(3.0, 8.0)
				stuck_timer = 0.0
		else:
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0

func _random_wander_point() -> Vector3:
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(5, 25)
	return global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
