#!/usr/bin/env python3
# az/vnetscan.py - internal VNet sweep: ssh/rdp/docker/kubelet/k8s/dcgm/ray/jupyter
import asyncio, ipaddress, os, socket, sys, time, json

PORTS = [22, 3389, 2375, 2376, 10250, 10255, 6443, 9400, 8265, 8888]
CIDRS = os.environ.get("SCAN_CIDRS", "10.29.0.0/16,10.131.0.0/16").split(",")
TIMEOUT = float(os.environ.get("SCAN_TIMEOUT", "0.45"))
CONC = int(os.environ.get("SCAN_CONC", "700"))
BUDGET = float(os.environ.get("SCAN_BUDGET", "1500"))
OUT = "/tmp/scan_hits.tsv"

sem = asyncio.Semaphore(CONC)
hits = []
lock = asyncio.Lock()
count = 0
t_start = time.time()

def log(msg):
    print(msg, flush=True)

async def probe(ip, port):
    global count
    async with sem:
        count += 1
        try:
            r, w = await asyncio.wait_for(asyncio.open_connection(ip, port), timeout=TIMEOUT)
            w.close()
            try:
                await w.wait_closed()
            except Exception:
                pass
            async with lock:
                hits.append((ip, port))
                log(f"SCAN_HIT {ip}:{port}")
        except Exception:
            pass

def local_nets():
    nets = set()
    try:
        out = os.popen("ip -4 -o addr show 2>/dev/null").read()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 4 and "/" in parts[3]:
                try:
                    nets.add(str(ipaddress.ip_interface(parts[3]).network))
                except Exception:
                    pass
    except Exception:
        pass
    return sorted(nets)

async def sweep(ips, ports, label):
    n = 0
    total = len(ips) * len(ports)
    log(f"SCAN_PHASE {label} hosts={len(ips)} ports={len(ports)} probes={total}")
    for port in ports:
        batch = []
        for ip in ips:
            if time.time() - t_start > BUDGET:
                log(f"SCAN_BUDGET_EXCEEDED phase={label} after_probes={count}")
                return False
            batch.append(probe(ip, port))
            if len(batch) >= 4000:
                await asyncio.gather(*batch)
                batch = []
                n += 4000
                if n % 40000 < 4000:
                    log(f"SCAN_PROGRESS {label} port={port} probes={n}/{total} hits={len(hits)}")
        if batch:
            await asyncio.gather(*batch)
    log(f"SCAN_PHASE_DONE {label} probes={count} hits={len(hits)}")
    return True

async def main():
    log(f"SCAN_START host={socket.gethostname()} cidrs={CIDRS} local={local_nets()}")
    nets = []
    for c in CIDRS:
        try:
            nets.append(ipaddress.ip_network(c))
        except Exception as e:
            log(f"SCAN_BADCIDR {c} {e}")
    # phase A: local /24s, all ports (fast, most valuable)
    lnets = []
    for n in local_nets():
        try:
            net = ipaddress.ip_network(n)
            if net.num_addresses > 512:
                net = ipaddress.ip_network(str(next(net.hosts())) + "/24", strict=False)
            lnets.append(net)
        except Exception:
            pass
    myips = set()
    try:
        for line in os.popen("hostname -I 2>/dev/null").read().split():
            myips.add(line)
    except Exception:
        pass
    seen = set()
    for net in lnets:
        ips = [str(ip) for ip in net.hosts() if str(ip) not in myips and str(ip) not in seen]
        seen.update(ips)
        await sweep(ips, PORTS, f"local{net}")
    # phase B: both /16s on 22
    all16 = []
    for net in nets:
        all16.extend(str(ip) for ip in net.hosts() if str(ip) not in myips)
    all16 = sorted(set(all16))
    await sweep(all16, [22], "port22-16s")
    # phase C: remaining ports on responding hosts first, then full /16 if budget allows
    responders = sorted({ip for ip, p in hits if p == 22} - set(myips))
    log(f"SCAN_RESPONDERS22 {len(responders)}: {' '.join(responders)[:2000]}")
    if responders:
        await sweep(responders, [p for p in PORTS if p != 22], "responders-allports")
    await sweep(all16, [p for p in PORTS if p != 22], "allports-16s")
    with open(OUT, "w") as f:
        for ip, p in sorted(hits):
            f.write(f"{ip}:{p}\n")
    log(f"SCAN_SUMMARY probes={count} hits={len(hits)} elapsed={int(time.time()-t_start)}s out={OUT}")
    for ip, p in sorted(hits):
        log(f"SCAN_RESULT {ip}:{p}")

if __name__ == "__main__":
    asyncio.run(main())
