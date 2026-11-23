# Sheriff of Pine Hollow (Godot 4)

> **This is the Godot 4.1 copy.** It's the same game as `pine-hollow-godot`, changed to open
> and run in Godot 4.1.x: the background layers use a small stand-in for the Parallax2D node
> (`scripts/compat/parallax_2d.gd`, since Parallax2D only arrived in Godot 4.3), the ground uses
> a TileMap instead of a TileMapLayer, and the 4.3-only motion smoothing calls are left out.
> Changes made to one copy don't carry over to the other.


A 2D side-scrolling chase platformer with a warm 1960s small-town Southern feel.
Godot 4.1.x, GDScript only. Everything (characters, names, places, music) is original.

## Who you play as

Pick **PLAYING AS** on the title screen (left / right): the Sheriff, Dewey or Jim. The jail-escape
episode is always Earl. Everyone plays the same and has the same rope moves; each has their own look:

| | Rope | Power-up (only they can grab it) |
|---|---|---|
| Sheriff | lasso | - |
| Dewey | jumper cables (Earl gets a zap) | **Lightning Soda**: 8 seconds of can't-be-hurt and extra speed; birds he runs into get bowled over: "SHAZAM!" |
| Jim | garden hose (Earl gets soaked) | **Zero-turn mower**: 8 seconds riding it, can't be hurt, turns on a dime, mows stripes in the grass and turns up bonus pies |

Bowled-over chickens, geese and ducks land dazed and get back up; in Chicken Run they flutter
straight home to the coop. Power-ups sit at two spots per episode ("powerup" in each level's
objects list). Their lines (power-up, hurt, win per episode, birds, roping Earl) are in
`scripts/config/game_text.gd` under HEROES, and voice files go in `audio/voices/dewey/` and
`audio/voices/jim/` (see `audio/voices/LINES.md`). Jim's built-in look is a stand-in until his
PixelLab art is in: drop his GIFs in `art/source/pixellab/jim/` like the Sheriff's.

## Run it
1. Install **Godot 4.1.x** (4.1.4 is what CI uses; standard build, not .NET):
   https://github.com/godotengine/godot/releases/tag/4.1.4-stable
2. Open Godot → **Import** → pick this folder's `project.godot` → **Import & Edit**.
3. Press **F5** (Run Project).

## Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | ← → / A D | D-pad / left stick |
| Jump (hold = higher) | Space / ↑ / W | A |
| Dash / slide | Shift / C / ↓ / S | B / D-pad down |
| Throw a rock (Rock Creek) / cast and reel (Gone Fishin') | F / X | X |
| Lasso (swing from hooks, rope Earl or hens) | E / Z | Y |
| Climb a ladder / hide (night level) | hold ↑ / W | D-pad up |
| Car chase: gas / brake | → / ← | D-pad |
| Car chase: change lane | ↑ ↓ | D-pad up/down |
| Car chase: siren / jump the ramp | Shift / Space | B / A |
| Pause | Esc / P | Start |
| Restart | R | Back/Select |
| Jump to level 1–7 | 1–7 | — |
| Debug readout | F3 | — |

Stand still for a few seconds and the Sheriff tips his hat.

On touch screens, on-screen buttons appear automatically.
The game pauses and releases every key when the window loses focus, so nothing gets stuck.

## Milestones
- [x] **1. Setup, movement, Main Street greybox, camera**
- [x] **2. Earl chase AI, hens and stomping, pies, HUD, win/lose, restart**
- [x] **3. Placeholder sprite generator, all animations, parallax backgrounds, tilesets**
- [x] **4. Levels 2–5 and their mechanics**
- [x] **5. Audio, voices, menus, saving, Edit Names**
- [x] **6. Levels 6–7, medals, favors, polish and juice**
- [x] **7. HTML5 + desktop export**

## Title screen and menus
The game starts on the title screen: **PLAY / CONTINUE** (first episode you haven't beaten),
**CHOOSE EPISODE** (a map of the county with your best time and medals for each place), **SETTINGS** (music, sound and
voice volume, spoken lines on/off, screen shake, full screen, unlock all episodes, scanlines, erase progress), **CREDITS** and
**EDIT NAMES** (the town, the cast and the 12 shop signs: pick one, type, press Enter).
Each episode unlocks when you beat the one before it (or turn on ALL EPISODES UNLOCKED).
Progress, settings and names are saved automatically. In a level, ESC opens the pause menu
(resume, back to checkpoint, start over, quit to title). Number keys 1-7 still jump to a level.

## Controls can be changed
Settings > CONTROLS: pick an action, then press the new key or gamepad button. Your choice
replaces the main key for that action (the other default keys still work). RESET CONTROLS puts
everything back. Saved with your other settings.

## Replacing the character art
`art_templates/` has a template for the sheriff, earl and deputy: an empty sheet
with the exact grid the game expects, the current art faintly underneath as a size guide, and a
`<name>_rows.txt` listing what goes in each row (idle, run, jump...). Frames are 48 x 64 px, feet
on the bottom edge of the frame, facing RIGHT (the game flips them for left).
Draw your frames over the template (Aseprite, PixelLab...), delete the guide, and save the result
as `art/sprites/<name>.png`. That's it. (Don't run `tools/make_placeholders.gd` afterwards: it
redraws the built-in art over yours.) Rebuild the templates with
`godot --headless -s tools/make_sprite_template.gd`.

**From PixelLab:** unzip the PixelLab download and run
`godot --headless -s tools/import_pixellab.gd -- <unzipped folder> sheriff` (or `earl`, `aunt`...).
It uses the east-facing (side view) frames, shrinks them to fit the 48 x 64 frames, and matches
PixelLab animations to the game's by name (walk/run, jump, idle, hurt, throw, crouch, celebrate,
climb... the list is `MATCH` in the script). Animations it can't find are faked from the idle
pose. The built-in art is kept in `art/sprites/generated/` so nothing is lost. For the crispest
result make the character on a 64 px canvas in PixelLab rather than shrinking a big one.

**From PixelLab GIFs:** the Sheriff's art comes from PixelLab animation GIFs kept in
`art/source/pixellab/sheriff/` (idle, run, jump, throw, hurt, celebrate, crouch, tiphat, climb).
Replace any GIF there with a new one of the same name and run
`sh art/source/pixellab/sheriff/build.sh` (needs Python 3 with Pillow) to rebuild the sheet.
Frames are used at their real size; the centre of the GIF goes to the centre of the frame and
his feet to the bottom. `--fix-navy` turns the navy trousers some PixelLab templates draw back
into khaki.

The townsfolk (aunt, barber, farmer, fisherman, barker, conductor, watchman) use the same 48 x 64
sheet layout, so they can be replaced the same way: `art/sprites/<name>.png`. Their built-in
looks (hats, clothes, colours) are in `tools/gen/townsfolk.gd`; regenerate just those sheets
with `godot --headless -s tools/make_townsfolk.gd`. Speech-bubble portraits are cut from each
character's first idle frame automatically, so new art shows up there too.

## Lighting and effects
Each level has a mood (sunset, dusk, night), real lights (street lamps, flashlight beams, the
fair's bulbs, the train's headlamp) and drifting particles (fireflies, leaves, dust). The looks
are in `scripts/levels/lighting.gd` (PRESETS). Settings > LIGHTING AND EFFECTS turns them off
for slow computers.

The same setting covers the rest of the visual polish:
- **Water** (`shaders/water.gdshader`, `scripts/levels/water.gd`): the lake, the duck pond and the
  creek mirror whatever stands above them, with ripples and glints.
- **Grass** (`scripts/levels/grass.gd`): blades sway in the breeze and part as people walk through.
- **Squash and stretch**: characters squash on landing and tackles and stretch when jumping
  (`scripts/actors/actor_sprite.gd`).
- **Camera**: each episode opens on Earl and glides back to the Sheriff (press JUMP to skip),
  zooms in when the showdown starts, and the final tackle goes into slow motion
  (`scripts/chase_camera.gd`).
- **Iris wipe** between scenes (`shaders/iris.gdshader`), the painted title screen with the
  hanging sign, and comic-book panels for the episode intros.

