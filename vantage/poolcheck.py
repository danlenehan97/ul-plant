#!/usr/bin/env python3
"""Pool-side verification for the canonical wallet after re-point.
Reads public pool APIs and prints worker rows. No secrets."""
import json, os, sys, urllib.request, time

W = "prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz"
PX = os.environ.get("PREFIX", "ul-t2-123-184-7-135")
OUT = sys.stdout


def get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8.4.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


for i in range(3):
    print("===== attempt %d %s" % (i + 1, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))
    try:
        d = json.loads(get("https://pool.kryptex.com/prl/api/v3/miner/workers/" + W))["results"]
    except Exception as e:
        print("kryptex err", e); d = []
    hits = 0
    for r in d:
        w = r.get("worker", "")
        if PX in w or "123-184" in w:
            hits += 1
            print("KRYPTEX", w, r.get("status"), "valid=%s" % r.get("valid"),
                  "last_share=%s" % r.get("last_share"),
                  "hr30m=%s" % r.get("avg_hashrate_30m"), "agent=%s" % r.get("agent"))
    print("KRYPTEX hits=%d total=%d" % (hits, len(d)))
    try:
        a = json.loads(get("https://pearlhash.xyz/api/account/" + W))
    except Exception as e:
        print("pearlhash err", e); a = {}
    ws = a.get("connected_workers") or []
    ph = 0
    print("PEARLHASH total_workers=%d estimated_hashrate_15s=%s" % (
        len(ws), a.get("estimated_hashrate_15s") or a.get("hashrate") or "?"))
    for w in ws:
        n = w.get("worker_name") or ""
        if PX in n or "123-184" in n:
            ph += 1
            print("PEARLHASH", n, json.dumps(w)[:260])
    print("PEARLHASH hits=%d" % ph)
    if hits or ph:
        if i < 2:
            time.sleep(45)
    else:
        time.sleep(20)
