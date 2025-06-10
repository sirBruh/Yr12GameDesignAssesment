extends CharacterBody3D

@onready var stand_col = get_node("standing")
@onready var crouch_col = get_node("crouching")
@onready var cam_pivot = get_node("cam_pivot")

@onready var top_head = get_node("raycast/top_head")
@onready var face_lvl = get_node("raycast/face")
@onready var new_pos = get_node("raycast/new_pos")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 5.0
var jump_velocity = 4.5
var mouse_sens = 0.002
var grav = 9.8
var is_crouching = false
var can_mantle = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	check_mantle()
	control_loop(delta)
	run_state()
	head_control()
	move_and_slide()

func control_loop(delta):
		# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if is_on_floor():
		if direction:
			if is_crouching:
				velocity.x = direction.x * speed / 2
				velocity.z = direction.z * speed / 2
			else:
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed 
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 10)
			velocity.z = lerp(velocity.z, direction.x * speed, delta * 10)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta)
		velocity.z = lerp(velocity.z, direction.x * speed, delta)
func head_control():
	if Input.is_action_just_pressed("Unlock"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sens)
		cam_pivot.rotate_x(-event.relative.y * mouse_sens)
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, -PI/2, PI/2)
	if event.is_action_pressed("Crouch"):
		check_crouch_state()
		is_crouching = not is_crouching
func check_crouch_state():
	stand_col.disabled = not is_crouching
	crouch_col.disabled = is_crouching
func run_state():
	if Input.is_action_pressed("Sprint"):
		speed = 8
	else:
		speed = 5
func check_mantle():
	var has_ledge = (face_lvl.is_colliding() and not top_head.is_colliding())
	if can_mantle:
		if has_ledge:
			velocity.y = 0
			gravity = 0
			if has_ledge and Input.is_action_just_pressed("Jump"):
				var peek = create_tween()
				peek.tween_property(self, "position", new_pos.global_position, .75)
				#self.global_position = new_pos.global_position
		else:
			gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _on_above_head_body_entered(body: Node3D) -> void:
	can_mantle = false

func _on_above_head_body_exited(body: Node3D) -> void:
	can_mantle = true
