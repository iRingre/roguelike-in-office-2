extends Node3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 48.0
var damage: float = 28.0
var traveled: float = 0.0
var max_distance: float = 80.0
var shooter: RID

func setup(origin: Vector3, aim_direction: Vector3, hit_damage: float, projectile_speed: float, tint: Color, shooter_rid: RID) -> void:
	global_position = origin
	direction = aim_direction.normalized()
	damage = hit_damage
	speed = projectile_speed
	shooter = shooter_rid
	look_at(global_position + direction, Vector3.UP)

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 2.5
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.42
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = PI / 2.0
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
	query.collision_mask = 3
	query.exclude = [shooter]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit["collider"]
		if target is Node and target.is_in_group("enemies"):
			target.call("take_damage", damage)
		queue_free()
		return

	global_position += step
	traveled += step.length()
	if traveled >= max_distance:
		queue_free()
