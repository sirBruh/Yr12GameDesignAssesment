extends Control
var new_resolution = Vector2i(1152, 648)
func _ready() -> void:
	var resolution = $MenuButton
	var popup = resolution.get_popup()
	popup.add_item("1920 x 1080", 1)
	popup.add_item("1600 x 900", 2)
	popup.add_item("1280 x 720", 3)
	popup.add_item("640 x 480", 4)
func _on_item_pressed(id):
	if id == 1:
		new_resolution = Vector2i(1920,1080)
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")
