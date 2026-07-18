extends Node

const CLICK_INTERVAL_MIN = 0.05
const CLICK_INTERVAL_MAX = 2.0
const PROBE_RADIUS = 10.0
const MAX_DOSIS = 100.0

var sources: Array = []
var timer: float = 0.0
var dosis: float = 0.0

@onready var player = get_node("/root/World/Player")
@onready var hud = get_node("/root/World/HUD")

func _ready():
	_randomize_sources()

func _randomize_sources():
	for i in 20:
		var angle = randf_range(0, TAU)
		var dist = randf_range(5, 130)
		var intensity = randf_range(0.1, 1.0)
		sources.append({
			pos = Vector3(cos(angle) * dist, 0, sin(angle) * dist),
			intensity = intensity
		})

func _process(delta):
	if not player:
		return
	_calculate_dosis()
	timer -= delta
	if timer <= 0:
		_click()
		var interval = lerp(CLICK_INTERVAL_MIN, CLICK_INTERVAL_MAX, 1.0 - dosis / MAX_DOSIS)
		timer = interval

func _calculate_dosis():
	dosis = 0.0
	var pp = player.global_position
	for s in sources:
		var dist = pp.distance_to(s.pos)
		if dist < PROBE_RADIUS:
			var falloff = 1.0 - dist / PROBE_RADIUS
			dosis += s.intensity * falloff * falloff
	dosis = min(dosis, MAX_DOSIS)

func _click():
	var vol = lerp(-30, -5, dosis / MAX_DOSIS)
	var pitch = lerp(0.5, 2.0, dosis / MAX_DOSIS)
	_play_geiger(vol, pitch)

func _play_geiger(volume: float, pitch: float):
	var audio = AudioStreamPlayer2D.new()
	var sr = 44100
	var dur = 0.04
	var frames = int(sr * dur)
	var data = PackedByteArray()
	for i in range(frames):
		var t = float(i) / sr
		var env = exp(-t * 80)
		var s = sin(t * 2000 * TAU) * env * 0.5
		var sample = int(clamp(s * 32767, -32767, 32767))
		data.append(sample & 0xFF)
		data.append((sample >> 8) & 0xFF)
	var wav = AudioStreamWAV.new()
	wav.data = data
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.stereo = false
	audio.stream = wav
	audio.volume_db = volume
	audio.pitch_scale = pitch
	add_child(audio)
	audio.play()
	await audio.finished
	audio.queue_free()

func get_dosis() -> float:
	return dosis

func get_dosis_percent() -> float:
	return dosis / MAX_DOSIS
