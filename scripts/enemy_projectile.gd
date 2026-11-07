extends Node3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 15.0
var damage: float = 10.0
var traveled: float = 0.0
var shooter: RID

func setup(origin: Vector3, aim_direction: Vector3, hit_damage: float, projectile_speed: float, shooter_rid: RID) -> void:
	global_position = origin
	direction = aim_direction.normalized()
	damage = hit_damage
	speed = projectile_speed
	shooter = shooter_rid
	look_at(global_position + direction, Vector3.UP)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.3, 0.2)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.12, 0.06)
	material.emission_energy_multiplier = 2.0
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
	query.collision_mask = 1
	query.exclude = [shooter]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit["collider"]
		if target is Node and target.is_in_group("player"):
			target.call("take_damage", damage)
		queue_free()
		return
	global_position += step
	traveled += step.length()
	if traveled >= 40.0:
		queue_free()
