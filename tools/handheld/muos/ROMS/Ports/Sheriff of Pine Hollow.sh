#!/bin/bash
# Sheriff of Pine Hollow - muOS launcher (RG35XX Pro).
# Lives at /mnt/mmc/ROMS/Ports/ on the SD card; the game files are in
# /mnt/mmc/ports/mayberrymayhem/. Needs PortMaster's Godot/FRT 4.1.3 runtime.
# Controls come from controller_bridge.py (buttons -> keyboard keys).
# SELECT + START quits.

GAME="/mnt/mmc/ports/mayberrymayhem"
RUNTIME_SQFS="/mnt/mmc/MUOS/PortMaster/libs/frt_4.1.3.squashfs"
RUNTIME_DIR="$GAME/frt_runtime"
FRT="$RUNTIME_DIR/frt_4.1.3"
PCK="sheriff-of-pine-hollow.pck"
LOG="$GAME/game.log"

cd "$GAME" || exit 1
: > "$LOG"   # a fresh log each launch
log() { echo "[launcher] $*" >> "$LOG"; }

# Mount the Godot/FRT runtime if it isn't already.
mounted_here=0
if [ ! -f "$FRT" ]; then
	mkdir -p "$RUNTIME_DIR"
	if mount -t squashfs -o loop,ro "$RUNTIME_SQFS" "$RUNTIME_DIR"; then
		mounted_here=1
	fi
fi
if [ ! -f "$FRT" ]; then
	log "ERROR: Godot/FRT 4.1.3 runtime not found ($RUNTIME_SQFS). Install it with PortMaster."
	exit 1
fi
if [ ! -f "$PCK" ]; then
	log "ERROR: $GAME/$PCK is missing."
	exit 1
fi

"$FRT" --display-driver frt --rendering-method gl_compatibility \
	--main-pack "$PCK" >> "$LOG" 2>&1 &
GAME_PID=$!

# The bridge gets the game's PID so SELECT + START closes the game itself.
python3 "$GAME/controller_bridge.py" "$GAME_PID" > "$GAME/controller_bridge.log" 2>&1 &
BRIDGE_PID=$!

# Every process still running the game: a program from the runtime, or one that
# loaded our .pck. (The runtime can start the real game as a child process, so
# stopping $GAME_PID alone can leave the game drawing over the muOS menu.)
game_pids() {
	local d exe cmd
	for d in /proc/[0-9]*; do
		[ "${d#/proc/}" = "$$" ] && continue
		exe=$(readlink "$d/exe" 2>/dev/null)
		case "$exe" in "$RUNTIME_DIR"/*) echo "${d#/proc/}"; continue ;; esac
		cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
		case "$cmd" in *"--main-pack $PCK"* | *frt_4.1.3*) echo "${d#/proc/}" ;; esac
	done
}

# Stop whatever is left of the game; force it after 3 seconds.
stop_game() {
	local pids i
	pids=$(game_pids)
	[ -z "$pids" ] && return
	log "stopping leftover game processes: $(echo $pids)"
	kill $pids 2>/dev/null
	for i in 1 2 3; do
		sleep 1
		pids=$(game_pids)
		[ -z "$pids" ] && return
	done
	log "force-stopping: $(echo $pids)"
	kill -9 $pids 2>/dev/null
	sleep 1
}

cleanup() {
	stop_game   # the screen must be free before muOS draws its menu again
	kill "$BRIDGE_PID" 2>/dev/null
	wait "$BRIDGE_PID" 2>/dev/null
	if [ "$mounted_here" = 1 ]; then
		umount "$RUNTIME_DIR" 2>/dev/null || log "runtime still busy, left mounted"
	fi
}
trap cleanup EXIT
trap 'exit 143' TERM INT   # if muOS stops the launcher, still clean up

wait "$GAME_PID"
log "game exited (code $?)"
