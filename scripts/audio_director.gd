class_name HorrorAudio
extends Node
## Original procedural sound for a dead god: bowed subharmonics, damaged tape,
## distant bronze, breath through a broken choir. No external assets are used.
## Public volume is linear (0..1); intensity is also 0..1.

const SAMPLE_RATE: int = 22050
const TAU_F: float = TAU
const CUE_POOL_SIZE: int = 8

var _ambience: AudioStreamPlayer
var _tension: AudioStreamPlayer
var _cue_players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next_voice: int = 0
var _started: bool = false
var _paused: bool = false
var _master_volume: float = 0.72
var _target_intensity: float = 0.0
var _intensity: float = 0.0
var _elapsed: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 7101998
	_ensure_players()


func _ensure_players() -> void:
	if is_instance_valid(_ambience):
		return
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "DeadAir"
	add_child(_ambience)
	_tension = AudioStreamPlayer.new()
	_tension.name = "AbsentChoir"
	add_child(_tension)
	for index in range(CUE_POOL_SIZE):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "TapeCue%d" % index
		voice.set_meta("cue_db", -9.0)
		add_child(voice)
		_cue_players.append(voice)


func start_ambience() -> void:
	if _started:
		return
	_ensure_players()
	_started = true
	_ambience.stream = _make_ambient(false)
	_tension.stream = _make_ambient(true)
	_update_mix()
	_ambience.play()
	_tension.play()


func set_intensity(value: float) -> void:
	_target_intensity = clampf(value, 0.0, 1.0)


func set_paused(value: bool) -> void:
	_paused = value
	_update_mix()


func set_volume(value: float) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_update_mix()
	_update_cue_mix()


func _process(delta: float) -> void:
	_elapsed += delta
	_intensity = move_toward(_intensity, _target_intensity, delta * 0.32)
	_update_cue_mix()
	if not _started:
		return
	_update_mix()
	_ambience.pitch_scale = 0.997 + sin(_elapsed * 0.41) * 0.003
	_tension.pitch_scale = 0.975 + _intensity * 0.025 + sin(_elapsed * 0.27) * 0.005


func _master_db() -> float:
	if _master_volume <= 0.0001:
		return -80.0
	return linear_to_db(_master_volume)


func _update_mix() -> void:
	if not is_instance_valid(_ambience):
		return
	var pause_db: float = -13.0 if _paused else 0.0
	_ambience.volume_db = -10.0 + _intensity * 1.5 + _master_db() + pause_db
	_tension.volume_db = lerpf(-36.0, -12.0, _intensity) + _master_db() + pause_db


func _update_cue_mix() -> void:
	# Reserve peak headroom for both drones even if every cue is triggered at
	# once. This controls only this node's players, never a project's buses.
	var active_count: int = 0
	for voice in _cue_players:
		if voice.playing:
			active_count += 1
	var ceiling_db: float = linear_to_db(0.42 / float(maxi(active_count, 1)))
	for voice in _cue_players:
		voice.volume_db = minf(float(voice.get_meta("cue_db", -9.0)), ceiling_db) + _master_db()


func play_cue(kind: String) -> void:
	_ensure_players()
	var cue_name: String = kind
	if cue_name not in ["pickup", "bell", "whisper", "scare", "ritual", "win", "click", "battery", "footstep"]:
		cue_name = "click"
	if not _cache.has(cue_name):
		_cache[cue_name] = _make_cue(cue_name)
	var voice: AudioStreamPlayer = _take_voice()
	voice.stop()
	voice.stream = _cache[cue_name]
	voice.pitch_scale = _rng.randf_range(0.97, 1.025)
	var gain: float = -9.0
	match cue_name:
		"footstep":
			gain = -17.0
		"click":
			gain = -14.0
		"whisper":
			gain = -10.0
		"scare":
			gain = -7.5
		"bell", "ritual", "win":
			gain = -8.0
	voice.set_meta("cue_db", gain)
	voice.volume_db = gain + _master_db()
	voice.play()
	_update_cue_mix()


func footstep(sprinting: bool = false) -> void:
	if _paused:
		return
	play_cue("footstep")
	# The most recently selected voice is kept in _next_voice - 1.
	var voice: AudioStreamPlayer = _cue_players[posmod(_next_voice - 1, CUE_POOL_SIZE)]
	voice.pitch_scale = _rng.randf_range(0.86, 1.15) * (1.12 if sprinting else 1.0)
	var gain: float = -14.0 if sprinting else -18.0
	voice.set_meta("cue_db", gain)
	_update_cue_mix()


func _take_voice() -> AudioStreamPlayer:
	for offset in range(CUE_POOL_SIZE):
		var index: int = (_next_voice + offset) % CUE_POOL_SIZE
		if not _cue_players[index].playing:
			_next_voice = (index + 1) % CUE_POOL_SIZE
			return _cue_players[index]
	var index: int = _next_voice
	_next_voice = (_next_voice + 1) % CUE_POOL_SIZE
	return _cue_players[index]


func _wav(bytes: PackedByteArray, looping: bool = false) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = bytes.size() / 2
	return stream


func _write_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	bytes.encode_s16(index * 2, int(clampf(value, -0.86, 0.86) * 32767.0))


