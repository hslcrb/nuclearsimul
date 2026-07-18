extends Node

const PHOTO_COOLDOWN = 3.0
var cooldown: float = 0.0
var photo_count: int = 0
var shutter_open: bool = false

@onready var hud = get_node("/root/World/HUD")
@onready var player = get_node("/root/World/Player")

signal photo_taken(photo_id)

func _process(delta):
	if cooldown > 0:
		cooldown -= delta

func take_photo() -> bool:
	if cooldown > 0:
		hud.notify("카메라 충전 중... (" + str(ceil(cooldown)) + "초)")
		return false
	photo_count += 1
	cooldown = PHOTO_COOLDOWN
	hud.notify("📸 사진 촬영! (#" + str(photo_count) + ")")
	_flash_effect()
	photo_taken.emit(photo_count)
	return true

func _flash_effect():
	var rect = ColorRect.new()
	rect.color = Color(1, 1, 1, 0.8)
	rect.size = get_viewport().get_visible_rect().size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(rect)
	var t = create_tween()
	t.tween_property(rect, "color:a", 0.0, 0.3)
	t.tween_callback(func(): rect.queue_free())

func get_photo_count() -> int:
	return photo_count
