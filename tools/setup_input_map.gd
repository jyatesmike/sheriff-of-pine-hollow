# Writes the default Input Map into project.godot.
# Run from the project folder:
#   godot --headless -s tools/setup_input_map.gd
# Safe to re-run; it overwrites only the actions listed below.
extends SceneTree

const KEYS := {
	"left": [KEY_LEFT, KEY_A],
	"right": [KEY_RIGHT, KEY_D],
	"jump": [KEY_SPACE, KEY_UP, KEY_W],
	"throw": [KEY_F, KEY_X],
	"action": [KEY_SHIFT, KEY_C, KEY_DOWN, KEY_S],   # dash / slide
	"pause": [KEY_ESCAPE, KEY_P],
	"restart": [KEY_R],
	"lasso": [KEY_E, KEY_Z],
	"up": [KEY_UP, KEY_W],          # steering the patrol car, climbing
	"down": [KEY_DOWN, KEY_S],
}
const BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A],
	"throw": [JOY_BUTTON_X],
	"action": [JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN],
	"pause": [JOY_BUTTON_START],
	"restart": [JOY_BUTTON_BACK],
	"lasso": [JOY_BUTTON_Y],
	"up": [JOY_BUTTON_DPAD_UP],
	"down": [JOY_BUTTON_DPAD_DOWN],
}
# [axis, direction]
const AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0],
	"right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0],
	"down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _init() -> void:
	for action in KEYS:
		var events: Array = []
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			events.append(e)
		for b in BUTTONS.get(action, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			events.append(j)
		if AXES.has(action):
			var m := InputEventJoypadMotion.new()
			m.axis = AXES[action][0]
			m.axis_value = AXES[action][1]
			events.append(m)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.4, "events": events})
	var err := ProjectSettings.save()
	print("input map written: ", error_string(err))
	quit()
