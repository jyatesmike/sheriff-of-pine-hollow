# Loads every .gd script and .tscn scene in the project and fails on any that
# doesn't compile or load. Opening the editor headless only compiles the
# autoloads, so this catches errors in everything else.
#   godot --headless -s tools/ci/check_scripts.gd
extends SceneTree

const SKIP := ["res://.godot", "res://build", "res://addons"]


func _initialize() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	# Reloading the running script from disk would replace it mid-run.
	files.erase(get_script().resource_path)
	var bad := 0
	for path in files:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var ok := res != null
		if ok and res is GDScript:
			ok = (res as GDScript).can_instantiate()
		if not ok:
			printerr("BROKEN: ", path)
			bad += 1
	print("check_scripts: %d files, %d broken" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	for skip in SKIP:
		if dir.begins_with(skip):
			return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)
