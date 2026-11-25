# Writes audio/voices/LINES.md: every spoken line, who says it, and the file
# name to record it as. Re-run after editing scripts/config/game_text.gd:
#   godot --headless -s tools/list_voice_lines.gd
# (or open it in the Script editor and choose File > Run).
@tool
extends SceneTree

# Same order as Game.LEVELS (this runs without the autoloads).
const LEVELS := ["main_street", "chicken_run", "rock_creek", "gone_fishin", "earls_big_break",
	"county_fair", "last_train"]


func _initialize() -> void:
	write()
	quit()


static func write() -> void:
	var by_who := {"sheriff": [], "earl": [], "dewey": [], "deputy": []}
	for id in LEVELS:
		var t: Dictionary = GameText.LEVELS.get(id, {})
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % id))
		var earl_level: bool = d.get("role", "sheriff") == "earl"
		by_who["earl"].append([id + "_start", t.get("start", "")])
		by_who["earl" if earl_level else "sheriff"].append([id + "_win", t.get("win", "")])
		by_who["deputy" if earl_level else "earl"].append([id + "_lose", t.get("lose", "")])
		var dw: Array = t.get("dewey", [])
		for i in dw.size():
			by_who["dewey"].append(["%s_%d" % [id, i + 1], dw[i]])
		var own: Array = t.get("taunts", [])   # this episode's own Earl taunts (earl.gd)
		for i in own.size():
			by_who["earl"].append(["%s_taunt_%d" % [id, i + 1], own[i]])
	_list(by_who.earl, "taunt", GameText.EARL_TAUNTS)
	_list(by_who.earl, "throw", GameText.EARL_THROWS)
	_list(by_who.earl, "tackled", GameText.EARL_TACKLED)
	for pair in [["hides", GameText.EARL_HIDES], ["peekaboo", GameText.EARL_PEEKABOO],
			["bonked", GameText.EARL_BONKED], ["lassoed", GameText.EARL_LASSOED],
			["cornered", GameText.EARL_CORNERED], ["caught_early", GameText.EARL_CAUGHT_EARLY],
			["cuffed", GameText.EARL_CUFFED]]:
		by_who.earl.append(pair)
	by_who.sheriff.append(["bell_hint", GameText.SHERIFF_BELL_HINT])
	for pair in [["grocer", GameText.EARL_GROCER], ["tower", GameText.EARL_TOWER], ["hosed", GameText.EARL_HOSED],
			["truck", GameText.EARL_TRUCK], ["chase_start", GameText.CHASE_START], ["chase_crate", GameText.CHASE_EARL_CRATE],
			["chase_spinout", GameText.CHASE_EARL_SPINOUT]]:
		by_who.earl.append(pair)
	_list(by_who.earl, "chase_bumped", GameText.CHASE_EARL_BUMPED)
	by_who.deputy.append(["start", GameText.DEPUTY_START])
	_list(by_who.deputy, "aim", GameText.DEPUTY_AIM)
	for pair in [["missed", GameText.DEPUTY_MISSED], ["fumble", GameText.DEPUTY_FUMBLE],
			["spotted", GameText.DEPUTY_SPOTTED], ["bonked", GameText.DEPUTY_BONKED]]:
		by_who.deputy.append(pair)

	var out := "# Voice lines\n\n"
	out += "Record any line and save it in `audio/voices/<character>/` with the file name shown\n"
	out += "(`.mp3`, `.ogg` or `.wav`). It plays instead of text-to-speech. Lines you don't record\n"
	out += "keep using text-to-speech. Names in {braces} are filled in from game_text.gd.\n\n"
	out += "Made by `tools/list_voice_lines.gd`; run it again after changing any text.\n"
	for who in by_who:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://audio/voices/" + who))
		out += "\n## %s  →  `audio/voices/%s/`\n\n| File | Line |\n|---|---|\n" % [GameText.NAMES[who], who]
		for pair in by_who[who]:
			if str(pair[1]).strip_edges() != "":
				out += "| `%s.mp3` | %s |\n" % [pair[0], _names(str(pair[1]))]
	out += _hero_sections()
	var f := FileAccess.open("res://audio/voices/LINES.md", FileAccess.WRITE)
	f.store_string(out)
	print("wrote audio/voices/LINES.md")


static func _list(into: Array, prefix: String, lines: Array) -> void:
	for i in lines.size():
		into.append(["%s_%d" % [prefix, i + 1], lines[i]])


static func _names(s: String) -> String:
	for k in GameText.NAMES:
		s = s.replace("{" + k + "}", GameText.NAMES[k]).replace("{" + k.to_upper() + "}", GameText.NAMES[k].to_upper())
	return s.replace("|", "/")


## The playable heroes' own lines (level.gd hero_line(), lasso.gd), from GameText.HEROES.
static func _hero_sections() -> String:
	var out := ""
	for hero in ["dewey", "jim"]:
		var h: Dictionary = GameText.HEROES.get(hero, {})
		var title: String = ("When you play as " if hero == "dewey" else "") + GameText.NAMES[hero]
		out += "\n## %s  →  `audio/voices/%s/`\n\n| File | Line |\n|---|---|\n" % [title, hero]
		var bird: Array = h.get("bird", [])
		if not bird.is_empty():
			out += "| `%s.mp3` | %s (bowling over a bird while powered up) |\n" % [
				"shazam" if hero == "dewey" else "bird", _names(bird[0])]
		if str(h.get("powerup", "")) != "":
			out += "| `powerup.mp3` | %s |\n" % _names(h.powerup)
		var hurt: Array = h.get("hurt", [])
		if not hurt.is_empty():
			out += "| `hurt.mp3` | %s (one of the hurt lines) |\n" % _names(hurt[0])
		if str(h.get("rope_earl", "")) != "":
			out += "| `rope_earl.mp3` | %s |\n" % _names(h.rope_earl)
		out += "| `<episode>_win.mp3` | the win line for that episode, e.g. `main_street_win.mp3` |\n"
	out += "\nWhen you play as %s, the %s takes over %s's street tips, so those\n" % [
		GameText.NAMES.dewey, GameText.NAMES.sheriff, GameText.NAMES.dewey]
	out += "lines (`main_street_1.mp3` and so on) play from `audio/voices/sheriff/`.\n"
	return out
