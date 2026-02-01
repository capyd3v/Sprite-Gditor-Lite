@tool
extends EditorPlugin

var dock_node

func _enter_tree():
	dock_node = preload("res://addons/Sprite-Gditor-Lite/sprite-editor.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_node)

func _exit_tree():
	if dock_node:
		remove_control_from_docks(dock_node)
		dock_node.queue_free()
