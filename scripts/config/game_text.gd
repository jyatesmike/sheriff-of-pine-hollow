# =============================================================================
#  GAME TEXT — every name, sign and line of dialogue in the game.
#  Edit anything in quotes, save, and run the game. Nothing else needs changing.
#
#  Name slots: write {town}, {sheriff}, {earl}, {dewey}, {jim} or {deputy} inside any
#  line and the name from NAMES below is filled in. Use capitals ({TOWN},
#  {EARL}...) for an all-caps version, e.g. on signs.
#  Keep the quotes, commas and brackets as they are.
# =============================================================================
class_name GameText
extends RefCounted


# --- The cast and the town ----------------------------------------------------
const NAMES := {
	"town": "Pine Hollow",
	"sheriff": "Sheriff",
	"earl": "Earl",
	"dewey": "Dewey",
	"deputy": "Deputy Plum",
	"jim": "Jim",
}

# The 12 shop signs painted on Main Street (left to right, then repeating).
const SHOP_SIGNS := [
	"BARBER", "DINER", "GAS", "GROCERY", "HARDWARE", "COURTHOUSE",
	"DRUGS", "POST OFFICE", "FEED & SEED", "HOTEL", "BANK", "FIRE DEPT",
]


# --- Who you play as ---------------------------------------------------------------
#  Pick on the title screen (PLAYING AS). In a level, {sheriff} always means
#  whoever you're playing, so Earl taunts Dewey or Jim by name.
#  label    : shown on the title screen
#  win      : said when you win, one per episode (1 to 7, the jail one is skipped)
#  hurt     : said now and then when you get hit
#  powerup  : said when you grab your power-up
#  bird     : said when you bowl over a chicken, goose or duck while powered up
#  rope_earl: said when your rope catches Earl
const HEROES := {
	"sheriff": {
		"label": "{sheriff}",
		"win": [],                # the episode's own "win" line (in LEVELS) is used
		"hurt": [],
		"powerup": "",
		"bird": [],
		"rope_earl": "",
	},
	"dewey": {
		"label": "{dewey}",
		"win": ["Gollll-ly! I caught him!", "Them hens is home safe!", "Well I'll be! Rocks and all!",
			"You're soakin' wet, {earl}!", "", "Shazam! Best day at the fair ever!", "All aboard for jail, {earl}!"],
		"hurt": ["Owww-eee!", "Gaw-lee, that smarts!", "Golly!"],
		"powerup": "Lightning Soda! Whoo-ee!",
		"bird": ["SHAZAM!"],
		"rope_earl": "Hold still, {earl}! Bzzt!",
	},
	"jim": {
		"label": "{jim}",
		"win": ["Looks like {earl} had a bug in his escape plan.", "Hens compiled and deployed. Back to the coop.",
			"Have you tried turning it off and on again, {earl}?", "You're all wet, {earl}. Just like my lawn.",
			"", "Mowed in perfect stripes. Unlike your getaway, {earl}.", "Process terminated. End of the line, {earl}."],
		"hurt": ["Error four-oh-four: dignity not found!", "Ow! That's a bug, not a feature!", "Ctrl-Z! Ctrl-Z!"],
		"powerup": "Fire up the zero-turn!",
		"bird": ["Coming through!", "Mind the blades!", "Beep beep!"],
		"rope_earl": "Hold still, {earl}. You need a rinse.",
	},
}

# The power-ups (only their own character can pick them up).
const POWERUPS := {
	"dewey": "LIGHTNING SODA",
	"jim": "ZERO-TURN MOWER",
}


