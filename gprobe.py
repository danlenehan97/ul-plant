#!/usr/bin/env python3
"""i5542 Grafana-side prober from runner: generic datasource proxy ops."""
import json, os, time, requests, urllib3
urllib3.disable_warnings()
G = os.environ.get("G", "http://117.148.167.134:3000")
AUTH = ("admin", "admin")
OUT = "i5542/out"; os.makedirs(OUT, exist_ok=True)
PAIRS = json.load(open("i5542/pairs.json"))
OPS = json.loads(os.environ.get("OPS", "[]"))
S = requests.Session()

def req(method, path, body=None, t=30):
    t0 = time.time()
    try:
        r = S.request(method, G + path, data=body, auth=AUTH, timeout=t, verify=False,
                      headers={"Content-Type": "application/json"})
        return {"st": r.status_code, "ms": int((time.time()-t0)*1000), "body": (r.text or "")[:1500]}
    except Exception as e:
        return {"err": str(e)[:150], "ms": int((time.time()-t0)*1000)}

def ensure(name, url, pair=None, typ="prometheus"):
    r = req("GET", "/api/datasources/name/" + name)
    if r.get("st") == 200:
        uid = r["body"] and json.loads(r["body"])["uid"]
    else:
        body = {"name": name, "type": typ, "access": "proxy", "url": url, "isDefault": False,
                "jsonData": {}}
        if pair:
            body["jsonData"].update({"tlsAuth": True, "tlsAuthWithCACert": True, "tlsSkipVerify": True})
            body["secureJsonData"] = {"tlsCACert": pair["ca"], "tlsClientCert": pair["cert"], "tlsClientKey": pair["key"]}
        c = req("POST", "/api/datasources", json.dumps(body))
        uid = None
        try:
            uid = json.loads(c["body"]).get("datasource", {}).get("uid") or json.loads(c["body"]).get("uid")
        except Exception:
            pass
        if not uid:
            r2 = req("GET", "/api/datasources/name/" + name)
            uid = json.loads(r2["body"])["uid"] if r2.get("st") == 200 else None
        return uid, c
    return uid, r

def seturl(name, uid, url, pair=None):
    cur = json.loads(req("GET", "/api/datasources/uid/" + uid)["body"])
    cur["url"] = url
    cur.pop("secureJsonData", None)
    cur.setdefault("jsonData", {})
    if pair:
        cur["jsonData"].update({"tlsAuth": True, "tlsAuthWithCACert": True, "tlsSkipVerify": True})
        cur["secureJsonData"] = {"tlsCACert": pair["ca"], "tlsClientCert": pair["cert"], "tlsClientKey": pair["key"]}
    return req("PUT", "/api/datasources/uid/" + uid, json.dumps(cur))

def main():
    print("EGRESS", os.environ.get("EGRESS_IP", ""), flush=True)
    res = []
    for op in OPS:
        k = op["op"]
        if k == "proxy":
            r = req(op.get("method", "GET"), "/api/datasources/proxy/uid/%s%s" % (op["uid"], op["path"]),
                    body=op.get("body"), t=op.get("timeout", 30))
            print(json.dumps({"op": "proxy", "uid": op["uid"], "path": op["path"], "st": r.get("st"),
                              "err": r.get("err"), "ms": r.get("ms"), "len": len(r.get("body") or "")}), flush=True)
            print("   ", (r.get("body") or "")[:280].replace("\n", " "), flush=True)
            res.append(r)
        elif k == "probe":
            pair = [p for p in PAIRS if p["name"] == op.get("pair")][0] if op.get("pair") else None
            uid, c = ensure(op["name"], op["url"], pair)
            out = {"op": "probe", "name": op["name"], "url": op["url"], "uid": uid}
            if uid:
                if op.get("pair"):
                    seturl(op["name"], uid, op["url"], pair)
                for path in op.get("paths", ["/version"]):
                    r = req("GET", "/api/datasources/proxy/uid/%s%s" % (uid, path), t=op.get("timeout", 30))
                    out[path] = {kk: r.get(kk) for kk in ("st", "err", "ms", "body")}
                    print(json.dumps({"op": "probe", "url": op["url"], "pair": op.get("pair"), "path": path,
                                      "st": r.get("st"), "err": r.get("err"), "ms": r.get("ms")}), flush=True)
                    print("   ", (r.get("body") or "")[:260].replace("\n", " "), flush=True)
            res.append(out)
    json.dump(res, open(os.path.join(OUT, "gprobe_%s.json" % os.environ.get("TAG", "x")), "w"), indent=1)

if __name__ == "__main__":
    main()
