import json,subprocess,posixpath,collections,hashlib
from pathlib import Path
root=Path('/workspace/integration-four');base=Path('/workspace/scratch/input-link-audit-a074');source=Path('/workspace/scratch/ci-pr106-a074/raw/gunman-rush/gunman-rush/build/verification/production-ci/inputs.json');d=json.loads(source.read_text());commit=d['commit']
def git(*args,input=None):return subprocess.check_output(['git','--no-lazy-fetch','-C',str(root),*args],input=input,stderr=subprocess.PIPE)
tree={}
for part in git('ls-tree','-r','-z',commit,'--','docs/quality/records','docs/quality/asset_records').split(b'\0'):
 if part:
  meta,name=part.split(b'\t');tree[name.decode()]=meta.decode().split()[2]
raw=git('cat-file','--batch',input=('\n'.join(tree.values())+'\n').encode());offset=0;records={}
for name in tree:
 end=raw.index(b'\n',offset);h=raw[offset:end].split();assert h[1]==b'blob',(name,h);n=int(h[2]);records[name]=json.loads(raw[end+1:end+1+n]);offset=end+n+2
sha_refs=collections.defaultdict(list);presence_refs=collections.defaultdict(list)
for name,record in records.items():
 for e in record.get('evidence',[]):
  if isinstance(e,dict) and isinstance(e.get('path'),str) and e.get('sha256'):sha_refs[posixpath.normpath(e['path'])].append({'record':name,'field':'evidence','sha256':e['sha256']})
 if isinstance(record.get('source_path'),str) and record.get('source_sha256'):sha_refs[posixpath.normpath(record['source_path'])].append({'record':name,'field':'source_path','sha256':record['source_sha256']})
 for e in record.get('associated_files',[]):
  if isinstance(e,dict) and isinstance(e.get('path'),str) and e.get('sha256'):sha_refs[posixpath.normpath(e['path'])].append({'record':name,'field':'associated_files','sha256':e['sha256']})
 for key in ['runtime_paths','user_acceptance_evidence']:
  for path in record.get(key,[]):presence_refs[posixpath.normpath(path)].append({'record':name,'field':key})
def ismd(s):return s.endswith('.md') or (s.startswith('directory existence only: ') and '.md' in s)
def media(p):return Path(p).suffix.lower() in {'.png','.jpg','.jpeg','.webp','.svg','.gif','.mp4','.webm','.mov','.wav','.mp3','.ogg','.flac','.zip','.gz','.tar','.7z'}
rows=[]
for item in d['materialized']:
 r=dict(item);p=r['path'];r['markdown_existence_sources']=[s for s in r['required_by'] if ismd(s)];r['quality_sha_refs']=sha_refs[p];r['quality_presence_refs']=presence_refs[p];r['markdown_content_read']='selected Markdown consumer' in r['required_by'];r['sole_markdown_existence']=bool(r['required_by']) and all(ismd(s) for s in r['required_by']);r['media_or_archive']=media(p);rows.append(r)
def metric(rs):return {'files':len(rs),'bytes':sum(r['size'] for r in rs),'unique_blobs':len({r['blob'] for r in rs}),'unique_blob_bytes':sum(next(r['size'] for r in rs if r['blob']==oid) for oid in {r['blob'] for r in rs})}
sets={'all':rows,'markdown_link_any':[r for r in rows if r['markdown_existence_sources']],'sole_markdown_existence':[r for r in rows if r['sole_markdown_existence']],'sole_markdown_existence_media_archive':[r for r in rows if r['sole_markdown_existence'] and r['media_or_archive']],'quality_sha_any':[r for r in rows if r['quality_sha_refs']],'quality_sha_media_archive':[r for r in rows if r['quality_sha_refs'] and r['media_or_archive']],'markdown_quality_sha_intersection':[r for r in rows if r['markdown_existence_sources'] and r['quality_sha_refs']],'markdown_quality_sha_intersection_media_archive':[r for r in rows if r['markdown_existence_sources'] and r['quality_sha_refs'] and r['media_or_archive']],'markdown_content_read':[r for r in rows if r['markdown_content_read']],'other':[r for r in rows if not r['sole_markdown_existence'] and not r['quality_sha_refs']]}
summary={'input_report':str(source),'input_report_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'commit':commit,'seconds':d['seconds'],'rounds':len(d['rounds']),'prefetch_batches':len(d['prefetch']),'metrics':{k:metric(v) for k,v in sets.items()},'quality_records_read':len(records),'top5':{k:[{'path':r['path'],'size':r['size'],'required_by':r['required_by'],'quality_sha_refs':r['quality_sha_refs']} for r in sorted(v,key=lambda r:r['size'],reverse=True)[:5]] for k,v in sets.items() if k in ['all','sole_markdown_existence','quality_sha_any','markdown_quality_sha_intersection']}}
(base/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');(base/'classified-materialized.json').write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='top5'},indent=2));print('TOP5SOLE',json.dumps(summary['top5']['sole_markdown_existence'],indent=2))
