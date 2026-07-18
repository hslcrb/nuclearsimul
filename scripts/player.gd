extends CharacterBody3D

const WALK_SPEED = 6.0
const SPRINT_SPEED = 11.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 5.5
const MOUSE_SENS = 0.002
const HEAD_HIGH = 1.8
const HEAD_LOW = 0.3
const STAMINA_MAX = 100.0
const STAMINA_DRAIN = 20.0
const STAMINA_REGEN = 12.0

var stamina: float = STAMINA_MAX
var is_crouching: bool = false
var was_grounded: bool = true
var head_t: float = 1.0

@onready var head = $Head
@onready var cam = $Head/Camera3D
@onready var neck = $Neck
@onready var flashlight = $Head/Flashlight

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENS)
		cam.rotate_x(-event.relative.y * MOUSE_SENS)
		cam.rotation.x = clamp(cam.rotation.x, -1.5, 1.5)
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
	if event.is_action_pressed("interact") and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		pass

func _physics_process(delta):
	var grounded = is_on_floor()
	if not grounded:
		velocity.y -= 9.8 * delta * 2
	if Input.is_action_just_pressed("jump") and grounded and not is_crouching:
		velocity.y = JUMP_VELOCITY

	var sprint = Input.is_action_pressed("sprint") and stamina > 0 and grounded and not is_crouching
	var crouch = Input.is_action_pressed("crouch")
	var moving = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	head_t = move_toward(head_t, 0.0 if crouch else 1.0, delta * 6.0)
	neck.position.y = lerp(neck.position.y, HEAD_LOW + (HEAD_HIGH - HEAD_LOW) * head_t, delta * 10.0)

	if sprint and moving.length() > 0:
		stamina = max(0, stamina - STAMINA_DRAIN * delta)
		if stamina <= 0:
			sprint = false
	elif stamina < STAMINA_MAX:
		stamina = min(STAMINA_MAX, stamina + STAMINA_REGEN * delta)

	var speed = WALK_SPEED
	if sprint: speed = SPRINT_SPEED
	if crouch: speed = CROUCH_SPEED
	if sprint and moving.length() == 0: speed = WALK_SPEED

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var dir = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	if grounded and not was_grounded:
		pass
	was_grounded = grounded

func get_head_transform() -> Transform3D:
	return head.global_transform
