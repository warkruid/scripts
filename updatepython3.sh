#!/bin/sh
# NAME        : updatepython3.sh
# AUTHOR      : ?? (Dont know where I got this one, stackoverflow maybe?)
# DESCRIPTION : Update python modules

sudo -H pip freeze --local | grep -v '^\-e' | cut -d = -f 1  | xargs -n1 sudo -H pip install -U

