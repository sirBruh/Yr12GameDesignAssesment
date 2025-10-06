extends Area3D

@export var required_box_name: String = "Delivery Box"
func _ready() -> void:
	self.body_entered.connect(_on_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
	if body is RigidBody3D and body.has_method("pickup_hold"):
		if body.box == required_box_name:
			body.queue_free()
			get_tree().change_scene_to_file("res://Scenes/end.tscn")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE
