#!/usr/bin/env python3
"""i5542 direct vantage: TCP/TLS/HTTPS + client-cert auth against public h4 endpoints from runner egress."""
import json, os, socket, ssl, sys, time, requests, urllib3
urllib3.disable_warnings()
OUT = "i5542/out"; os.makedirs(OUT, exist_ok=True)
PAIRS = json.load(open("i5542/pairs.json"))
TARGETS = json.loads(os.environ.get("TARGETS", "[]"))
PATHS = json.loads(os.environ.get("PATHS", '["/version","/api/v1/nodes?limit=1"]'))

def tcp(host, port, t=6):
    s = socket.socket(); s.settimeout(t)
    t0 = time.time()
    try:
        s.connect((host, port)); return {"tcp": "open", "ms": int((time.time()-t0)*1000)}
    except Exception as e:
        return {"tcp": "err:%s" % e.__class__.__name__, "e": str(e)[:80]}
    finally:
        s.close()

def tls_peer(host, port, t=8):
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    try:
        with socket.create_connection((host, port), timeout=t) as s:
            with ctx.wrap_socket(s, server_hostname=host) as ss:
                c = ss.getpeercert()
                return {"tls": "ok", "subject": str(c.get("subject")), "issuer": str(c.get("issuer"))}
    except Exception as e:
        return {"tls": "err:%s" % e.__class__.__name__, "e": str(e)[:120]}

def https(host, port, path, pair=None, t=12):
    url = "https://%s:%s%s" % (host, port, path)
    kw = {"verify": False, "timeout": t}
    if pair:
        import tempfile
        d = tempfile.mkdtemp()
        cp, kp, cap = os.path.join(d, "c.pem"), os.path.join(d, "k.pem"), os.path.join(d, "ca.pem")
        open(cp, "w").write(pair["cert"]); open(kp, "w").write(pair["key"]); open(cap, "w").write(pair["ca"])
        kw["cert"] = (cp, kp)
    try:
        r = requests.get(url, **kw)
        return {"st": r.status_code, "len": len(r.text), "body": (r.text or "")[:800]}
    except Exception as e:
        return {"err": str(e)[:160]}

def main():
    print("EGRESS", os.environ.get("EGRESS_IP", ""), flush=True)
    res = []
    for tgt in TARGETS:
        host, port = tgt["host"], int(tgt["port"])
        r = {"target": tgt, **tcp(host, port)}
        print(tgt, r.get("tcp"), flush=True)
        if r.get("tcp") == "open":
            r.update(tls_peer(host, port))
            print("  tls", r.get("tls"), r.get("subject", "")[:80], flush=True)
            r["anon"] = [{"path": p, **https(host, port, p)} for p in PATHS]
            print("  anon", [a.get("st") or a.get("err", "")[:40] for a in r["anon"]], flush=True)
            if r.get("tls") == "ok":
                r["cert"] = {}
                for p in PAIRS:
                    out = [{"path": path, **https(host, port, path, p)} for path in PATHS]
                    r["cert"][p["name"]] = out
                    print("  ", p["name"], [o.get("st") or o.get("err", "")[:40] for o in out], flush=True)
        res.append(r)
    json.dump(res, open(os.path.join(OUT, "direct_%s.json" % os.environ.get("TAG", "x")), "w"), indent=1)

if __name__ == "__main__":
    main()
