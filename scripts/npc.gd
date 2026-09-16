extends CharacterBody3D

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const JUMP_VELOCITY := 5.0
const GRAVITY := 9.8

var target_position: Vector3 = Vector3.ZERO
var is_walking := false
var wander_timer := 0.0
var walk_direction := Vector3.ZERO

func _ready() -> void:
	target_position = _random_wander_point()
	wander_timer = randf_range(3.0, 8.0)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	wander_timer -= delta
	if wander_timer <= 0.0:
		target_position = _random_wander_point()
		wander_timer = randf_range(3.0, 8.0)

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

func _random_wander_point() -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(5, 25)
	return global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