# --- Levels ----------------------------------------------------------------------
#  name / episode / blurb : shown on the intro card
#  sign       : the two lines on the wooden sign at the start of the level
#  start      : what Earl shouts as the level begins
#  win        : said when you win     lose : said when you lose
#  dewey      : Dewey's cheers, in the order you pass him
const LEVELS := {
	"main_street": {
		"name": "Main Street",
		"episode": "Episode 1 - \"The Jailbird Flies\"",
		"blurb": ["{earl} slipped out of the jailhouse again.", "Chase him down before he leaves town!"],
		"sign": ["{TOWN}", "TOWN LIMIT"],
		"start": "So long, {sheriff}!",
		"win": "Come on, {earl}. Supper's waiting.",
		"lose": "Toodle-oo, {sheriff}!",
		"dewey": ["Well golly, {sheriff}!", "Gee whiz! He went thataway!", "Jumpin' Jehoshaphat!"],
	},
	"chicken_run": {
		"name": "The Chicken Run",
		"episode": "Episode 2 - \"Fowl Play\"",
		"blurb": ["{earl} let the Miller hens loose and ran for it.", "Herd them home, ride the hay wagon, mind the goat!"],
		"sign": ["MILLER FARM", "KEEP OUT"],
		"start": "Oopsie, I let the hens out!",
		"win": "Next time, leave the hens out of it.",
		"lose": "Cluck cluck, {sheriff}!",
		"dewey": ["Get BEHIND them hens, {sheriff}! Hop right over 'em!", "Never turn your back on that goat!"],
	},
	"rock_creek": {
		"name": "Rock Creek",
		"episode": "Episode 3 - \"Rocks Away\"",
		"blurb": ["{earl}'s loose in the Rock Creek canyon.", "Dodge the rockslide, ride the mine cart, throw rocks (F/X)!"],
		"sign": ["ROCK CREEK", "BRIDGE OUT"],
		"start": "Heads up, {sheriff}!",
		"win": "You throw a mean rock, {sheriff}.",
		"lose": "Rock-a-bye, {sheriff}!",
		"dewey": ["Swing across on them hooks with your rope, {sheriff}!"],
		"vehicle": "Mine cart! All aboard the Earl Express!",
		"tower": "Nyah nyah! Can't get me up here!",
		"tower_hint": "I'll knock him down with a rock!",
	},
	"gone_fishin": {
		"name": "Gone Fishin'",
		"episode": "Episode 4 - \"The Big One Got Away\"",
		"blurb": ["{earl}'s makin' a getaway across Pine Lake.", "Paddle the canoe, hop the docks, then reel him in!"],
		"sign": ["PINE LAKE", "NO SWIMMING"],
		"start": "Last one in's a rotten egg!",
		"win": "You're all wet, {earl}.",
		"lose": "Better luck next cast, {sheriff}!",
		"dewey": ["Them docks sink if you stand still, {sheriff}!"],
		"vehicle": "Row, row, row your boat! See ya, {sheriff}!",
	},
	"earls_big_break": {
		"name": "{earl}'s Big Break",
		"episode": "Episode 5 - \"A Deputy's Duty\"",
		"blurb": ["This time YOU are {earl}, bustin' loose at night!", "Dodge the flashlights, shake the hound, catch the midnight freight!"],
		"sign": ["{TOWN}", "COUNTY LINE"],
		"start": "So long, jailhouse!",
		"win": "Free as a bird... for now.",
		"lose": "Gotcha, {earl}! Back to the jailhouse!",
		"dewey": [],
	},
	"county_fair": {
		"name": "The County Fair",
		"episode": "Episode 6 - \"Step Right Up\"",
		"blurb": ["{earl}'s loose at the {town} County Fair!", "Ride the Ferris wheel, win the pie contest, catch him in the bumper cars!"],
		"sign": ["COUNTY FAIR", "THIS WAY"],
		"start": "Whee! Cotton candy's on you, {sheriff}!",
		"win": "Ride's over, {earl}.",
		"lose": "Better luck at the ring toss, {sheriff}!",
		"dewey": ["Ride the Ferris wheel over the fence, {sheriff}!"],
		"vehicle": "Bumper cars! Catch me if you can!",
	},
	"last_train": {
		"name": "The Last Train",
		"episode": "Episode 7 - \"End of the Line\"",
		"blurb": ["{earl} hopped the last train out of {town}.", "Run the car roofs, mind the tunnels, end of the line!"],
		"sign": ["", ""],
		"start": "All aboard the Earl Express, {sheriff}!",
		"win": "End of the line, {earl}. For real this time.",
		"lose": "Toot toot, {sheriff}! See ya next stop!",
		"dewey": [],
	},
}


# --- Things characters say during play ------------------------------------------------
const EARL_TAUNTS := [
	"Can't catch me, {sheriff}!", "I'll be back for supper!", "Too slow, lawman!",
	"Mind the chickens!", "Tell the judge I said hey!",
]
const EARL_THROWS := ["Heads up!", "Catch!", "Think fast, {sheriff}!"]
const EARL_HIDES := "Shhh..."
const EARL_PEEKABOO := "Peekaboo!"
const EARL_BONKED := "Ow! No fair!"
const EARL_LASSOED := "Whoa! Lemme go!"
const EARL_CORNERED := "Aw, shucks..."
const EARL_CAUGHT_EARLY := "Hey! No fair!"
const EARL_TACKLED := ["Oof!", "Ow! Quit it!"]
const EARL_CUFFED := "Aw, shucks. You got me."

