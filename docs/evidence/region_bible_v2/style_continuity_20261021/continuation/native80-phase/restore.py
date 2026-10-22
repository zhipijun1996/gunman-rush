"""Restore only indexed original terminal-PASS capture bytes, refusing conflicts."""
from pathlib import Path
import argparse,hashlib,json,os,stat,zipfile
HERE=Path(__file__).resolve().parent

def digest(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()

def restore_one(z,row,root):
 relative=Path(row['original_relative_path']);assert not relative.is_absolute()and'..'not in relative.parts
 target=root/relative
 if target.exists()or target.is_symlink():
  if target.is_symlink()or not target.is_file()or target.stat().st_size!=row['bytes']or digest(target)!=row['sha256']:raise FileExistsError('Refuse conflicting existing file: '+str(target))
  return 'already_present_exact'
 raw=z.read(row['member']);assert len(raw)==row['bytes']and hashlib.sha256(raw).hexdigest()==row['sha256'];target.parent.mkdir(parents=True,exist_ok=True)
 with target.open('xb')as f:f.write(raw)
 os.chmod(target,row['metadata']['mode'])
 if os.geteuid()==0:os.chown(target,row['metadata']['uid'],row['metadata']['gid'])
 os.utime(target,ns=(row['metadata']['atime_ns'],row['metadata']['mtime_ns']))
 assert target.stat().st_size==row['bytes']and digest(target)==row['sha256']
 return 'restored_exact'

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--repository-root',type=Path,default=Path('/workspace/gunman-rush'));args=parser.parse_args();index=json.loads((HERE/'restore-index.json').read_text());archive=(HERE/index['archive_relative_to_index']).resolve();assert digest(archive)==index['archive_sha256'];results=[]
 with zipfile.ZipFile(archive)as z:
  for row in index['entries']:results.append(dict(path=row['original_relative_path'],result=restore_one(z,row,args.repository_root)))
 print(json.dumps(results,indent=2))
if __name__=='__main__':main()
