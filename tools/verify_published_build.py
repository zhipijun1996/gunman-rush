"""Verify the public deployment matches the tested export, never an older cached pack."""
import argparse
import json
import hashlib
from urllib.request import urlopen
from urllib.parse import urljoin
import time


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--url',required=True);p.add_argument('--build-id',required=True);p.add_argument('--commit',required=True)
    args=p.parse_args();last='not fetched'
    for attempt in range(12):
        try:
            with urlopen(urljoin(args.url, 'build-info.json')+'?verify='+args.build_id, timeout=15) as response: info=json.load(response)
            if info.get('build_id')==args.build_id and info.get('source_commit')==args.commit:
                with urlopen(urljoin(args.url, 'index.html')+'?verify='+args.build_id, timeout=15) as response: html=response.read().decode()
                if info['pack'] not in html: raise RuntimeError('HTML references another pack')
                with urlopen(urljoin(args.url,info['pack']), timeout=15) as response:
                    if int(response.headers.get('Content-Length','0')) != info['pack_bytes']: raise RuntimeError('Public pack size mismatch')
                    digest=hashlib.sha256()
                    while block := response.read(1024*1024): digest.update(block)
                    if digest.hexdigest()[:12] != args.build_id: raise RuntimeError('Public pack hash mismatch')
                print(json.dumps({'status':'passed','build_id':args.build_id,'source_commit':args.commit,'url':args.url}));return 0
            last='Public metadata still references another build'
        except (OSError, ValueError, KeyError, RuntimeError) as error: last=str(error)
        if attempt<11: time.sleep(5)
    raise RuntimeError(last)


if __name__=='__main__':
    raise SystemExit(main())
