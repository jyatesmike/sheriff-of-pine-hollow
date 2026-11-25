#!/usr/bin/env bash
# Headless Godot checks, used by CI and runnable on any Linux or Mac:
#   GODOT=/path/to/godot-4.1 tools/ci/godot_checks.sh [import|bots|pack|all]
#
#   import  open the project once (builds .godot/), then load every script and
#           scene (tools/ci/check_scripts.gd); fail on any script/parse error
#   bots    the test bot plays all 7 levels as each hero, invulnerable ("god"),
#           in parallel; fails if any run doesn't reach the cuffs
#   pack    export build/handheld/sheriff-of-pine-hollow.pck (preset
#           "Handheld (Linux ARM64)"); needs no export templates
#   muos    build/muos-sd/: launcher + controller bridge + .pck laid out like
#           the muOS SD card (tools/handheld/muos/), ready to copy
set -uo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="${CI_OUT:-build/ci}"
LEVELS="${LEVELS:-1 2 3 4 5 6 7}"
HEROES="${HEROES:-sheriff dewey jim}"
# Seconds before a bot run is stopped. A normal run takes well under a minute;
# a level the game hangs on would otherwise hold the check up for a long time.
BOT_TIMEOUT="${BOT_TIMEOUT:-180}"
mkdir -p "$OUT"

do_import() {
	echo "== import (Godot $("$GODOT" --version))"
	# --quit-after lets the first scan finish so the class cache gets written.
	"$GODOT" --headless --editor --quit-after 600 >"$OUT/import1.log" 2>&1
	"$GODOT" --headless --editor --quit >"$OUT/import.log" 2>&1
	if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$OUT/import.log"; then
		echo "FAIL: script errors (full log: $OUT/import.log)"
		return 1
	fi
	# The editor only compiles the autoloads; load every other script and scene too.
	if ! timeout 300 "$GODOT" --headless -s tools/ci/check_scripts.gd >"$OUT/check_scripts.log" 2>&1; then
		grep -E "BROKEN|SCRIPT ERROR" "$OUT/check_scripts.log"
		echo "FAIL: scripts that don't compile (full log: $OUT/check_scripts.log)"
		return 1
	fi
	grep "check_scripts:" "$OUT/check_scripts.log"
	echo "ok: no script errors"
}

do_bots() {
	echo "== bots: levels [$LEVELS] x heroes [$HEROES]"
	local pids=() names=()
	for hero in $HEROES; do
		for n in $LEVELS; do
			CHAR="$hero" timeout "$BOT_TIMEOUT" "$GODOT" --headless --fixed-fps 60 \
				-s tools/test_bot_run.gd -- "$n" god >"$OUT/bot_${hero}_$n.log" 2>&1 &
			pids+=($!)
			names+=("${hero}_$n")
		done
	done
	local fail=0
	for i in "${!pids[@]}"; do
		local log="$OUT/bot_${names[$i]}.log" rc=0
		wait "${pids[$i]}" || rc=$?
		if [ "$rc" = 0 ] && ! grep -q 'SCRIPT ERROR' "$log"; then
			echo "ok   ${names[$i]}: $(grep -m1 ' WON ' "$log")"
		elif [ "$rc" = 0 ]; then
			# Won, but something broke on the way (e.g. a platform with bad data the
			# level skipped): that's a failure too.
			echo "FAIL ${names[$i]}: won, but with errors: $(grep -m1 -A1 'SCRIPT ERROR' "$log" | tr '\n' ' ')"
			fail=1
		elif [ "$rc" = 124 ]; then
			echo "FAIL ${names[$i]}: no result: stopped after ${BOT_TIMEOUT}s. $(grep -m1 -A1 'SCRIPT ERROR' "$log" | tr '\n' ' ')"
			fail=1
		else
			echo "FAIL ${names[$i]}: $(grep -m1 -E 'FAILED|SCRIPT ERROR' "$log" || echo "the game crashed (exit code $rc)")"
			fail=1
		fi
	done
	return $fail
}

do_pack() {
	echo "== pack"
	mkdir -p build/handheld
	"$GODOT" --headless --export-pack "Handheld (Linux ARM64)" \
		build/handheld/sheriff-of-pine-hollow.pck >"$OUT/pack.log" 2>&1
	if [ ! -s build/handheld/sheriff-of-pine-hollow.pck ]; then
		echo "FAIL: no .pck written (log: $OUT/pack.log)"
		return 1
	fi
	ls -l build/handheld/sheriff-of-pine-hollow.pck
}

# SD-card layout for muOS: copy the contents of build/muos-sd/ to the card's root.
do_muos() {
	echo "== muOS package"
	[ -s build/handheld/sheriff-of-pine-hollow.pck ] || do_pack || return 1
	local src=tools/handheld/muos dst=build/muos-sd
	bash -n "$src/ROMS/Ports/Sheriff of Pine Hollow.sh" || return 1
	python3 -m py_compile "$src/ports/mayberrymayhem/controller_bridge.py" || return 1
	rm -rf "$dst"
	mkdir -p "$dst/ROMS/Ports" "$dst/ports/mayberrymayhem"
	cp "$src/ROMS/Ports/Sheriff of Pine Hollow.sh" "$dst/ROMS/Ports/"
	cp "$src/ports/mayberrymayhem/controller_bridge.py" "$dst/ports/mayberrymayhem/"
	cp build/handheld/sheriff-of-pine-hollow.pck "$dst/ports/mayberrymayhem/"
	if grep -lq $'\r' "$dst/ROMS/Ports/"*.sh "$dst/ports/mayberrymayhem/"*.py; then
		echo "FAIL: Windows line endings (CRLF) in the launcher or bridge"
		return 1
	fi
	(cd "$dst" && find . -type f | sort)
}

case "${1:-all}" in
	import) do_import ;;
	bots) do_bots ;;
	pack) do_pack ;;
	muos) do_muos ;;
	all) do_import && do_bots && do_pack && do_muos ;;
	*) echo "usage: $0 [import|bots|pack|muos|all]"; exit 2 ;;
esac