const DEPUTY_START := "Halt! Stop right there, {earl}!"
const DEPUTY_AIM := ["Freeze!", "Hold it right there!", "Don't make me use this!"]
const DEPUTY_MISSED := "Dagnabbit! Missed!"
const DEPUTY_FUMBLE := "Now where'd that cork go?"
const DEPUTY_SPOTTED := "I see you, {earl}!"
const DEPUTY_BONKED := "Hey! My hat!"


# --- Main Street set-pieces -------------------------------------------------------------
const JAIL_SIGN := "{TOWN} JAIL"
const FIRE_SIGN := "FIRE DEPT"
const EARL_GROCER := "Oops! Clean-up on Main Street!"
const CAR_HINT := "HOP IN!"
const EARL_TOWER := "Can't reach me up here, {sheriff}!"
const SHERIFF_BELL_HINT := "Somebody ring that fire bell!"
const EARL_HOSED := "Whoa! Who turned on the hose?!"
const EARL_TRUCK := "Ooh, a milk truck! Don't mind if I do!"

# --- The car chase ------------------------------------------------------------------------
const CHASE_START := "Beep beep! So long, {sheriff}!"
const CHASE_EARL_CRATE := "Have some milk!"
const CHASE_EARL_BUMPED := ["Hey! Watch the paint!", "Quit bumpin' me!", "Whoa whoa whoa!"]
const CHASE_EARL_SPINOUT := "Aw, nuts! I'll take the water tower!"
const CHASE_TRUCK := "MILK"
const CHASE_SKID := "Skidded into the hay!"
const CHASE_PULL_OVER := "Pull over!"
const CHASE_CRASH := "Crash!"
const CHASE_HONK_TIP := "Bump! Use the siren (Shift)"
const CHASE_BUMP := "Bump %d/3!"
const CHASE_SPLASH := "Splash! Hit the ramp at full speed!"
const CHASE_SIGN_CURVE := "SLOW"
const CHASE_SIGN_RAMP := "BRIDGE OUT - FULL SPEED!"
const CHASE_FARM_STAND := "PIES"
const CHASE_CONTROLS := "RIGHT = GAS   LEFT = BRAKE   UP/DOWN = LANE   SHIFT = SIREN"


# --- The Chicken Run set-pieces -----------------------------------------------------------
const CR_GATE_SIGN := ["GATE OPENS WHEN", "ALL HENS ARE HOME"]
const CR_HENS := "HENS %d/%d"
const CR_HEN_HOME := "HOME! +100"
const CR_ALL_HOME := "ALL HENS HOME! +1000"
const CR_EARL_GATE := "Better herd them chickens, {sheriff}!"
const CR_EARL_FREE := "Much obliged for the head start!"
const CR_WAGON_HINT := "HOP ON!"
const CR_EARL_EGGS := ["Have an egg!", "Breakfast is served!", "Eggs-cuse me!"]
const CR_BARN_SIGN := "MILLER"
const CR_EARL_GOAT := "Yowch! Call off your goat!"
const CR_EARL_SLIPPERY := "Too slippery, {sheriff}! Hee hee!"
const CR_ROPE_FIRST := "ROPE HIM FIRST, THEN TACKLE!"

# --- Rock Creek set-pieces ----------------------------------------------------------------
const RC_EARL_SLIDE := "Look out below, {sheriff}!"
const RC_DUCK := "DUCK! (HOLD DOWN)"
const RC_JUMP := "JUMP THE BROKEN TRACK!"
const RC_EARL_HIT := ["Ow! My elbow!", "Quit it, {sheriff}!"]
const RC_EARL_KNOCKED := "Whoaaa! I'm fallin'!"

# --- Gone Fishin' set-pieces --------------------------------------------------------------
const GF_DUCK := "DUCK! (HOLD DOWN)"
const GF_ROCK := "SPLASH! JUMP OVER THE ROCKS!"
const GF_CURRENT := "PADDLE HARD!"
const GF_CAST := "PRESS F TO CAST!"
const GF_GO_END := "GO TO THE END OF THE PIER!"
const GF_HOOKED := "HOOKED HIM!"
const GF_REEL := "HOLD F TO REEL!"
const GF_LET_GO := "LET GO! HE'S PULLING!"
const GF_GET_READY := "HE'S ABOUT TO PULL..."
const GF_SNAP := "SNAP! CAST AGAIN!"
const GF_EARL_TUG := ["Heave!", "Not today!", "Pull, Earl, pull!"]
const GF_EARL_SNAP := "Ha! The one that got away!"

