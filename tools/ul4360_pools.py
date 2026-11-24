import socket, ssl, json
W='prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz.ul-gh4360-g0'
SUB=json.dumps({"id":1,"method":"mining.subscribe","params":["ul-gh4360"]})+"\n"
AUTH=json.dumps({"id":2,"method":"mining.authorize","params":[W,"x"]})+"\n"
T=[("prl.kryptex.network",8048,True),("prl.kryptex.network",7048,False),
   ("pool.pearlhash.xyz",9000,False),("pool.pearlhash.xyz",9443,True),
   ("pearl.luckypool.io",3360,False)]
for h,p,tls in T:
    tag="%s:%d%s"%(h,p,"/tls" if tls else "")
    try:
        s=socket.create_connection((h,p),12); s.settimeout(12)
        if tls:
            s=ssl.create_default_context().wrap_socket(s,server_hostname=h)
        s.sendall((SUB+AUTH).encode())
        buf=b""
        try:
            while len(buf)<8192:
                d=s.recv(4096)
                if not d: break
                buf+=d
        except Exception:
            pass
        print(tag,"RECV",len(buf),buf.decode('utf-8','replace')[:400].replace("\n"," | "))
        s.close()
    except Exception as e:
        print(tag,"ERR",type(e).__name__,str(e)[:120])
