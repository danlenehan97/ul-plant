import socket, sys, concurrent.futures

hosts = []
for line in open(sys.argv[1]).read().splitlines():
    f = line.split('\t')
    if len(f) >= 2 and f[1].strip():
        hosts.append((f[0].strip(), f[1].strip()))

ports = [22, 80, 443, 3389, 5900, 8080, 8443, 8888, 8265, 9400, 5555, 10250,
         3000, 6006, 8000, 5000, 11434, 7860, 8889, 9000, 9090, 2375, 2376,
         6443, 10255, 18080, 30999]

def chk(job):
    nm, ip, p = job
    s = socket.socket()
    s.settimeout(2.5)
    try:
        s.connect((ip, p))
        return '%s\t%s\t%d\tOPEN' % (nm, ip, p)
    except Exception:
        return None
    finally:
        s.close()

jobs = [(nm, ip, p) for nm, ip in hosts for p in ports]
with concurrent.futures.ThreadPoolExecutor(max_workers=120) as ex:
    for r in ex.map(chk, jobs):
        if r:
            print(r, flush=True)
