#!/bin/bash
note=$(rofi -dmenu -p "Note rapide :")
if [ -n "$note" ]; then
    echo -e "- $(date '+%Y-%m-%d %H:%M')\n  - $note" >> ~/ObsidianVault/lafe/Note_rapide/$(date '+%Y-%m-%d').md
fi
