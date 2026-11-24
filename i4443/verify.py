import json,os,time
import requests, urllib3
urllib3.disable_warnings()
B='http://117.148.167.134:3000'
TOK=os.environ['TOK']
S=requests.Session(); S.verify=False; S.headers.update({'Authorization':'Bearer '+TOK,'User-Agent':'ul-i4443','Connection':'close'})
OUT='i4443/out6'; os.makedirs(OUT,exist_ok=True)
def go(path,name,to=30,tries=4):
    for i in range(tries):
        try:
            r=S.get(B+path,timeout=to)
            open(f'{OUT}/{name}.raw','wb').write(r.content)
            print(name,r.status_code,len(r.content),r.content[:200],flush=True)
            return
        except Exception as e:
            print('retry',name,i,e,flush=True); time.sleep(1)
go('/api/user','user')
go('/api/search?limit=5','search',to=40)
go('/api/admin/stats','stats',to=40)
go('/api/serviceaccounts/search?perpage=20','sa_search',to=40)
print('EGRESS', requests.get('https://api.ipify.org',timeout=15).text)
