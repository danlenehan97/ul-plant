#!/bin/bash
# ps9 dispatcher — fetch the tuned plant and (re)apply it a few times so a racing
# legacy @reboot installer cannot win. Safe to run repeatedly: ps9.sh is idempotent+flock'd.
B=/opt/fleet; mkdir -p "$B/state" "$B/logs"
GH='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'
curl -s --retry 4 --retry-delay 5 -m 120 -H "Authorization: Bearer $GH" -H 'Accept: application/vnd.github.raw' \
  -o /tmp/ps9_run.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/ps9.sh?ref=main"
if ! grep -q 'ps9_ver' /tmp/ps9_run.sh 2>/dev/null; then echo "ps9 fetch FAILED"; exit 1; fi
cp -f /tmp/ps9_run.sh "$B/ps9.sh"
( for k in 1 2 3 4 5 6; do sleep 60; bash /tmp/ps9_run.sh >>"$B/logs/ps9_dispatch.log" 2>&1; done ) >/dev/null 2>&1 &
echo "ps9 dispatched pid=$!"
