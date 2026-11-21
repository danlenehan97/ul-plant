#!/usr/bin/env python3
# az/imdsprobe.py - mint IMDS identities on the host and fingerprint them zero-cost
import json, hashlib, urllib.request, urllib.parse, sys, time

IMDS = "http://169.254.169.254"
SUB = "21bcfd92-9348-4285-a51e-815d6e56bddf"
BATCH_ACCTS = [
    ("ulbatcheastus", "eastus"), ("ulbatchswedencentral", "swedencentral"),
    ("ulbatchbrazilsouth", "brazilsouth"), ("ulbatchitalynorth", "italynorth"),
    ("ulbatchpolandcentral", "polandcentral"), ("ulbatchwestus2", "westus2"),
]

def req(url, headers=None, method="GET", timeout=15):
    h = {"Metadata": "true"} if url.startswith(IMDS) else {}
    if headers:
        h.update(headers)
    r = urllib.request.Request(url, headers=h, method=method)
    op = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with op.open(r, timeout=timeout) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return -1, f"ERR {type(e).__name__}: {e}"

def mint(label, resource, client_id=None):
    q = {"api-version": "2018-02-01", "resource": resource}
    if client_id:
        q["client_id"] = client_id
    url = f"{IMDS}/metadata/identity/oauth2/token?" + urllib.parse.urlencode(q)
    code, body = req(url)
    print(f"MINT[{label}] http={code}")
    if code != 200:
        print("MINT_BODY " + body[:400].replace("\n", " "))
        return None
    try:
        d = json.loads(body)
    except Exception:
        print("MINT_PARSE_FAIL " + body[:300]); return None
    tok = d.get("access_token", "")
    print(f"MINT_META[{label}] client_id={d.get('client_id')} resource={d.get('resource')} "
          f"expires_on={d.get('expires_on')} token_len={len(tok)} sha256_16={hashlib.sha256(tok.encode()).hexdigest()[:16]}")
    open(f"/tmp/imds_{label}.tok", "w").write(tok)
    return tok

def probe(label, tok, url, extra=None):
    if not tok:
        print(f"PROBE_SKIP[{label}] no token"); return
    h = {"Authorization": "Bearer " + tok, "Content-Type": "application/json"}
    if extra: h.update(extra)
    code, body = req(url, h)
    print(f"PROBE[{label}] http={code} url={url}")
    print("PROBE_BODY " + body[:700].replace("\n", " "))

def main():
    print(f"IMDSPROBE_START host={urllib.parse.quote(sys.argv[1] if len(sys.argv)>1 else '')} ts={int(time.time())}")
    code, body = req(f"{IMDS}/metadata/instance?api-version=2021-11-15")
    info = {}
    if code == 200:
        try:
            d = json.loads(body)
            info = d.get("compute", {})
            print("INSTANCE name=%s rg=%s sub=%s location=%s vmId=%s" % (
                info.get("name"), info.get("resourceGroupName"), info.get("subscriptionId"),
                info.get("location"), info.get("vmId")))
            global SUB
            SUB = info.get("subscriptionId") or SUB
        except Exception as e:
            print("INSTANCE_PARSE_FAIL", e)
    else:
        print("INSTANCE_HTTP", code, body[:300])
    code, body = req(f"{IMDS}/metadata/identity/info?api-version=2018-02-01")
    ids = {}
    if code == 200:
        try:
            ids = json.loads(body)
            print("IDENTITIES " + json.dumps(ids)[:1200])
        except Exception:
            print("IDENTITIES_RAW " + body[:800])
    else:
        print("IDENTITIES_HTTP", code, body[:300])
    targets = []
    if isinstance(ids.get("systemAssignedIdentity"), dict):
        targets.append(("system", ids["systemAssignedIdentity"].get("clientId")))
    for k in (ids.get("userAssignedIdentities") or []):
        targets.append(("uami_" + (k.get("clientId") or "x")[:8], k.get("clientId")))
    if not targets:
        targets = [("system", None), ("uami_2ac1b8af", "2ac1b8af-6f93-4fa3-b65c-e629ad9c0bb6")]
    name = info.get("name", "vm"); rg = info.get("resourceGroupName", "rg")
    for label, cid in targets:
        tok = mint(label, "https://management.azure.com/", cid)
        if tok:
            probe(label, tok, "https://management.azure.com/subscriptions?api-version=2022-12-01")
            probe(label, tok, f"https://management.azure.com/subscriptions/{SUB}/providers/Microsoft.Authorization/permissions?api-version=2022-04-01")
            probe(label, tok, f"https://management.azure.com/subscriptions/{SUB}/resourcegroups?api-version=2021-04-01")
            probe(label, tok, f"https://management.azure.com/subscriptions/{SUB}/providers/Microsoft.Batch/batchAccounts?api-version=2023-05-01")
            probe(label, tok, f"https://management.azure.com/subscriptions/{SUB}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{name}?api-version=2023-09-01")
            probe(label, tok, f"https://management.azure.com/subscriptions/{SUB}/resourceGroups/{rg}/providers/Microsoft.Authorization/permissions?api-version=2022-04-01")
        btok = mint(label + "_batch", "https://batch.core.windows.net/", cid)
        for acct, region in BATCH_ACCTS[:3]:
            probe(label + "_batch", btok, f"https://{acct}.{region}.batch.azure.com/pools?api-version=2023-05-01.0")
        gtok = mint(label + "_graph", "https://graph.microsoft.com/", cid)
        probe(label + "_graph", gtok, "https://graph.microsoft.com/v1.0/organization")
        vtok = mint(label + "_vault", "https://vault.azure.net", cid)
        stok = mint(label + "_storage", "https://storage.azure.com/", cid)
    # negative controls
    bogus = "bogus.invalid.token.negative.control"
    code, body = req("https://management.azure.com/subscriptions?api-version=2022-12-01",
                     {"Authorization": "Bearer " + bogus})
    print(f"NEGCTL[arm_bogus] http={code} body={body[:200]}")
    code, body = req(f"https://{BATCH_ACCTS[0][0]}.{BATCH_ACCTS[0][1]}.batch.azure.com/pools?api-version=2023-05-01.0",
                     {"Authorization": "Bearer " + bogus})
    print(f"NEGCTL[batch_bogus] http={code} body={body[:200]}")
    print("IMDSPROBE_END")

if __name__ == "__main__":
    main()