# --- Earl's Big Break set-pieces -----------------------------------------------------------
const NB_HOUND_NAME := "BLUE"          # painted over the kennel door
const NB_SPOTTED := "SPOTTED!"
const NB_WATCH_SHOUT := ["Who goes there?!", "Jailbreak! Jailbreak!", "I see you, {earl}!"]
const NB_HIDE_HINT := "UP = HIDE"
const NB_SIC_EM := "Sic 'im, Biscuit!"
const NB_SAUSAGE := "SAUSAGE! (F = TOSS)"
const NB_CARRYING := "SAUSAGES x%d"
const NB_LOST_SCENT := "LOST THE SCENT!"
const NB_HOWL := "AROOOO..."
const NB_DEPUTY_TRAIN := "Halt! Somebody stop that train!"
const NB_DEPUTY_RAVINE := "Dagnabbit! Come back here, {earl}!"
const NB_DUCK := "SLIDE UNDER! (SHIFT)"

# --- Townsfolk favors (one optional mini-goal per level) ------------------------------------
#  ask: said when you walk up   got: shown when you pick the thing up   thanks: when you bring it back
const FAVORS := {
	"main_street": {
		"ask": "Yoo-hoo, {sheriff}! The wind took my pie tin up on a rooftop!",
		"got": "AUNT'S PIE TIN!",
		"thanks": "Bless you, {sheriff}! Pie's on me!",
	},
	"chicken_run": {
		"ask": "Lost my lucky horseshoe up in the hayloft, {sheriff}.",
		"got": "LUCKY HORSESHOE!",
		"thanks": "Well I'll be! Much obliged.",
	},
	"rock_creek": {
		"ask": "A gust took my good hat clean up the canyon!",
		"got": "THE BARBER'S HAT!",
		"thanks": "My hat! Free haircut, any time!",
	},
	"gone_fishin": {
		"ask": "My lucky lure's out there on the water somewhere...",
		"got": "LUCKY LURE!",
		"thanks": "That's the one! They'll be bitin' now!",
	},
	"earls_big_break": {
		"ask": "Psst, {earl}! You seen my best scissors? Left 'em by the creek.",
		"got": "THE BARBER'S SCISSORS!",
		"thanks": "Well, for a jailbird you ain't half bad, {earl}.",
	},
	"county_fair": {
		"ask": "Step right up! Has anybody seen my megaphone?",
		"got": "THE BARKER'S MEGAPHONE!",
		"thanks": "LADIES AND GENTLEMEN... the {sheriff}!",
	},
	"last_train": {
		"ask": "My lantern rolled off down the line, {sheriff}!",
		"got": "THE CONDUCTOR'S LANTERN!",
		"thanks": "Couldn't run this train without it!",
	},
}

# --- Title screen and menus ----------------------------------------------------------------
const MENU := {
	"title_top": "SHERIFF OF",
	"title_main": "{TOWN}",
	"tagline": "A lawman's work is never done",
	"play": "PLAY",
	"continue": "CONTINUE - EPISODE %d",
	"episodes": "CHOOSE EPISODE",
	"settings": "SETTINGS",
	"names": "EDIT NAMES",
	"quit": "QUIT",
	"credits": "CREDITS",
	"map_title": "{TOWN} COUNTY",
	"map_help": "ARROWS = PICK A PLACE   JUMP = GO   ESC = BACK",
	"back": "BACK",
	"locked": "LOCKED",
	"best": "BEST %s   PIES %d/%d",
	"golden": "GOLDEN PIE",
	"not_played": "NOT PLAYED YET",
	"music_volume": "MUSIC",
	"sfx_volume": "SOUND EFFECTS",
	"voice_volume": "VOICES",
	"voices_on": "SPOKEN LINES",
	"screen_shake": "SCREEN SHAKE",
	"scanlines": "SCANLINES",
	"zoom": "GAME ZOOM",
	"zoom_auto": "AUTO",
	"fancy_effects": "LIGHTING AND EFFECTS",
	"fullscreen": "FULL SCREEN",
	"unlock_all": "ALL EPISODES UNLOCKED",
	"reset_progress": "ERASE PROGRESS",
	"controls_menu": "CONTROLS",
	"controls_help": "PICK ONE, THEN PRESS THE NEW KEY OR PAD BUTTON",
	"controls_wait": "PRESS A KEY OR PAD BUTTON...  (ESC = CANCEL)",
	"reset_controls": "RESET CONTROLS",
	"ctl_left": "MOVE LEFT",
	"ctl_right": "MOVE RIGHT",
	"ctl_up": "UP (CLIMB, HIDE, LANE)",
	"ctl_down": "DOWN (DUCK, LANE)",
	"ctl_jump": "JUMP",
	"ctl_action": "DASH / SLIDE / SIREN",
	"ctl_lasso": "LASSO",
	"ctl_throw": "THROW / CAST / TOSS",
	"ctl_pause": "PAUSE",
	"ctl_restart": "RESTART LEVEL",
	"reset_confirm": "PRESS AGAIN TO ERASE",
	"on": "ON",
	"off": "OFF",
	"names_help": "PICK A NAME, TYPE A NEW ONE, PRESS ENTER",
	"editing_help": "TYPE - ENTER TO KEEP - ESC TO CANCEL",
	"name_town": "TOWN",
	"name_sheriff": "SHERIFF",
	"name_earl": "ESCAPED CONVICT",
	"name_dewey": "TOWN KID",
	"name_deputy": "DEPUTY",
	"name_jim": "RETIRED PROGRAMMER",
	"playing_as": "PLAYING AS",
	"shop": "SHOP SIGN %d",
	"reset_names": "RESET ALL NAMES",
	"controls": "ARROWS = CHOOSE   JUMP / ENTER = OK   ESC = BACK",
	"pause_resume": "RESUME",
	"pause_restart": "START LEVEL OVER",
	"pause_checkpoint": "BACK TO CHECKPOINT",
	"pause_menu": "QUIT TO TITLE",
	"end_menu": "ESC = MENU",
}

