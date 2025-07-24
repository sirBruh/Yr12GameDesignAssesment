extends CharacterBody3D

@onready var stand_col = get_node("standing")
@onready var crouch_col = get_node("crouching")
@onready var cam_pivot = get_node("cam_pivot")
@onready var top_head = get_node("raycast/top_head")
@onready var face_lvl = get_node("raycast/face")
@onready var new_pos = get_node("raycast/new_pos")
@onready var slide_check = get_node("raycast/slide_check")

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 5.0
var jump_velocity = 4.5
var mouse_sens = 0.002
var grav = 9.8

var is_crouching = false
var is_running = false
var last_floor = false
var coyote = 0.1
var air_time = 0
var can_mantle = true
var mouse_unlocked = false

var slide_speed = 0
var fall_distance = 0
var can_slide = false
var sliding = false
var falling = false


var stamina = 100

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	last_floor = is_on_floor()
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
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() or air_time < coyote:
			velocity.y = jump_velocity
	if is_on_floor():
		air_time = 0
	else:
		air_time += delta
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
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 8)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 8)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 2) 
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 2)
func head_control():
	if Input.is_action_just_pressed("Unlock"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
		mouse_unlocked = not mouse_unlocked
func _input(event):
	if event is InputEventMouseMotion:
		if mouse_unlocked == false:
			rotate_y(-event.relative.x * mouse_sens)
			cam_pivot.rotate_x(-event.relative.y * mouse_sens)
			cam_pivot.rotation.x = clamp(cam_pivot.rotation.x, -PI/2, PI/2)
	if event.is_action_pressed("Crouch"):
		check_crouch_state()
		is_crouching = not is_crouching
	if Input.is_action_pressed("Sprint"):
		is_running = not is_running
		run_state()
func check_crouch_state():
	stand_col.disabled = not is_crouching
	crouch_col.disabled = is_crouching
func run_state():
	if is_running:
		speed = 8
	elif not is_running:
		speed = 5
func _on_above_head_body_entered(_body: Node3D):
	can_mantle = false
func _on_above_head_body_exited(_body: Node3D):
	can_mantle = true
func check_mantle():
	var has_ledge = (face_lvl.is_colliding() and not top_head.is_colliding())
	if can_mantle:
		if has_ledge:
			velocity.y = 0
			gravity = 0
			if has_ledge and Input.is_action_just_pressed("Jump"):
				var peek = create_tween()
				peek.tween_property(self, "position", new_pos.global_position, .75)
				
		else:
			gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
