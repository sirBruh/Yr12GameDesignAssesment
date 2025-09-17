extends RigidBody3D

@export var box: String = "Delivery Box"

var is_held = false
var pickup_ray: RayCast3D = null
var hold_offset: Transform3D
var hold_distance: float = 3.0

func pickup_hold(raycast: RayCast3D):
	is_held = true
	pickup_ray = raycast
	hold_offset = pickup_ray.global_transform.affine_inverse() * global_transform
func drop():
	is_held = false
	pickup_ray = null
func _physics_process(delta):
	if is_held and pickup_ray:
		var target_pos = pickup_ray.global_transform.origin + pickup_ray.global_transform.basis.z * -hold_distance
		var direction = target_pos - global_transform.origin
		linear_velocity = direction * 6.0
		angular_velocity = Vector3.ZERO
