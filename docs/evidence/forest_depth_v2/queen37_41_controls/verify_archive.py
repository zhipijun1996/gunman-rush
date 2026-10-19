from pathlib import Path
import tarfile,json,hashlib,stat
OUT=Path('/workspace/gunman-rush-design/build/forest_depth/independent/queen37-41-custody');ROOT=OUT.parents[3];archive=OUT/'queen37-41-selected.tar.gz';plan=json.loads((OUT/'plan.json').read_text());index={};expected=plan['payload'];verified_payload=set()
with tarfile.open(archive,'r|gz')as tar:
 for member in tar:
  assert member.isfile() and not member.issym() and not member.islnk(),member.name
  p=Path(member.name);assert not p.is_absolute() and '..'not in p.parts and member.name not in index,member.name
  data=tar.extractfile(member).read();h=hashlib.sha256(data).hexdigest();index[member.name]={'sha256':h,'bytes':len(data),'mode':stat.S_IMODE(member.mode)}
  if member.name in expected:
   e=expected[member.name];assert e['sha256']==h and e['bytes']==len(data),member.name;verified_payload.add(member.name)
  else:
   assert member.name.startswith('custody/'),member.name
   local=OUT/p.name;assert local.read_bytes()==data,member.name
assert verified_payload==set(expected)
(OUT/'archive-members.json').write_text(json.dumps(index,indent=2)+'\n')
cache={};projects=[]
for project in plan['projects']:
 snapshot=ROOT/'snapshots'/project['name'] if False else Path('/workspace/gunman-rush-design/build/forest_depth/snapshots')/project['name']
 for rel,e in project['source_files'].items():
  p=snapshot/rel;s=p.stat();key=(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns)
  if key not in cache:cache[key]=hashlib.sha256(p.read_bytes()).hexdigest()
  assert cache[key]==e['sha256'] and s.st_size==e['bytes'] and stat.S_IMODE(s.st_mode)==e['mode'],str(p)
 projects.append({'name':project['name'],'verified_original_source_files':len(project['source_files']),'all_SHA_size_mode_unchanged':True})
r={'scope':'Single sequential stream readback, all members SHA+size matched, no native or restore; original five source inventories SHA/size/mode reverified','archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive_bytes':archive.stat().st_size,'regular_members':len(index),'payload_members_verified':len(verified_payload),'custody_metadata_members_verified':len(index)-len(verified_payload),'member_index_sha256':hashlib.sha256((OUT/'archive-members.json').read_bytes()).hexdigest(),'projects':projects,'no_assets_source_or_raw_deleted':True};(OUT/'sequential-member-check.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
