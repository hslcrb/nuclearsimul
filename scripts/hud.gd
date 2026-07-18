extends CanvasLayer

var player: CharacterBody3D
var pause_menu: Control

@onready var crosshair = $Crosshair
@onready var stamina_bar = $StaminaBar
@onready var stamina_fill = $StaminaBar/StaminaFill
@onready var interaction_label = $InteractionLabel
@onready var info_panel = $InfoPanel
@onready var info_title = $InfoPanel/Margin/VBox/InfoTitle
@onready var info_text = $InfoPanel/Margin/VBox/InfoText
@onready var compass = $Compass
@onready var compass_label = $Compass/Label
@onready var pos_label = $PosLabel
@onready var notif_label = $NotificationLabel
@onready var dosis_label = $DosisLabel
@onready var photo_count_label = $PhotoCountLabel
@onready var pause_panel = $PausePanel

var current_interactable: Interactable = null
var showing_info: bool = false
var notification_queue: Array = []
var notification_timer: float = 0.0
var geiger: Node

func _ready():
	player = get_node("/root/World/Player")
	geiger = get_node("/root/World/GameManager/GeigerCounter")
	hide_info()
	if pause_panel:
		pause_panel.hide()

func _process(delta):
	_update_raycast(delta)
	_update_stamina()
	_update_compass()
	_update_position()
	_update_notification(delta)
	_update_geiger()

func _update_raycast(_delta):
	if showing_info:
		return
	var cam = player.get_node("Neck/Head/Camera3D") as Camera3D
	var space = cam.get_world_3d().direct_space_state
	var viewport = get_viewport()
	var center = viewport.get_size() / 2
	var from = cam.project_ray_origin(center)
	var to = from + cam.project_ray_normal(center) * 25.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = 2
	var result = space.intersect_ray(query)
	if result and result.collider is Interactable:
		current_interactable = result.collider
		interaction_label.text = "[E] " + current_interactable.title
		interaction_label.show()
		crosshair.modulate = Color(0, 1, 0.5)
	else:
		current_interactable = null
		interaction_label.hide()
		crosshair.modulate = Color(1, 1, 1, 0.6)

func _update_stamina():
	if not stamina_bar or not player:
		return
	var s = player.get("stamina")
	if s != null:
		var pct = s / player.get("STAMINA_MAX")
		stamina_fill.scale.x = pct
		if pct < 0.3:
			stamina_fill.modulate = Color(1, 0.3, 0.2)
		elif pct < 0.6:
			stamina_fill.modulate = Color(1, 0.8, 0.2)
		else:
			stamina_fill.modulate = Color(0.3, 1, 0.3)
		stamina_bar.visible = pct < 1.0

func _update_compass():
	if not player:
		return
	var head = player.get_node("Neck/Head")
	var rot = -head.global_rotation.y
	var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var i = int(round(rot / (PI / 4))) % 8
	compass_label.text = dirs[i]

func _update_position():
	if not player:
		return
	var p = player.global_position
	pos_label.text = "%.0f, %.0f, %.0f" % [p.x, p.y, p.z]

func _update_geiger():
	if not dosis_label or not geiger:
		return
	var pct = geiger.get_dosis_percent()
	var bar = ""
	var n = int(pct * 20)
	for i in range(20):
		bar += "█" if i < n else "░"
	dosis_label.text = "방사선: " + bar

func _update_notification(delta):
	if notification_queue.size() > 0:
		notification_timer -= delta
		notif_label.text = notification_queue[0]
		notif_label.show()
		if notification_timer <= 0:
			notification_queue.pop_front()
			if notification_queue.size() > 0:
				notification_timer = 3.0
			else:
				notif_label.hide()

func notify(text: String):
	notification_queue.append(text)
	if notification_queue.size() == 1:
		notification_timer = 3.0

func show_info(interactable: Interactable):
	showing_info = true
	info_title.text = interactable.title
	info_text.text = interactable.info
	info_panel.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	interaction_label.hide()

func hide_info():
	showing_info = false
	info_panel.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause():
	if pause_panel:
		pause_panel.show()

func hide_pause():
	if pause_panel:
		pause_panel.hide()

func is_showing_info() -> bool:
	return showing_info

func get_current_interactable() -> Interactable:
	return current_interactable
