import json, urllib.request, collections
for h in ["24.165.187.21:8265"]:
    try:
        d=json.load(urllib.request.urlopen("http://%s/api/jobs/" % h, timeout=60))
    except Exception as e:
        print(h,"ERR",e); continue
    print(h,"jobs:",len(d))
    print(" status:", dict(collections.Counter(j.get("status") for j in d)))
    for j in d[:5]:
        print(" sample:", {k:str(j.get(k))[:200] for k in ("job_id","submission_id","status","entrypoint")})
    txt=json.dumps(d).lower()
    for kw in ["nvidia","cuda","gpu","a100","h100","4090","miner","wildrig","torch"]:
        print(" kw",kw,txt.count(kw))