# --- County Fair set-pieces ----------------------------------------------------------------
const CF_ARCH := "{TOWN} COUNTY FAIR"
const CF_TICKETS := "TICKETS"
const CF_FENCE_SIGN := "RIDES ONLY"
const CF_CONTEST_SIGN := "PIE EATING CONTEST"
const CF_CONTEST_HINT := "PRESS F TO ENTER!"
const CF_CONTEST_START := "Ladies and gentlemen, the pie-eating contest! On your marks!"
const CF_COUNTDOWN := ["1", "2", "3"]
const CF_MASH := "MASH F! EAT! EAT!"
const CF_CONTEST_WIN := "YOU WIN! FULL HEARTS!"
const CF_CONTEST_LOSE := "THE FARMER WINS!"
const CF_BUMPER_SIGN := "BUMPER CARS"
const CF_BUMP_HELP := "RAM EARL 3 TIMES! UP/DOWN = ROW"
const CF_BUMPS := "BUMPS %d/3"

# --- The Last Train set-pieces -------------------------------------------------------------
const LT_TUNNEL := "TUNNEL!"
const LT_GET_LOW := "GET DOWN OFF THE ROOFS!"
const LT_BONK := "BONK! STAY LOW IN TUNNELS!"

# --- Credits (shown from the title screen) -------------------------------------------------
const CREDITS := [
	"SHERIFF OF {TOWN}",
	"",
	"STARRING",
	"{SHERIFF}  -  THE LAW",
	"{EARL}  -  THE JAILBIRD",
	"{DEWEY}  -  THE GAS STATION KID",
	"{DEPUTY}  -  THE DEPUTY",
	"AND THE FOLKS OF {TOWN}",
	"",
	"MADE WITH GODOT ENGINE",
	"ALL ART, SOUND AND MUSIC MADE BY THE GAME'S OWN TOOLS",
	"",
	"THANKS FOR PLAYING!",
]

# --- Screens ---------------------------------------------------------------------------
const UI := {
	"showdown": "SHOWDOWN! TACKLE HIM 3 TIMES",
	"win_title_sheriff": "Gotcha, {earl}!",
	"win_title_earl": "{earl} got away!",
	"lose_title_sheriff": "{earl} got away!",
	"lose_title_earl": "Back to the jailhouse!",
	"next_level": "PRESS JUMP FOR THE NEXT LEVEL",
	"last_level": "THAT'S ALL FOR NOW - PRESS JUMP FOR THE TITLE SCREEN",
	"try_again": "PRESS JUMP OR R TO TRY AGAIN",
	"try_checkpoint": "JUMP = BACK TO THE CHECKPOINT   R = START OVER",
	"checkpoint": "CHECKPOINT!",
	"star": "SHERIFF STAR %d/%d! +500",
	"favor_done": "FAVOR DONE! +750",
	"medal_names": ["-", "BRONZE", "SILVER", "GOLD"],
	"favor": "FAVOR",
	"favor_yes": "DONE",
	"favor_no": "NOT DONE",
	"roped": "ROPED! +150",
	"roped_tackle": "ROPED! NOW TACKLE HIM!",
	"lasso_missed": "MISSED! WAIT TILL HE LANDS",
	"paused": "PAUSED",
	"closing_in": "CLOSING IN",
	"milk_truck": "MILK TRUCK",
	"deputy_near": "DEPUTY",
}
