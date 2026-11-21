import sys, subprocess

WEB = {80: 'http', 443: 'https', 8080: 'http', 8443: 'https', 8888: 'http',
       8265: 'http', 8000: 'http', 5000: 'http', 11434: 'http', 7860: 'http',
       8889: 'http', 9000: 'http', 9090: 'http', 3000: 'http', 6006: 'http',
       18080: 'http', 30999: 'http', 10250: 'https', 10255: 'http'}

for line in open(sys.argv[1]).read().splitlines():
    f = line.split('\t')
    if len(f) < 4 or f[3] != 'OPEN':
        continue
    nm, ip, p = f[0], f[1], int(f[2])
    if p not in WEB:
        continue
    url = '%s://%s:%d/' % (WEB[p], ip, p)
    print('== %s %s:%d %s' % (nm, ip, p, url), flush=True)
    r = subprocess.run(['curl', '-sk', '-m', '8', '-D', '-', url, '-o', '/dev/null'],
                       capture_output=True, text=True)
    for l in (r.stdout or '').splitlines()[:8]:
        print('   ' + l.strip(), flush=True)
    b = subprocess.run(['curl', '-sk', '-m', '8', url], capture_output=True, text=True)
    print('   BODY ' + (b.stdout or '').replace('\n', ' ')[:300], flush=True)
