extends Node3D

const ROAD_LENGTH := 40.0
const ROAD_WIDTH := 8.0
const GRID_SIZE := 5
const BLOCK_SIZE := ROAD_LENGTH

var world: Node3D
var player: CharacterBody3D
var vehicle_container: Node3D
var npc_container: Node3D
var hud: CanvasLayer
var nav_region: NavigationRegion3D
var missions: MissionSystem
var police: PoliceSystem
var save_system: Node

var player_in_vehicle: bool = false
var current_vehicle: VehicleBody3D = null
var original_camera: Node3D = null
var nearby_vehicle: VehicleBody3D = null

var health := 100
var cash := 0
var wanted_level := 0
var current_mission := ""
var completed_missions: Array[String] = []
var game_started := false
var paused := false
var _shot_mode := false
var _shot_frames := 0
var _move_test := false
var _move_start := Vector3.ZERO

var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var compass_label: Label
var speed_label: Label
var mission_arrow: Label

const NEPAL_BRICK := Color(0.545, 0.224, 0.165)
const NEPAL_BRICK_DARK := Color(0.478, 0.231, 0.180)
const NEPAL_WOOD := Color(0.243, 0.153, 0.137)
const NEPAL_WOOD_LIGHT := Color(0.365, 0.251, 0.216)
const NEPAL_GOLD := Color(0.855, 0.647, 0.125)
const NEPAL_WHITE := Color(0.961, 0.937, 0.882)
const NEPAL_TERRACOTTA := Color(0.753, 0.251, 0.188)
const NEPAL_STONE := Color(0.478, 0.478, 0.478)

func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	add_child(nav_region)

	vehicle_container = Node3D.new()
	vehicle_container.name = "Vehicles"
	add_child(vehicle_container)

	npc_container = Node3D.new()
	npc_container.name = "NPCs"
	add_child(npc_container)

	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)

	missions = MissionSystem.new()
	missions.name = "MissionSystem"
	add_child(missions)

	police = PoliceSystem.new()
	police.name = "PoliceSystem"
	add_child(police)

	save_system = Node.new()
	save_system.name = "SaveGame"
	save_system.set_script(load("res://scripts/save_game.gd"))
	add_child(save_system)

	_shot_mode = OS.get_cmdline_args().has("--shot") or OS.get_cmdline_user_args().has("--shot")
	if _shot_mode:
		game_started = true
		print("SHOT MODE ACTIVE - will save screenshot after 90 frames")
	_move_test = OS.get_cmdline_args().has("--movetest") or OS.get_cmdline_user_args().has("--movetest")

	_build_environment()
	_build_nepal_city()
	_spawn_player()
	_spawn_vehicles()
	_spawn_npcs()
	_spawn_blender_props()
	_setup_hud()
	_connect_systems()
	_load_game()

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.position = Vector3(0, 60, 0)
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.72, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.65, 0.6)
	env.ambient_light_energy = 0.6
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.72, 0.68)
	env.fog_density = 0.0015

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	ground.collision_mask = 0
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GRID_SIZE * BLOCK_SIZE + ROAD_LENGTH * 4, GRID_SIZE * BLOCK_SIZE + ROAD_LENGTH * 4)
	plane.material = _make_material(Color(0.35, 0.30, 0.25))
	ground_mesh.mesh = plane
	ground.add_child(ground_mesh)
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(GRID_SIZE * BLOCK_SIZE + ROAD_LENGTH * 4, 0.1, GRID_SIZE * BLOCK_SIZE + ROAD_LENGTH * 4)
	ground_col.shape = ground_shape
	ground_col.position.y = -0.05
	ground.add_child(ground_col)
	add_child(ground)

