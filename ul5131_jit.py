import json,socket,base64,os,concurrent.futures,ssl,urllib.request
T=json.load(open('gh/targets.json'))
hosts=T['targets'][:48]
def chk(ip,p,t=4):
    s=socket.socket(); s.settimeout(t)
    try: s.connect((ip,p)); return True
    except Exception: return False
    finally: s.close()
def one(item):
    name,ip=item
    op=[p for p in (22,80,443,3389,7681,8000,8080,8888,11434,9400,10250,6443) if chk(ip,p)]
    if op: print('OPEN',name,ip,op,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=24) as ex: list(ex.map(one,hosts))
ctx=ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
for u in ('https://20.125.42.21/','https://20.125.42.21:443/api/tags','https://20.125.42.21/v1/models','https://20.125.42.21:443/v1/models'):
    try:
        r=urllib.request.urlopen(urllib.request.Request(u,headers={'User-Agent':'curl/8'}),timeout=12,context=ctx)
        b=r.read(400)
        print('HTTP',u,r.status,dict(r.headers).get('Server'),b[:200],flush=True)
    except Exception as e: print('HTTPFAIL',u,type(e).__name__,str(e)[:120],flush=True)
import subprocess
print(subprocess.run(['bash','-lc','echo | openssl s_client -connect 20.125.42.21:443 -servername 20.125.42.21 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null'],capture_output=True,text=True).stdout,flush=True)
print('DONE')
