class_name BikeAudioManager
extends Node3D

@export var bike_controller: Node

var bell_player: AudioStreamPlayer3D
var freewheel_player: AudioStreamPlayer3D
var wind_player: AudioStreamPlayer3D

var freewheel_timer: float = 0.0

func _ready() -> void:
	# 1. Setup Bell Player with procedural chime
	bell_player = AudioStreamPlayer3D.new()
	bell_player.stream = _create_bell_audio_stream()
	bell_player.volume_db = 0.0
	add_child(bell_player)

	# 2. Setup Freewheel Ratchet Player
	freewheel_player = AudioStreamPlayer3D.new()
	freewheel_player.stream = _create_click_audio_stream()
	freewheel_player.volume_db = -6.0
	add_child(freewheel_player)

	if bike_controller and bike_controller.has_signal("bell_rung"):
		bike_controller.connect("bell_rung", _on_bell_rung)

func _process(delta: float) -> void:
	if not bike_controller:
		return

	var is_coasting: bool = bike_controller.get("is_coasting") if "is_coasting" in bike_controller else false
	var current_speed: float = bike_controller.get("current_speed") if "current_speed" in bike_controller else 0.0

	# Freewheel clicking when coasting at speed
	if is_coasting and current_speed > 0.8:
		# Interval between ratchet teeth clicks decreases with speed
		var click_interval: float = clampf(0.3 / current_speed, 0.04, 0.25)
		freewheel_timer += delta
		if freewheel_timer >= click_interval:
			freewheel_timer = 0.0
			freewheel_player.pitch_scale = randf_range(0.95, 1.05)
			freewheel_player.play()
	else:
		freewheel_timer = 0.0

func _on_bell_rung() -> void:
	if bell_player:
		bell_player.pitch_scale = randf_range(0.98, 1.02)
		bell_player.play()

## Synthesize a metallic brass bell chime (dual harmonic frequency with exponential decay)
func _create_bell_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.0
	var total_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2) # 16-bit mono

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Exponential acoustic decay
		var decay: float = exp(-5.5 * t)
		# Dual chime frequency (C7 ~2093Hz and F7 ~2793Hz) + slight subharmonic
		var s1: float = sin(2.0 * PI * 2093.0 * t)
		var s2: float = sin(2.0 * PI * 2793.0 * t)
		var s3: float = sin(2.0 * PI * 4186.0 * t) * 0.2
		var sample: float = (0.5 * s1 + 0.4 * s2 + s3) * decay
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	return stream

## Synthesize a short crisp mechanical click for freewheel ratchet
func _create_click_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.025 # 25ms crisp click
	var total_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		var decay: float = exp(-280.0 * t)
		# High frequency snap (3200Hz) with noise burst
		var snap: float = sin(2.0 * PI * 3200.0 * t) * decay
		var s16: int = int(clampf(snap, -1.0, 1.0) * 24000.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	return stream
