#!/bin/sh
# 
# NAME        : wallpaper.sh
# DESCRIPTION : Change the desktop background
# AUTHOR      : H.J. Enneman
# DATE        : 2016
# REQUIREMENTS: The program shuf, and a .wallpaper file which contains the 
#               the directory with the pictures.
#               That way you can easily switch between directories.
# TESTED ON   : Ubuntu/Mint
# NOTES       : Slideshow on Ubuntu/Mint chokes when there are
#               too many pictures. So I made this and created
#               a crontab entry, so the background switched every
#               15 minutes
# ------------------------------------------------------------------------

sessionfile=$(find "${HOME}/.dbus/session-bus/" -type f)
export $(grep "DBUS_SESSION_BUS_ADRESS" "${sessionfile}" | sed '/^#/d')

# Read the directory where the images are.
DIR=$(cat ${HOME}/.wallpaper) 

# Select a random pictures
PIC=$(ls $DIR/*.jpg | shuf -n1)

# set the path to the background image
gsettings set org.gnome.desktop.background picture-uri file://"${PIC}"

# Wallpaper display settings
# 'none', 'wallpaper', 'centered', 'scaled', 'stretched', 'zoom', 'spanned'
gsettings set org.gnome.desktop.background picture-options 'scaled'
