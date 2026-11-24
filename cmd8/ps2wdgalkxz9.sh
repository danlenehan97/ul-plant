#!/bin/bash
( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i3478_roster.sh')" >/dev/null 2>&1 & )
echo "=== i3478 queued $(hostname) $(date -u)"
id; hostname; nvidia-smi -L
