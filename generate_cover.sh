#!/bin/bash
# Generate cover images with text for epubs
# Author : H.J. Enneman
# Uses Image magick "convert" program

if [ "$1" ]; then
TEXT="$1"
else
echo "USAGE generate_cover.sh TEXT image"
exit 1
fi
cp $2 cover.jpeg

echo "$TEXT" > temp_text
FONT=/usr/lib64/X11/fonts/TTF/DejaVuSerif.ttf
FGCOLOR="black"
CONVERTSTRING=" -background white -fill ${FGCOLOR} -strokewidth 1 -stroke black -font ${FONT} -pointsize 30 label:@temp_text -gravity center cover.jpeg"

#  echo $CONVERTSTRING
convert $CONVERTSTRING
rm temp_text

exit 0

