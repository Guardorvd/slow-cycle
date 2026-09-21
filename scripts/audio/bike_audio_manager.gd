class_name BikeAudioManager
extends Node3D

@export var bike_controller: Node

var bell_player: AudioStreamPlayer3D
var freewheel_player_a: AudioStreamPlayer3D
var freewheel_player_b: AudioStreamPlayer3D
var freewheel_player: AudioStreamPlayer3D ## Backward-compatibility alias for freewheel_player_a
var wind_player: AudioStreamPlayer3D
var gravel_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D

var freewheel_timer: float = 0.0
var freewheel_use_a: bool = true

func _ready() -> void:
	if not bike_controller:
		bike_controller = get_parent()

	# 1. Setup Bell Player with physical modal chime
	bell_player = AudioStreamPlayer3D.new()
	bell_player.name = "BellPlayer"
	bell_player.stream = _create_bell_audio_stream()
	bell_player.volume_db = -2.0
	bell_player.bus = "SFX"
	add_child(bell_player)

	# 2. Setup Dual Alternating Freewheel Ratchet Players (Voice ping-pong)
	freewheel_player_a = AudioStreamPlayer3D.new()
	freewheel_player_a.name = "FreewheelPlayerA"
	freewheel_player_a.stream = _create_click_audio_stream()
	freewheel_player_a.volume_db = -5.0
	freewheel_player_a.bus = "SFX"
	add_child(freewheel_player_a)

	freewheel_player_b = AudioStreamPlayer3D.new()
	freewheel_player_b.name = "FreewheelPlayerB"
	freewheel_player_b.stream = _create_click_audio_stream()
	freewheel_player_b.volume_db = -5.0
	freewheel_player_b.bus = "SFX"
	add_child(freewheel_player_b)

	# Backward compatibility pointer for test suite
	freewheel_player = freewheel_player_a

	# 3. Setup Wind Rush Player (Procedural 4.5s pink noise loop, fixed pitch)
	wind_player = AudioStreamPlayer3D.new()
	wind_player.name = "WindPlayer"
	wind_player.stream = _create_wind_audio_stream()
	wind_player.volume_db = -80.0
	wind_player.bus = "Ambient"
	wind_player.autoplay = true
	add_child(wind_player)

	# 4. Setup Gravel / Road Tire Noise Player (Procedural 4.0s multi-layer loop)
	gravel_player = AudioStreamPlayer3D.new()
	gravel_player.name = "GravelPlayer"
	gravel_player.stream = _create_gravel_audio_stream()
	gravel_player.volume_db = -80.0
	gravel_player.bus = "Ambient"
	gravel_player.autoplay = true
	add_child(gravel_player)

	# 5. Setup Scrub & Skid Player (Event overlay for lateral slide and brake lockup)
	skid_player = AudioStreamPlayer3D.new()
	skid_player.name = "SkidPlayer"
	skid_player.stream = _create_skid_audio_stream()
	skid_player.volume_db = -80.0
	skid_player.bus = "SFX"
	skid_player.autoplay = true
	add_child(skid_player)

	if bike_controller and bike_controller.has_signal("bell_rung"):
		if not bike_controller.is_connected("bell_rung", _on_bell_rung):
			bike_controller.connect("bell_rung", _on_bell_rung)

