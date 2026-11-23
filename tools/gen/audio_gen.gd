# Built-in music and sound effects, synthesised sample by sample and saved as
# WAV files in audio/builtin/. The game uses these whenever you haven't
# dropped in your own file (see scripts/config/sound_files.gd).
#
# Music: the original "front porch" whistling tune from the browser version
# (8 bars in G), arranged differently for each area.
extends RefCounted

const SR := 22050

# The tune: [midi note, beats]; 0 = rest. 32 beats = one loop.
const MEL := [[67,1],[71,.5],[74,.5],[74,1],[76,.5],[74,.5], [72,1],[71,1],[69,2],
	[66,1],[69,.5],[72,.5],[72,1],[74,.5],[72,.5], [71,1],[69,1],[67,2],
	[74,1],[76,1],[79,1.5],[76,.5], [74,1],[72,.5],[71,.5],[69,2],
	[67,.5],[69,.5],[71,1],[72,1],[69,1], [67,3],[0,1]]
# Per bar (repeats every 4 bars): bass root + fifth, and a strum chord.
const BASS := [[43, 50], [48, 55], [50, 57], [43, 50]]
const CHORD := [[55, 59, 62], [55, 60, 64], [54, 57, 62], [55, 59, 62]]
const LOOP_BEATS := 32

# Arrangements: tempo, key shift, swing, and which instruments play.
const STYLES := {
	"title":           {"bpm": 126, "shift": 0,  "lead": "whistle",   "bass": "boomchick", "drums": "hats",  "extra": "",       "swing": 0.0},
	"main_street":     {"bpm": 126, "shift": 0,  "lead": "whistle",   "bass": "boomchick", "drums": "hats",  "extra": "strum",  "swing": 0.0},
	"chicken_run":     {"bpm": 138, "shift": 2,  "lead": "whistle",   "bass": "boomchick", "drums": "hats",  "extra": "banjo",  "swing": 0.0},
	"rock_creek":      {"bpm": 116, "shift": -2, "lead": "harmonica", "bass": "walking",   "drums": "brush", "extra": "",       "swing": 0.15},
	"gone_fishin":     {"bpm": 100, "shift": 0,  "lead": "whistle",   "bass": "lazy",      "drums": "",      "extra": "strum",  "swing": 0.33},
	"earls_big_break": {"bpm": 92,  "shift": -5, "lead": "clarinet",  "bass": "walking",   "drums": "brush", "extra": "",       "swing": 0.25},
	"chase":           {"bpm": 176, "shift": 2,  "lead": "fiddle",    "bass": "eighths",   "drums": "drive", "extra": "banjo",  "swing": 0.0},
	"showdown":        {"bpm": 168, "shift": 0,  "lead": "fiddle",    "bass": "eighths",   "drums": "drive", "extra": "banjo",  "swing": 0.0},
	"county_fair":     {"bpm": 148, "shift": 5,  "lead": "whistle",   "bass": "boomchick", "drums": "hats",  "extra": "banjo",  "swing": 0.12},
	"last_train":      {"bpm": 160, "shift": -3, "lead": "harmonica", "bass": "eighths",   "drums": "drive", "extra": "strum",  "swing": 0.0},
}


