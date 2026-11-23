# Pine Hollow AI Studio: Inspection Report, Architecture Proposal and Phased Plan

Status: **APPROVED 2026-11-23.** Decisions: build on this **Godot 4.1** repo; paid-API cap
**$10/month** across all providers. Phase 1 is in progress (see "Phase 1 status" at the end).
No paid API calls have been made. No agent framework has been installed.
Inspected: `jyatesmike/sheriff-of-pine-hollow` @ `f29c73d` ("Initial Sheriff of Pine Hollow project"), 2026-11-23.

---

## 1. Project architecture and Godot version

| Item | Finding | Source |
|---|---|---|
| Engine | **Godot 4.1.x**, standard (non-.NET) build | `project.godot` → `config/features=("4.1", "GL Compatibility")` |
| Language | GDScript only, ~16,000 lines (scripts + tools) | `scripts/`, `tools/` |
| Renderer | `gl_compatibility` (OpenGL ES 3 / WebGL2) on desktop **and** mobile | `project.godot [rendering]` |
| Resolution | 480×270 viewport, `stretch/mode="viewport"`, `scale_mode="integer"`, pixel snapping, nearest filtering | `project.godot [display]` |
| Main scene | `res://scenes/ui/title.tscn` (`scripts/ui/menu.gd`) | |
| Autoloads | `Game` (state, settings, save to `user://save.json`, pause/restart, auto zoom), `Audio` (SFX/music/voice + TTS fallback), `Names` (renameable cast/town/signs) | `scripts/autoload/` |
| Note | This is the **4.1 copy** of a game that also exists as `pine-hollow-godot` (4.3+). Shims: `scripts/compat/parallax_2d.gd` stands in for Parallax2D, TileMap instead of TileMapLayer. The README says the copies diverge. | `README.md` header |

### How the game is put together

The game is **data-driven with procedural fallbacks**, which suits AI workers well:

```
title.tscn (menu.gd) ──► level.tscn (level.gd, 1,126 lines)
                           ├─ Background (background.gd + compat Parallax2D, 5 layers per area)
                           ├─ World/Terrain (terrain_view.gd, TileMap from art/tiles/<area>.png)
                           ├─ World/Pies, World/Actors (spawned from JSON)
                           ├─ Player (player.tscn), Camera (chase_camera.gd)
                           └─ HUD, touch controls
level.gd reads data/levels/<id>.json → spawns each "objects" entry via
          scripts/levels/objects/<type>.gd (37 object scripts, base class LevelObject)
Main Street car chase: scripts/levels/chase/ + data/chases/main_street.json
Art:      SpriteLib turns art/sprites/*.png + data/sprites.json into SpriteFrames
Text:     every name/line lives in scripts/config/game_text.gd (GameText), Names.fmt() fills {tokens}
Sound:    scripts/config/sound_files.gd maps names → audio/sfx|music overrides → audio/builtin defaults;
          voices audio/voices/<char>/<line>.mp3, else DisplayServer TTS
```

**Generators and pipelines (all local and free):**
- `tools/gen/*` + `tools/make_placeholders*.gd`: draws every placeholder sprite, tile, prop and background in code.
- `tools/make_audio*.gd` + `tools/gen/audio_gen.gd`: synthesises all built-in music and SFX.
- `tools/import_pixellab.gd`, `tools/pixellab_gifs.py`, `art/source/pixellab/sheriff/build.sh`: PixelLab art → sprite sheet.
- `tools/make_sprite_template.gd`: art templates. `tools/list_voice_lines.gd`: regenerates `audio/voices/LINES.md`.
- `tools/test_bot_run.gd` + `tools/bot.gd`: **headless bot smoke test** (`godot --headless -s tools/test_bot_run.gd -- <level> [god]`, exit 0 = won). This is the most valuable QA asset in the repo.

---

## 2. Inventory

### Characters (sprite sheets `art/sprites/<name>.png`)

| Character | Role | Sheet | Scene / script | Voices recorded |
|---|---|---|---|---|
| Sheriff | Default hero (lasso) | 384×1152, 18 rows, **from PixelLab GIFs** | `player.tscn` / `player.gd`, `lasso.gd` | 2 |
| Dewey | Playable hero (jumper cables, Lightning Soda); also NPC | 384×1152 (generated) | `dewey.tscn` / `dewey.gd` | 4 |
| Jim | Playable hero (garden hose, zero-turn mower) | 384×1152, **stand-in art** | uses player + `mower.gd` | 0 |
| Earl | Antagonist; playable in Ep. 5 | 384×1152 (generated) | `earl.tscn` / `earl.gd` | 29 |
| Deputy Plum | Pursuer (popgun/cork) | 384×1152 (generated) | `deputy.tscn` / `deputy.gd` | 0 |
| Townsfolk: aunt, barber, barker, conductor, farmer, fisherman, watchman | Favors, set pieces | 384×1152 each | used by objects (e.g. `watchman.gd`, `pie_contest.gd`) | 0 |
| Animals: hen, goose, duck (32×24 frames, 4 rows); goat, pigs, bloodhound "Biscuit", fish | Hazards / pads | hen/goose/duck sheets; others drawn in code | `hen.tscn` / `hen.gd`, `goat.gd`, `bloodhound.gd`… | — |

