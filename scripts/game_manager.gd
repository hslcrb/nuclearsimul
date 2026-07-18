extends Node

var hud: Node
var player: CharacterBody3D
var geiger: Node
var camera_rig: Node
var paused: bool = false

func _ready():
	hud = get_node("/root/World/HUD")
	player = get_node("/root/World/Player")
	geiger = $GeigerCounter
	camera_rig = $PhotoCamera

func _input(event):
	if event.is_action_pressed("interact"):
		if hud and hud.is_showing_info():
			hud.hide_info()
		elif hud and hud.get_current_interactable():
			hud.show_info(hud.get_current_interactable())
	if event.is_action_pressed("ui_cancel"):
		if hud and hud.is_showing_info():
			hud.hide_info()
		elif not paused:
			toggle_pause()
	if event.is_action_pressed("camera"):
		if camera_rig:
			camera_rig.take_photo()

func _process(_delta):
	if Input.is_action_just_pressed("flashlight"):
		var fl = player.get_node("Neck/Head/Flashlight")
		if fl:
			fl.visible = not fl.visible
			hud.notify("손전등 " + ("ON" if fl.visible else "OFF"))

func toggle_pause():
	paused = not paused
	get_tree().paused = paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		hud.show_pause()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		hud.hide_pause()

func notify(msg: String):
	if hud:
		hud.notify(msg)