func _build_nepal_city() -> void:
	var half := GRID_SIZE / 2
	var offset := Vector3(-half * BLOCK_SIZE, 0, -half * BLOCK_SIZE)

	for z in range(GRID_SIZE + 1):
		for x in range(GRID_SIZE + 1):
			var pos := offset + Vector3(x * BLOCK_SIZE, 0, z * BLOCK_SIZE)
			_place_chowk(pos, x, z)

	for z in range(GRID_SIZE + 1):
		for x in range(GRID_SIZE):
			var pos := offset + Vector3((x + 0.5) * BLOCK_SIZE, 0, z * BLOCK_SIZE)
			_place_bazaar_street(pos, false)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE + 1):
			var pos := offset + Vector3(x * BLOCK_SIZE, 0, (z + 0.5) * BLOCK_SIZE)
			_place_bazaar_street(pos, true)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var center := offset + Vector3((x + 0.5) * BLOCK_SIZE, 0, (z + 0.5) * BLOCK_SIZE)
			_place_courtyard_block(center, x, z)

	_place_stupa(offset + Vector3(0, 0, 0))
	_place_pagoda_temple(offset + Vector3(BLOCK_SIZE, 0, BLOCK_SIZE))
	_place_pagoda_temple(offset + Vector3(-BLOCK_SIZE, 0, -BLOCK_SIZE))
	_add_prayer_flags(offset + Vector3(0, 12, 0), offset + Vector3(BLOCK_SIZE, 10, BLOCK_SIZE))

func _place_chowk(pos: Vector3, gx: int, gz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = gx * 100 + gz

	var plaza_size := ROAD_LENGTH * 0.9
	var plaza := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(plaza_size, 0.05, plaza_size)
	box.material = _make_material(Color(0.45, 0.38, 0.32))
	plaza.mesh = box
	plaza.position = pos
	world.add_child(plaza)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(plaza_size, 0.1, plaza_size)
	col.shape = shape
	body.add_child(col)
	world.add_child(body)

	if rng.randf() > 0.6:
		_place_chaitya(pos + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)))

func _place_chaitya(pos: Vector3) -> void:
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(2, 1, 2)
	base_box.material = _make_material(NEPAL_STONE)
	base.mesh = base_box
	base.position = pos + Vector3(0, 0.5, 0)
	world.add_child(base)

	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 1.2
	dome_mesh.height = 1.5
	dome_mesh.material = _make_material(NEPAL_WHITE)
	dome.mesh = dome_mesh
	dome.position = pos + Vector3(0, 1.8, 0)
	world.add_child(dome)

	var spire := MeshInstance3D.new()
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.05
	spire_mesh.bottom_radius = 0.3
	spire_mesh.height = 2.0
	spire_mesh.material = _make_gold_material()
	spire.mesh = spire_mesh
	spire.position = pos + Vector3(0, 3.5, 0)
	world.add_child(spire)

func _place_bazaar_street(pos: Vector3, rotated: bool) -> void:
	var road := MeshInstance3D.new()
	var quad := BoxMesh.new()
	if rotated:
		quad.size = Vector3(ROAD_WIDTH, 0.02, ROAD_LENGTH)
	else:
		quad.size = Vector3(ROAD_LENGTH, 0.02, ROAD_WIDTH)
	quad.material = _make_material(Color(0.4, 0.35, 0.30))
	road.mesh = quad
	road.position = pos
	world.add_child(road)

	var lane := MeshInstance3D.new()
	var lane_mesh := BoxMesh.new()
	if rotated:
		lane_mesh.size = Vector3(0.12, 0.03, ROAD_LENGTH - 2)
	else:
		lane_mesh.size = Vector3(ROAD_LENGTH - 2, 0.03, 0.12)
	lane_mesh.material = _make_material(Color(0.85, 0.75, 0.25))
	lane.mesh = lane_mesh
	lane.position = pos + Vector3(0, 0.01, 0)
	world.add_child(lane)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	if rotated:
		shape.size = Vector3(ROAD_WIDTH, 0.1, ROAD_LENGTH)
	else:
		shape.size = Vector3(ROAD_LENGTH, 0.1, ROAD_WIDTH)
	col.shape = shape
	body.add_child(col)
	world.add_child(body)

func _place_courtyard_block(center: Vector3, bx: int, bz: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bx * 1000 + bz * 100 + 42

	var block_w := BLOCK_SIZE - ROAD_WIDTH - 4
	var courtyard_size := block_w * 0.35

	var building_count := rng.randi_range(4, 8)
	for i in range(building_count):
		var bw := rng.randf_range(5, block_w * 0.4)
		var bd := rng.randf_range(5, block_w * 0.4)
		var bh := rng.randf_range(6, 14)
		var angle := TAU * i / building_count
		var dist := rng.randf_range(courtyard_size + 2, block_w * 0.4)
		var local_x := cos(angle) * dist
		var local_z := sin(angle) * dist
		var bpos := center + Vector3(local_x, bh * 0.5, local_z)

		_place_nepal_building(bpos, bw, bh, bd, rng)

	if rng.randf() > 0.5:
		_place_small_temple(center + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), rng)

