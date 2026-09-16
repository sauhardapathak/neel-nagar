extends CharacterBody3D

const SPEED := 8.0
const RUN_SPEED := 14.0
const JUMP_VELOCITY := 8.0
const MOUSE_SENSITIVITY := 0.002

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var camera_pivot: Node3D
var camera: Camera3D
var model: Node3D

func _ready() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 2, 0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 3, -8)
	camera.rotation.x = -0.15
	camera_pivot.add_child(camera)

	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	body_mesh.mesh = capsule
	body_mesh.position.y = 1.0
	body_mesh.name = "BodyMesh"
	model.add_child(body_mesh)

	var head_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	head_mesh.mesh = sphere
	head_mesh.position.y = 2.1
	head_mesh.name = "HeadMesh"
	model.add_child(head_mesh)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 1.0
	add_child(col)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_physics_process(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_pivot.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.0, 1.0)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := RUN_SPEED if Input.is_action_pressed("run") else SPEED
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 5)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 5)

	move_and_slide()

	if velocity.length() > 0.5 and model:
		var look_target := position + Vector3(velocity.x, 0, velocity.z)
		if position.distance_to(look_target) > 0.01:
			model.look_at(look_target, Vector3.UP)
