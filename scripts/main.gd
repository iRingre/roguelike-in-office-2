extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const ROOM_SIZE: float = 24.0
const DOOR_WIDTH: float = 4.0
const FLOOR_COUNT: int = 3
const ROOMS_PER_FLOOR: int = 6
const ROOM_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(1, 0), Vector2i(2, 1), Vector2i(2, 0)
]

var player: PlayerController
var hud: GameHud
var room_centers: Array[Vector3] = []
var room_children: Array = []
var room_cleared: Array[bool] = []
var room_started: Array[bool] = []
var weapon_pickups_placed: Array[bool] = [true, false, false]
var floor_exit_key_placed: Array[bool] = []
var door_barriers: Dictionary = {}
var unlocked_doors: Dictionary = {}
var current_room: int = -1
var enemies_left: int = 0
var scrap: int = 0
var crafted_equipment: Array[String] = []
var run_started: bool = false
var ending: bool = false
var boss_active: bool = false

func _ready() -> void:
	randomize()
	_generate_layout()
	_build_arena()
	player = PLAYER_SCENE.instantiate() as PlayerController
	player.position = room_centers[0] + Vector3(0.0, 0.1, 7.0)
	player.add_to_group("player")
	add_child(player)
	for room_index in range(room_centers.size()):
		_add_weapon_pickup(room_index)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)

	hud = GameHud.new()
	add_child(hud)
	hud.start_pressed.connect(_start_run)
	hud.equipment_chosen.connect(_on_equipment_chosen)
	hud.restart_pressed.connect(_restart_run)
	player.weapon_changed.connect(hud.set_weapon)
	hud.set_scrap(scrap)
	hud.set_equipment(crafted_equipment)
	hud.set_room(0, FLOOR_COUNT, ROOMS_PER_FLOOR, 0)

func _process(_delta: float) -> void:
	if not run_started or ending or current_room < 0:
		return
	var player_position := player.global_position
	for room_index in range(room_centers.size()):
		if room_index == current_room:
			continue
		if not room_cleared[current_room] and room_cleared[room_index]:
			continue
		if player_position.distance_to(room_centers[room_index]) < ROOM_SIZE * 0.42:
			if _is_room_accessible(room_index):
				_enter_room(room_index)
				return

func _generate_layout() -> void:
	room_centers.clear()
	door_barriers.clear()
	unlocked_doors.clear()
	floor_exit_key_placed.clear()
	for floor_index in range(FLOOR_COUNT):
		floor_exit_key_placed.append(false)
		for cell in ROOM_CELLS:
			var global_cell := cell + Vector2i(floor_index * 3, 0)
			room_centers.append(Vector3(global_cell.x * ROOM_SIZE, 0.0, global_cell.y * ROOM_SIZE))
	room_children.clear()
	room_cleared.clear()
	room_started.clear()
	for _index in range(ROOM_CELLS.size() * FLOOR_COUNT):
		room_children.append([])
		room_cleared.append(false)
		room_started.append(false)

	for floor_index in range(FLOOR_COUNT):
		var floor_start := floor_index * ROOMS_PER_FLOOR
		var visited: Array[int] = [floor_start]
		var stack: Array[int] = [floor_start]
		while not stack.is_empty():
			var current: int = stack.back()
			var options := _unvisited_neighbors(current, visited)
			if options.is_empty():
				stack.pop_back()
				continue
			var next: int = options.pick_random()
			visited.append(next)
			stack.append(next)
			room_children[current].append(next)
			room_children[next].append(current)
			door_barriers[_edge_key(current, next)] = null

		if floor_index < FLOOR_COUNT - 1:
			var exit_room := floor_start + ROOMS_PER_FLOOR - 1
			var next_floor_entry := floor_start + ROOMS_PER_FLOOR
			room_children[exit_room].append(next_floor_entry)
			room_children[next_floor_entry].append(exit_room)
			door_barriers[_edge_key(exit_room, next_floor_entry)] = null

