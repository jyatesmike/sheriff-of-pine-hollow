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
    SELECT -> Tab
    START  -> Enter  -> confirm in menus
    D-pad  -> arrows -> move; up also jumps/climbs, down also dashes
"""
import fcntl
import os
import select
import signal
import struct
import sys

SOURCE = os.environ.get("PINE_PAD", "/dev/input/event3")
UINPUT = "/dev/uinput"
GAME_PID = int(sys.argv[1]) if len(sys.argv) > 1 else None

# Linux button code -> Linux keyboard code
KEYS = {
    304: 57,   # A -> Space (jump)
    305: 1,    # B -> Escape
    307: 33,   # X -> F (throw)
    308: 18,   # Y -> E (lasso)
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


def quit_game():
    target = GAME_PID if GAME_PID else os.getppid()
    print("Exit combo pressed, stopping", target, flush=True)
    try:
        os.kill(target, signal.SIGTERM)
    except ProcessLookupError:
        pass


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
