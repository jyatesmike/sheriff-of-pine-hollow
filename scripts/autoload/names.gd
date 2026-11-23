# Names: the names of the town, cast and the 12 shop signs.
# Defaults come from scripts/config/game_text.gd (edit them there).
# All text goes through Names.fmt("{sheriff} spotted {earl}!") so a renamed
# character shows up everywhere. The in-game Edit Names screen (milestone 5)
# saves overrides on top of these.
extends Node

# The names themselves live in scripts/config/game_text.gd.
const DEFAULTS := GameText.NAMES
const DEFAULT_SIGNS := GameText.SHOP_SIGNS

var values := DEFAULTS.duplicate()
## Inside a level, {sheriff} means whoever you're playing ("sheriff", "dewey", "jim").
var hero := "sheriff"
var signs: Array = DEFAULT_SIGNS.duplicate()


func _ready() -> void:
	var saved: Dictionary = Game.names_data
	for k in DEFAULTS:
		values[k] = values.get(k, DEFAULTS[k])
		if saved.get(k, "") != "":
			values[k] = saved[k]
	var s: Array = saved.get("signs", [])
	for i in signs.size():
		if i < s.size() and str(s[i]) != "":
			signs[i] = str(s[i])


## Replace {town}, {sheriff}, {earl}, {dewey}, {deputy} and {sign0}..{sign11}.
func fmt(text: String) -> String:
	if hero != "sheriff" and values.has(hero):
		text = text.replace("{sheriff}", values[hero]).replace("{SHERIFF}", values[hero].to_upper())
	for k in values:
		text = text.replace("{" + k + "}", values[k])
		text = text.replace("{" + k.to_upper() + "}", values[k].to_upper())
	for i in signs.size():
		text = text.replace("{sign%d}" % i, signs[i])
	return text


func reset_to_original() -> void:
	values = DEFAULTS.duplicate()
	signs = DEFAULT_SIGNS.duplicate()
	store()


func store() -> void:
	var d := values.duplicate()
	d["signs"] = signs
	Game.names_data = d
	Game.save_game()
