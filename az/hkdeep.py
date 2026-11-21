import socket, sys, concurrent.futures

hosts = [h for h in sys.argv[1].split(',') if h.strip()]
MAXP = int(sys.argv[2]) if len(sys.argv) > 2 else 65535

def chk(a):
    ip, p = a
    s = socket.socket()
    s.settimeout(1.0)
    try:
        s.connect((ip, p))
        return p
    except Exception:
        return None
    finally:
        s.close()

for ip in hosts:
    openp = []
    jobs = [(ip, p) for p in range(1, MAXP + 1)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=600) as ex:
        for r in ex.map(chk, jobs, chunksize=128):
            if r:
                openp.append(r)
                print('%s\t%d\tOPEN' % (ip, r), flush=True)
    print('# %s open=%d %s' % (ip, len(openp), openp), flush=True)

    for p in openp:
        b = ''
        try:
            s = socket.socket(); s.settimeout(3)
            s.connect((ip, p))
            if p in (80, 8080, 8000, 8888, 8265, 3000, 9090, 9400, 8501, 6006, 11434, 8188):
                try:
                    s.sendall(b'GET / HTTP/1.0\r\nHost: x\r\n\r\n')
                except Exception:
                    pass
            d = s.recv(256)
            b = d.decode('latin1', 'replace').replace('\r', ' ').replace('\n', ' ')[:160]
            s.close()
        except Exception:
            pass
        print('BANNER\t%s\t%d\t%s' % (ip, p, b), flush=True)
