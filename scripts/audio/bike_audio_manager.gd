class_name BikeAudioManager
extends Node3D

@export var bike_controller: Node

var bell_player: AudioStreamPlayer3D
var freewheel_player: AudioStreamPlayer3D
var wind_player: AudioStreamPlayer3D
var gravel_player: AudioStreamPlayer3D

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

	# 3. Setup Wind Rush Player (Procedural looped pink noise)
	wind_player = AudioStreamPlayer3D.new()
	wind_player.stream = _create_wind_audio_stream()
	wind_player.volume_db = -80.0
	wind_player.autoplay = true
	add_child(wind_player)

	# 4. Setup Gravel Tire Noise Player (Procedural textured noise)
	gravel_player = AudioStreamPlayer3D.new()
	gravel_player.stream = _create_gravel_audio_stream()
	gravel_player.volume_db = -80.0
	gravel_player.autoplay = true
	add_child(gravel_player)

	if bike_controller and bike_controller.has_signal("bell_rung"):
		if not bike_controller.is_connected("bell_rung", _on_bell_rung):
			bike_controller.connect("bell_rung", _on_bell_rung)

func _process(delta: float) -> void:
	if not bike_controller:
		return

	var is_coasting: bool = bike_controller.get("is_coasting") if "is_coasting" in bike_controller else false
	var current_speed: float = bike_controller.get("current_speed") if "current_speed" in bike_controller else 0.0
	var is_on_grass: bool = bike_controller.get("is_on_grass") if "is_on_grass" in bike_controller else false

	# 1. Freewheel clicking when coasting at speed
	if is_coasting and current_speed > 0.8:
		var click_interval: float = clampf(0.3 / current_speed, 0.04, 0.25)
		freewheel_timer += delta
		if freewheel_timer >= click_interval:
			freewheel_timer = 0.0
			freewheel_player.pitch_scale = randf_range(0.95, 1.05)
			freewheel_player.play()
	else:
		freewheel_timer = 0.0

	# 2. Dynamic Wind Rush modulation (FEAT-007.2)
	if wind_player:
		var target_wind_vol: float = -80.0
		var target_wind_pitch: float = 1.0
		if current_speed > 3.0: # ~11 km/h threshold
			var wind_ratio: float = clampf((current_speed - 3.0) / 9.0, 0.0, 1.0)
			target_wind_vol = lerpf(-38.0, -12.0, wind_ratio)
			target_wind_pitch = lerpf(0.85, 1.25, wind_ratio)
		wind_player.volume_db = lerpf(wind_player.volume_db, target_wind_vol, 5.0 * delta)
		wind_player.pitch_scale = lerpf(wind_player.pitch_scale, target_wind_pitch, 5.0 * delta)

	# 3. Dynamic Gravel / Turf Tire Noise modulation (FEAT-007.2)
	if gravel_player:
		var target_gravel_vol: float = -80.0
		var target_gravel_pitch: float = 1.0
		if current_speed > 0.2:
			var speed_ratio: float = clampf(current_speed / 8.0, 0.0, 1.0)
			target_gravel_vol = lerpf(-36.0, -14.0, speed_ratio)
			if is_on_grass:
				target_gravel_vol -= 3.0
				target_gravel_pitch = 0.65 # Deep muffled turf rumble
			else:
				target_gravel_pitch = lerpf(0.9, 1.15, speed_ratio)
		gravel_player.volume_db = lerpf(gravel_player.volume_db, target_gravel_vol, 6.0 * delta)
		gravel_player.pitch_scale = lerpf(gravel_player.pitch_scale, target_gravel_pitch, 6.0 * delta)

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

## Synthesize a seamless looping pink-noise wind stream
func _create_wind_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.0
	var total_samples: int = int(sample_rate * duration)
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(total_samples)

	# Low-pass filter over white noise to create soothing aerodynamic wind rush
	var filter_val: float = 0.0
	for _w in range(500):
		var white: float = randf_range(-1.0, 1.0)
		filter_val = filter_val * 0.94 + white * 0.06

	for i in range(total_samples):
		var white: float = randf_range(-1.0, 1.0)
		filter_val = filter_val * 0.94 + white * 0.06
		raw_samples[i] = filter_val

	# Smooth crossfade boundary (256 samples) for seamless loop
	var fade_len: int = 256
	for i in range(fade_len):
		var t: float = float(i) / float(fade_len)
		var blended: float = raw_samples[i] * t + raw_samples[total_samples - fade_len + i] * (1.0 - t)
		raw_samples[i] = blended
		raw_samples[total_samples - fade_len + i] = blended

	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)
	for i in range(total_samples):
		var s16: int = int(clampf(raw_samples[i] * 3.0, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream

## Synthesize a textured looping granular surface noise stream
func _create_gravel_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.5
	var total_samples: int = int(sample_rate * duration)
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(total_samples)

	var low_state: float = 0.0
	var band_state: float = 0.0
	for _w in range(400):
		var white: float = randf_range(-1.0, 1.0)
		low_state += 0.25 * band_state
		var high: float = white - low_state - 0.5 * band_state
		band_state += 0.25 * high

	for i in range(total_samples):
		var white: float = randf_range(-1.0, 1.0)
		low_state += 0.25 * band_state
		var high: float = white - low_state - 0.5 * band_state
		band_state += 0.25 * high

		var grit: float = 0.0
		if randf() < 0.015:
			grit = randf_range(-0.4, 0.4)

		raw_samples[i] = band_state * 0.7 + grit

	var fade_len: int = 256
	for i in range(fade_len):
		var t: float = float(i) / float(fade_len)
		var blended: float = raw_samples[i] * t + raw_samples[total_samples - fade_len + i] * (1.0 - t)
		raw_samples[i] = blended
		raw_samples[total_samples - fade_len + i] = blended

	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)
	for i in range(total_samples):
		var s16: int = int(clampf(raw_samples[i] * 2.2, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream
