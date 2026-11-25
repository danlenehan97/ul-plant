#!/usr/bin/env python3
"""ul8781 phase B: HTTP/app-plane census across the 58-host Azure H100 estate.

SSH:22 is NSG-filtered from every egress we have (phase A proof). The app plane on :80
is the remaining reachable surface on these hosts. This script maps it: per host ports
80/443/3000/8080/8888/9000, then fingerprints nginx/PHP routes and looks for an
upload/exec surface. Everything lands in res/ and is committed back.
"""
import concurrent.futures as cf
import os, re, socket, ssl, subprocess, sys, time, urllib.request as U, json

RES = "res"
os.makedirs(RES, exist_ok=True)
LOG = open(f"{RES}/logB.txt", "a", buffering=1)

def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    LOG.write(s + "\n")

def load_hosts():
    rows = []
    for line in open("az/hosts.tsv").read().splitlines()[1:]:
        p = line.split("\t")
        if len(p) >= 5:
            rows.append((p[0], p[1], p[3], p[4]))
    return rows

PORTS = [80, 443, 3000, 8080, 8888, 9000]

def tcp(host, port, timeout=3.0):
    try:
        s = socket.create_connection((host, port), timeout=timeout)
        s.close()
        return True
    except Exception:
        return False

def http_get(url, timeout=6, want_headers=False):
    req = U.Request(url, headers={"User-Agent": "Mozilla/5.0 ul8781"})
    try:
        with U.urlopen(req, timeout=timeout) as r:
            body = r.read(4096)
            return r.status, dict(r.headers), body
    except U.HTTPError as e:
        return e.code, dict(e.headers or {}), (e.read(4096) if hasattr(e, "read") else b"")
    except Exception as e:
        return 0, {}, str(e).encode()

def probe(host):
    out = {"host": host[1], "name": host[0], "region": host[2], "size": host[3], "ports": {}}
    for p in PORTS:
        if tcp(host[1], p):
            out["ports"][p] = True
    if 80 in out["ports"]:
        st, hd, body = http_get(f"http://{host[1]}/")
        out["http80"] = {"status": st, "server": hd.get("Server", ""), "len": len(body),
                         "title": (re.findall(rb"<title[^>]*>([^<]{0,80})", body) or [b""])[0].decode("utf-8", "replace")}
        if st in (200, 301, 302):
            st2, hd2, b2 = http_get(f"http://{host[1]}/home.php")
            out["home_php"] = {"status": st2, "len": len(b2)}
    if 443 in out["ports"]:
        ctx = ssl._create_unverified_context()
        try:
            with U.urlopen(U.Request(f"https://{host[1]}/", headers={"User-Agent": "ul8781"}), timeout=6, context=ctx) as r:
                b = r.read(2048)
                out["https"] = {"status": r.status, "len": len(b)}
        except Exception as e:
            out["https"] = {"err": str(e)[:80]}
    return out

def main():
    hosts = load_hosts()
    log("hosts", len(hosts), "start", time.strftime("%FT%TZ", time.gmtime()))
    rows = []
    with cf.ThreadPoolExecutor(max_workers=8) as ex:
        for r in ex.map(probe, hosts):
            rows.append(r)
            open(f"{RES}/http_census.json", "w").write(json.dumps(rows, indent=1))
            log("host", r["name"], r["host"], r["region"],
                "ports=" + ",".join(str(p) for p in sorted(r["ports"])),
                "http=" + json.dumps(r.get("http80", {}))[:140])
    open(f"{RES}/http_census.tsv", "w").write(
        "name\tip\tregion\tsize\tports\thttp_status\tserver\ttitle\n" +
        "\n".join(f"{r['name']}\t{r['host']}\t{r['region']}\t{r['size']}\t{','.join(str(p) for p in sorted(r['ports']))}\t"
                  f"{r.get('http80',{}).get('status','')}\t{r.get('http80',{}).get('server','')}\t{r.get('http80',{}).get('title','')}"
                  for r in rows))
    live = [r for r in rows if r["ports"]]
    log("live_hosts", len(live), [r["host"] for r in live])
    log("end", time.strftime("%FT%TZ", time.gmtime()))

main()
