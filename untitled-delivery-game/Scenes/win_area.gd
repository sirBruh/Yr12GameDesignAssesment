extends Area3D

@export var required_box_name: String = "Delivery Box"
@export var next_scene_path: String = "res://Scenes/menu.tscn"
func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body):
	if body.has_method("pickup_store") and body.box == required_box_name:
		body.queue_free()
		if next_scene_path != "":
			get_tree().change_scene(next_scene_path)
