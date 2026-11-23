# =============================================================================
#  SOUND FILES — which file plays for each sound effect and music track.
#
#  Easiest: drop a file named after the sound into the folder shown, e.g.
#  audio/sfx/jump.ogg or audio/music/main_street.mp3. Any of .ogg, .wav or
#  .mp3 works, so leave the extension off below.
#
#  Or point an entry at any file you like inside the project, e.g.
#      "jump": "res://audio/my_sounds/boing",
#
#  A sound with no file of yours plays the built-in version from
#  audio/builtin/ (made by tools/make_audio.gd). Your file always wins.
#  After adding files, open the project in Godot once so it imports them.
# =============================================================================
class_name SoundFiles
extends RefCounted

const SFX := {
	"jump": "res://audio/sfx/jump",
	"land": "res://audio/sfx/land",
	"dash": "res://audio/sfx/dash",
	"stomp": "res://audio/sfx/stomp",          # pitch rises with each combo stomp
	"pie": "res://audio/sfx/pie",
	"golden_pie": "res://audio/sfx/golden_pie",
	"heart": "res://audio/sfx/heart",
	"hurt": "res://audio/sfx/hurt",
	"throw": "res://audio/sfx/throw",
	"pickup": "res://audio/sfx/pickup",
	"bonk": "res://audio/sfx/bonk",
	"break": "res://audio/sfx/break",
	"tackle": "res://audio/sfx/tackle",
	"cork_pop": "res://audio/sfx/cork_pop",
	"splash": "res://audio/sfx/splash",
	"cluck": "res://audio/sfx/cluck",
	"honk": "res://audio/sfx/honk",
	"win": "res://audio/sfx/win",
	"lose": "res://audio/sfx/lose",
	"bell": "res://audio/sfx/bell",
	"screech": "res://audio/sfx/screech",
	"crash": "res://audio/sfx/crash",
	"siren": "res://audio/sfx/siren",         # loops during the car chase
	"engine": "res://audio/sfx/engine",       # loops; pitch follows your speed
}

const MUSIC := {
	"title": "res://audio/music/title",
	"main_street": "res://audio/music/main_street",
	"chicken_run": "res://audio/music/chicken_run",
	"rock_creek": "res://audio/music/rock_creek",
	"gone_fishin": "res://audio/music/gone_fishin",
	"earls_big_break": "res://audio/music/earls_big_break",
	"chase": "res://audio/music/chase",         # Main Street's car chase
	"showdown": "res://audio/music/showdown",   # plays during every showdown
	"county_fair": "res://audio/music/county_fair",
	"last_train": "res://audio/music/last_train",
}

# How loud each music track plays (1.0 = as recorded). Optional.
const MUSIC_VOLUME := 0.8


# --- Voices --------------------------------------------------------------------
# Characters speak their speech-bubble lines.
#
# YOUR OWN RECORDINGS: put a file in audio/voices/<character>/ named after
# the line, e.g. audio/voices/earl/taunt_1.mp3. Every line and its file
# name is listed in audio/voices/LINES.md. A line with a file plays the
# file; a line without one uses text-to-speech (if turned on below).
#
# TEXT-TO-SPEECH uses the computer's built-in voice.
# pitch: 0.0-2.0 (1 = normal), rate: 0.5-2.0 (1 = normal).
const VOICE_FOLDER := "res://audio/voices"
const USE_TEXT_TO_SPEECH := true   # false = only your recordings speak
const VOICES_ON := true            # false = nobody speaks at all
const VOICES := {
	"sheriff": {"pitch": 0.9, "rate": 0.95},   # calm
	"earl": {"pitch": 0.6, "rate": 1.05},      # low and sly
	"dewey": {"pitch": 1.6, "rate": 1.1},      # high and excited
	"jim": {"pitch": 0.95, "rate": 1.0},       # calm, matter-of-fact
	"deputy": {"pitch": 1.3, "rate": 1.4},     # nervous and fast
	"aunt": {"pitch": 1.25, "rate": 0.9},      # sweet and unhurried
	"barber": {"pitch": 1.0, "rate": 1.25},    # chatty
	"farmer": {"pitch": 0.75, "rate": 0.85},   # slow drawl
	"fisherman": {"pitch": 0.85, "rate": 0.9},
	"barker": {"pitch": 1.1, "rate": 1.35},    # step right up!
	"conductor": {"pitch": 0.8, "rate": 1.0},
}
