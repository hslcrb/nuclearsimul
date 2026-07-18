extends Node

var player: CharacterBody3D
var was_grounded: bool = true
var footstep_timer: float = 0.0
var footstep_interval: float = 0.45

func _ready():
	player = get_node("/root/World/Player")

func _process(delta):
	if not player:
		return
	var grounded = player.is_on_floor()
	var vel = player.velocity
	var moving = Vector2(vel.x, vel.z).length() > 0.5

	if grounded and moving:
		var speed = vel.length()
		footstep_interval = 0.55 if speed < 7.0 else 0.35 if speed < 12.0 else 0.25
		footstep_timer -= delta
		if footstep_timer <= 0:
			footstep_timer = footstep_interval
			_play_footstep()
	else:
		footstep_timer = 0.0

	was_grounded = grounded

func _play_footstep():
	var pitch = randf_range(0.9, 1.1)
	var vol = randf_range(-3, -1)
	_play_sound(pitch, vol)

func _play_sound(pitch: float, volume: float):
	var audio = AudioStreamPlayer3D.new()
	audio.bus = &"SFX"
	var tone = 80 + randi() % 40
	var dur = 0.08
	var sr = 22050
	var frames = int(sr * dur)
	var data = PackedByteArray()
	for i in range(frames):
		var t = float(i) / sr
		var env = exp(-t * 30)
		var s = sin(t * tone * TAU) * env * 0.3
		var sample = int(clamp(s * 32767, -32767, 32767))
		data.append(sample & 0xFF)
		data.append((sample >> 8) & 0xFF)
	var wav = AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	audio.stream = wav
	audio.pitch_scale = pitch
	audio.volume_db = volume
	audio.position = player.global_position
	add_child(audio)
	audio.play()
	await audio.finished
	audio.queue_free()
