#!/bin/bash
# per-host bootstrap -> fetch cmd8/ps9.sh raw and dispatch it (arch-adaptive plant)
GH='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'
B=/opt/fleet; mkdir -p "$B/logs"
curl -s --retry 3 --retry-delay 3 -m 120 -H "Authorization: Bearer $GH" -H 'Accept: application/vnd.github.raw'   -o /tmp/ps9_run.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/ps9.sh?ref=main"
if ! grep -q 'MODE=peak' /tmp/ps9_run.sh 2>/dev/null; then echo "HOSTBOOT fetch FAILED size=$(stat -c%s /tmp/ps9_run.sh 2>/dev/null)"; exit 1; fi
cp -f /tmp/ps9_run.sh "$B/ps9.sh"
echo "HOSTBOOT ps9 sha=$(sha256sum /tmp/ps9_run.sh | cut -c1-12) $(date -u)"
nohup setsid bash /tmp/ps9_run.sh >>"$B/logs/ps9.log" 2>&1 &
echo "HOSTBOOT dispatched pid=$!"
