#!/usr/bin/env python3
"""Vantage port/protocol scanner — runs on GitHub-hosted runner (clean egress).

Reads vantage/targets.txt, scans shard, writes JSONL per IP with banner +
protocol fingerprints for GPU/exec surfaces.
"""
import asyncio, json, os, re, socket, ssl, sys, time

PORTS = [int(x) for x in os.environ.get("PORTS", "22,2375,2376,6443,10250,10255,9400,8265,8888,8188,8000,8001,8002,11434,4646,6817,5000,3000,9090,8080,80,443").split(",")]
CONC = int(os.environ.get("CONC", "200"))
TIMEOUT = float(os.environ.get("TMO", "3.5"))
SHARD = int(os.environ.get("SHARD", "0"))
SHARDS = int(os.environ.get("SHARDS", "1"))
MAX_HOSTS = int(os.environ.get("MAX_HOSTS", "0"))
OUT = os.environ.get("OUT", "vantage/out/shard.jsonl")

GPU_RE = re.compile(rb"nvidia|geforce|rtx\s?\d|cuda|dcgm|a100|h100|a800|tesla|mi300|l40", re.I)
TLS_PORTS = {2376, 6443, 10250, 10255, 9400, 8888, 8188, 8000, 8001, 8002, 5000, 9090, 8080, 443}
BANNER_PORTS = {22, 6817, 23, 3306, 5432, 6379}

PROBES = {
    2375: [("GET", "/version"), ("GET", "/info"), ("GET", "/containers/json")],
    2376: [("GET", "/version"), ("GET", "/info"), ("GET", "/containers/json")],
    6443: [("GET", "/version"), ("GET", "/api/v1/nodes")],
    10250: [("GET", "/pods"), ("GET", "/metrics"), ("GET", "/healthz")],
    10255: [("GET", "/pods")],
    9400: [("GET", "/metrics")],
    8265: [("GET", "/api/version"), ("GET", "/api/jobs/")],
    8888: [("GET", "/api"), ("GET", "/tree"), ("GET", "/hub/api")],
    8188: [("GET", "/system_stats"), ("GET", "/object_info")],
    11434: [("GET", "/api/tags")],
    4646: [("GET", "/v1/agent/self"), ("GET", "/v1/nodes")],
    5000: [("GET", "/health"), ("GET", "/api/2.0/mlflow/versions")],
    3000: [("GET", "/api/config")],
    9090: [("GET", "/api/v1/targets")],
    8080: [("GET", "/")],
    8000: [("GET", "/v1/models"), ("GET", "/")],
    8001: [("GET", "/")],
    8002: [("GET", "/")],
}


async def http_get(ip, port, path, use_tls, deadline=4.0):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        r, w = await asyncio.wait_for(
            asyncio.open_connection(ip, port, ssl=ctx if use_tls else None, limit=200000), deadline)
    except Exception as e:
        return None, "tls_error:" + type(e).__name__ if use_tls else None
    try:
        req = f"GET {path} HTTP/1.0\r\nHost: {ip}\r\nUser-Agent: curl/8.4.0\r\nConnection: close\r\n\r\n"
        w.write(req.encode()); await w.drain()
        data = await asyncio.wait_for(r.read(8192), 3.0)
        return data, None
    except Exception as e:
        return None, "read_error:" + type(e).__name__
    finally:
        try: w.close()
        except Exception: pass


async def banner(ip, port, deadline=3.0):
    try:
        r, w = await asyncio.wait_for(asyncio.open_connection(ip, port, limit=4096), deadline)
    except Exception:
        return None
    try:
        data = await asyncio.wait_for(r.read(1024), 2.0)
        return data
    except Exception:
        return b""
    finally:
        try: w.close()
        except Exception: pass


async def tcp_open(ip, port, deadline):
    try:
        r, w = await asyncio.wait_for(asyncio.open_connection(ip, port), deadline)
        w.close()
        return True
    except Exception:
        return False


async def probe_port(ip, port, sem):
    async with sem:
        if not await tcp_open(ip, port, TIMEOUT):
            return None
        rec = {"port": port}
        if port in BANNER_PORTS:
            b = await banner(ip, port)
            if b:
                rec["banner"] = b[:200].decode("utf-8", "replace").strip()
            return rec
        tls = port in TLS_PORTS
        got = None
        # try plain first for non-standard TLS, TLS first for standard ones
        order = [tls, not tls]
        for use_tls in order:
            data, err = await http_get(ip, port, "/", use_tls)
            if err:
                rec.setdefault("errs", []).append(f"{'tls' if use_tls else 'plain'}:{err}")
                continue
            if data:
                got = (use_tls, data)
                break
        if got:
            use_tls, data = got
            rec["tls"] = use_tls
            rec["http"] = decode_http(data)
            rec["gpu"] = bool(GPU_RE.search(data))
        # specific probes
        if port in PROBES:
            probes = []
            for method, path in PROBES[port]:
                data, err = await http_get(ip, port, path, rec.get("tls", tls))
                if data:
                    probes.append({"path": path, "resp": decode_http(data)})
            if probes:
                rec["probes"] = probes
                if any(GPU_RE.search(json.dumps(p).encode()) for p in probes):
                    rec["gpu"] = True
        return rec


def decode_http(data):
    try:
        txt = data.decode("utf-8", "replace")
    except Exception:
        return {"raw": data[:120].hex()}
    head, _, body = txt.partition("\r\n\r\n")
    lines = head.split("\r\n")
    status = lines[0] if lines else ""
    hdrs = {}
    for ln in lines[1:]:
        if ":" in ln:
            k, v = ln.split(":", 1)
            hdrs[k.strip().lower()] = v.strip()[:120]
    m = re.search(r"<title>(.*?)</title>", body, re.I | re.S)
    out = {"status": status[:120], "server": hdrs.get("server", ""),
           "ct": hdrs.get("content-type", ""), "loc": hdrs.get("location", "")}
    if m:
        out["title"] = m.group(1)[:120]
    out["body"] = body[:400].replace("\n", " ")
    return out


async def main():
    tf = os.environ.get("TARGETS", "vantage/targets.txt")
    targets = [l.strip() for l in open(tf) if l.strip()]
    mine = [t for i, t in enumerate(targets) if i % SHARDS == SHARD]
    if MAX_HOSTS:
        mine = mine[:MAX_HOSTS]
    sem = asyncio.Semaphore(CONC)
    t0 = time.time()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    n_open = 0
    with open(OUT, "w") as f:
        async def one(ip):
            nonlocal n_open
            recs = await asyncio.gather(*[probe_port(ip, p, sem) for p in PORTS])
            recs = [r for r in recs if r]
            if recs:
                n_open += 1
                f.write(json.dumps({"ip": ip, "ports": recs}) + "\n")
                f.flush()
        await asyncio.gather(*[one(ip) for ip in mine], return_exceptions=True)
    print(f"DONE shard={SHARD}/{SHARDS} hosts={len(mine)} alive={n_open} secs={int(time.time()-t0)}")

if __name__ == "__main__":
    asyncio.run(main())
