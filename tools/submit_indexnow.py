#!/usr/bin/env python3
"""Submit only our verified public Pages URLs to IndexNow; receipt is not indexing."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

SITE = 'https://sbezruk180.github.io/AHK-FOR-GOS-BY-SBEZRUK/'
KEY = 'ad0f1143ae1c40c5878cb86868e900b0'
ENDPOINT = 'https://api.indexnow.org/indexnow'


def main(output, wait_seconds):
    urls = [SITE, SITE + 'features.html']
    key_url = SITE + KEY + '.txt'
    report = {'checked_at':datetime.now(timezone.utc).isoformat(), 'endpoint':ENDPOINT,
              'urls':urls, 'key_location':key_url, 'accepted':False,
              'meaning':'Acceptance acknowledges a submission; it does not confirm indexing or rankings.'}
    try:
        deadline = time.monotonic() + wait_seconds
        while True:
            try:
                with urlopen(key_url, timeout=15) as response:
                    if response.status != 200 or response.read().decode().strip() != KEY:
                        raise ValueError('The public ownership key does not match')
                break
            except (HTTPError, URLError, ValueError) as error:
                if time.monotonic() >= deadline:
                    raise RuntimeError('Public key was not ready: ' + str(error)) from error
                time.sleep(5)
        report['ownership_verified'] = True
        for url in urls:
            with urlopen(url, timeout=20) as response:
                if response.status != 200:
                    raise ValueError('URL is not public: ' + url)
                body = response.read().decode('utf-8')
                if 'AHK FOR GOS' not in body:
                    raise ValueError('Unexpected public page: ' + url)
        report['pages_verified'] = True
        request = Request(ENDPOINT, data=json.dumps({'host':urlsplit(SITE).hostname,
                          'key':KEY, 'keyLocation':key_url, 'urlList':urls}).encode(),
                          headers={'Content-Type':'application/json; charset=utf-8',
                                   'User-Agent':'AHK-FOR-GOS-Publication/1.1'}, method='POST')
        with urlopen(request, timeout=30) as response:
            report['http_status'] = response.status
            report['accepted'] = response.status in (200, 202)
            report['response'] = response.read(1024).decode('utf-8', errors='replace')
    except HTTPError as error:
        report.update(http_status=error.code, error=str(error), response=error.read(1024).decode('utf-8', errors='replace'))
    except Exception as error:
        report['error'] = str(error)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2),flush=True)
    return 0 if report['accepted'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--wait-seconds',type=int,default=180)
    args = parser.parse_args()
    raise SystemExit(main(args.output,args.wait_seconds))
