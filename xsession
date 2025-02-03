#!/bin/bash

setxkbmap "us,ru" -option "grp:caps_toggle"
xsetroot -solid "#000000"
# rescuetime &
slstatus &
# ## Hide cursor when typing
# xbanish &
xrandr --newmode "1680x1050_60.00"  146.25  1680 1784 1960 2240  1050 1053 1059 1089 -hsync +vsync
xrandr --addmode HDMI-1 1680x1050_60.00
exec dwm
