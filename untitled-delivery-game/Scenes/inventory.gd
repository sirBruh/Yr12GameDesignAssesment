extends Node3D

var items: Array[String] = []
func add_item(item_name: String):
	items.append(item_name)
func remove_item(item_name: String):
	if item_name in items:
		items.erase(item_name)
