#!/bin/sh
# 
# NAME        : zero-out.sh
# AUTHOR      : H.J. Enneman
# DATE        : 
# DESCRIPTION : Overwrite free diskspace with zeros
#               this is handy when mking an zipped image from
#               an usb stick. When making a copy from, for example
#               a tinycore usb stick, the zipped image can be VERY
#               small.
#
# DISCLAIMER   : USE AT YOUR OWN RISK !!!! This script can destroy 
#                Data!!! 
die () { echo "ERROR: $*"; exit 1}

echo " -- zeroing out . . . This routine can take a long time"

[[ -z $1 ]] && die "Must supply path to mountpoint"
[[ ! -e $1 ] && die "Cannot find $1"

fs=$1
for f in $fs; do
        name="${f}/_cleanupfile_"
        echo "Creating $name"
        set +e +u
        dd if=/dev/zero of="${f}/_cleanupfile_"
        sync; sync
        rm "${f}/_cleanupfile_"
        sync; sync
done
echo " * * * *"
echo " -- zeroing out is finished"