func _process(delta: float) -> void:
	if not bike_controller:
		bike_controller = get_parent()
	if not bike_controller:
		return

	var is_coasting: bool = bike_controller.get("is_coasting") if "is_coasting" in bike_controller else false
	var is_pedaling: bool = bike_controller.get("is_pedaling") if "is_pedaling" in bike_controller else false
	var is_braking: bool = bike_controller.get("is_braking") if "is_braking" in bike_controller else false
	var current_speed: float = bike_controller.get("current_speed") if "current_speed" in bike_controller else 0.0
	var is_on_grass: bool = bike_controller.get("is_on_grass") if "is_on_grass" in bike_controller else false
	var current_surf: int = bike_controller.get("current_surface") if "current_surface" in bike_controller else 0
	var terrain_rough: float = bike_controller.get("terrain_roughness") if "terrain_roughness" in bike_controller else 0.16
	var corner_scrub: float = bike_controller.get("cornering_scrub_accel") if "cornering_scrub_accel" in bike_controller else 0.0
	var visual_skid: float = bike_controller.get("visual_skid_factor") if "visual_skid_factor" in bike_controller else 0.0

	# -------------------------------------------------------------
	# 1. Freewheel Ratchet (Dual alternating voices, continuously speed-scaled)
	# -------------------------------------------------------------
	if is_coasting and not is_pedaling and not is_braking and current_speed > 0.6:
		# Effective step distance between ratchet tooth clicks: 0.22m
		# Minimum interval: 0.018s (55.5 clicks/s at 44 km/h)
		# Maximum interval: 0.180s (5.5 clicks/s at low coast)
		var click_interval: float = clampf(0.22 / maxf(current_speed, 0.5), 0.018, 0.180)
		freewheel_timer += delta
		if freewheel_timer >= click_interval:
			freewheel_timer = 0.0
			var active_player: AudioStreamPlayer3D = freewheel_player_a if freewheel_use_a else freewheel_player_b
			freewheel_use_a = not freewheel_use_a
			active_player.pitch_scale = randf_range(0.97, 1.03)
			active_player.play()
	else:
		freewheel_timer = 0.0

	# -------------------------------------------------------------
	# 2. Aerodynamic Wind Rush (Pink noise airflow without pitch bend)
	# -------------------------------------------------------------
	if wind_player:
		var target_wind_vol: float = -80.0
		var target_wind_pitch: float = 1.0 # Fixed pitch: speed increases pressure, not tone
		if current_speed > 5.0: # ~18 km/h onset threshold
			var wind_ratio: float = clampf((current_speed - 5.0) / 6.2, 0.0, 1.0)
			var curved_ratio: float = pow(wind_ratio, 1.25)
			target_wind_vol = lerpf(-46.0, -26.0, curved_ratio)
			target_wind_pitch = 1.0
		wind_player.volume_db = lerpf(wind_player.volume_db, target_wind_vol, 4.0 * delta)
		wind_player.pitch_scale = lerpf(wind_player.pitch_scale, target_wind_pitch, 4.0 * delta)

	# -------------------------------------------------------------
	# 3. Dynamic Tire Noise (Bounded contributions & comfortable mix ceiling)
	# -------------------------------------------------------------
	if gravel_player:
		var target_gravel_vol: float = -80.0
		var target_gravel_pitch: float = 1.0
		if current_speed > 0.2:
			var speed_ratio: float = clampf(current_speed / 8.0, 0.0, 1.0)
			var base_vol: float = lerpf(-38.0, -26.0, speed_ratio)

			# Strictly bounded additive contributions
			var rough_add: float = clampf(4.0 * terrain_rough, 0.0, 3.0)
			var scrub_add: float = clampf(5.0 * corner_scrub, 0.0, 3.5)
			var skid_add: float = clampf(4.0 * visual_skid, 0.0, 4.0)

			# Combined tire volume capped at safe ceiling (-20.0 dB)
			target_gravel_vol = minf(base_vol + rough_add + scrub_add + skid_add, -20.0)

			if is_on_grass or current_surf == 1:
				target_gravel_vol -= 3.0
				target_gravel_pitch = 0.65 # Deep muffled turf rumble
			else:
				target_gravel_pitch = lerpf(0.96, 1.06, speed_ratio)

		gravel_player.volume_db = lerpf(gravel_player.volume_db, target_gravel_vol, 6.0 * delta)
		gravel_player.pitch_scale = lerpf(gravel_player.pitch_scale, target_gravel_pitch, 6.0 * delta)

	# -------------------------------------------------------------
	# 4. Skid & Lateral Scrub Friction Overlay
	# -------------------------------------------------------------
	if skid_player:
		var target_skid_vol: float = -80.0
		var skid_intensity: float = maxf(visual_skid, clampf(corner_scrub / 0.8, 0.0, 1.0))
		if skid_intensity > 0.06 and current_speed > 1.0:
			target_skid_vol = lerpf(-38.0, -18.0, skid_intensity)
		skid_player.volume_db = lerpf(skid_player.volume_db, target_skid_vol, 12.0 * delta)

func _on_bell_rung() -> void:
	if bell_player:
		bell_player.pitch_scale = randf_range(0.99, 1.01)
		bell_player.play()

