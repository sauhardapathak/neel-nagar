extends CharacterBody3D

@onready var interaction_area: Area3D = $InteractionArea
var nearby_vehicle: VehicleBody3D = null

func _ready() -> void:
	if not has_node("InteractionArea"):
		var area := Area3D.new()
		area.name = "InteractionArea"
		area.collision_layer = 0
		area.collision_mask = 4
		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 4.0
		col.shape = shape
		area.add_child(col)
		add_child(area)
		interaction_area = area
	else:
		interaction_area = $InteractionArea

	interaction_area.body_entered.connect(_on_vehicle_entered)
	interaction_area.body_exited.connect(_on_vehicle_exited)

func _on_vehicle_entered(body: Node3D) -> void:
	if body is VehicleBody3D and body.has_method("is_madvanced"):
		nearby_vehicle = body

func _on_vehicle_exited(body: Node3D) -> void:
	if body == nearby_vehicle:
		nearby_vehicle = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var game := get_tree().current_scene
		if game.player_in_vehicle:
			game.exit_vehicle()
		elif nearby_vehicle:
			game.enter_vehicle(nearby_vehicle)
