extends Node3D

@export var lean_amount: float = 3.0
@export var lean_speed: float = 5.0
var target_tilt: float = 0.0
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var tilt = 0.0
	if Input.is_action_pressed("Left"):
		tilt = lean_amount
	elif Input.is_action_pressed("Right"):
		tilt = -lean_amount
	else:
		tilt = 0.0
	target_tilt = lerp(target_tilt, tilt, lean_speed * delta)
	rotation_degrees.z = target_tilt
func update_from_velocity(vel: Vector3, delta: float):
	var tilt = vel.x * 0.5   # scale sideways speed into tilt
	target_tilt = lerp(target_tilt, tilt, lean_speed * delta)
	rotation_degrees.z = target_tilt
