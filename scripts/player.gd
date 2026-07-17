extends CharacterBody3D

const WALK_SPEED = 8.0
const SPRINT_SPEED = 14.0
const JUMP_VELOCITY = 6.0
const MOUSE_SENS = 0.002

@onready var head = $Head
@onready var cam = $Head/Camera3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENS)
		cam.rotate_x(-event.relative.y * MOUSE_SENS)
		cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)
	if event.is_action_pressed("ui_cancel"):
		var mode = Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(mode)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= 9.8 * delta * 2
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
