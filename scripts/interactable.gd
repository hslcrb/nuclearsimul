extends Area3D

class_name Interactable

@export var title: String = ""
@export_multiline var info: String = ""
@export var icon: Texture2D

func get_interaction_text() -> String:
	return "[E] " + title
