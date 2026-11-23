# Voice lines

Record any line and save it in `audio/voices/<character>/` with the file name shown
(`.mp3`, `.ogg` or `.wav`). It plays instead of text-to-speech. Lines you don't record
keep using text-to-speech. Names in {braces} are filled in from game_text.gd.

Made by `tools/list_voice_lines.gd`; run it again after changing any text.

## Sheriff  →  `audio/voices/sheriff/`

| File | Line |
|---|---|
| `main_street_win.mp3` | Come on, Earl. Supper's waiting. |
| `chicken_run_win.mp3` | Next time, leave the hens out of it. |
| `rock_creek_win.mp3` | You throw a mean rock, Sheriff. |
| `gone_fishin_win.mp3` | You're all wet, Earl. |
| `bell_hint.mp3` | Somebody ring that fire bell! |

## Earl  →  `audio/voices/earl/`

| File | Line |
|---|---|
| `main_street_start.mp3` | So long, Sheriff! |
| `main_street_lose.mp3` | Toodle-oo, Sheriff! |
| `chicken_run_start.mp3` | Oopsie, I let the hens out! |
| `chicken_run_lose.mp3` | Cluck cluck, Sheriff! |
| `rock_creek_start.mp3` | Heads up, Sheriff! |
| `rock_creek_lose.mp3` | Rock-a-bye, Sheriff! |
| `gone_fishin_start.mp3` | Last one in's a rotten egg! |
| `gone_fishin_lose.mp3` | Better luck next cast, Sheriff! |
| `earls_big_break_start.mp3` | So long, jailhouse! |
| `earls_big_break_win.mp3` | Free as a bird... for now. |
| `taunt_1.mp3` | Can't catch me, Sheriff! |
| `taunt_2.mp3` | I'll be back for supper! |
| `taunt_3.mp3` | Too slow, lawman! |
| `taunt_4.mp3` | Mind the chickens! |
| `taunt_5.mp3` | Tell the judge I said hey! |
| `throw_1.mp3` | Heads up! |
| `throw_2.mp3` | Catch! |
| `throw_3.mp3` | Think fast, Sheriff! |
| `tackled_1.mp3` | Oof! |
| `tackled_2.mp3` | Ow! Quit it! |
| `hides.mp3` | Shhh... |
| `peekaboo.mp3` | Peekaboo! |
| `bonked.mp3` | Ow! No fair! |
| `lassoed.mp3` | Whoa! Lemme go! |
| `cornered.mp3` | Aw, shucks... |
| `caught_early.mp3` | Hey! No fair! |
| `cuffed.mp3` | Aw, shucks. You got me. |
| `grocer.mp3` | Oops! Clean-up on Main Street! |
| `tower.mp3` | Can't reach me up here, Sheriff! |
| `hosed.mp3` | Whoa! Who turned on the hose?! |
| `truck.mp3` | Ooh, a milk truck! Don't mind if I do! |
| `chase_start.mp3` | Beep beep! So long, Sheriff! |
| `chase_crate.mp3` | Have some milk! |
| `chase_spinout.mp3` | Aw, nuts! I'll take the water tower! |
| `chase_bumped_1.mp3` | Hey! Watch the paint! |
| `chase_bumped_2.mp3` | Quit bumpin' me! |
| `chase_bumped_3.mp3` | Whoa whoa whoa! |

## Dewey  →  `audio/voices/dewey/`

| File | Line |
|---|---|
| `main_street_1.mp3` | Well golly, Sheriff! |
| `main_street_2.mp3` | Gee whiz! He went thataway! |
| `main_street_3.mp3` | Jumpin' Jehoshaphat! |
| `chicken_run_1.mp3` | Get BEHIND them hens, Sheriff! Hop right over 'em! |
| `chicken_run_2.mp3` | Never turn your back on that goat! |
| `rock_creek_1.mp3` | Swing across on them hooks with your rope, Sheriff! |
| `gone_fishin_1.mp3` | Them docks sink if you stand still, Sheriff! |

## Deputy Plum  →  `audio/voices/deputy/`

| File | Line |
|---|---|
| `earls_big_break_lose.mp3` | Gotcha, Earl! Back to the jailhouse! |
| `start.mp3` | Halt! Stop right there, Earl! |
| `aim_1.mp3` | Freeze! |
| `aim_2.mp3` | Hold it right there! |
| `aim_3.mp3` | Don't make me use this! |
| `missed.mp3` | Dagnabbit! Missed! |
| `fumble.mp3` | Now where'd that cork go? |
| `spotted.mp3` | I see you, Earl! |
| `bonked.mp3` | Hey! My hat! |

## When you play as Dewey  →  `audio/voices/dewey/`

| File | Line |
|---|---|
| `shazam.mp3` | SHAZAM! (bowling over a bird with the Lightning Soda) |
| `powerup.mp3` | Lightning Soda! Whoo-ee! |
| `hurt.mp3` | Owww-eee! (one of his hurt lines) |
| `rope_earl.mp3` | Hold still, Earl! Bzzt! |
| `<episode>_win.mp3` | his win line for that episode, e.g. `main_street_win.mp3` |

## Jim  →  `audio/voices/jim/`

| File | Line |
|---|---|
| `bird.mp3` | Coming through! (scattering birds on the mower) |
| `powerup.mp3` | Fire up the zero-turn! |
| `hurt.mp3` | Error four-oh-four: dignity not found! |
| `rope_earl.mp3` | Hold still, Earl. You need a rinse. |
| `<episode>_win.mp3` | his win line for that episode, e.g. `main_street_win.mp3` |

When you play as Dewey, the Sheriff takes over Dewey's street tips, so those
lines (`main_street_1.mp3` and so on) play from `audio/voices/sheriff/`.