func _place_nepal_building(pos: Vector3, w: float, h: float, d: float, rng: RandomNumberGenerator) -> void:
	var building := StaticBody3D.new()
	building.collision_layer = 1
	building.position = pos

	var brick_shade := rng.randf_range(0.8, 1.1)
	var brick_color := NEPAL_BRICK * brick_shade
	brick_color.a = 1.0

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	box.material = _make_material(brick_color)
	mesh_inst.mesh = box
	building.add_child(mesh_inst)

	var floor_count := int(h / 3.0)
	for fi in range(1, floor_count):
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(w + 0.2, 0.2, d + 0.2)
		strip_mesh.material = _make_material(NEPAL_WOOD)
		strip.mesh = strip_mesh
		strip.position.y = fi * 3.0 - h * 0.5
		building.add_child(strip)

	var window_cols := maxi(1, int(w / 2.5))
	var window_rows := floor_count
	for wy in range(window_rows):
		for wx in range(window_cols):
			var win := MeshInstance3D.new()
			var win_box := BoxMesh.new()
			win_box.size = Vector3(0.8, 1.2, 0.15)
			win_box.material = _make_material(NEPAL_WOOD_LIGHT)
			win.mesh = win_box
			var win_x := (wx - (window_cols - 1) * 0.5) * 2.2
			var win_y := (wy + 0.5) * 3.0 - h * 0.5
			win.position = Vector3(win_x, win_y, d * 0.51)
			building.add_child(win)

			if rng.randf() > 0.4:
				var glow := OmniLight3D.new()
				glow.position = win.position + Vector3(0, 0, 0.3)
				glow.light_color = Color(1.0, 0.85, 0.55)
				glow.light_energy = 0.15
				glow.omni_range = 2.5
				building.add_child(glow)

	var roof_tiers := rng.randi_range(1, 3)
	for ti in range(roof_tiers):
		var tier_w := w + 1.5 - ti * 1.0
		var tier_d := d + 1.5 - ti * 1.0
		var tier_h := 1.2
		var tier_y := h * 0.5 + ti * 1.5 + 0.5

		var roof := MeshInstance3D.new()
		var roof_box := BoxMesh.new()
		roof_box.size = Vector3(tier_w, tier_h, tier_d)
		roof_box.material = _make_material(NEPAL_TERRACOTTA)
		roof.mesh = roof_box
		roof.position.y = tier_y
		building.add_child(roof)

		for si in range(4):
			var strut := MeshInstance3D.new()
			var strut_mesh := BoxMesh.new()
			strut_mesh.size = Vector3(0.15, 0.8, 0.15)
			strut_mesh.material = _make_material(NEPAL_WOOD)
			strut.mesh = strut_mesh
			var side := si % 2
			var edge := 1 if si < 2 else -1
			if side == 0:
				strut.position = Vector3(edge * tier_w * 0.5, tier_y - 0.5, 0)
			else:
				strut.position = Vector3(0, tier_y - 0.5, edge * tier_d * 0.5)
			strut.rotation_degrees.z = edge * 25 if side == 0 else 0
			strut.rotation_degrees.x = edge * 25 if side == 1 else 0
			building.add_child(strut)

	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(w, h, d)
	col_shape.shape = box_shape
	building.add_child(col_shape)
	world.add_child(building)

