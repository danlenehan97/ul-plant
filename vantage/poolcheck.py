import socket, json, ssl
W = "prl1pek8rh8yjck5q7596aph7ua7xnkqs8ur9mkfmz8w7xfzcdfcfx5vsx2f4lz"
def hs(host, port, tls=False):
    try:
        s = socket.create_connection((host, port), 8); s.settimeout(8)
        if tls:
            c = ssl.create_default_context(); c.check_hostname=False; c.verify_mode=ssl.CERT_NONE
            s = c.wrap_socket(s)
        s.sendall(json.dumps({"id":1,"method":"mining.subscribe","params":["ul/1.0"]}).encode()+b"\n")
        r1 = s.recv(2048)
        s.sendall(json.dumps({"id":2,"method":"mining.authorize","params":[W+".ul-t2-probe-g0","x"]}).encode()+b"\n")
        r2 = s.recv(2048)
        s.close()
        return r1[:160], r2[:160]
    except Exception as e:
        return None, f"{type(e).__name__}:{e}"[:120]
for host, port, tls in [("prl-sg.kryptex.network",7048,False),("prl-sg.kryptex.network",8048,True),
                        ("prl-eu.kryptex.network",7048,False),("prl-us.kryptex.network",7048,False),
                        ("pool.pearlhash.xyz",9000,False),("pool.pearlhash.xyz",9443,True),
                        ("pearl.luckypool.io",443,True),("pearl.luckypool.io",3360,False)]:
    r1, r2 = hs(host, port, tls)
    print(f"{host}:{port} tls={tls} SUB={r1} AUTH={r2}", flush=True)
