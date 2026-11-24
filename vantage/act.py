#!/usr/bin/env python3
"""Act on execution surfaces from the runner vantage. Reads vantage/act.json:
[{"ip":"1.2.3.4","port":10250,"kind":"kubelet"}, ...]
Executes read probes and writes JSONL with raw responses."""
import asyncio, json, os, ssl, sys

OUT = os.environ.get("OUT", "vantage/out/act.jsonl")
TLS = {2376, 6443, 10250, 10255, 9400, 8888, 8188, 8000, 8001, 8002, 5000, 9090, 8080, 443, 3000}

PATHS = {
    "kubelet": ["/pods", "/metrics", "/healthz", "/version", "/runningpods"],
    "kubelet_ro": ["/pods", "/metrics", "/healthz"],
    "apiserver": ["/version", "/healthz", "/livez", "/readyz", "/api/v1/nodes", "/api/v1/pods", "/apis"],
    "docker": ["/version", "/info", "/containers/json", "/images/json"],
    "dcgm": ["/metrics"],
    "ray": ["/api/version", "/api/jobs/", "/api/nodes", "/api/cluster_status"],
    "comfyui": ["/system_stats", "/object_info", "/queue", "/history"],
    "jupyter": ["/api", "/tree", "/hub/api", "/api/status"],
    "gpustack": ["/v1/models", "/v1/workers", "/v1/gpu-devices", "/v2/workers", "/api/v1/auth/login"],
    "vllm": ["/v1/models", "/health", "/metrics"],
    "ollama": ["/api/tags", "/api/version"],
    "nomad": ["/v1/agent/self", "/v1/nodes", "/v1/jobs"],
    "minio": ["/minio/health/live", "/"],
    "etcd": ["/version", "/health"],
    "slurm": ["/slurm/v0.0.38/nodes", "/slurm/v0.0.39/nodes"],
    "generic": ["/", "/version", "/health", "/api", "/status"],
}


async def fetch(ip, port, path, tls, timeout=6.0):
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        r, w = await asyncio.wait_for(
            asyncio.open_connection(ip, port, ssl=ctx if tls else None, limit=400000), timeout)
    except Exception as e:
        return {"path": path, "err": type(e).__name__}
    try:
        req = (f"GET {path} HTTP/1.1\r\nHost: {ip}:{port}\r\nUser-Agent: curl/8.4.0\r\n"
               f"Accept: */*\r\nConnection: close\r\n\r\n")
        w.write(req.encode()); await w.drain()
        data = await asyncio.wait_for(r.read(200000), 5.0)
        return {"path": path, "raw": data.decode("utf-8", "replace")[:20000],
                "len": len(data)}
    except Exception as e:
        return {"path": path, "err": "read:" + type(e).__name__}
    finally:
        try: w.close()
        except Exception: pass


async def one(entry):
    ip, port, kind = entry["ip"], int(entry["port"]), entry.get("kind", "generic")
    tls = entry.get("tls", port in TLS)
    paths = entry.get("paths") or PATHS.get(kind, PATHS["generic"])
    res = []
    for p in paths:
        r = await fetch(ip, port, p, tls)
        res.append(r)
        if "raw" not in r and p == paths[0]:
            # first path failed entirely: try opposite scheme once
            r2 = await fetch(ip, port, p, not tls)
            if "raw" in r2:
                res[-1] = r2; tls = not tls
    return {"ip": ip, "port": port, "kind": kind, "tls": tls, "results": res}


async def main():
    entries = json.load(open(os.environ.get("ACT","vantage/act.json")))
    sem = asyncio.Semaphore(int(os.environ.get("CONC", "40")))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    f = open(OUT, "w")

    async def run(e):
        async with sem:
            r = await one(e)
            f.write(json.dumps(r) + "\n"); f.flush()
            first = next((x for x in r["results"] if "raw" in x), {})
            head = (first.get("raw") or first.get("err", ""))[:160].replace("\n", " ")
            print(f"{e['ip']}:{e['port']} {e.get('kind')} -> {head}")

    await asyncio.gather(*[run(e) for e in entries], return_exceptions=True)
    f.close()

if __name__ == "__main__":
    asyncio.run(main())
