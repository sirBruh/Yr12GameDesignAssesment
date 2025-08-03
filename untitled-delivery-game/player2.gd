extends CharacterBody3D

var jump_velocity = 4.5
var mouse_sens = 0.002

var walking_speed = 5.0
var crouchingSpeed = 3.5
 
var true_speed = walking_speed
var isCrouching = false



func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	if Input.is_action_just_pressed("crouch"):
		if isCrouching == false:
			movementStateChange("crouch")
			true_speed = crouchingSpeed 
	elif isCrouching == true:
			movementStateChange("uncrouch")
			true_speed = walking_speed
			
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * walking_speed
		velocity.z = direction.z * walking_speed
	else:
		velocity.x = move_toward(velocity.x, 0, walking_speed)
		velocity.z = move_toward(velocity.z, 0, walking_speed)

	move_and_slide()
func movementStateChange(changeType):
	match changeType:
		"crouch":
			$AnimationPlayer.play("StandingToCrouch")
			isCrouching = true
			changeCollisionShapeTo("crouching")
		"uncrouch":
			$AnimationPlayer.play_backwards("StandingToCrouch")
			isCrouching = false
			changeCollisionShapeTo("standing")
func changeCollisionShapeTo(shape):
	match shape:
		"crouching":
			#Disabled == false is enabled!
			$CrouchingCollisionShape.disabled = false
			$StandingCollisionShape.disabled = true
		"standing":
			#Disabled == false is enabled!
			$StandingCollisionShape.disabled = false
			$CrouchingCollisionShape.disabled = true
