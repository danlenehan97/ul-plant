#!/usr/bin/env python3
"""i5542 raw HTTP probe from runner: plain http and https, arbitrary paths, optional client cert."""
import json, os, ssl, socket, sys, time, requests, urllib3
urllib3.disable_warnings()
OUT = "i5542/out"; os.makedirs(OUT, exist_ok=True)
PAIRS = json.load(open("i5542/pairs.json"))
REQS = json.loads(os.environ.get("REQS", "[]"))

def call(url, pair=None, timeout=12, method="GET", body=None, ctype="application/json"):
    kw = {"verify": False, "timeout": timeout, "allow_redirects": False}
    if pair:
        import tempfile
        d = tempfile.mkdtemp()
        cp, kp, cap = (os.path.join(d, n) for n in ("c.pem", "k.pem", "ca.pem"))
        open(cp, "w").write(pair["cert"]); open(kp, "w").write(pair["key"]); open(cap, "w").write(pair["ca"])
        kw["cert"] = (cp, kp)
    t = time.time()
    try:
        r = requests.request(method, url, data=body, headers={"Content-Type": ctype} if body else {}, **kw)
        return {"url": url, "st": r.status_code, "ms": int((time.time()-t)*1000),
                "len": len(r.text), "body": (r.text or "")[:1500]}
    except Exception as e:
        return {"url": url, "err": str(e)[:150], "ms": int((time.time()-t)*1000)}

def main():
    print("EGRESS", os.environ.get("EGRESS_IP", ""), flush=True)
    out = []
    for q in REQS:
        pair = None
        if q.get("pair"):
            pair = [p for p in PAIRS if p["name"] == q["pair"]][0]
        r = call(q["url"], pair=pair, timeout=q.get("timeout", 12), method=q.get("method", "GET"),
                 body=q.get("body"))
        print(json.dumps({k: r.get(k) for k in ("url", "st", "err", "ms", "len")}), flush=True)
        print("   ", (r.get("body") or r.get("err") or "")[:300].replace("\n", " "), flush=True)
        out.append(r)
    json.dump(out, open(os.path.join(OUT, "http_%s.json" % os.environ.get("TAG", "x")), "w"), indent=1)

if __name__ == "__main__":
    main()