Voice coverage: **35 of 68** lines listed in `audio/voices/LINES.md` have recordings; the rest use TTS.

### Other art
- `art/sprites/props.png` (256×300 atlas, rects in `data/props.json`), 5 tile atlases (64×64), 5 background sets × 5 layers (town, farm, quarry, lake, night).

### Scenes (7)
`scenes/ui/title.tscn`, `scenes/levels/level.tscn`, `scenes/actors/{player,earl,deputy,dewey,hen}.tscn`. Almost everything else is built in code from JSON.

### Levels (7 episodes, `Game.LEVELS` order)

| # | id | Theme | Width (tiles) | Set-piece objects |
|---|---|---|---|---|
| 1 | `main_street` | town | 270 | jailhouse, flowerpots, clotheslines, buildings, chimneys, zipline, grocer, **patrol_car → car chase**, fire_bell, water_tower |
| 2 | `chicken_run` | farm | 304 | coop_yard, mud, hay_wagon, barn, windmill, goat, pig_pen |
| 3 | `rock_creek` | quarry | 320 | rockslide, mine_cart, rock_pillar |
| 4 | `gone_fishin` | lake | 320 | canoe, docks, fishing_pier |
| 5 | `earls_big_break` (play as Earl) | night | 336 | hiding_spot ×6, watchman ×4, bloodhound, freight_train |
| 6 | `county_fair` | farm | 250 | balloons, ferris_wheel, fair_fence, pie_contest, bumper_cars, fair_decor |
| 7 | `last_train` | quarry | 208 | train_cars, tunnels |

Every level also has 3 `star`s, 1 `favor`, checkpoints, medals, and (most) 2 `powerup`s.

