#!/bin/sh
# Builds art/sprites/jim@2x.png (double-resolution Jim, 96x128 frames) from the
# PixelLab export in this folder, then the normal-size art/sprites/jim.png from it
# (needs python3 + Pillow). Run from the project folder:
#   sh "art/source/pixellab/jim@2x/build.sh"
# The ":a-b" after a folder picks which of its frames to use (0 = frame_000.png).
# Left out: the belly-flop slide frames (2-5), the throw follow-through.
# For now "run" uses the walk (there is no Running animation yet), and "victory"
# uses the sunglasses-and-point animation, which faces the camera.
P="art/source/pixellab/jim@2x"
A="$P/Idle/animations"
TIPHAT=$(echo "$A"/Jim_facing_right_in_side_view_raises_his_right_han)
WIN=$(echo "$A"/Raise_both_hands_to_adjust_sunglasses_on_the_face)
THROW=$(echo "$P"/facing_east_arm_ba/animations/Throw_Object)
CLIMB=$(echo "$P"/Create_one_96128_pi_2/animations/*)
HOSE=$(echo "$P"/Side_view_facing_rig/animations/*)
TAUNT=$(echo "$P"/Jim_stands_facing_ri/animations/*)
python3 tools/pixellab_gifs.py jim art/sprites/jim@2x.png --scale=2 --pin-feet --anchor=body --despeckle \
  idle="$A/Breathing_Idle/east" run="$A/Walking/east" jumpall="$A/Running_Jump/east" \
  throw="$THROW/east:1-4" aim="$THROW/east:0-2" hurt="$A/Taking_Punch/east:1-2" \
  victory="$WIN/south:3-8" slide="$A/Slide/east:1-1" skid="$A/Slide/east:0-1" \
  tiphat="$TIPHAT/east:2-5" taunt="$TAUNT/east:3-6" \
  climb="$CLIMB/north:0-7" climb_idle="$CLIMB/north:0-0" lasso="$HOSE/east:1-8"
python3 tools/half_sheet.py art/sprites/jim@2x.png art/sprites/jim.png
