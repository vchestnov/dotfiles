#!/bin/bash

NOTE_DIR="$HOME/dev/zk"
if [[ ! -d "$NOTE_DIR" ]]; then
    mkdir -p "$NOTE_DIR"
fi
NOTE_FILENAME="$NOTE_DIR/note_$(date +%Y_%m_%d).md"

if [[ ! -f $NOTE_FILENAME ]]; then
    echo "# Notes for $(date +%Y-%m-%d)" > $NOTE_FILENAME
fi

vim -c "norm Go" \
    -c "norm Go## $(date +%H:%M)" \
    -c "norm G2o" \
    -c "norm zz" \
    -c "startinsert" $NOTE_FILENAME
