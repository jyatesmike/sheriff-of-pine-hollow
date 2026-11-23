# Audio: plays sound effects and music from the files listed in
# scripts/config/sound_files.gd (or dropped into audio/sfx and audio/music),
# falling back to the built-in versions in audio/builtin/. Also speaks the
# characters' lines with text-to-speech. Buses: Music, SFX, Voice.
extends Node

const BUSES := ["Music", "SFX", "Voice"]
const EXTENSIONS := [".ogg", ".wav", ".mp3"]
const SFX_VOICES := 10

var _streams := {}        # base path -> AudioStream or null
var _sfx: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _music_track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = linear_to_db(SoundFiles.MUSIC_VOLUME)
	_music.finished.connect(func(): _music.play())      # loop any format
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	apply_volumes()


func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	_set_bus("Music", s.music_volume)
	_set_bus("SFX", s.sfx_volume)
	_set_bus("Voice", s.voice_volume)


func _set_bus(bus: String, linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(linear, 0.0001)))


## Play a sound effect by name (see SoundFiles.SFX). pitch 1.0 = normal.
func sfx(name: String, pitch := 1.0) -> void:
	var stream := _find(SoundFiles.SFX.get(name, ""), "res://audio/builtin/sfx/" + name)
	if stream == null:
		return
	var p := _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.5)
	p.play()


## Switch music track (see SoundFiles.MUSIC). If the track has no file:
## stop the music, or keep the current one when keep_if_missing is true.
func music(track: String, keep_if_missing := false) -> void:
	if track == _music_track:
		return
	var stream := _find(SoundFiles.MUSIC.get(track, ""), "res://audio/builtin/music/" + track)
	if stream == null:
		if not keep_if_missing:
			_music.stop()
			_music_track = ""
		return
	_music_track = track
	_music.stream = _looping(stream)
	_music.play()


## Speak a line in a character's voice. Never waits: speech runs alongside
## the game, and a new line interrupts the previous one.
## If audio/voices/<who>/<line_id>.mp3 (or .ogg / .wav) exists, that file
## plays; otherwise the computer's text-to-speech reads the line
## (see SoundFiles.VOICES). The full list of line ids is audio/voices/LINES.md.
func say(who: String, text: String, line_id := "") -> void:
	if not SoundFiles.VOICES_ON or not Game.settings.voices_on or text.strip_edges() == "":
		return
	if line_id != "":
		var clip := _load_first("%s/%s/%s" % [SoundFiles.VOICE_FOLDER, who, line_id])
		if clip:
			stop_speaking()
			_voice.stream = clip
			_voice.play()
			return
	if not SoundFiles.USE_TEXT_TO_SPEECH or not _tts_ready():
		return
	_voice.stop()
	var v: Dictionary = SoundFiles.VOICES.get(who, {"pitch": 1.0, "rate": 1.0})
	var vol := int(Game.settings.voice_volume * 100.0)
	var clean := text.replace("{", "").replace("}", "")
	DisplayServer.tts_speak(clean, _voice_id, vol, v.pitch, v.rate, 0, true)


var _voice_id := ""
var _tts_checked := false


func _tts_ready() -> bool:
	if not _tts_checked:
		_tts_checked = true
		if DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("audio/general/text_to_speech", false):
			var voices := DisplayServer.tts_get_voices_for_language("en")
			if not voices.is_empty():
				_voice_id = voices[0]
	return _voice_id != ""


func stop_speaking() -> void:
	if _voice_id != "":
		DisplayServer.tts_stop()


var _loops := {}


## Start/stop a looping sound effect (siren, engine...). Call every frame
## with a new pitch to change it smoothly.
func loop(name: String, on: bool, pitch := 1.0, volume := 1.0) -> void:
	var p: AudioStreamPlayer = _loops.get(name)
	if not on:
		if p:
			p.stop()
		return
	if p == null:
		var stream := _find(SoundFiles.SFX.get(name, ""), "res://audio/builtin/sfx/" + name)
		if stream == null:
			return
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = _looping(stream)
		add_child(p)
		_loops[name] = p
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.volume_db = linear_to_db(maxf(volume, 0.001))
	if not p.playing:
		p.play()


func stop_loops() -> void:
	for n in _loops:
		_loops[n].stop()


func has_sound(name: String) -> bool:
	return _find(SoundFiles.SFX.get(name, ""), "res://audio/builtin/sfx/" + name) != null


## The player's file if there is one, else the built-in fallback.
func _find(base: String, builtin: String) -> AudioStream:
	var s := _load_first(base)
	return s if s != null else _load_first(builtin)


func _load_first(base: String) -> AudioStream:
	if base == "":
		return null
	if _streams.has(base):
		return _streams[base]
	var found: AudioStream = null
	for ext in ([""] if base.get_extension() != "" else EXTENSIONS):
		if ResourceLoader.exists(base + ext):
			found = load(base + ext) as AudioStream
			break
	_streams[base] = found
	return found


## Make a music stream loop seamlessly (falls back to the `finished` restart).
func _looping(stream: AudioStream) -> AudioStream:
	var s := stream.duplicate()
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	elif s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.loop = true
	return s
