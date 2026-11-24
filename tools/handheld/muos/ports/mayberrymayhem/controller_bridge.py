"""Controller bridge for the RG35XX Pro (muOS): turns gamepad buttons into
keyboard keys the game already understands, through a virtual keyboard
(/dev/uinput). The FRT runtime doesn't read the pad itself.

    python3 controller_bridge.py [GAME_PID]

SELECT + START closes the game: it stops GAME_PID if given, otherwise the
bridge's parent process (the old behaviour).
Set PINE_PAD=/dev/input/eventN if the pad isn't event3.

Buttons -> keys -> game actions:
    A      -> Space  -> jump (and confirm in menus)
    B      -> Esc    -> pause (and back in menus)
    X      -> F      -> throw / cast
    Y      -> E      -> lasso
    L1     -> Shift  -> dash / slide (tackle Earl)
    R1     -> R      -> restart the level
    SELECT -> Tab
    START  -> Enter  -> confirm in menus
    D-pad  -> arrows -> move; up also jumps/climbs, down also dashes

Buttons not in the list are written to controller_bridge.log when pressed,
so a button with a different code on another pad can be found and added.
"""
import fcntl
import os
import select
import signal
import struct
import sys
import time

SOURCE = os.environ.get("PINE_PAD", "/dev/input/event3")
UINPUT = "/dev/uinput"
GAME_PID = int(sys.argv[1]) if len(sys.argv) > 1 else None

# Linux button code -> Linux keyboard code
KEYS = {
    304: 57,   # A -> Space (jump)
    305: 1,    # B -> Escape
    307: 33,   # X -> F (throw)
    308: 18,   # Y -> E (lasso)
    310: 42,   # L1 -> Left Shift (dash)
    311: 19,   # R1 -> R (restart)
    314: 15,   # SELECT -> Tab
    315: 28,   # START -> Enter
}
SELECT, START = 314, 315

# D-pad axis code -> (negative key, positive key)
HATS = {
    16: (105, 106),  # Left / Right arrows
    17: (103, 108),  # Up / Down arrows
}

pressed = set()
hat_state = {16: 0, 17: 0}
held_buttons = set()


def emit(fd, event_type, code, value):
    os.write(fd, struct.pack("llHHi", 0, 0, event_type, code, value))


def send_key(code, down):
    if down and code not in pressed:
        emit(ui, 1, code, 1)
        emit(ui, 0, 0, 0)
        pressed.add(code)
    elif not down and code in pressed:
        emit(ui, 1, code, 0)
        emit(ui, 0, 0, 0)
        pressed.remove(code)


def descendants(pid):
    """pid and every process it started (children, grandchildren...)."""
    parents = {}
    for entry in os.listdir("/proc"):
        if entry.isdigit():
            try:
                with open(f"/proc/{entry}/stat") as f:
                    # the field after "(name)" is the state, then the parent pid
                    ppid = int(f.read().rsplit(")", 1)[1].split()[1])
            except (OSError, ValueError, IndexError):
                continue
            parents.setdefault(ppid, []).append(int(entry))
    found, todo = [], [pid]
    while todo:
        p = todo.pop()
        found.append(p)
        todo.extend(parents.get(p, []))
    return found


def is_zombie(pid):
    """Exited but not yet collected by its parent: it no longer runs."""
    try:
        with open(f"/proc/{pid}/stat") as f:
            return f.read().rsplit(")", 1)[1].split()[0] == "Z"
    except (OSError, IndexError):
        return True


def signal_all(pids, sig):
    alive = []
    for p in pids:
        try:
            os.kill(p, sig)
            if not is_zombie(p):
                alive.append(p)
        except ProcessLookupError:
            pass
    return alive


def quit_game():
    """Stop the game and everything it started; force it after 3 seconds."""
    target = GAME_PID if GAME_PID else os.getppid()
    pids = descendants(target)
    print("Exit combo pressed, stopping", pids, flush=True)
    signal_all(pids, signal.SIGTERM)
    for _ in range(30):
        time.sleep(0.1)
        if not signal_all(pids, 0):   # signal 0 only checks they still exist
            return
    print("Still running, force-stopping", pids, flush=True)
    signal_all(pids, signal.SIGKILL)


src = os.open(SOURCE, os.O_RDONLY | os.O_NONBLOCK)
ui = os.open(UINPUT, os.O_WRONLY | os.O_NONBLOCK)

UI_SET_EVBIT = 0x40045564
UI_SET_KEYBIT = 0x40045565
UI_DEV_CREATE = 0x5501
UI_DEV_DESTROY = 0x5502
UI_DEV_SETUP = 0x405c5503

fcntl.ioctl(ui, UI_SET_EVBIT, 1)

all_keys = set(KEYS.values())
for pair in HATS.values():
    all_keys.update(pair)

for key in all_keys:
    fcntl.ioctl(ui, UI_SET_KEYBIT, key)

setup = struct.pack(
    "HHHH80sI",
    3, 0x1234, 0x5678, 1,
    b"Pine Hollow Keyboard", 0
)

fcntl.ioctl(ui, UI_DEV_SETUP, setup)
fcntl.ioctl(ui, UI_DEV_CREATE)

print("Controller bridge running:", SOURCE, "game pid", GAME_PID, flush=True)

try:
    while True:
        readable, _, _ = select.select([src], [], [], 1)
        if not readable:
            continue

        data = os.read(src, 24 * 64)

        for offset in range(0, len(data) - 23, 24):
            _, _, event_type, code, value = struct.unpack(
                "llHHi", data[offset:offset + 24]
            )

            # Physical buttons
            if event_type == 1 and code in KEYS:
                if value == 1:
                    held_buttons.add(code)
                elif value == 0:
                    held_buttons.discard(code)

                if SELECT in held_buttons and START in held_buttons:
                    quit_game()
                    raise SystemExit

                send_key(KEYS[code], value != 0)

            elif event_type == 1 and value == 1:
                print("Unmapped button code", code, flush=True)

            # D-pad axes
            elif event_type == 3 and code in HATS:
                old = hat_state[code]
                if value == old:
                    continue

                negative_key, positive_key = HATS[code]

                if old == -1:
                    send_key(negative_key, False)
                elif old == 1:
                    send_key(positive_key, False)

                if value == -1:
                    send_key(negative_key, True)
                elif value == 1:
                    send_key(positive_key, True)

                hat_state[code] = value

finally:
    for code in list(pressed):   # don't leave a key held down
        send_key(code, False)
    fcntl.ioctl(ui, UI_DEV_DESTROY)
    os.close(ui)
    os.close(src)
