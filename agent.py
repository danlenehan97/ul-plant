import base64,json,os,subprocess,time,urllib.request,sys
T=os.environ.get('GHT','');R='dongsuju/ul-plant'
BASE='https://api.github.com/repos/'+R+'/contents/'
def api(url,data=None,method='GET'):
    req=urllib.request.Request(url,data=json.dumps(data).encode() if data is not None else None,method=method)
    req.add_header('Authorization','token '+T);req.add_header('Accept','application/vnd.github+json');req.add_header('Content-Type','application/json')
    op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with op.open(req,timeout=60) as r: return json.loads(r.read().decode() or '{}')
def get(p):
    d=api(BASE+p+'?ref=main'); return base64.b64decode(d['content']).decode('utf-8','replace'), d.get('sha')
def put(p,txt,msg='ul5685 out'):
    body={'message':msg,'content':base64.b64encode(txt.encode()).decode(),'branch':'main'}
    try:
        _,sha=get(p); body['sha']=sha
    except Exception: pass
    return api(BASE+p,body,'PUT')
cur=''
open('/tmp/ul5685_agent.log','a').write('agent start %s\n'%time.time())
while True:
    try:
        c,_=get('ul5685/cmd')
        if c.strip() and c.strip()!=cur:
            cur=c.strip()
            open('/tmp/ul5685_agent.log','a').write('run: %s\n'%cur[:200])
            try:
                p=subprocess.run(['bash','-lc',c],capture_output=True,timeout=1800)
                out='### EXIT %d\n'%p.returncode+p.stdout.decode('utf-8','replace')+p.stderr.decode('utf-8','replace')
            except subprocess.TimeoutExpired as e:
                out='### TIMEOUT\n'+(e.stdout or b'').decode('utf-8','replace')
            out=out[-90000:]
            try: put('ul5685/out.txt',out)
            except Exception as e: open('/tmp/ul5685_agent.log','a').write('put fail %r\n'%e)
    except Exception as e:
        open('/tmp/ul5685_agent.log','a').write('poll fail %r\n'%e)
    time.sleep(8)
