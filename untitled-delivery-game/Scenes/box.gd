extends RigidBody3D

@export var box: String = "Delivery Box"

var is_held = false
var pickup_ray: RayCast3D = null

func pickup_hold(raycast: RayCast3D):
	is_held = true
	pickup_ray = raycast
	freeze = true
func drop():
	is_held = false
	pickup_ray = null
	freeze = false
func _physics_process(delta):
	if is_held and pickup_ray:
		var target_pos = pickup_ray.to_global(pickup_ray.target_position)
		global_transform.origin = target_pos