func _unvisited_neighbors(room_index: int, visited: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var cell := _room_cell(room_index)
	var floor_index := _room_floor(room_index)
	for candidate in range(floor_index * ROOMS_PER_FLOOR, (floor_index + 1) * ROOMS_PER_FLOOR):
		if visited.has(candidate):
			continue
		var other := _room_cell(candidate)
		if absi(cell.x - other.x) + absi(cell.y - other.y) == 1:
			result.append(candidate)
	return result

func _room_cell(room_index: int) -> Vector2i:
	var floor_index := _room_floor(room_index)
	return ROOM_CELLS[room_index % ROOMS_PER_FLOOR] + Vector2i(floor_index * 3, 0)

func _room_floor(room_index: int) -> int:
	return floori(float(room_index) / float(ROOMS_PER_FLOOR))

func _room_number(room_index: int) -> int:
	return room_index % ROOMS_PER_FLOOR + 1

func _edge_key(first: int, second: int) -> String:
	return "%d:%d" % [mini(first, second), maxi(first, second)]

func _room_index_at_cell(cell: Vector2i) -> int:
	for room_index in range(room_centers.size()):
		if _room_cell(room_index) == cell:
			return room_index
	return -1

func _has_door(first: int, second: int) -> bool:
	return door_barriers.has(_edge_key(first, second))

func _is_room_accessible(room_index: int) -> bool:
	for connected_room in room_children[current_room]:
		if connected_room == room_index:
			return unlocked_doors.has(_edge_key(current_room, room_index))
	return false

func _build_arena() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.027, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.4, 0.62)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	key_light.light_color = Color(0.45, 0.62, 1.0)
	key_light.light_energy = 0.8
	key_light.shadow_enabled = true
	add_child(key_light)

	var floor_material := _material(Color(0.12, 0.105, 0.09), Color(0.08, 0.045, 0.02), 0.2)
	var wall_material := _material(Color(0.27, 0.28, 0.3), Color(0.08, 0.07, 0.05), 0.15)
	var trim_material := _material(Color(0.72, 0.48, 0.2), Color(0.9, 0.43, 0.08), 0.8)
	var desk_material := _material(Color(0.2, 0.13, 0.09), Color(0.06, 0.025, 0.01), 0.1)
	var screen_material := _material(Color(0.18, 0.35, 0.38), Color(0.12, 0.65, 0.62), 0.8)
	for room_index in range(room_centers.size()):
		_build_room(room_index, floor_material, wall_material, trim_material, desk_material, screen_material)

func _build_room(room_index: int, floor_material: StandardMaterial3D, wall_material: StandardMaterial3D, trim_material: StandardMaterial3D, desk_material: StandardMaterial3D, screen_material: StandardMaterial3D) -> void:
	var center := room_centers[room_index]
	_add_box("Pavimento", center + Vector3(0, -0.5, 0), Vector3(ROOM_SIZE, 1, ROOM_SIZE), floor_material)
	_build_wall(room_index, Vector2i(0, -1), Vector3(0, 2, -ROOM_SIZE / 2.0), wall_material)
	_build_wall(room_index, Vector2i(0, 1), Vector3(0, 2, ROOM_SIZE / 2.0), wall_material)
	_build_wall(room_index, Vector2i(1, 0), Vector3(ROOM_SIZE / 2.0, 2, 0), wall_material, true)
	_build_wall(room_index, Vector2i(-1, 0), Vector3(-ROOM_SIZE / 2.0, 2, 0), wall_material, true)

	for position in [
		Vector3(-ROOM_SIZE * 0.34, 0, -ROOM_SIZE * 0.34),
		Vector3(ROOM_SIZE * 0.34, 0, -ROOM_SIZE * 0.34),
		Vector3(-ROOM_SIZE * 0.34, 0, ROOM_SIZE * 0.34),
		Vector3(ROOM_SIZE * 0.34, 0, ROOM_SIZE * 0.34)
	]:
		_add_box("Pilastro", center + position + Vector3(0, 1.25, 0), Vector3(1.2, 2.5, 1.2), wall_material)
		_add_box("Luce pilastro", center + position + Vector3(0, 2.45, 0), Vector3(1.3, 0.08, 1.3), trim_material, false)

	for desk_x in [-5.0, 5.0]:
		var desk_position := center + Vector3(desk_x, 0.8, -4.5)
		_add_box("Scrivania", desk_position, Vector3(3.2, 0.16, 1.5), desk_material, false)
		_add_box("Monitor", desk_position + Vector3(0, 0.62, -0.38), Vector3(0.9, 0.85, 0.12), screen_material, false)

	var floor_sign := Label3D.new()
	floor_sign.name = "NumeroPiano"
	floor_sign.text = "PIANO %02d  •  STANZA %02d" % [_room_floor(room_index) + 1, _room_number(room_index)]
	floor_sign.position = center + Vector3(0, 2.8, -ROOM_SIZE * 0.46)
	floor_sign.font_size = 48
	floor_sign.outline_size = 8
	floor_sign.modulate = Color(1.0, 0.72, 0.35)
	floor_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(floor_sign)

	var beacon_light := OmniLight3D.new()
	beacon_light.position = center + Vector3(0, 2.7, -ROOM_SIZE * 0.35)
	beacon_light.light_color = Color(1.0, 0.65, 0.32)
	beacon_light.light_energy = 1.0
	beacon_light.omni_range = 7.0
	add_child(beacon_light)

