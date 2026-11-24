import hashlib,hmac,datetime,urllib.parse,urllib.request,ssl
AK='v9e0awatbphfbanm'; SK='trnbqv14bg0adnvq'
CTX=ssl.create_default_context(); CTX.check_hostname=False; CTX.verify_mode=ssl.CERT_NONE
def _s(k,m): return hmac.new(k,m.encode(),hashlib.sha256).digest()
def sign(host,scheme,path='/',query=None,ak=AK,sk=SK,region='us-east-1'):
    q=query or {}
    cq='&'.join('%s=%s'%(urllib.parse.quote(k,safe='-_.~'),urllib.parse.quote(str(v),safe='-_.~')) for k,v in sorted(q.items()))
    now=datetime.datetime.now(datetime.timezone.utc); amz=now.strftime('%Y%m%dT%H%M%SZ'); day=now.strftime('%Y%m%d')
    ph=hashlib.sha256(b'').hexdigest()
    hh={'host':host,'x-amz-date':amz,'x-amz-content-sha256':ph}
    sh=';'.join(sorted(hh))
    canon='\n'.join(['GET',path,cq,'\n'.join('%s:%s'%(k,hh[k]) for k in sorted(hh))+'\n',sh,ph])
    scope='%s/%s/s3/aws4_request'%(day,region)
    sts='\n'.join(['AWS4-HMAC-SHA256',amz,scope,hashlib.sha256(canon.encode()).hexdigest()])
    k=('AWS4'+sk).encode()
    for p in (day,region,'s3','aws4_request'): k=_s(k,p)
    sig=hmac.new(k,sts.encode(),hashlib.sha256).hexdigest()
    auth='AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s'%(ak,scope,sh,sig)
    return '%s://%s%s%s'%(scheme,host,path,('?'+cq) if cq else ''), {'x-amz-date':amz,'x-amz-content-sha256':ph,'Authorization':auth}
def hit(url,hdr=None,t=20):
    try:
        r=urllib.request.urlopen(urllib.request.Request(url,headers=hdr or {}),timeout=t,context=CTX)
        return r.status, r.read()[:1500].decode('utf-8','replace')
    except Exception as e:
        b=getattr(e,'read',lambda:b'')()
        return getattr(e,'code',0), (b[:800].decode('utf-8','replace') if isinstance(b,bytes) else str(e)[:300])
for host,scheme,port in [('47.100.200.41:9000','http',9000),('47.100.200.41:32002','http',32002)]:
    u,h=sign(host,scheme)
    print('==',host,'LISTBUCKETS',hit(u,h))
    u,h=sign(host,scheme,sk='AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='); print('== NEGCTL',host,hit(u,h))
for u in ('http://47.100.200.41:30002/','https://47.100.200.41:30444/','http://47.100.200.41/'):
    print('==',u,hit(u))
