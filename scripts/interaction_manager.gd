extends Node

@onready var label = get_node("../UI/InteractionLabel")
@onready var info_panel = get_node("../UI/InfoPanel")
@onready var info_title = get_node("../UI/InfoPanel/Margin/VBox/InfoTitle")
@onready var info_text = get_node("../UI/InfoPanel/Margin/VBox/InfoText")
@onready var cam = get_node("../Player/Head/Camera3D")

var current_interactable: Interactable = null
var showing_info: bool = false

func _process(_delta):
	if showing_info:
		return
	var space = cam.get_world_3d().direct_space_state
	var viewport = get_viewport()
	var center = viewport.get_size() / 2
	var from = cam.project_ray_origin(center)
	var to = from + cam.project_ray_normal(center) * 20.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 1
	
	var result = space.intersect_ray(query)
	if result and result.collider is Interactable:
		current_interactable = result.collider
		label.text = current_interactable.get_interaction_text()
		label.show()
	else:
		current_interactable = null
		label.hide()

func _input(event):
	if event.is_action_pressed("interact") and current_interactable and not showing_info:
		show_info(current_interactable)
	if event.is_action_pressed("ui_cancel") and showing_info:
		hide_info()

func show_info(interactable: Interactable):
	showing_info = true
	info_title.text = interactable.title
	info_text.text = interactable.info
	info_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func hide_info():
	showing_info = false
	info_panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