func _build_wall(room_index: int, direction: Vector2i, offset: Vector3, material: StandardMaterial3D, rotated: bool = false) -> void:
	var cell := _room_cell(room_index)
	var neighbor_cell := cell + direction
	var neighbor_index := _room_index_at_cell(neighbor_cell)
	var center := room_centers[room_index] + offset
	if neighbor_index >= 0 and _has_door(room_index, neighbor_index):
		var segment_length := (ROOM_SIZE - DOOR_WIDTH) / 2.0
		for side in [-1.0, 1.0]:
			var segment_offset := Vector3(0, 0, side * (DOOR_WIDTH + segment_length) / 2.0) if rotated else Vector3(side * (DOOR_WIDTH + segment_length) / 2.0, 0, 0)
			var segment_size := Vector3(0.8, 4.0, segment_length) if rotated else Vector3(segment_length, 4.0, 0.8)
			_add_box("Parete", center + segment_offset, segment_size, material)
		if room_index < neighbor_index:
			_create_door(room_index, neighbor_index, center, rotated)
	else:
		var size := Vector3(0.8, 4.0, ROOM_SIZE) if rotated else Vector3(ROOM_SIZE, 4.0, 0.8)
		_add_box("Parete", center, size, material)

func _create_door(first: int, second: int, center: Vector3, rotated: bool) -> void:
	var barrier := StaticBody3D.new()
	barrier.name = "PortaChiusa"
	barrier.position = center
	add_child(barrier)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 3.2, DOOR_WIDTH) if rotated else Vector3(DOOR_WIDTH, 3.2, 0.35)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(Color(0.06, 0.28, 0.38), Color(0.1, 0.75, 1.0), 2.0)
	barrier.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	barrier.add_child(collision)
	door_barriers[_edge_key(first, second)] = barrier

func _add_weapon_pickup(room_index: int) -> void:
	var floor_index := _room_floor(room_index)
	if floor_index == 0 or _room_number(room_index) != 1:
		return
	var weapon_index := floor_index
	if weapon_index >= player_weapon_count() or weapon_pickups_placed[weapon_index]:
		return
	weapon_pickups_placed[weapon_index] = true
	_create_pickup(
		room_centers[room_index] + Vector3(0.0, 0.8, 0.0),
		Color(0.3, 1.0, 0.55) if weapon_index == 1 else Color(1.0, 0.55, 0.2),
		"Arma",
		weapon_index
	)

func player_weapon_count() -> int:
	return 3

func _create_pickup(position: Vector3, tint: Color, pickup_name: String, value: int, source_room: int = -1) -> void:
	var area := Area3D.new()
	area.name = pickup_name
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5 if pickup_name == "Arma" else 1.1
	collision.shape = shape
	area.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.35 if pickup_name == "Chiave" else 0.58
	mesh.height = 0.7 if pickup_name == "Chiave" else 1.16
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(tint, tint, 2.0)
	area.add_child(mesh_instance)
	var pickup_label := Label3D.new()
	pickup_label.position = Vector3(0, 1.25, 0)
	pickup_label.font_size = 40
	pickup_label.outline_size = 8
	pickup_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup_label.modulate = Color.WHITE
	pickup_label.text = "CHIAVE" if pickup_name == "Chiave" else player.weapon_name(value).to_upper()
	area.add_child(pickup_label)
	add_child(area)
	if pickup_name == "Chiave":
		area.body_entered.connect(_on_key_collected.bind(value, area, source_room))
	else:
		area.body_entered.connect(_on_weapon_collected.bind(value, area))