func _make_ambient(is_tension: bool) -> AudioStreamWAV:
	# Four seconds per layer, under 180 KB each. Oscillator frequencies complete
	# whole periods; a short edge envelope also hides the random-noise seam.
	var duration: float = 4.0
	var count: int = int(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var low_noise: float = 0.0
	var lower_noise: float = 0.0
	var noise_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	noise_rng.seed = 90417 if is_tension else 28019
	for index in range(count):
		var t: float = float(index) / float(SAMPLE_RATE)
		var white: float = noise_rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, white, 0.026)
		lower_noise = lerpf(lower_noise, white, 0.003)
		var warp: float = 0.021 * sin(TAU_F * 0.25 * t) + 0.003 * sin(TAU_F * 3.0 * t)
		var value: float
		if is_tension:
			# A tritone where a congregation should have been: narrow, breathy
			# harmonic bands suggest a choir without intelligible speech.
			var throat: float = sin(TAU_F * 73.5 * t + warp)
			var mouth: float = sin(TAU_F * 294.0 * t + warp * 3.0) * 0.16
			mouth += sin(TAU_F * 367.5 * t + warp * 4.0) * 0.08
			var dissonance: float = sin(TAU_F * 104.0 * t - warp) * 0.12
			var breath: float = 0.7 + 0.3 * sin(TAU_F * 0.5 * t)
			value = (throat * 0.17 + mouth + dissonance) * breath
			value += (low_noise - lower_noise) * 0.34
		else:
			var organ: float = sin(TAU_F * 32.0 * t + warp) * 0.21
			organ += sin(TAU_F * 48.0 * t - warp) * 0.10
			organ += sin(TAU_F * 63.75 * t + warp) * 0.07
			organ += sin(TAU_F * 96.0 * t + warp * 2.0) * 0.04
			var wind: float = low_noise * (0.32 + 0.10 * sin(TAU_F * 0.25 * t))
			var hiss: float = white * 0.009
			value = organ + wind + lower_noise * 0.3 + hiss
		var edge: float = smoothstep(0.0, 0.035, minf(t, duration - t))
		_write_sample(bytes, index, value * edge)
	return _wav(bytes, true)


func _make_cue(kind: String) -> AudioStreamWAV:
	var duration: float = 1.0
	match kind:
		"footstep": duration = 0.24
		"click": duration = 0.10
		"battery": duration = 0.55
		"pickup": duration = 1.1
		"bell": duration = 2.65
		"whisper": duration = 1.65
		"scare": duration = 1.2
		"ritual": duration = 2.6
		"win": duration = 4.4
	var count: int = int(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var low_noise: float = 0.0
	var high_noise: float = 0.0
	var noise_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	noise_rng.seed = 84117 + kind.hash()
	for index in range(count):
		var t: float = float(index) / float(SAMPLE_RATE)
		var u: float = t / duration
		var white: float = noise_rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, white, 0.075)
		high_noise = lerpf(high_noise, white, 0.55)
		var value: float = 0.0
		match kind:
			"footstep":
				var heel: float = exp(-t * 32.0)
				var grit: float = exp(-t * 19.0) * smoothstep(0.0, 0.008, t)
				value = sin(TAU_F * (77.0 * t - 49.0 * t * t)) * heel * 0.40
				value += low_noise * grit * 0.65
			"click":
				value = (sin(TAU_F * 470.0 * t) * 0.17 + white * 0.14) * exp(-t * 75.0)
			"battery":
				value = sin(TAU_F * (175.0 * t - 100.0 * t * t)) * exp(-t * 8.0) * 0.2
				value += low_noise * exp(-t * 16.0) * 0.4
			"pickup":
				value = _bell_partial(t, 246.94, 2.8) * 0.40
				value += _bell_partial(maxf(t - 0.18, 0.0), 261.63, 4.0) * 0.14 * smoothstep(0.18, 0.20, t)
			"bell":
				value = _bell_partial(t, 110.0, 1.7) * 0.49
				value += low_noise * exp(-t * 35.0) * 0.35
			"whisper":
				var mouth: float = sin(PI * u) * (0.65 + 0.35 * sin(TAU_F * 3.2 * t))
				var band: float = high_noise - low_noise
				value = band * mouth * 0.46
				value += sin(TAU_F * 89.0 * t + 0.25 * sin(TAU_F * 1.7 * t)) * mouth * 0.07
			"scare":
				var hit: float = exp(-t * 6.0)
				var scrape: float = sin(TAU_F * (830.0 * t - 185.0 * t * t))
				value = sin(TAU_F * (53.0 * t - 8.0 * t * t)) * hit * 0.40
				value += scrape * exp(-t * 8.5) * 0.13 + low_noise * hit * 0.70
				value += sin(TAU_F * 77.78 * t) * exp(-t * 3.0) * 0.15
			"ritual":
				var swell: float = pow(sin(PI * u), 1.3)
				var warp: float = 0.045 * sin(TAU_F * 2.5 * t)
				value = (sin(TAU_F * 55.0 * t + warp) + sin(TAU_F * 77.78 * t - warp) * 0.55) * swell * 0.24
				value += (high_noise - low_noise) * swell * 0.13
				value += _bell_partial(t, 164.81, 1.5) * 0.16
			"win":
				# The ending leaves an open, damaged fifth instead of a victory fanfare.
				var tail: float = smoothstep(0.0, 0.28, t) * exp(-t * 0.62)
				value = (sin(TAU_F * 65.41 * t) + sin(TAU_F * 98.0 * t) * 0.6) * tail * 0.25
				value += _bell_partial(t, 196.0, 1.05) * 0.28
				value += low_noise * tail * 0.09
		var edge: float = smoothstep(0.0, 0.004, t) * smoothstep(0.0, 0.025, duration - t)
		_write_sample(bytes, index, value * edge)
	return _wav(bytes)


func _bell_partial(t: float, frequency: float, decay: float) -> float:
	var value: float = sin(TAU_F * frequency * t) * exp(-t * decay)
	value += sin(TAU_F * frequency * 2.756 * t) * exp(-t * decay * 1.7) * 0.29
	value += sin(TAU_F * frequency * 5.404 * t) * exp(-t * decay * 2.7) * 0.12
	return value