func _place_small_temple(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var plinth := MeshInstance3D.new()
	var plinth_box := BoxMesh.new()
	plinth_box.size = Vector3(5, 1, 5)
	plinth_box.material = _make_material(NEPAL_STONE)
	plinth.mesh = plinth_box
	plinth.position = pos + Vector3(0, 0.5, 0)
	world.add_child(plinth)

	var body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(4, 4, 4)
	body_box.material = _make_material(NEPAL_BRICK_DARK)
	body.mesh = body_box
	body.position = pos + Vector3(0, 3, 0)
	world.add_child(body)

	for ti in range(2):
		var tier := MeshInstance3D.new()
		var tier_box := BoxMesh.new()
		tier_box.size = Vector3(5.5 - ti * 1.0, 0.8, 5.5 - ti * 1.0)
		tier_box.material = _make_material(NEPAL_TERRACOTTA)
		tier.mesh = tier_box
		tier.position = pos + Vector3(0, 5.5 + ti * 1.5, 0)
		world.add_child(tier)

	var pinnacle := MeshInstance3D.new()
	var pinnacle_mesh := SphereMesh.new()
	pinnacle_mesh.radius = 0.4
	pinnacle_mesh.material = _make_gold_material()
	pinnacle.mesh = pinnacle_mesh
	pinnacle.position = pos + Vector3(0, 9, 0)
	world.add_child(pinnacle)

func _place_pagoda_temple(pos: Vector3) -> void:
	var tiers := 3
	var base_w := 10.0

	for step in range(3):
		var step_mesh := MeshInstance3D.new()
		var step_box := BoxMesh.new()
		step_box.size = Vector3(base_w + 4 - step * 1.5, 1, base_w + 4 - step * 1.5)
		step_box.material = _make_material(NEPAL_STONE)
		step_mesh.mesh = step_box
		step_mesh.position = pos + Vector3(0, step * 1.0 + 0.5, 0)
		world.add_child(step_mesh)

	var temple_body := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(base_w, 8, base_w)
	body_box.material = _make_material(NEPAL_BRICK)
	temple_body.mesh = body_box
	temple_body.position = pos + Vector3(0, 7, 0)
	world.add_child(temple_body)

	for ti in range(tiers):
		var tw := base_w + 3 - ti * 2.0
		var tier := MeshInstance3D.new()
		var tier_box := BoxMesh.new()
		tier_box.size = Vector3(tw, 1.0, tw)
		tier_box.material = _make_material(NEPAL_TERRACOTTA)
		tier.mesh = tier_box
		tier.position = pos + Vector3(0, 12 + ti * 2.5, 0)
		world.add_child(tier)

		for si in range(4):
			var strut := MeshInstance3D.new()
			var strut_mesh := BoxMesh.new()
			strut_mesh.size = Vector3(0.2, 1.5, 0.2)
			strut_mesh.material = _make_material(NEPAL_WOOD)
			strut.mesh = strut_mesh
			var side_offsets: Array[Vector3] = [Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
			var side_off: Vector3 = side_offsets[si]
			strut.position = pos + Vector3(side_off.x * tw * 0.45, 12 + ti * 2.5 - 0.8, side_off.z * tw * 0.45)
			world.add_child(strut)

	var gajur := MeshInstance3D.new()
	var gajur_mesh := CylinderMesh.new()
	gajur_mesh.top_radius = 0.05
	gajur_mesh.bottom_radius = 0.5
	gajur_mesh.height = 3.0
	gajur_mesh.material = _make_gold_material()
	gajur.mesh = gajur_mesh
	gajur.position = pos + Vector3(0, 12 + tiers * 2.5 + 1.5, 0)
	world.add_child(gajur)

func _place_stupa(pos: Vector3) -> void:
	var base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(12, 2, 12)
	base_box.material = _make_material(NEPAL_STONE)
	base.mesh = base_box
	base.position = pos + Vector3(0, 1, 0)
	world.add_child(base)

	for step in range(3):
		var step_mesh := MeshInstance3D.new()
		var step_box := BoxMesh.new()
		var sw := 10.0 - step * 1.5
		step_box.size = Vector3(sw, 0.8, sw)
		step_box.material = _make_material(NEPAL_WHITE)
		step_mesh.mesh = step_box
		step_mesh.position = pos + Vector3(0, 2.5 + step * 0.8, 0)
		world.add_child(step_mesh)

	var dome := MeshInstance3D.new()
	var dome_mesh := SphereMesh.new()
	dome_mesh.radius = 5.0
	dome_mesh.height = 7.0
	dome_mesh.material = _make_material(NEPAL_WHITE)
	dome.mesh = dome_mesh
	dome.position = pos + Vector3(0, 7, 0)
	world.add_child(dome)

	var harmika := MeshInstance3D.new()
	var harmika_box := BoxMesh.new()
	harmika_box.size = Vector3(2, 2, 2)
	harmika_box.material = _make_material(NEPAL_WHITE)
	harmika.mesh = harmika_box
	harmika.position = pos + Vector3(0, 12, 0)
	world.add_child(harmika)

	for ri in range(13):
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		var rw := 1.5 - ri * 0.08
		ring_mesh.top_radius = rw
		ring_mesh.bottom_radius = rw + 0.1
		ring_mesh.height = 0.3
		ring_mesh.material = _make_gold_material()
		ring.mesh = ring_mesh
		ring.position = pos + Vector3(0, 13.5 + ri * 0.4, 0)
		world.add_child(ring)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var col := CollisionShape3D.new()
	var col_shape := CylinderShape3D.new()
	col_shape.radius = 6.0
	col_shape.height = 20.0
	col.shape = col_shape
	body.add_child(col)
	world.add_child(body)

func _add_prayer_flags(from: Vector3, to: Vector3) -> void:
	var flag_colors := [
		Color(0.0, 0.33, 0.64),
		Color(1, 1, 1),
		Color(0.81, 0.07, 0.15),
		Color(0.0, 0.52, 0.24),
		Color(1.0, 0.87, 0.0)
	]
	var dir := to - from
	var length := dir.length()
	var count := int(length / 1.5)

	for i in range(count):
		var t := float(i) / count
		var pos := from.lerp(to, t)
		for ci in range(flag_colors.size()):
			var flag := MeshInstance3D.new()
			var flag_mesh := BoxMesh.new()
			flag_mesh.size = Vector3(0.8, 0.5, 0.02)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = flag_colors[ci]
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			flag_mesh.material = mat
			flag.mesh = flag_mesh
			flag.position = pos + Vector3(ci * 0.9 - 2, -0.3, 0)
			world.add_child(flag)

func _make_material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.85
	return mat

func _make_gold_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = NEPAL_GOLD
	mat.metallic = 0.8
	mat.roughness = 0.35
	return mat

func _spawn_player() -> void:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/simple_player.gd"))
	p.position = Vector3(0, 1, 0)
	p.collision_layer = 2
	p.collision_mask = 1
	add_child(p)
	player = p
	original_camera = p.get_node_or_null("CameraPivot/CameraArm/Camera")

	var area := Area3D.new()
	area.name = "VehicleInteractionArea"
	area.collision_layer = 0
	area.collision_mask = 4
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 5.0
	col.shape = shape
	area.add_child(col)
	p.add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void: if b is VehicleBody3D: nearby_vehicle = b as VehicleBody3D)
	area.body_exited.connect(func(b: Node3D) -> void: if b == nearby_vehicle: nearby_vehicle = null)

func _spawn_vehicles() -> void:
	var car_scene := preload("res://addons/M.A.V.S/Vehicle/TGR/TRG.tscn")
	var positions := [
		Vector3(12, 0.5, 12), Vector3(-12, 0.5, 12),
		Vector3(12, 0.5, -12), Vector3(-12, 0.5, -12),
		Vector3(30, 0.5, 30), Vector3(-30, 0.5, 30),
	]
	for pos in positions:
		var car := car_scene.instantiate()
		car.position = pos
		car.set("key_gear_1", "Gear 1")
		car.set("key_gear_2", "Gear 2")
		car.set("key_gear_3", "Gear 3")
		car.set("key_gear_4", "Gear 4")
		car.set("key_gear_5", "Gear 5")
		car.set("key_gear_reverse", "Gear Reverse")
		vehicle_container.add_child(car)

func _spawn_npcs() -> void:
	var npc_scene := preload("res://scenes/NPC.tscn")
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = 777
	for i in range(20):
		var npc := npc_scene.instantiate()
		npc.set_meta("spawn_index", i)
		var angle := spawn_rng.randf() * TAU
		var dist := spawn_rng.randf_range(10, 60)
		npc.position = Vector3(cos(angle) * dist, 1, sin(angle) * dist)
		npc_container.add_child(npc)

func _spawn_blender_props() -> void:
	var specs := [
		{"path": "res://assets/props/market_stall.glb",
		 "items": [[Vector3(0.0, 0, -22.0), 0.0], [Vector3(12.0, 0, 9.5), -0.3]],
		 "collider": Vector3(2.4, 2.2, 1.6), "collider_y": 1.1},
		{"path": "res://assets/props/roadside_shrine.glb",
		 "items": [[Vector3(-12.0, 0, -10.0), 0.5]],
		 "collider": Vector3(2.2, 2.5, 2.2), "collider_y": 1.25},
		{"path": "res://assets/props/street_lantern.glb",
		 "items": [[Vector3(3.5, 0, 14.0), 0.0], [Vector3(-3.5, 0, 14.0), 0.0],
				   [Vector3(3.5, 0, -14.0), 0.0], [Vector3(-3.5, 0, -14.0), 0.0]],
		 "collider": Vector3.ZERO, "collider_y": 0.0},
		{"path": "res://assets/props/prayer_flags.glb",
		 "items": [[Vector3(0.0, 0, 26.0), 0.0]],
		 "collider": Vector3.ZERO, "collider_y": 0.0},
	]
	for spec in specs:
		var ps: PackedScene = load(spec["path"])
		if ps == null:
			push_warning("Prop missing: " + str(spec["path"]))
			continue
		for item in spec["items"]:
			var inst := ps.instantiate()
			inst.position = item[0]
			inst.rotation.y = item[1]
			world.add_child(inst)
			var csize: Vector3 = spec["collider"]
			if csize.length() > 0.01:
				var body := StaticBody3D.new()
				body.collision_layer = 1
				body.collision_mask = 0
				body.position = item[0] + Vector3(0, spec["collider_y"], 0)
				var col := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = csize
				col.shape = shape
				body.add_child(col)
				world.add_child(body)
	print("PROPS spawned: market_stall x2, shrine x1, lanterns x4, prayer_flags x1")

func _setup_hud() -> void:
	var panel := PanelContainer.new()
	panel.name = "InfoPanel"
	panel.offset_right = 300
	panel.offset_bottom = 190
	panel.position = Vector2(10, 10)
	hud.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Info"
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "NEEL NAGAR"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	compass_label = Label.new()
	compass_label.name = "Compass"
	compass_label.text = "Heading: N"
	compass_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(compass_label)

	var health_label := Label.new()
	health_label.name = "Health"
	health_label.text = "Health: 100%%"
	vbox.add_child(health_label)

	var cash_label := Label.new()
	cash_label.name = "Cash"
	cash_label.text = "Cash: $0"
	vbox.add_child(cash_label)

	var wanted_label := Label.new()
	wanted_label.name = "Wanted"
	wanted_label.text = "Wanted: None"
	vbox.add_child(wanted_label)

	var mission_label := Label.new()
	mission_label.name = "Mission"
	mission_label.text = ""
	vbox.add_child(mission_label)

	var timer_label := Label.new()
	timer_label.name = "Timer"
	timer_label.text = ""
	vbox.add_child(timer_label)

	var controls := Label.new()
	controls.name = "Controls"
	controls.text = "WASD / Arrows: Move | Shift: Sprint | Space: Jump\nE: Enter/Exit Vehicle | F: Mission | L: Lights | C: Camera | Esc: Pause"
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -50
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(controls)

	mission_arrow = Label.new()
	mission_arrow.name = "MissionArrow"
	mission_arrow.text = "▶"
	mission_arrow.add_theme_font_size_override("font_size", 48)
	mission_arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	mission_arrow.visible = false
	mission_arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mission_arrow.offset_top = -30
	mission_arrow.offset_bottom = 30
	mission_arrow.offset_left = -20
	mission_arrow.offset_right = 20
	hud.add_child(mission_arrow)

	_setup_minimap()
	_setup_speedometer()

func _setup_minimap() -> void:
	var container := SubViewportContainer.new()
	container.name = "Minimap"
	container.custom_minimum_size = Vector2(120, 120)
	container.size = Vector2(120, 120)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	container.position = Vector2(vs.x - 140, 10)
	minimap_viewport = SubViewport.new()
	minimap_viewport.name = "MinimapViewport"
	minimap_viewport.size = Vector2i(120, 120)
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_viewport.transparent_bg = false
	minimap_viewport.own_world_3d = false
	container.add_child(minimap_viewport)
	hud.add_child(container)
	minimap_camera = Camera3D.new()
	minimap_camera.name = "MinimapCamera"
	minimap_camera.position = Vector3(0, 80, 0)
	minimap_camera.rotation_degrees.x = -90
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = 120.0
	minimap_camera.near = 0.5
	minimap_camera.far = 200.0
	minimap_viewport.add_child(minimap_camera)

func _setup_speedometer() -> void:
	speed_label = Label.new()
	speed_label.name = "Speedometer"
	speed_label.text = "0 km/h"
	speed_label.add_theme_font_size_override("font_size", 20)
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	speed_label.add_theme_constant_override("outline_size", 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	speed_label.add_theme_stylebox_override("normal", sb)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.offset_left = -140
	speed_label.offset_top = -44
	speed_label.offset_right = -14
	speed_label.offset_bottom = -12
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(speed_label)

func _connect_systems() -> void:
	missions.mission_started.connect(func(name: String) -> void:
		current_mission = name
		_update_hud()
		_show_toast("Mission: " + name)
	)
	missions.mission_completed.connect(func(name: String) -> void:
		var info := missions.get_current_mission_info()
		cash += info.get("reward_cash", 0)
		health = mini(100, health + info.get("reward_health", 0))
		completed_missions.append(name)
		current_mission = ""
		save_system.call("save_game")
		_update_hud()
		_show_toast("Mission Complete: " + name)
	)
	missions.mission_failed.connect(func(name: String) -> void:
		current_mission = ""
		_update_hud()
		_show_toast("Mission Failed: " + name)
	)
	police.wanted_level_changed.connect(func(level: int) -> void:
		wanted_level = level
		_update_hud()
	)

func _process(delta: float) -> void:
	if _move_test:
		_shot_frames += 1
		if _shot_frames == 10:
			_move_start = player.global_position
			print("MOVETEST actions present: forward=", InputMap.has_action("move_forward"), " sprint=", InputMap.has_action("run"), " jump=", InputMap.has_action("jump"), " accel=", InputMap.has_action("Acceleration"))
			Input.action_press("move_forward")
			Input.action_press("run")
		if _shot_frames == 80:
			var end_pos: Vector3 = player.global_position
			print("MOVETEST start=", _move_start, " end=", end_pos, " delta=", end_pos - _move_start, " dist=", _move_start.distance_to(end_pos))
			Input.action_release("move_forward")
			Input.action_release("run")
			get_tree().quit()
			return

	if _shot_mode:
		_shot_frames += 1
		if _shot_frames == 90:
			var img := get_viewport().get_texture().get_image()
			if img:
				var save_path := ProjectSettings.globalize_path("res://qa_shot.png")
				img.save_png(save_path)
				print("Screenshot saved to: " + save_path)
			else:
				print("WARNING: Could not get viewport image")
			get_tree().quit()
			return

	if Input.is_action_just_pressed("pause"):
		paused = !paused
		get_tree().paused = paused

	if Input.is_action_just_pressed("interact"):
		if player_in_vehicle:
			exit_vehicle()
		elif nearby_vehicle:
			enter_vehicle(nearby_vehicle)

	if Input.is_action_just_pressed("ui_accept") and not game_started:
		game_started = true
		_show_toast("Welcome to Neel Nagar")

	if Input.is_action_just_pressed("interact") and game_started:
		_try_start_mission()

	if missions.call("get_current_mission_info") != {}:
		_check_mission_proximity()

	_update_mission_arrow()
	_update_compass()
	_update_speedometer()
	_update_minimap()
	_update_hud()

func _check_mission_proximity() -> void:
	if not player:
		return
	var info: Dictionary = missions.call("get_current_mission_info")
	if info.is_empty():
		return
	var positions: Array = missions.current_mission.get("objective_positions", [])
	var idx: int = info.get("objective_index", 0)
	if idx < positions.size():
		var obj_pos: Vector3 = positions[idx]
		var check_pos := current_vehicle.global_position if player_in_vehicle and current_vehicle else player.global_position
		if check_pos.distance_to(obj_pos) < 8.0:
			missions.call("complete_current_objective")

func _try_start_mission() -> void:
	var info: Dictionary = missions.call("get_current_mission_info")
	if not info.is_empty():
		return
	var available: Array = missions.call("get_available_missions")
	if available.size() > 0:
		var pos: Vector3 = player.global_position
		for m_name in available:
			var m_info: Dictionary = missions.call("get_mission_info", m_name)
			if m_info.has("start_position"):
				if pos.distance_to(m_info["start_position"]) < 10.0:
					missions.call("start_mission", m_name)
					return
		if available.size() > 0:
			missions.call("start_mission", available[0])

func enter_vehicle(vehicle: VehicleBody3D) -> void:
	if player_in_vehicle:
		return
	player_in_vehicle = true
	current_vehicle = vehicle
	vehicle.set("is_current_veh", true)
	vehicle.set("veh_state", vehicle.get("state").DRIVE)
	player.visible = false
	player.set_physics_process(false)
	_show_toast("Entered vehicle")

func exit_vehicle() -> void:
	if not player_in_vehicle or not current_vehicle:
		return
	current_vehicle.set("is_current_veh", false)
	current_vehicle.set("veh_state", current_vehicle.get("state").MENU)
	player.position = current_vehicle.position + Vector3(3, 1, 0)
	player.visible = true
	player.set_physics_process(true)
	current_vehicle = null
	player_in_vehicle = false
	_show_toast("Exited vehicle")

func take_damage(amount: int) -> void:
	health = maxi(0, health - amount)
	police.call("add_heat", 10.0)
	_update_hud()
	if health <= 0:
		_show_toast("WASTED")
		get_tree().reload_current_scene()

func add_cash(amount: int) -> void:
	cash += amount
	_update_hud()

func _show_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.offset_top = -20
	toast.offset_bottom = 10
	toast.add_theme_font_size_override("font_size", 24)
	hud.add_child(toast)
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)

func _update_mission_arrow() -> void:
	if not mission_arrow:
		return
	var info: Dictionary = missions.call("get_current_mission_info")
	if info.is_empty():
		mission_arrow.visible = false
		return
	var positions: Array = missions.current_mission.get("objective_positions", [])
	var idx: int = info.get("objective_index", 0)
	if idx >= positions.size():
		mission_arrow.visible = false
		return
	var target_pos: Vector3 = positions[idx]
	var player_pos: Vector3 = current_vehicle.global_position if player_in_vehicle and current_vehicle else player.global_position
	var direction: Vector3 = target_pos - player_pos
	var angle: float = atan2(direction.x, direction.z)
	mission_arrow.rotation = -angle
	var dist: float = player_pos.distance_to(target_pos)
	mission_arrow.text = "▶ " + str(int(dist)) + "m"
	mission_arrow.visible = true

func _update_compass() -> void:
	if not compass_label or not player:
		return
	var forward := -player.global_transform.basis.z
	var heading := rad_to_deg(atan2(forward.x, forward.z))
	if heading < 0:
		heading += 360.0
	var dir := ""
	if heading >= 337.5 or heading < 22.5:
		dir = "N"
	elif heading >= 22.5 and heading < 67.5:
		dir = "NE"
	elif heading >= 67.5 and heading < 112.5:
		dir = "E"
	elif heading >= 112.5 and heading < 157.5:
		dir = "SE"
	elif heading >= 157.5 and heading < 202.5:
		dir = "S"
	elif heading >= 202.5 and heading < 247.5:
		dir = "SW"
	elif heading >= 247.5 and heading < 292.5:
		dir = "W"
	else:
		dir = "NW"
	compass_label.text = "Heading: " + dir

func _update_speedometer() -> void:
	if not speed_label:
		return
	var speed_kmh := 0.0
	if player_in_vehicle and current_vehicle:
		speed_kmh = current_vehicle.linear_velocity.length() * 3.6
	elif player:
		speed_kmh = player.velocity.length() * 3.6
	speed_label.text = "%d km/h" % int(speed_kmh)

func _update_minimap() -> void:
	if not minimap_camera or not player:
		return
	var pp: Vector3 = player.global_position
	if player_in_vehicle and current_vehicle:
		pp = current_vehicle.global_position
	var above := pp + Vector3(0, 80, 0)
	var fwd := -player.global_transform.basis.z
	var up := Vector3(fwd.x, 0, fwd.z)
	if up.length() < 0.01:
		up = Vector3(0, 0, -1)
	minimap_camera.look_at_from_position(above, pp, up.normalized())

func _update_hud() -> void:
	var info_panel := hud.get_node_or_null("InfoPanel/Info")
	if not info_panel:
		return
	info_panel.get_node("Health").text = "Health: %d%%" % health
	info_panel.get_node("Cash").text = "Cash: $%d" % cash
	var stars := ""
	for i in range(5):
		if i < wanted_level:
			stars += "★"
		else:
			stars += "☆"
	info_panel.get_node("Wanted").text = "Wanted: " + ("☆☆☆☆☆" if wanted_level == 0 else stars)
	info_panel.get_node("Mission").text = current_mission if current_mission != "" else ""
	var mission_info: Dictionary = missions.call("get_current_mission_info")
	var time_remaining: float = mission_info.get("time_remaining", -1.0)
	if time_remaining >= 0:
		info_panel.get_node("Timer").text = "Time: %.0fs" % time_remaining
	else:
		info_panel.get_node("Timer").text = ""

func _load_game() -> void:
	if save_system.call("has_save"):
		save_system.call("load_game")
		health = save_system.get("player_health")
		cash = save_system.get("player_cash")
		completed_missions = save_system.get("completed_missions")
		if player:
			player.global_position = save_system.get("player_position")
		_update_hud()
		_show_toast("Game Loaded")
