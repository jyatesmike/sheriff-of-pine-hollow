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

cleanup() {
	kill "$BRIDGE_PID" 2>/dev/null
	wait "$BRIDGE_PID" 2>/dev/null
	if [ "$mounted_here" = 1 ]; then
		umount "$RUNTIME_DIR" 2>/dev/null
	fi
}
trap cleanup EXIT

wait "$GAME_PID"
log "game exited (code $?)"
