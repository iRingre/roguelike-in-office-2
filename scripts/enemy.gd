class_name Sentinel
extends CharacterBody3D

signal defeated

enum Kind { HUNTER, RUNNER, BRUTE, SHOOTER, BOSS }

@export var max_health: float = 55.0
@export var move_speed: float = 3.1
@export var touch_damage: float = 11.0

var kind: int = Kind.HUNTER
var health: float = 55.0
var is_defeated: bool = false
var attack_cooldown: float = 0.0
var player: CharacterBody3D
var gravity: float = 20.0
var flash_timer: float = 0.0
var base_material: StandardMaterial3D
var flash_material: StandardMaterial3D
var projectile_scene: Script = preload("res://scripts/enemy_projectile.gd")
@onready var body_mesh: MeshInstance3D = $Corpo
@onready var core_mesh: MeshInstance3D = $Nucleo

func configure(enemy_kind: int, difficulty: int) -> void:
	kind = enemy_kind
	match kind:
		Kind.RUNNER:
			max_health = 34.0 + difficulty * 3.0
			move_speed = 5.2 + difficulty * 0.12
			touch_damage = 8.0 + difficulty
		Kind.BRUTE:
			max_health = 105.0 + difficulty * 10.0
			move_speed = 2.0 + difficulty * 0.08
			touch_damage = 20.0 + difficulty * 2.0
		Kind.SHOOTER:
			max_health = 48.0 + difficulty * 5.0
			move_speed = 2.6 + difficulty * 0.08
			touch_damage = 10.0 + difficulty
		Kind.BOSS:
			max_health = 720.0 + difficulty * 45.0
			move_speed = 2.8 + difficulty * 0.08
			touch_damage = 24.0 + difficulty * 1.5
		_:
			max_health = 55.0 + difficulty * 6.0
			move_speed = 3.1 + difficulty * 0.1
			touch_damage = 11.0 + difficulty

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	base_material = StandardMaterial3D.new()
	var tint := Color(0.16, 0.23, 0.42)
	match kind:
		Kind.RUNNER:
			tint = Color(0.58, 0.18, 0.3)
			body_mesh.scale = Vector3(0.72, 0.75, 0.72)
			core_mesh.scale = Vector3(0.8, 0.8, 0.8)
		Kind.BRUTE:
			tint = Color(0.4, 0.25, 0.14)
			body_mesh.scale = Vector3(1.45, 1.4, 1.45)
			core_mesh.scale = Vector3(1.25, 1.25, 1.25)
		Kind.SHOOTER:
			tint = Color(0.22, 0.36, 0.18)
			body_mesh.scale = Vector3(0.9, 1.1, 0.9)
		Kind.BOSS:
			tint = Color(0.48, 0.12, 0.16)
			scale = Vector3(1.55, 1.55, 1.55)
			body_mesh.scale = Vector3(1.2, 1.3, 1.2)
			core_mesh.scale = Vector3(1.5, 1.5, 1.5)
	base_material.albedo_color = tint
	base_material.emission_enabled = true
	base_material.emission = tint.lightened(0.2)
	base_material.emission_energy_multiplier = 0.8
	body_mesh.material_override = base_material
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(0.75, 0.95, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(0.45, 0.9, 1.0)
	flash_material.emission_energy_multiplier = 1.4
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.2, 0.95, 1.0)
	core_material.emission_enabled = true
	core_material.emission = Color(0.1, 0.8, 1.0)
	core_material.emission_energy_multiplier = 2.0
	core_mesh.material_override = core_material
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	flash_timer = maxf(0.0, flash_timer - delta)
	body_mesh.material_override = _flash_material() if flash_timer > 0.0 else base_material
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var is_ranged := kind == Kind.SHOOTER or kind == Kind.BOSS
	if is_ranged and distance >= 7.0 and distance <= 10.0:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
		if attack_cooldown <= 0.0:
			_shoot()
			attack_cooldown = 1.15 if kind == Kind.BOSS else 1.7
	elif is_ranged and distance < 7.0:
		var retreat_direction := -offset.normalized()
		velocity.x = retreat_direction.x * move_speed
		velocity.z = retreat_direction.z * move_speed
		look_at(global_position - retreat_direction, Vector3.UP)
	elif distance > (10.0 if is_ranged else 1.55):
		var direction := offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		look_at(global_position + direction, Vector3.UP)
		if is_on_floor():
			velocity.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 5.0 * delta)
		if not is_ranged and attack_cooldown <= 0.0:
			player.call("take_damage", touch_damage)
			attack_cooldown = 0.9
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

func take_damage(amount: float) -> void:
	if is_defeated:
		return
	health -= amount
	flash_timer = 0.09
	if health <= 0.0:
		is_defeated = true
		defeated.emit()
		queue_free()

func _shoot() -> void:
	var projectile := Node3D.new()
	projectile.set_script(projectile_scene)
	get_tree().current_scene.add_child(projectile)
	projectile.call(
		"setup",
		global_position + Vector3.UP * 1.1,
		(player.global_position + Vector3.UP * 0.8 - global_position).normalized(),
		touch_damage,
		15.0,
		get_rid()
	)

func _flash_material() -> StandardMaterial3D:
	return flash_material
