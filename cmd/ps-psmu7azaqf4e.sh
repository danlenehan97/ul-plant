#!/bin/bash
set -u
HD=/opt/fleet/bin/ps_hb.sh
echo "=== priv $(date -u) on $(cat /opt/fleet/prefix 2>/dev/null)"
sed -i 's#contents/cmd/#contents/pscmd/#g' "$HD" 2>/dev/null
grep -q '^B=' "$HD" || sed -i '2a B=/opt/fleet/bin' "$HD"
echo "hb cmd url now: $(grep -o 'contents/[a-z]*/' "$HD" | sort -u | tr '\n' ' ')"
echo "B line: $(grep -c '^B=' "$HD")"
ls -la /opt/fleet/bin/ | head -12
echo "supervisor:"; grep -m2 'gpu-intensity\|margs' /opt/fleet/bin/ps_sup.sh 2>/dev/null
echo "=== priv done"
