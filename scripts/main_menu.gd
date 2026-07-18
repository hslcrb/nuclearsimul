extends Control

@onready var title_label = $VBox/Title
@onready var start_btn = $VBox/StartBtn
@onready var quit_btn = $VBox/QuitBtn
@onready var info_label = $VBox/InfoLabel

func _ready():
	start_btn.grab_focus()

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_start_mouse_entered():
	start_btn.grab_focus()

func _on_quit_mouse_entered():
	quit_btn.grab_focus()
