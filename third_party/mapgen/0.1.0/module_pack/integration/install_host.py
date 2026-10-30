#!/usr/bin/env python3
"""Install only the hash-locked shared gunman-rush runtime, never its Git history."""
import argparse,concurrent.futures,hashlib,json,os,shutil,urllib.request,urllib.parse
from pathlib import Path

def install(lock_path,target,source=None):
 lock=json.loads(Path(lock_path).read_text());target=Path(target).resolve();target.mkdir(parents=True,exist_ok=True)
 source=Path(source).resolve()if source else None
 def one(item):
  name,expected=item;rel=Path(name)
  if rel.is_absolute()or '..'in rel.parts:raise ValueError('unsafe_host_dependency:'+name)
  dest=target/rel
  if dest.exists():
   if hashlib.sha256(dest.read_bytes()).hexdigest()!=expected:raise ValueError('conflicting_host_dependency:'+name)
   return
  if source:
   origin=source/rel
   if not origin.is_file():raise ValueError('missing_host_dependency:'+name)
   data=origin.read_bytes()
  else:
   url=lock['repository'].replace('https://github.com/','https://raw.githubusercontent.com/')+'/'+lock['commit']+'/'+urllib.parse.quote(name)
   with urllib.request.urlopen(url,timeout=90)as r:data=r.read()
  if hashlib.sha256(data).hexdigest()!=expected:raise ValueError('host_dependency_hash_mismatch:'+name)
  dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_name(dest.name+'.installing');tmp.write_bytes(data);os.replace(tmp,dest)
 with concurrent.futures.ThreadPoolExecutor(max_workers=8)as pool:list(pool.map(one,lock['files'].items()))
 return dict(profile=lock['id'],commit=lock['commit'],files=len(lock['files']))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lock',default=str(Path(__file__).resolve().parents[1]/'runtime/host-lock.json'));p.add_argument('--target',required=True);p.add_argument('--source',help='Optional clean checkout/cache at the locked commit; every file is hashed. Omit to download exact files.');a=p.parse_args()
 print(json.dumps(install(a.lock,a.target,a.source),sort_keys=True))
