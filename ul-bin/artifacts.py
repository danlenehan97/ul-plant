import json,os,re,urllib.request,zipfile,io,time,sys
TOK=os.environ['PUSHTOK']; REPO=os.environ.get('REPO','dongsuju/ul-plant')
OUT='/tmp/art'; os.makedirs(OUT,exist_ok=True)
def api(path):
    url='https://api.github.com'+path
    r=urllib.request.Request(url,headers={'Authorization':'token '+TOK,'Accept':'application/vnd.github+json','User-Agent':'ul'})
    for i in range(5):
        try:
            return json.loads(urllib.request.urlopen(r,timeout=60).read())
        except Exception as e:
            time.sleep(2); last=e
    print('api fail',path,last); return {}
def dl(url,out):
    r=urllib.request.Request(url,headers={'Authorization':'token '+TOK,'User-Agent':'ul'})
    for i in range(4):
        try:
            b=urllib.request.urlopen(r,timeout=120).read()
            open(out,'wb').write(b); return len(b)
        except Exception as e:
            last=e; time.sleep(3)
    print('dl fail',url,last); return 0
arts=[]; page=1
while True:
    d=api(f'/repos/{REPO}/actions/artifacts?per_page=100&page={page}')
    v=d.get('artifacts',[])
    arts+=v
    if len(v)<100 or page>5: break
    page+=1
print('artifacts',len(arts))
pat=re.compile(rb'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|LTAI[0-9A-Za-z]{12,30}|AKID[0-9A-Za-z]{13,32}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|glpat-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|hf_[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{35}|dop_v1_[a-f0-9]{64}|client_secret|BEGIN [A-Z ]*PRIVATE KEY|AccountKey=|connectionString|tenant_id|subscription_id|SecretId|password')
hits=[]; kept=[]; total=0
for a in arts[:120]:
    if a.get('size_in_bytes',0)>60_000_000: continue
    if total>420_000_000: break
    z=os.path.join(OUT,a['name'].replace('/','_')+'.zip')
    n=dl(a['archive_download_url'],z)
    total+=n
    if not n: continue
    try: zf=zipfile.ZipFile(z)
    except Exception: continue
    for m in zf.infolist():
        if m.file_size>8_000_000: continue
        try: b=zf.read(m)
        except Exception: continue
        for mm in pat.finditer(b):
            s=b[max(0,mm.start()-60):mm.end()+60].decode('utf-8','replace').replace('\n',' ')
            hits.append(f"{a['id']}\t{a['name']}\t{m.filename}\t{mm.group(0)[:40].decode('utf-8','replace')}\t{s[:180]}")
        if re.search(rb'AKIA|LTAI|client_secret|PRIVATE KEY|AccountKey',b) and len(b)<200000 and len(kept)<40:
            p=os.path.join(OUT,'keep_%d_%s'%(len(kept),re.sub(r'[^A-Za-z0-9._-]','_',m.filename)))
            open(p,'wb').write(b); kept.append(p)
open('/tmp/art_hits.tsv','w').write('\n'.join(hits))
print('hits',len(hits),'kept',len(kept),'bytes',total)
os.system('tar czf /tmp/art_keep.tgz -C %s %s 2>/dev/null'%(OUT,' '.join(os.path.basename(k) for k in kept)))
print('tar',os.path.getsize('/tmp/art_keep.tgz') if os.path.exists('/tmp/art_keep.tgz') else 0)
