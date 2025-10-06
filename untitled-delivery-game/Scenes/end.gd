extends Control


func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/menu.tscn")


func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/level.tscn")
