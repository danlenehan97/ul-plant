#!/bin/bash
set +e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
log(){ echo "$@"; }
log "### START8 $(date -u +%FT%TZ)"
log "### MOUNTS"; mount 2>/dev/null | grep -viE 'proc|sysfs|cgroup|devpts|tmpfs|overlay|shm' | head -25
log "### EXPORTS"; cat /etc/exports 2>/dev/null | head -10; exportfs -v 2>/dev/null | head -10; ls /etc/fstab && cat /etc/fstab | head -15
log "### NFS-CLIENT"; cat /proc/mounts | grep -E 'nfs|cifs' | head -5
log "### FSCAN-VCC"
python3 - <<'PY'
import socket,concurrent.futures,sys,time
hosts=["192.168.0.20","192.168.0.21","192.168.0.22","192.168.0.24","192.168.0.28","192.168.0.30","192.168.0.31"]
ports=list(range(1,65536))
def chk(a):
    h,p=a
    s=socket.socket(); s.settimeout(0.65)
    try:
        r=s.connect_ex((h,p))
        if r==0: return (h,p)
    except Exception: pass
    finally:
        s.close()
    return None
out={h:[] for h in hosts}
for h in hosts:
    t0=time.time()
    with concurrent.futures.ThreadPoolExecutor(700) as ex:
        for r in ex.map(chk,[(h,p) for p in ports],chunksize=128):
            if r: out[h].append(r[1]); print("OPENP",h,r[1],flush=True)
    print("SCANDONE",h,len(out[h]),round(time.time()-t0,1),flush=True)
open('/root/ul_farmfan/fullscan.txt','w').write("\n".join(f"{h} {p}" for h in out for p in sorted(out[h]))+"\n")
PY
log "### BANNERS"
while read -r h p; do
  [ -z "$h" ] && continue
  b=$(timeout 4 bash -c "exec 3<>/dev/tcp/$h/$p; printf 'GET / HTTP/1.0\r\n\r\n' >&3; timeout 2 head -c 160 <&3" 2>/dev/null | tr -d '\r' | tr '\n' ' ')
  log "B $h:$p :: ${b:0:150}"
done < /root/ul_farmfan/fullscan.txt
log "### SSH-HISTORY"; grep -rhoE 'ssh [^ ]*@(192\.168\.[0-9.]+|vcc[^ ]*)' /root/.bash_history /home/*/.bash_history /root/.ssh/config 2>/dev/null | sort -u | head -10
log "### ANOTHER-KEYS"; ls -la /root/.ssh/*.pub /home/*/.ssh/*.pub 2>/dev/null | head; grep -h "ssh-" /root/.ssh/authorized_keys 2>/dev/null | awk '{print $1, $3}' | sort -u | head -12
log "### DONE8 $(date -u +%FT%TZ)"
