#!/bin/sh
# Rebuilds art/sprites/sheriff.png from these PixelLab GIFs (needs python3 + Pillow).
# Run from the project folder:  sh art/source/pixellab/sheriff/build.sh
# The ":a-b" after a file picks which of its frames to use.
# No lasso art at this size: the lasso row uses the throw (the double-resolution
# Sheriff, art/source/pixellab/sheriff@2x/build.sh, has a real lasso throw).
S=art/source/pixellab/sheriff
python3 tools/pixellab_gifs.py sheriff art/sprites/sheriff.png --fix-navy \
  idle=$S/idle.gif run=$S/run.gif jumpall=$S/jump.gif \
  throw=$S/throw.gif aim=$S/throw.gif:0-3 hurt=$S/hurt.gif:2-6 \
  victory=$S/celebrate.gif:1-7 slide=$S/crouch.gif:3-4 skid=$S/crouch.gif:1-2 \
  tiphat=$S/tiphat.gif climb=$S/climb.gif:1-8 climb_idle=$S/climb.gif:3-3 \
  lasso=$S/throw.gif
