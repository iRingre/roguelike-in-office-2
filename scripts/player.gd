class_name PlayerController
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal weapon_changed(weapon_name: String, weapon_index: int)

const PROJECTILE_SCRIPT = preload("res://scripts/projectile.gd")
const WEAPONS: Array[Dictionary] = [
	{"name": "Pistola", "damage": 28.0, "fire_interval": 0.24, "projectile_speed": 48.0, "color": Color(0.2, 0.85, 1.0)},
	{"name": "Carabina", "damage": 14.0, "fire_interval": 0.11, "projectile_speed": 62.0, "color": Color(0.35, 1.0, 0.55)},
	{"name": "Cannone", "damage": 70.0, "fire_interval": 0.72, "projectile_speed": 36.0, "color": Color(1.0, 0.55, 0.2)}
]

@export var walk_speed: float = 7.5
@export var jump_velocity: float = 5.2
@export var max_health: float = 100.0
@export var shot_damage: float = 28.0
@export var fire_interval: float = 0.24

var health: float = 100.0
var controls_enabled: bool = false
var fire_cooldown: float = 0.0
var muzzle_timer: float = 0.0
var selected_weapon: int = 0
var unlocked_weapons: Array[bool] = [true, false, false]
var mouse_sensitivity: float = 0.0018
var gravity: float = 20.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var weapon_body: MeshInstance3D = $Head/Camera3D/Weapon/Body
@onready var weapon_barrel: MeshInstance3D = $Head/Camera3D/Weapon/Barrel
@onready var muzzle_flash: OmniLight3D = $Head/Camera3D/Weapon/MuzzleFlash

func _ready() -> void:
	health = max_health
	_apply_weapon_appearance()
	health_changed.emit(health, max_health)
	weapon_changed.emit(WEAPONS[selected_weapon]["name"], selected_weapon)

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-82.0), deg_to_rad(82.0))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_fire()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_select_weapon(0)
			KEY_2:
				_select_weapon(1)
			KEY_3:
				_select_weapon(2)
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	muzzle_timer = maxf(0.0, muzzle_timer - delta)
	muzzle_flash.visible = muzzle_timer > 0.0
	if not controls_enabled:
		return

	var input_vector := Vector2.ZERO
	input_vector.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	input_vector.y = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	input_vector = input_vector.normalized()
	var direction := (global_transform.basis * Vector3(input_vector.x, 0.0, -input_vector.y)).normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	var bob := sin(Time.get_ticks_msec() * 0.012) * 0.012 if input_vector.length_squared() > 0.0 else 0.0
	weapon.position.y = -0.3 + bob
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire()

func _fire() -> void:
	if not controls_enabled or fire_cooldown > 0.0:
		return
	var weapon_data: Dictionary = WEAPONS[selected_weapon]
	fire_cooldown = fire_interval if selected_weapon == 0 else float(weapon_data["fire_interval"])
	muzzle_timer = 0.045
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 80.0
	)
	query.collision_mask = 3
	query.exclude = [get_rid()]
	var aim_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = aim_hit["position"] if not aim_hit.is_empty() else query.to
	var muzzle_position := weapon_barrel.global_position
	var direction := (aim_point - muzzle_position).normalized()
	var projectile: Node3D = Node3D.new()
	projectile.set_script(PROJECTILE_SCRIPT)
	get_tree().current_scene.add_child(projectile)
	projectile.call(
		"setup",
		muzzle_position,
		direction,
		float(weapon_data["damage"]) + shot_damage - 28.0,
		float(weapon_data["projectile_speed"]),
		weapon_data["color"],
		get_rid()
	)
	muzzle_flash.light_color = weapon_data["color"]

func take_damage(amount: float) -> void:
	if not controls_enabled:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		died.emit()

func upgrade_damage(amount: float) -> void:
	shot_damage += amount

func upgrade_health(amount: float) -> void:
	max_health += amount
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)

func upgrade_speed(amount: float) -> void:
	walk_speed += amount

func unlock_weapon(index: int) -> void:
	if index < 0 or index >= WEAPONS.size() or unlocked_weapons[index]:
		return
	unlocked_weapons[index] = true
	_select_weapon(index)

func weapon_name(index: int) -> String:
	if index < 0 or index >= WEAPONS.size():
		return ""
	return str(WEAPONS[index]["name"])

func _select_weapon(index: int) -> void:
	if index < 0 or index >= WEAPONS.size() or not unlocked_weapons[index] or selected_weapon == index:
		return
	selected_weapon = index
	_apply_weapon_appearance()
	weapon_changed.emit(WEAPONS[selected_weapon]["name"], selected_weapon)

func _apply_weapon_appearance() -> void:
	var weapon_data: Dictionary = WEAPONS[selected_weapon]
	var material := StandardMaterial3D.new()
	material.albedo_color = weapon_data["color"]
	material.emission_enabled = true
	material.emission = weapon_data["color"]
	material.emission_energy_multiplier = 0.65
	weapon_body.material_override = material
	weapon_barrel.material_override = material
	match selected_weapon:
		0:
			weapon.scale = Vector3.ONE
		1:
			weapon.scale = Vector3(1.15, 1.0, 1.25)
		2:
			weapon.scale = Vector3(1.4, 1.3, 1.2)
	muzzle_flash.light_color = weapon_data["color"]