func _add_box(node_name: String, position: Vector3, size: Vector3, material: StandardMaterial3D, solid: bool = true) -> MeshInstance3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = node_name
	body.position = position
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return mesh_instance

func _material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = 0.25
	result.roughness = 0.72
	result.emission_enabled = true
	result.emission = emission
	result.emission_energy_multiplier = energy
	return result

func _start_run() -> void:
	if run_started:
		return
	run_started = true
	hud.close_intro()
	player.set_controls_enabled(true)
	_enter_room(0)

func _enter_room(room_index: int) -> void:
	current_room = room_index
	if room_started[room_index]:
		hud.set_room(room_index, FLOOR_COUNT, ROOMS_PER_FLOOR, _unlocked_door_count())
		return
	room_started[room_index] = true
	hud.set_room(room_index, FLOOR_COUNT, ROOMS_PER_FLOOR, _unlocked_door_count())
	hud.show_message("Piano %d, stanza %d: libera l'ufficio e recupera le chiavi." % [_room_floor(room_index) + 1, _room_number(room_index)])
	var difficulty := _room_floor(room_index) * 3 + _room_number(room_index) - 1
	var enemy_count := 4 + difficulty
	enemies_left = enemy_count
	hud.set_remaining(enemies_left)
	for index in range(enemy_count):
		var enemy := ENEMY_SCENE.instantiate() as Sentinel
		var angle := TAU * float(index) / float(enemy_count) + randf_range(-0.2, 0.2)
		var radius := randf_range(5.5, 8.0)
		enemy.position = room_centers[room_index] + Vector3(cos(angle) * radius, 0.1, sin(angle) * radius)
		var enemy_kind := _choose_enemy_kind(difficulty)
		enemy.configure(enemy_kind, difficulty)
		add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)

func _choose_enemy_kind(difficulty: int) -> int:
	if difficulty == 0:
		return Sentinel.Kind.HUNTER
	var choices: Array[int] = [Sentinel.Kind.HUNTER, Sentinel.Kind.RUNNER]
	if difficulty >= 1:
		choices.append(Sentinel.Kind.BRUTE)
	if difficulty >= 2:
		choices.append(Sentinel.Kind.SHOOTER)
	return choices.pick_random()

func _on_enemy_defeated() -> void:
	enemies_left = maxi(0, enemies_left - 1)
	scrap += 1
	hud.set_scrap(scrap)
	hud.set_remaining(enemies_left)
	if enemies_left == 0:
		if boss_active:
			ending = true
			player.set_controls_enabled(false)
			hud.show_ending(true)
		else:
			_on_room_cleared()

func _on_room_cleared() -> void:
	room_cleared[current_room] = true
	if _all_rooms_cleared():
		_spawn_boss()
		return
	var current_floor := _room_floor(current_room)
	if _floor_cleared(current_floor) and current_floor < FLOOR_COUNT - 1:
		_place_floor_exit_key(current_floor)
	var children: Array = []
	for neighbor in room_children[current_room]:
		if not room_cleared[neighbor] and _room_floor(neighbor) == current_floor:
			children.append(neighbor)
	for index in range(children.size()):
		var target_room: int = children[index]
		var direction := (room_centers[target_room] - room_centers[current_room]).normalized()
		var side := Vector3(-direction.z, 0.0, direction.x)
		var key_position := room_centers[current_room] + direction * 7.0 + side * (float(index) - float(children.size() - 1) / 2.0) * 2.0 + Vector3.UP * 0.6
		_create_pickup(key_position, Color(1.0, 0.78, 0.2), "Chiave", target_room, current_room)
	player.set_controls_enabled(false)
	var room_message := "Stanza liberata. Raccogli la chiave e apri le porte per proseguire."
	if children.is_empty():
		room_message = "Stanza liberata. Torna indietro e cerca le porte ancora chiuse."
	hud.show_workshop(current_floor + 1, _room_number(current_room), ROOMS_PER_FLOOR, FLOOR_COUNT, room_message, scrap)

