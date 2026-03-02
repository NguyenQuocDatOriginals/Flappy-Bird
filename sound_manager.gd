extends Node

# Procedurally generated sound effects for Flappy Bird 2.5D
# All sounds are created from raw PCM data — no external audio files needed.

const MIX_RATE: int = 22050

var _flap_player: AudioStreamPlayer = null
var _score_player: AudioStreamPlayer = null
var _hit_player: AudioStreamPlayer = null
var _die_player: AudioStreamPlayer = null
var _bgm_player: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flap_player = _make_player(_gen_flap(), 0.0)
	_score_player = _make_player(_gen_score(), 0.0)
	_hit_player = _make_player(_gen_hit(), -2.0)
	_die_player = _make_player(_gen_die(), -2.0)
	_bgm_player = _make_player(_gen_bgm(), -14.0)


func play_flap() -> void:
	_flap_player.play()


func play_score() -> void:
	_score_player.play()


func play_hit() -> void:
	_hit_player.play()


func play_die() -> void:
	_die_player.play()


func play_bgm() -> void:
	_bgm_player.play()


func stop_bgm() -> void:
	_bgm_player.stop()


func set_bgm_paused(p: bool) -> void:
	_bgm_player.stream_paused = p


# ------------------------------------------------------------------
#  Internal helpers
# ------------------------------------------------------------------

func _make_player(stream: AudioStreamWAV, vol_db: float) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	return p


func _write_sample(data: PackedByteArray, idx: int, value: float) -> void:
	var s: int = clampi(int(value * 32767.0), -32768, 32767)
	var u: int = s & 0xFFFF
	data[idx] = u & 0xFF
	data[idx + 1] = (u >> 8) & 0xFF


func _make_wav(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(data.size() / 2.0)
	wav.data = data
	return wav


# ------------------------------------------------------------------
#  Sound generators
# ------------------------------------------------------------------

func _gen_flap() -> AudioStreamWAV:
	# Quick ascending chirp
	var dur: float = 0.08
	var n: int = int(dur * MIX_RATE)
	var d: PackedByteArray = PackedByteArray()
	d.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / MIX_RATE
		var p: float = float(i) / n
		var freq: float = 500.0 + p * 800.0
		var env: float = (1.0 - p) * (1.0 - p)
		var v: float = sin(TAU * freq * t) * env * 0.45
		_write_sample(d, i * 2, v)
	return _make_wav(d)


func _gen_score() -> AudioStreamWAV:
	# Two-tone ding (pleasant)
	var dur: float = 0.25
	var n: int = int(dur * MIX_RATE)
	var d: PackedByteArray = PackedByteArray()
	d.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / MIX_RATE
		var p: float = float(i) / n
		var env: float = (1.0 - p) * (1.0 - p)
		var f1: float = 880.0
		var f2: float = 1320.0
		var blend: float = 0.0 if t < 0.08 else 1.0
		var freq: float = f1 * (1.0 - blend) + f2 * blend
		var v: float = sin(TAU * freq * t) * env * 0.35
		v += sin(TAU * freq * 2.0 * t) * env * 0.1
		_write_sample(d, i * 2, v)
	return _make_wav(d)


func _gen_hit() -> AudioStreamWAV:
	# Short impact noise
	var dur: float = 0.12
	var n: int = int(dur * MIX_RATE)
	var d: PackedByteArray = PackedByteArray()
	d.resize(n * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in range(n):
		var p: float = float(i) / n
		var env: float = (1.0 - p) * (1.0 - p) * (1.0 - p)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var t: float = float(i) / MIX_RATE
		var tone: float = sin(TAU * 150.0 * t)
		var v: float = (noise * 0.5 + tone * 0.5) * env * 0.5
		_write_sample(d, i * 2, v)
	return _make_wav(d)


func _gen_die() -> AudioStreamWAV:
	# Sad descending tone
	var dur: float = 0.6
	var n: int = int(dur * MIX_RATE)
	var d: PackedByteArray = PackedByteArray()
	d.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / MIX_RATE
		var p: float = float(i) / n
		var freq: float = 440.0 - p * 300.0
		var env: float = (1.0 - p)
		var v: float = sin(TAU * freq * t) * env * 0.3
		v += sin(TAU * freq * 0.5 * t) * env * 0.15
		_write_sample(d, i * 2, v)
	return _make_wav(d)


func _gen_bgm() -> AudioStreamWAV:
	# Cheerful looping pentatonic melody
	var notes: Array = [
		523.25, 587.33, 659.25, 783.99, 880.00,
		783.99, 659.25, 587.33, 523.25, 440.00,
		523.25, 659.25, 783.99, 880.00, 783.99,
		659.25, 587.33, 523.25, 440.00, 523.25,
	]
	var note_dur: float = 0.22
	var total: float = note_dur * notes.size()
	var n: int = int(total * MIX_RATE)
	var d: PackedByteArray = PackedByteArray()
	d.resize(n * 2)
	for i: int in range(n):
		var t: float = float(i) / MIX_RATE
		var ni: int = int(t / note_dur) % notes.size()
		var nt: float = fmod(t, note_dur)
		var freq: float = notes[ni]
		var attack: float = minf(nt / 0.01, 1.0)
		var release: float = 1.0 - (nt / note_dur) * 0.5
		var env: float = attack * release
		var v: float = sin(TAU * freq * t) * env * 0.08
		v += sin(TAU * freq * 2.0 * t) * env * 0.03
		v += sin(TAU * freq * 0.5 * t) * env * 0.04
		_write_sample(d, i * 2, v)
	return _make_wav(d, true)