## Exporting (web, Mac, Windows, handheld)
`export_presets.cfg` has four presets: **Web** (single-threaded, so it runs on itch.io without
special server headers), **macOS** (universal app, ad-hoc signed), **Windows**, and
**Handheld (Linux ARM64)** (see "Handheld build" below).
1. In Godot: Editor > Manage Export Templates > Download and Install (once, about 1 GB).
2. Project > Export, pick a preset, Export Project. Output goes into `build/`.
- **itch.io:** zip the files in `build/web/` (index.html at the top level), upload as an HTML game,
  tick "This file will be played in the browser", set the viewport to 960 x 540.
- **Mac app:** the first time, right-click the app and choose Open (it isn't notarized by Apple).

## Change names, text and sounds (in the code)
- **Names, signs and every line of dialogue:** `scripts/config/game_text.gd`.
  Edit anything in quotes. `{town}`, `{sheriff}`, `{earl}`, `{dewey}` and `{deputy}`
  fill in the names from the top of that file.
- **Sound effects and music:** the game ships with built-in music (the original whistling
  theme, arranged differently for each area, plus a faster showdown version) and sound effects.
  To use your own, drop files into `audio/sfx/` and `audio/music/`, named after the sound
  (`jump.ogg`, `main_street.mp3` ...). `.ogg`, `.wav` and `.mp3` all work, music loops, and your
  file always replaces the built-in one. The full list of names, and how to point any sound at a
  different file, is in `scripts/config/sound_files.gd`. Open the project in Godot once after adding files.
- **Voices:** every spoken line can be your own recording. Save it as
  `audio/voices/<character>/<line>.mp3` (or `.ogg` / `.wav`), e.g. `audio/voices/earl/taunt_1.mp3`.
  **`audio/voices/LINES.md` lists every line and the file name to use.** Lines without a recording
  use the computer's text-to-speech; pitch and speed per character, or turning text-to-speech off,
  are in `scripts/config/sound_files.gd`. After changing any text, re-run `tools/list_voice_lines.gd`
  (File > Run) to refresh the list.
- **Rebuild the built-in audio:** open `tools/make_audio.gd` and choose File > Run.

## The levels
1. **Main Street** – a string of different scenes rather than one long run:
   dodge falling flowerpots, slide under washing (and bounce off the springy line), climb a ladder
   onto the rooftops, ride chimney smoke up to the high pies, take the zip line down (jump into it),
   jump the grocer's barrels, then **the car chase**: Earl steals the milk truck and you follow in
   the patrol car. Hold → for gas and ← to brake, change lanes round traffic, slow down for the
   curve signs (or skid into the hay), jump the ramp over the creek, and use the siren to make cars
   pull over. Bump the truck 3 times to end it early. After that Earl climbs the water tower: ring the fire bell
   (touch it or lasso it) so the firemen hose him down, then it's the showdown.
2. **The Chicken Run** – farm at sunset, in scenes:
   - **Hen yard:** Earl let the hens out and the gate stays shut until they're all home. Hens run
     away from you, so hop over them to get behind and walk them into the coop.
   - **Hay wagon:** the mud slows you (and Earl) to a slog. Jump on the wagon and the tractor pulls
     you across; climb the bales for pies while Earl lobs eggs.
   - **Barn:** walk the ground floor (falling bales, slide under the hay wall), or climb the ladder
     to the loft and rope the beam hook (E/Z) to swing across for pies.
   - **Windmill:** ride a sail tip up over the top for the golden pie.
   - **Goat:** don't turn your back on him. Jump on him for a huge bounce; he'll butt Earl too.
   - **Showdown in the pig pen:** slick mud, shoving pigs, and Earl's too slippery to tackle until
     you rope him first.
3. **Rock Creek** – the canyon, in scenes:
   - **Rockslide:** boulders come bouncing down the trail. Jump them, shelter under the rock
     overhangs (they bounce over the top), or smash one with a thrown rock (F/X).
   - **Mine cart:** Earl jumps in a cart and you follow in another across the chasm. JUMP hops the
     cart over broken track, hold DOWN to duck the low timbers. Miss a jump and you're back at the start.
   - **Rope canyon:** lasso (E/Z) the two hooks to swing across; the golden pie hangs low in the middle.
   - **Showdown at the rock pillar:** Earl climbs up and pelts you with stones. Throw rocks back
     (they lob up at him); three hits knock him down, then tackle him.
   Boulders on the ground still hide pies (break them with a rock or a dash).
4. **Gone Fishin'** – Pine Lake, in scenes:
   - **Canoe:** Earl paddles off and you follow. Hold RIGHT to paddle hard (you'll need it in the
     whirlpool current), JUMP to hop the canoe over rocks, hold DOWN to duck the willow branches.
     Hit a rock and you swim back to the dock.
   - **Sinking docks:** each dock sinks while you stand on it, so keep hopping. Fish leap out of the
     gaps: bounce off their backs, but one in the face costs a heart.
   - **Fishing finale:** Earl rows off from the end of the pier. Stand at the end, press F to cast at
     his boat once he's well out, then HOLD F to reel him in. A red "!" warns he's about to yank:
     let go of F while he pulls ("LET GO!") or the line snaps, then reel again. The blue bar shows
     how close he is.
5. **Earl's Big Break** – night, and *you* are Earl:
   - **Flashlights:** watchers in lit windows sweep the street, and one walks his beat. Stay in a
     beam too long and you're spotted (a heart, and back to the last checkpoint). Stand at a hedge,
     barrel, doorway or laundry basket and press UP to hide; UP again (or move) to slip out.
   - **Bloodhound:** the deputy lets Biscuit loose, and he's faster than you. Grab sausages and press
     F to toss one behind you (he stops to eat), or wade the creek to make him lose your scent.
   - **Midnight freight:** reach the station and the train pulls out with the deputy running after
     you. Jump up on the car roofs, slide (Shift) under the signal arms, and ride it across the
     ravine to the county line. Don't run off the front of the engine!

6. **The County Fair** – bounce across the balloon bridge, ride the Ferris wheel over the rides
   fence (it's the only way over), win the pie-eating contest (mash F; beat the farmer for full
   hearts), and catch Earl in the bumper cars: LEFT/RIGHT to drive, UP/DOWN to change rows, ram
   him 3 times.
7. **The Last Train** – the whole level is the top of a moving train. Jump the gaps between cars,
   climb the boxcars, and when "TUNNEL!" flashes get down onto a flat deck before it reaches you.
   The final showdown is on the engine.

**Every level** also has 3 hidden **sheriff stars**, one **favor** for a townsperson (find what
they've lost and bring it back), and **medals** for time, pies and stars (bronze, silver, gold),
shown on the results screen and the county map.

Win a level and press jump to go to the next one.

## How a level plays
- **Chase:** Earl runs ahead and keeps just out of reach. He hops gaps and crates, takes awning
  shortcuts, and sometimes doubles back to jeer. The CLOSING IN meter shows how near you are.
- **Showdown:** when Earl reaches the end fence (or you catch him), he dodges around.
  Tackle him 3 times (a dash is the surest way) and he's cuffed.
- **Hens:** land on them to bounce (hold jump for a higher bounce). Chain stomps in the air for
  X2, X4, X8… combos. Touching one from the side costs a heart; a dash knocks it aside.
  Flapping hens over gaps are harmless bounce pads that never leave.
- **Pies:** 100 points each; every 10 pies = +1 heart (max 5). One golden pie per level.
- **Hearts:** start with 3. Falling in a pit costs one and puts you back on solid ground.
- **Checkpoints:** run past a checkpoint post (its flag goes up) and, if you lose, JUMP puts you
  back there with your score and pies; R starts the level over. The car chase, and getting out of
  the car after it, are checkpoints too. Add more with `{"type": "checkpoint", "x": ...}` in a level file.
- **In the car chase** only a head-on crash with an oncoming car costs a heart, and never your last.
  A red **!** at the right edge warns you an oncoming car is in your lane; a horn sounds too.
  Rear-ending slow tractors or skidding into the hay just slows you down.

## Adding set pieces
Each scene in a level is an object listed under `"objects"` in `data/levels/<level>.json`
(position in 16-px tiles, height in tiles above the ground). Every object type is one script in
`scripts/levels/objects/` (flowerpot, clothesline, building, chimney, zipline, grocer, patrol_car,
fire_bell, water_tower, coop_yard, hay_wagon, mud, barn, windmill, goat, pig_pen, rockslide, mine_cart, rock_pillar, canoe, docks, fishing_pier, watchman, hiding_spot, bloodhound, freight_train, balloons,
ferris_wheel, fair_fence, pie_contest, bumper_cars, fair_decor, train_cars, tunnels, star, favor, checkpoint ...). The car chase route (length, hills, curves, ramp, traffic, pies) is
in `data/chases/main_street.json`.

## Layout
```
scenes/   levels/ actors/ ui/          .tscn scenes
scripts/  config/ (game_text.gd, sound_files.gd)  autoload/ (Game, Audio, Names)  actors/ levels/ ui/
audio/    sfx/ and music/ — drop your sound files here;  builtin/ — generated defaults
data/     levels/*.json                level layouts (16 px tile units)
art/      sprites/ tiles/ backgrounds/ — generated placeholder art (see art/README.md)
audio/
tools/    make_placeholders.gd         regenerates all art (File > Run in the editor)
          make_audio.gd                regenerates the built-in music and sound effects
          make_placeholders_cli.gd     same, from the command line
          gen/                         the generator: rig, poses, cast, animals, props, tiles, backgrounds
          convert_html_levels.py       browser LEVELS -> data/levels/*.json
          setup_input_map.gd           writes the default Input Map
          test_bot_run.gd + bot.gd     headless smoke test (bot plays Main Street to the cuffs)
```

Level data (`data/levels/*.json`) holds only layout, in tile units (16 px); heights are
"tiles above the ground line". Words live in `scripts/config/game_text.gd`.
Text may use `{town}`, `{sheriff}`, `{earl}`, `{dewey}`, `{deputy}` (or upper-case
`{TOWN}` etc.) and `{sign0}`…`{sign11}`; `Names.fmt()` fills them in.

Headless test: `godot --headless -s tools/test_bot_run.gd -- 3 god` plays level 3
(exit code 0 = won; `god` makes the bot invulnerable to prove the level can be finished).
`CHAR=dewey` or `CHAR=jim` in front plays as someone else.

## Automatic checks (CI)
Every push and pull request runs `.github/workflows/ci.yml` on GitHub Actions (free for this
public repo, no secrets, no paid services):
1. `python3 tools/validate.py`: sprite sheet sizes vs `data/sprites.json`, props atlas,
   tiles and backgrounds, every level's theme/music/object types, `{name}` slots in
   `game_text.gd`, and audio file names.
2. `tools/ci/godot_checks.sh import`: opens the project in Godot 4.1.4 and loads every
   script and scene (`tools/ci/check_scripts.gd`); any script error fails.
3. `tools/ci/godot_checks.sh bots`: the bot plays all 7 levels as the Sheriff, Dewey and Jim
   (21 runs, in parallel, under a minute).
4. `tools/ci/godot_checks.sh pack`: exports `sheriff-of-pine-hollow.pck` for the handheld,
   downloadable from the run's **Artifacts**.

Run the same thing locally: `GODOT=/path/to/godot tools/ci/godot_checks.sh all`.

## Handheld build (RG35XX Pro and other ARM64 Linux handhelds)
The **Handheld (Linux ARM64)** export preset makes a `.pck`: the whole game in one file, for a
Godot 4.1 runtime on the device to load (`godot --main-pack sheriff-of-pine-hollow.pck`).
It needs no export templates:
`godot --headless --export-pack "Handheld (Linux ARM64)" build/handheld/sheriff-of-pine-hollow.pck`.
The preset sets the `handheld` feature tag, so code can check `OS.has_feature("handheld")`.
Packaging for a specific firmware (launcher script, controls) is not set up yet.