func _spawn_boss() -> void:
	boss_active = true
	enemies_left = 1
	hud.set_remaining(enemies_left)
	hud.show_message("PIANO 3 COMPLETATO. Il Direttore ti aspetta: sconfiggilo per uscire!")
	player.set_controls_enabled(true)
	var boss := ENEMY_SCENE.instantiate() as Sentinel
	boss.name = "IlDirettore"
	boss.position = room_centers[current_room] + Vector3(0.0, 0.1, -6.0)
	boss.configure(Sentinel.Kind.BOSS, FLOOR_COUNT * 3)
	add_child(boss)
	var boss_label := Label3D.new()
	boss_label.text = "IL DIRETTORE"
	boss_label.position = Vector3(0.0, 3.0, 0.0)
	boss_label.font_size = 44
	boss_label.outline_size = 8
	boss_label.modulate = Color(1.0, 0.55, 0.35)
	boss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	boss.add_child(boss_label)
	boss.defeated.connect(_on_enemy_defeated)

func _place_floor_exit_key(floor_index: int) -> void:
	if floor_exit_key_placed[floor_index]:
		return
	floor_exit_key_placed[floor_index] = true
	var exit_room := (floor_index + 1) * ROOMS_PER_FLOOR - 1
	var target_room := exit_room + 1
	_create_pickup(
		room_centers[exit_room] + Vector3(0.0, 0.6, 6.0),
		Color(1.0, 0.78, 0.2),
		"Chiave",
		target_room,
		exit_room
	)

func _floor_cleared(floor_index: int) -> bool:
	var first_room := floor_index * ROOMS_PER_FLOOR
	for room_index in range(first_room, first_room + ROOMS_PER_FLOOR):
		if not room_cleared[room_index]:
			return false
	return true

func _on_key_collected(body: Node3D, target_room: int, pickup: Area3D, source_room: int) -> void:
	if body != player or not is_instance_valid(pickup):
		return
	pickup.queue_free()
	var key_room := current_room if source_room < 0 else source_room
	var barrier: StaticBody3D = door_barriers[_edge_key(key_room, target_room)]
	var collision := barrier.get_child(1) as CollisionShape3D
	collision.set_deferred("disabled", true)
	unlocked_doors[_edge_key(key_room, target_room)] = true
	(barrier.get_child(0) as MeshInstance3D).hide()
	hud.show_message("Chiave raccolta: porta della stanza %d del piano %d aperta." % [_room_number(target_room), _room_floor(target_room) + 1])
	player.set_controls_enabled(true)
	hud.set_room(current_room, FLOOR_COUNT, ROOMS_PER_FLOOR, _unlocked_door_count())

func _on_weapon_collected(body: Node3D, weapon_index: int, pickup: Area3D) -> void:
	if body != player or not is_instance_valid(pickup):
		return
	pickup.queue_free()
	player.unlock_weapon(weapon_index)
	hud.show_message("%s trovata e equipaggiata. Cambiala con il tasto %d." % [player.weapon_name(weapon_index), weapon_index + 1])

func _on_equipment_chosen(index: int) -> void:
	if index == 3:
		hud.close_workshop()
		player.set_controls_enabled(true)
		return
	if scrap < 3:
		return
	scrap -= 3
	match index:
		0:
			player.upgrade_damage(8.0)
			crafted_equipment.append("Modulo balistico")
		1:
			player.upgrade_health(30.0)
			crafted_equipment.append("Corazza d'eco")
		2:
			player.upgrade_speed(1.4)
			crafted_equipment.append("Stivali inerziali")
		_:
			scrap += 3
			return
	hud.set_scrap(scrap)
	hud.set_equipment(crafted_equipment)
	hud.close_workshop()
	player.set_controls_enabled(true)

func _unlocked_door_count() -> int:
	var count := 0
	for connected_room in room_children[current_room]:
		if unlocked_doors.has(_edge_key(current_room, connected_room)):
			count += 1
	return count

func _all_rooms_cleared() -> bool:
	for cleared in room_cleared:
		if not cleared:
			return false
	return true

func _on_health_changed(current: float, maximum: float) -> void:
	if is_instance_valid(hud):
		hud.set_health(current, maximum)

func _on_player_died() -> void:
	ending = true
	hud.show_ending(false)

func _restart_run() -> void:
	get_tree().reload_current_scene()