static func run() -> void:
	var t0 := Time.get_ticks_msec()
	for d in ["res://audio/builtin/music", "res://audio/builtin/sfx"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	for name in STYLES:
		_save(render_music(STYLES[name]), "res://audio/builtin/music/%s.wav" % name)
	var fx := sfx_all()
	for name in fx:
		_save(fx[name], "res://audio/builtin/sfx/%s.wav" % name)
	_save(_siren(), "res://audio/builtin/sfx/siren.wav")
	_save(_engine(), "res://audio/builtin/sfx/engine.wav")
	print("Built-in audio generated in %d ms" % (Time.get_ticks_msec() - t0))


# =============================================================================
#  Music
# =============================================================================
static func render_music(st: Dictionary) -> PackedFloat32Array:
	var spb: float = 60.0 / st.bpm
	var n := int(LOOP_BEATS * spb * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var shift: int = st.shift
	var swing: float = st.swing
	# lead
	var beat := 0.0
	for e in MEL:
		var dur: float = e[1]
		if e[0] > 0:
			var t := _swung(beat, swing) * spb
			var d := (_swung(beat + dur, swing) - _swung(beat, swing)) * spb
			_lead(buf, st.lead, t, d, _hz(e[0] + shift))
		beat += dur
	# bass, chords, drums, per beat
	for bar in 8:
		var bass: Array = BASS[bar % 4]
		var chord: Array = CHORD[bar % 4]
		for b in 4:
			var bt := bar * 4 + b
			var t := bt * spb
			match st.bass:
				"boomchick":
					if b % 2 == 0:
						_bass(buf, t, spb * 0.9, _hz(bass[0 if b == 0 else 1] + shift), 0.30)
				"walking":
					var steps := [0, 4, 7, 9]
					_bass(buf, t, spb * 0.8, _hz(bass[0] + steps[b] + shift), 0.28)
				"lazy":
					if b == 0 or b == 2:
						_bass(buf, t, spb * 1.6, _hz(bass[0 if b == 0 else 1] + shift), 0.26)
				"eighths":
					for k in 2:
						_bass(buf, t + k * spb * 0.5, spb * 0.45, _hz(bass[0] + shift + (12 if k == 1 else 0)), 0.24)
			match st.drums:
				"hats":
					if b % 2 == 1:
						_hat(buf, t, 0.10)
				"brush":
					_brush(buf, _swung(bt + 0.5, swing) * spb, 0.05)
					if b % 2 == 1:
						_brush(buf, t, 0.08)
				"drive":
					if b % 2 == 0:
						_kick(buf, t, 0.45)
					else:
						_snare(buf, t, 0.22)
					_hat(buf, t + spb * 0.5, 0.07)
			match st.extra:
				"strum":
					if b == 1 or b == 3:
						for k in chord.size():
							_pluck(buf, t + k * 0.012, spb * 0.9, _hz(chord[k] + shift), 0.08, 0.994)
				"banjo":
					for k in 2:
						var note: int = chord[(b * 2 + k) % 3] + 12
						_pluck(buf, t + k * spb * 0.5, spb * 0.5, _hz(note + shift), 0.07, 0.985)
	return _master(buf)


static func _swung(beat: float, swing: float) -> float:
	# push every off-beat eighth later by `swing` of an eighth
	var whole := floorf(beat)
	var frac := beat - whole
	if is_equal_approx(frac, 0.5):
		return whole + 0.5 + swing * 0.5
	return beat


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func _lead(buf: PackedFloat32Array, kind: String, t: float, d: float, f: float) -> void:
	var i0 := int(t * SR)
	var n := int(d * SR)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			idx -= buf.size()          # wrap note tails into the loop start
		var s := float(i) / SR
		var env := clampf(s / 0.03, 0.0, 1.0)
		if s > d * 0.75:
			env *= clampf(1.0 - (s - d * 0.75) / (d * 0.22), 0.0, 1.0)
		var scoop := lerpf(0.96, 1.0, clampf(s / 0.05, 0.0, 1.0))
		var vib := 1.0 + 0.012 * sin(TAU * 5.5 * s) * clampf(s / 0.2, 0.0, 1.0)
		phase += TAU * f * scoop * vib / SR
		var v := 0.0
		match kind:
			"whistle":
				v = sin(phase) * 0.30 + (randf() - 0.5) * 0.01
			"harmonica":
				v = (sin(phase) + 0.5 * sin(2.0 * phase) + 0.3 * sin(3.0 * phase)) * 0.17 * (0.9 + 0.1 * sin(TAU * 7.0 * s))
			"clarinet":
				v = (sin(phase) + 0.35 * sin(3.0 * phase) + 0.15 * sin(5.0 * phase)) * 0.2
			"fiddle":
				for h in range(1, 7):
					v += sin(h * phase) / h
				v *= 0.13
		buf[idx] += v * env


static func _bass(buf: PackedFloat32Array, t: float, d: float, f: float, vol: float) -> void:
	var i0 := int(t * SR)
	for i in int(d * SR):
		var idx := (i0 + i) % buf.size()
		var s := float(i) / SR
		var ph := fmod(f * s, 1.0)
		var tri := 4.0 * absf(ph - 0.5) - 1.0
		var attack := clampf(s / 0.003, 0.0, 1.0)      # 3 ms fade-in: no click
		buf[idx] += tri * vol * attack * exp(-s * 4.0 / d)


static func _pluck(buf: PackedFloat32Array, t: float, d: float, f: float, vol: float, damp: float) -> void:
	# Karplus-Strong plucked string
	var period := maxi(2, int(SR / f))
	var ring := PackedFloat32Array()
	ring.resize(period)
	for k in period:
		ring[k] = randf() * 2.0 - 1.0
	var i0 := int(t * SR)
	var p := 0
	for i in int(d * SR):
		var nxt := (p + 1) % period
		var v := ring[p]
		ring[p] = (ring[p] + ring[nxt]) * 0.5 * damp
		p = nxt
		buf[(i0 + i) % buf.size()] += v * vol


static func _hat(buf: PackedFloat32Array, t: float, vol: float) -> void:
	var i0 := int(t * SR)
	var prev := 0.0
	for i in int(0.06 * SR):
		var w := randf() * 2.0 - 1.0
		var hp := w - prev                     # crude high-pass
		prev = w
		buf[(i0 + i) % buf.size()] += hp * vol * exp(-float(i) / SR * 60.0)


static func _brush(buf: PackedFloat32Array, t: float, vol: float) -> void:
	var i0 := int(t * SR)
	var lp := 0.0
	for i in int(0.14 * SR):
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.35)
		buf[(i0 + i) % buf.size()] += lp * vol * exp(-float(i) / SR * 22.0)


static func _kick(buf: PackedFloat32Array, t: float, vol: float) -> void:
	var i0 := int(t * SR)
	var ph := 0.0
	for i in int(0.15 * SR):
		var s := float(i) / SR
		ph += TAU * lerpf(120.0, 45.0, clampf(s / 0.12, 0.0, 1.0)) / SR
		buf[(i0 + i) % buf.size()] += sin(ph) * vol * exp(-s * 18.0)


static func _snare(buf: PackedFloat32Array, t: float, vol: float) -> void:
	var i0 := int(t * SR)
	for i in int(0.15 * SR):
		var s := float(i) / SR
		var v := (randf() * 2.0 - 1.0) * 0.8 + sin(TAU * 185.0 * s) * 0.5
		buf[(i0 + i) % buf.size()] += v * vol * exp(-s * 25.0)


static func _master(buf: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0001
	for i in buf.size():
		buf[i] = tanh(buf[i] * 1.2)
		peak = maxf(peak, absf(buf[i]))
	var g := 0.8 / peak
	for i in buf.size():
		buf[i] *= g
	return buf


# =============================================================================
#  Sound effects (recipes follow the browser version's beeps)
# =============================================================================
static func sfx_all() -> Dictionary:
	return {
		"jump": _fx([[0.0, 330, 0.15, "square", 300, 0.25]]),
		"land": _fx([[0.0, 120, 0.09, "triangle", -50, 0.4]]),
		"dash": _fx([], [[0.0, 0.18, 1800, 0.35, 900]]),
		"stomp": _fx([[0.0, 500, 0.12, "triangle", -300, 0.4], [0.08, 1100, 0.05, "square", -400, 0.18], [0.14, 1300, 0.07, "square", -500, 0.18]]),
		"pie": _fx([[0.0, 880, 0.07, "square", 0, 0.22], [0.06, 1320, 0.1, "square", 0, 0.22]]),
		"golden_pie": _fx([[0.0, 988, 0.09, "square", 0, 0.18], [0.06, 1319, 0.09, "square", 0, 0.18], [0.12, 1568, 0.09, "square", 0, 0.18], [0.18, 1976, 0.14, "square", 0, 0.18]]),
		"heart": _fx([[0.0, 523, 0.1, "triangle", 0, 0.35], [0.09, 784, 0.1, "triangle", 0, 0.35], [0.18, 1047, 0.18, "triangle", 0, 0.35]]),
		"hurt": _fx([[0.0, 200, 0.35, "sawtooth", -150, 0.3]]),
		"throw": _fx([[0.0, 400, 0.1, "triangle", 500, 0.2]], [[0.0, 0.12, 2200, 0.25, 0]]),
		"pickup": _fx([[0.0, 520, 0.06, "triangle", 200, 0.3]]),
		"bonk": _fx([[0.0, 180, 0.12, "square", -80, 0.35], [0.06, 1400, 0.15, "triangle", -200, 0.2]]),
		"break": _fx([[0.0, 90, 0.2, "triangle", -40, 0.45]], [[0.0, 0.3, 700, 0.6, 0]]),
		"tackle": _fx([[0.0, 140, 0.14, "triangle", -60, 0.5], [0.05, 900, 0.12, "square", -300, 0.15]], [[0.0, 0.1, 1200, 0.4, 0]]),
		"cork_pop": _fx([[0.0, 700, 0.1, "square", -500, 0.3]], [[0.0, 0.08, 2500, 0.7, 0]]),
		"splash": _fx([[0.0, 300, 0.15, "triangle", -200, 0.2]], [[0.0, 0.5, 900, 0.6, -500]]),
		"cluck": _fx([[0.0, 850, 0.04, "square", -250, 0.15], [0.07, 700, 0.06, "square", -300, 0.15]]),
		"honk": _fx([[0.0, 330, 0.12, "sawtooth", -60, 0.2], [0.13, 300, 0.14, "sawtooth", -60, 0.2]]),
		"win": _fx([[0.0, 523, 0.25, "triangle", 0, 0.4], [0.14, 659, 0.25, "triangle", 0, 0.4], [0.28, 784, 0.25, "triangle", 0, 0.4], [0.42, 1047, 0.4, "triangle", 0, 0.4]]),
		"bell": _fx([[0.0, 1320, 0.9, "sine", 0, 0.5], [0.0, 2640, 0.5, "sine", 0, 0.2], [0.0, 3960, 0.3, "sine", 0, 0.1]]),
		"screech": _fx([[0.0, 1800, 0.35, "sawtooth", -300, 0.15]], [[0.0, 0.35, 3000, 0.5, -800]]),
		"crash": _fx([[0.0, 70, 0.35, "triangle", -30, 0.5]], [[0.0, 0.45, 1200, 0.8, -900], [0.05, 0.3, 3500, 0.4, 0]]),
		"lose": _fx([[0.0, 392, 0.3, "triangle", 0, 0.4], [0.18, 330, 0.3, "triangle", 0, 0.4], [0.36, 262, 0.3, "triangle", 0, 0.4], [0.54, 196, 0.5, "triangle", 0, 0.4]]),
	}


## beeps: [start, freq, dur, wave, slide (Hz), vol]; noises: [start, dur, centre Hz, vol, sweep Hz]
static func _fx(beeps: Array, noises := []) -> PackedFloat32Array:
	var length := 0.05
	for b in beeps:
		length = maxf(length, b[0] + b[2])
	for nz in noises:
		length = maxf(length, nz[0] + nz[1])
	var buf := PackedFloat32Array()
	buf.resize(int((length + 0.02) * SR))
	for b in beeps:
		_beep(buf, b[0], b[1], b[2], b[3], b[4], b[5])
	for nz in noises:
		_noise(buf, nz[0], nz[1], nz[2], nz[3], nz[4])
	# level every effect to the same peak so none is buried or blaring
	var peak := 0.0001
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	for i in buf.size():
		buf[i] = clampf(buf[i] * 0.5 / peak, -1.0, 1.0)
	# 5 ms fade-out so nothing ends with a click
	var fade := int(0.005 * SR)
	for k in fade:
		buf[buf.size() - 1 - k] *= float(k) / fade
	return buf


static func _beep(buf: PackedFloat32Array, t: float, f: float, d: float, wave: String, slide: float, vol: float) -> void:
	var i0 := int(t * SR)
	var ph := 0.0
	var n := int(d * SR)
	for i in n:
		if i0 + i >= buf.size():
			break
		var k := float(i) / n
		var fr := f * pow(maxf(40.0, f + slide) / f, k)      # exponential slide
		ph = fmod(ph + fr / SR, 1.0)
		var v := 0.0
		match wave:
			"square": v = 1.0 if ph < 0.5 else -1.0
			"triangle": v = 4.0 * absf(ph - 0.5) - 1.0
			"sawtooth": v = 2.0 * ph - 1.0
			_: v = sin(TAU * ph)
		var env := pow(0.001, k) * clampf(float(i) / (0.004 * SR), 0.0, 1.0)
		buf[i0 + i] += v * vol * env


static func _noise(buf: PackedFloat32Array, t: float, d: float, centre: float, vol: float, sweep: float) -> void:
	# band-passed noise: two one-pole filters around `centre`
	var i0 := int(t * SR)
	var n := int(d * SR)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		if i0 + i >= buf.size():
			break
		var k := float(i) / n
		var c := clampf((centre + sweep * k) / SR * TAU, 0.01, 0.99)
		lp = lerpf(lp, randf() * 2.0 - 1.0, c)
		lp2 = lerpf(lp2, lp, c * 0.5)
		buf[i0 + i] += (lp - lp2) * 2.0 * vol * pow(0.001, k)


## Two-tone police wail, exactly one loop long.
static func _siren() -> PackedFloat32Array:
	var n := int(1.6 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var s := float(i) / n
		var f := 700.0 + 260.0 * (0.5 - 0.5 * cos(s * TAU))
		ph += f / SR
		var v := sin(TAU * ph) * 0.6 + sin(TAU * ph * 2.0) * 0.15 + (1.0 if fmod(ph, 1.0) < 0.5 else -1.0) * 0.06
		buf[i] = v * 0.5
	return buf


## Engine drone (pitch is raised with speed at runtime), seamless loop.
static func _engine() -> PackedFloat32Array:
	var n := int(0.5 * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var f := 60.0                 # 30 cycles in 0.5 s: loops cleanly
	var lp := 0.0
	for i in n:
		var t := float(i) / SR
		var ph := fmod(t * f, 1.0)
		var saw := 2.0 * ph - 1.0
		var chug := 0.7 + 0.3 * sin(TAU * t * 8.0)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.08)
		buf[i] = (saw * 0.5 + sin(TAU * t * f * 0.5) * 0.4 + lp * 0.3) * chug * 0.45
	return buf


# =============================================================================
static func _save(samples: PackedFloat32Array, path: String) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	var err := wav.save_to_wav(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Could not write %s" % path)