## Synthesize a physical modal brass bell chime (hammer strike + harmonic beat overtones)
func _create_bell_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.8
	var total_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Fast initial hammer strike transient
		var transient: float = sin(2.0 * PI * 5200.0 * t) * exp(-1400.0 * t) * 0.4
		# Primary dome resonance (2180 Hz)
		var mode1: float = sin(2.0 * PI * 2180.0 * t) * exp(-3.2 * t) * 0.45
		# Shimmering harmonic beat overtone pair (2840 Hz and 2843.5 Hz -> 3.5 Hz beat)
		var mode2_beat: float = sin(2.0 * PI * 2840.0 * t) * cos(2.0 * PI * 1.75 * t) * exp(-3.8 * t) * 0.35
		# High overtone (4360 Hz)
		var mode3: float = sin(2.0 * PI * 4360.0 * t) * exp(-6.0 * t) * 0.12
		# Warm body lower mode (1090 Hz)
		var mode4: float = sin(2.0 * PI * 1090.0 * t) * exp(-4.5 * t) * 0.15

		var sample: float = (transient + mode1 + mode2_beat + mode3 + mode4) * 0.85
		var s16: int = int(clampf(sample, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	return stream

## Synthesize a 25ms multi-harmonic pawl click (metallic snap + aluminum hub shell resonance)
func _create_click_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.025 # Strictly 25ms transient (safe for dual-voice ping-pong)
	var total_samples: int = int(sample_rate * duration)
	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(sample_rate)
		# Sharp metallic pawl snap (3600 Hz, fast decay 6ms)
		var snap: float = sin(2.0 * PI * 3600.0 * t) * exp(-450.0 * t) * 0.55
		# Hub shell cavity body resonance (980 Hz and 1420 Hz, decay 16ms)
		var hub_body: float = (0.3 * sin(2.0 * PI * 980.0 * t) + 0.2 * sin(2.0 * PI * 1420.0 * t)) * exp(-180.0 * t)
		# Pawl spring friction micro-noise
		var friction: float = ((float((i * 1103515245 + 12345) & 0x7FFFFFFF) / 1073741824.0) - 1.0) * exp(-350.0 * t) * 0.15

		var sample: float = snap + hub_body + friction
		var s16: int = int(clampf(sample, -1.0, 1.0) * 26000.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	return stream

## Synthesize a 4.5s seamless pink-noise aerodynamic airflow stream
func _create_wind_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 4.5 # Expanded 4.5s buffer to eliminate loop earworm
	var total_samples: int = int(sample_rate * duration)
	var fade_len: int = 512
	var gen_samples: int = total_samples + fade_len
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(gen_samples)

	# 3-pole pinking filter on white noise (-3 dB/octave soothing aerodynamic rush)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	for _w in range(300):
		var w: float = randf_range(-1.0, 1.0)
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913

	for i in range(gen_samples):
		var w: float = randf_range(-1.0, 1.0)
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		raw_samples[i] = (b0 + b1 + b2 + w * 0.1848) * 0.11

	# Smooth crossfade boundary
	for i in range(fade_len):
		var t: float = float(i) / float(fade_len)
		var s: float = t * t * (3.0 - 2.0 * t)
		raw_samples[i] = lerpf(raw_samples[total_samples + i], raw_samples[i], s)

	raw_samples.resize(total_samples)

	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)
	for i in range(total_samples):
		var s16: int = int(clampf(raw_samples[i] * 1.8, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream

## Synthesize a 4.0s textured multi-layer road and gravel surface noise stream
func _create_gravel_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 4.0 # Expanded 4.0s buffer to eliminate loop fatigue
	var total_samples: int = int(sample_rate * duration)
	var fade_len: int = 512
	var gen_samples: int = total_samples + fade_len
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(gen_samples)

	var low_state: float = 0.0
	var band_state: float = 0.0
	for _w in range(300):
		var white: float = randf_range(-1.0, 1.0)
		low_state += 0.22 * band_state
		var high: float = white - low_state - 0.55 * band_state
		band_state += 0.22 * high

	for i in range(gen_samples):
		var white: float = randf_range(-1.0, 1.0)
		low_state += 0.22 * band_state
		var high: float = white - low_state - 0.55 * band_state
		band_state += 0.22 * high

		var grit: float = 0.0
		if randf() < 0.012 and i > 64 and i < (total_samples - 64):
			grit = randf_range(-0.35, 0.35)

		# Combined casing low rumble + bandpassed gravel grain
		raw_samples[i] = band_state * 0.65 + low_state * 0.25 + grit

	# Smooth crossfade boundary
	for i in range(fade_len):
		var t: float = float(i) / float(fade_len)
		var s: float = t * t * (3.0 - 2.0 * t)
		raw_samples[i] = lerpf(raw_samples[total_samples + i], raw_samples[i], s)

	raw_samples.resize(total_samples)

	# Seam bridge continuity
	var seam_bridge_len: int = 32
	for j in range(seam_bridge_len):
		var w: float = float(j + 1) / float(seam_bridge_len)
		var idx: int = total_samples - seam_bridge_len + j
		raw_samples[idx] = lerpf(raw_samples[idx], raw_samples[0], w * 0.85)

	var pcm_data := PackedByteArray()
	pcm_data.resize(total_samples * 2)
	for i in range(total_samples):
		var s16: int = int(clampf(raw_samples[i] * 2.0, -1.0, 1.0) * 32767.0)
		pcm_data.encode_s16(i * 2, s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = pcm_data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	return stream

## Synthesize a 2.0s looping skid/scrub shear friction stream
func _create_skid_audio_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 2.0
	var total_samples: int = int(sample_rate * duration)
	var fade_len: int = 512
	var gen_samples: int = total_samples + fade_len
	var raw_samples := PackedFloat32Array()
	raw_samples.resize(gen_samples)

	var bp_low: float = 0.0
	var bp_band: float = 0.0
	for _w in range(200):
		var white: float = randf_range(-1.0, 1.0)
		bp_low += 0.35 * bp_band
		var high: float = white - bp_low - 0.45 * bp_band
		bp_band += 0.35 * high

	for i in range(gen_samples):
		var white: float = randf_range(-1.0, 1.0)
		bp_low += 0.35 * bp_band
		var high: float = white - bp_low - 0.45 * bp_band
		bp_band += 0.35 * high
		raw_samples[i] = bp_band * 0.8

	for i in range(fade_len):
		var t: float = float(i) / float(fade_len)
		var s: float = t * t * (3.0 - 2.0 * t)
		raw_samples[i] = lerpf(raw_samples[total_samples + i], raw_samples[i], s)

	raw_samples.resize(total_samples)

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