### Scripts (by area)
- `scripts/actors/` (11): player, earl, deputy, dewey, hen, lasso, projectile, pie, mower, log_platform, actor_sprite
- `scripts/levels/` (8 + 37 objects + 2 chase): level, background, terrain_view, lighting, water, grass, objects/*, chase/*
- `scripts/ui/` (5): menu (881 lines), hud, bubble, popup_text, touch_controls
- `scripts/autoload/` (3), `scripts/config/` (2), plus `sprite_lib`, `pixel_font`, `chase_camera`, `compat/parallax_2d`
- `shaders/`: iris, scanlines, water

### Inconsistencies found (not fixed; listed for your decision)
1. `README.md` "Run it" says **install Godot 4.3 or newer**, but this repo is the 4.1 copy.
2. `art/README.md` says sheets have **16 rows**; actual sheets and `data/sprites.json` have **18** (climb, climb_idle).
3. `art_templates/deputy_rows.txt` is **empty**; there is no Dewey template although the README lists one.
4. README mentions `art/sprites/generated/` backups; the folder doesn't exist (only made by the importer).
5. `.gitignore` ignores `builds/` and `dist/`, but export presets write to **`build/`**, so an export could be committed by accident.
6. Comments say "levels 1–5" (`game.gd` number keys, `test_bot_run.gd` header); there are 7.
7. Jim has no PixelLab source yet (`art/source/pixellab/` holds only `sheriff/`).
8. **The repository is public.** Any secret committed here is exposed, which shapes the studio design below.

---

## 3. Current game structure (summary)

The game is a 7-episode chase platformer. Each episode is one `level.tscn` instance configured by
`data/levels/<id>.json`, with set pieces as object scripts, text in one GDScript constants file,
art in fixed-size PNG sheets described by JSON, and audio found by naming convention with
generated fallbacks. The useful boundaries for AI workers are:

| Seam | Files | Machine-checkable? |
|---|---|---|
| Dialogue / names | `scripts/config/game_text.gd` (one file) | Yes: parse, `{token}` check, line length, LINES.md regen |
| Level layout | `data/levels/*.json`, `data/chases/*.json` | Yes: schema, object type ↔ script exists, **bot playthrough** |
| Sprites | `art/sprites/*.png` (exact sizes), `art_templates/` | Yes: dimensions, cell grid, transparency, palette, feet line |
| Animation timing | `data/sprites.json` | Yes: row count / frame count matches sheet |
| Sound | `audio/sfx|music|voices/`, `sound_files.gd` | Yes: name in map, format, loudness, duration |
| Gameplay code | `scripts/**` | Partly: headless import/parse + bot runs; needs human playtest |

---

## 4. RG35XX Pro build and deployment: what exists

**There is no RG35XX Pro build or deployment process in this repository.** Searched for
RG35XX/Anbernic/PortMaster/muOS/Knulli/ROCKNIX/arm64/aarch64/ssh/scp/deploy:

- `export_presets.cfg` has only **Web**, **macOS** (universal) and **Windows** (x86_64). No Linux/ARM64 preset, no `.pck`-only preset.
- No launcher script, PortMaster port folder, `gptokeyb` mapping, or copy-to-SD/SSH script.
- Handheld awareness in the code: `Game.zoom()` auto-zooms 1.5× on screens ≤1280×800 (comment: "handhelds like Anbernic devices"), `window/handheld/orientation`, full gamepad mapping, focus-loss pause, a "fancy effects" toggle for slow devices, GL Compatibility renderer.

So the handheld process is either manual and outside the repo, or still to be built. My **hypothesis**
(please confirm) is that the 4.1 copy exists because the handheld runs the game on a Godot
4.1 runtime, most likely through **PortMaster** on a custom firmware (muOS/Knulli/ROCKNIX), with
a platform-independent `.pck` launched by that runtime.

Device facts that matter for the studio's QA gates: Allwinner H700 (4× Cortex-A53, **arm64**),
Mali-G31 GPU (GLES 3.2, so GL Compatibility is right), **1 GB RAM**, **640×480 (4:3)** screen.

**Risks to check on the device (not changed):**
- **Scaling:** 480×270 into 640×480. With true integer scaling that is 1× (a small picture with large borders). Also, as far as I know `window/stretch/scale_mode` only arrived in **Godot 4.2**, so a 4.1 runtime probably ignores it and scales by a fraction (about 1.33×, uneven pixels). Please confirm what you see on the device.
- **TTS:** `DisplayServer.tts_speak` usually has no speech backend on handheld Linux. `Audio._tts_ready()` guards it, so expect silence for unrecorded lines on the device.
- **Memory/perf:** 1 GB RAM; lighting, water shader and particles should be measured on the device.

**Questions for you (these block Phase 1's handheld work):**
1. Which firmware is on the RG35XX Pro (stock, muOS, Knulli, ROCKNIX, other)?
2. How do you get the game onto it today: PortMaster port folder, SD card copy, SSH/SFTP, or not yet?
3. Which Godot runtime/version runs it there?
4. Is this 4.1 repo the one to build on, or should the studio target `pine-hollow-godot` (4.3+)?

---

## 5. Recommended architecture for a separate AI Studio dashboard

### Principles
1. **Separate and private.** The studio lives in a new **private** repo (e.g. `pine-hollow-studio`). The game repo stays clean and public and never holds keys.
2. **Workers propose, humans dispose.** Every worker's output is a **pull request on a `studio/<role>/<job-id>` branch**. Nothing merges without your approval. `main` is protected.
3. **Deterministic gates before any model gets to judge.** Godot headless import, validators and bot runs decide pass/fail. They cost $0.
4. **One choke point for paid calls.** Workers never hold provider keys. All paid calls (Claude, PixelLab, voice) go through a **budget gateway** that checks the ledger first and refuses when a cap is reached.
5. **Default is $0.** Every job runs in **dry-run** first: it builds the prompt, estimates tokens and cost, and waits for your approval.
6. **Your Mac is only a client.** It needs a browser, git, and Godot 4.1 for playtesting. All agents, builds and tests run remotely.

### Components

```
 ┌──────────── Your 2016 Mac (browser + Godot editor for playtests) ────────────┐
 └───────────────▲─────────────────────────────────────────────▲────────────────┘
                 │ HTTPS                                        │ git pull / PR review
 ┌───────────────┴──────────────┐                 ┌────────────┴─────────────────┐
 │ STUDIO DASHBOARD (private)   │                 │ GAME REPO (public)           │
 │ • job queue + approvals      │   opens PRs     │ sheriff-of-pine-hollow       │
 │ • budget ledger + caps       │◄──────────────► │ main protected; studio/*     │
 │ • asset inventory, CI status │                 │ branches only                │
 │ • build downloads (.pck/zip) │                 └────────────┬─────────────────┘
 └───────────────┬──────────────┘                              │ CI on every PR (free)
                 │ dispatch approved job                       ▼
 ┌───────────────┴──────────────┐                 ┌──────────────────────────────┐
 │ WORKER RUNNER (ephemeral     │  paid calls     │ VALIDATION PIPELINE ($0)     │
 │ container per job)           │ ──► BUDGET ───► │ godot --headless --import    │
 │ role prompt + scoped files   │     GATEWAY     │ asset/JSON validators        │
 │ no keys, no push to main     │  (keys live     │ bot run, all 7 levels (god)  │
 └──────────────────────────────┘   only here)    │ export: Web + ARM64 pck      │
                                                  └──────────────────────────────┘
```

**Recommended concrete stack (cheapest that is safe):**

| Piece | Recommendation | Why |
|---|---|---|
| Job queue + audit | **GitHub Issues in the private studio repo** (labels `role:dialogue`, `state:approved`…) | Free, audited, phone-friendly, no server to run |
| Validation/CI | **GitHub Actions on the public game repo** with a pinned Godot 4.1.x Linux headless binary | Free for public repos; no secrets needed for validation |
| Worker execution | GitHub Actions in the **private** studio repo (secrets live there), or Claude Code cloud sessions for coding jobs | No always-on server; containers are discarded per job |
| Dashboard UI | A small static site (GitHub Pages from the private repo, or a private Claude artifact) reading the GitHub API + `ledger.json` | Read-mostly, no backend to secure in v1 |
| Budget gateway | A ~150-line script used by every worker step: check ledger → call → record `usage` → write ledger | One choke point; enforces caps before spending |
| Backstop caps | **Provider-side** spend limits: a dedicated Anthropic workspace + API key for the studio with its own monthly limit; prepaid-only or lowest-tier credit on PixelLab / voice services | Hard stop even if the gateway has a bug |

**Access control:**
- A fine-grained GitHub token (or GitHub App) for the studio: `contents:write` + `pull_requests:write` on the game repo only. A branch ruleset lets workers push only `studio/**`. `main` requires PR + green CI + your review.
- Workers are given an **allowlist of paths per role** (below). CI fails a PR that touches files outside its role's list.
- No worker can edit `.github/`, `export_presets.cfg`, `project.godot` or `tools/` without a role that is explicitly allowed and your extra approval.

### Worker roles mapped to this repo

| Role | May change | Free/local tools first | Paid tool (gated) | Automatic gate |
|---|---|---|---|---|
| **QA** | nothing (reports only) | bot runs, screenshots (`tools/_cap.gd`, `snap_at.gd`), validators | Claude for triage summaries | — |
| **Dialogue** | `scripts/config/game_text.gd`, `audio/voices/LINES.md` | `tools/list_voice_lines.gd` | Claude | parses, tokens valid, line-length limits, LINES.md regenerated |
| **Storyline** | `docs/story/**` (bible, episode outlines) | — | Claude | human review only |
| **Level design** | `data/levels/*.json`, `data/chases/*.json` | bot `god` run | Claude | schema, object types exist, bot finishes level |
| **Sprites** | `art/sprites/*.png`, `art/source/**` | `tools/gen/*`, templates, `pixellab_gifs.py` | PixelLab | sheet 384×1152, 48×64 cells, transparent bg, outline colour |
| **Animation** | `data/sprites.json`, `art/source/**` | `pixellab_gifs.py` | PixelLab | row/frame counts match sheet |
| **Sound** | `audio/sfx/`, `audio/music/`, `audio/voices/**` | `tools/make_audio*.gd` | voice/TTS service | name exists in `sound_files.gd`, format, length, loudness |
| **Coding** | `scripts/**`, `scenes/**`, `shaders/**` | — | Claude | headless import clean, all 7 bot runs pass, diff size limit |

Workers for sprites and sound should **use the existing free generators first**. Many requests
("a new townsperson", "a new SFX") can be met at $0.

---

## 6. Phased plan with strict API cost controls

### Cost controls (apply to every phase)

| Control | Setting |
|---|---|
| Global kill switch | `STUDIO_PAID_CALLS=off` by default; the gateway refuses every paid call while off |
| Monthly cap | You choose. Suggested start: **$10/month** across all providers. Gateway stops at 80% and asks you |
| Daily cap | e.g. $2/day |
| Per-job cap | Estimate shown before approval; hard cap e.g. $0.50/job; the job aborts when reached |
| Per-role cap | e.g. Dialogue $2/mo, Level $3/mo, Coding $5/mo (only once enabled) |
| Approval | Every paid job needs your click. No auto-retry loops: at most 2 iterations, then it stops and reports |
| Provider backstop | Separate Anthropic workspace/key with its own spend limit; prepaid-only accounts for art/voice |
| Context hygiene | Workers get only their role's files plus a short cached "studio bible" (prompt caching), never the whole repo |
| Model choice | Your decision per role. Current list prices per 1M tokens (input/output): Haiku 5.5 $0.10/$0.50, Sonnet 5.5 $2/$10, Opus 5.5 $4/$20. Suggestion: Haiku for triage/summaries, Sonnet for dialogue/levels, Opus only for coding jobs you approve individually; use low/medium effort by default |
| Non-urgent work | Message Batches API (about 50% cheaper, results within hours) for bulk dialogue variants and QA summaries |
| Ledger | Every call records model, tokens in/out, cache reads, cost and job id from the API's `usage` field; the dashboard shows spend by role, day and job |

### Phases

| Phase | Goal | Paid API spend | Exit criteria (your sign-off) |
|---|---|---|---|
| **0. Approve** (now) | Agree this plan; answer the RG35XX questions in §4; pick the target repo (4.1 vs 4.3) | **$0** | Plan approved |
| **1. Safety rails in the game repo** | Branch protection on `main`; `.gitignore` adds `build/`; CI workflow: Godot 4.1 headless import, validators (sheets, JSON, sprites.json parity, object types), bot run of all 7 levels in `god` mode; ARM64/`.pck` export + RG35XX package as a downloadable artifact; fix doc inconsistencies from §2 | **$0** | CI green on a no-op PR; you install a CI-built package on the RG35XX and it runs |
| **2. Studio skeleton (no AI)** | Private `pine-hollow-studio` repo; issue templates per role; static dashboard showing inventory, CI status, builds and the ledger; budget gateway with kill switch **off** and all caps at $0; dry-run jobs that build prompts and estimate cost without sending them | **$0** | You can create a job, see a cost estimate and approve/reject it from your phone |
| **3. First worker: Dialogue** | Lowest risk: one file, fully checkable. Gateway on with a small cap ($2–5) | ≤ your cap | 5 jobs merged; real cost per job measured; no file-scope violations |
| **4. Level design + QA workers** | Level JSON proposals verified by bot runs; QA files issues from failed runs and screenshots | ≤ your cap | A new set-piece layout passes the bot and your playtest |
| **5. Coding worker** | PRs only, diff-size limit, all gates required; Opus only on approval | ≤ your cap | 3 merged PRs with no regressions on device |
| **6. Asset workers** | Sprites/animation (local generators → PixelLab), sound (local synth → voice service), each with its own prepaid cap | per-provider cap | Jim's PixelLab sheet passes validators and looks right on device |
| **7. Orchestration** | Only now pick a framework (e.g. Claude Agent SDK, Managed Agents, or keep plain Actions) for multi-step pipelines like story → dialogue → voice → QA | ≤ your cap | Chosen after measuring phases 3–6 |

### What I need from you to start Phase 1
1. Approval of this plan, or changes to it.
2. Answers to the four RG35XX questions in §4.
3. Your monthly cap and per-role caps (or accept the suggested $10/month).
4. OK to create the private `pine-hollow-studio` repo (Phase 2) and to change game-repo settings and CI (Phase 1).

---

## Phase 1 status

| Item | Status |
|---|---|
| CI workflow `.github/workflows/ci.yml` (free, no secrets, Godot 4.1.3 pinned by SHA-512, same as the device) | Done |
| `tools/validate.py`: sheets, props, tiles, backgrounds, levels, name slots, audio names | Done; tested by breaking 8 things on purpose, all caught |
| `tools/ci/check_scripts.gd`: compiles every script and scene (the editor alone only compiles autoloads) | Done; a broken script and its 4 dependents were caught |
| Bot runs: 7 levels × 3 heroes in god mode | Done; 21/21 pass, about 1 minute in total |
| Handheld `.pck` export (preset "Handheld (Linux ARM64)", no templates needed) | Done; 9 MB, runs standalone, CI uploads it as an artifact |
| `.gitignore` covers `build/` | Done |
| Doc fixes: Godot version, 18-row sheets, deputy rows file, template list, level 1-7 comments | Done |
| Bug found by the validator: `earl/chase_bumped_one.mp3` was never played (code asks for `chase_bumped_1`) | Fixed by renaming |
| Branch protection on `main` (PR + green CI required) | **You:** GitHub → Settings → Rules → Rulesets (no tool here can change repo settings) |
| RG35XX packaging (launcher, controls) and on-device test | **Blocked:** needs firmware / install method / runtime answers |
| Exit check: you run a CI-built `.pck` on the RG35XX | **Waiting on you** |
