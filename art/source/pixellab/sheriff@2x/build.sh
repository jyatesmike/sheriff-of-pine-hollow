#!/bin/sh
# Builds art/sprites/sheriff@2x.png (double-resolution Sheriff, 96x128 frames) from
# the PixelLab export in this folder (needs python3 + Pillow). Run from the project
# folder:  sh "art/source/pixellab/sheriff@2x/build.sh"
# The ":a-b" after a folder picks which of its frames to use (0 = frame_000.png).
# Smeared frames (PixelLab motion blur) are left out: slide 3-4, punch 4.
P="art/source/pixellab/sheriff@2x"
A="$P/Idle/animations"
TIPHAT=$(echo "$A"/The_character_slowly_lifts*)
CHEER=$(echo "$A"/The_character_clenches_both*)
THROW=$(echo "$P"/about_to_throw_an_ob/animations/*)
CLIMB=$(echo "$P"/facing_away_north/animations/*)
LASSO=$(echo "$P"/facing_east_about_t/animations/*)
python3 tools/pixellab_gifs.py sheriff art/sprites/sheriff@2x.png --scale=2 --pin-feet --anchor=body \
  idle="$A/Idle/east" run="$A/Running/east" jumpall="$A/Running_Jump/east" \
  throw="$THROW/east:4-8" aim="$THROW/east:0-3" hurt="$A/Taking_Punch/east:1-3" \
  victory="$CHEER/east:2-7" slide="$A/Slide/east:1-2" skid="$A/Slide/east:0-1" \
  tiphat="$TIPHAT/east:2-7" climb="$CLIMB/north:0-7" climb_idle="$CLIMB/north:0-0" \
  lasso="$LASSO/east:1-8"
