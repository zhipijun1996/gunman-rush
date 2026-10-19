from pathlib import Path
import json,os,shutil,datetime,hashlib,subprocess
base=Path('build/integration01/cache-cleanup02');target=Path('/tmp/gunman-forest-feedback-runtime/.godot');project=target.parent;current=Path('.godot').resolve()
assert target.is_dir() and not target.is_symlink() and target.resolve()==target and target!=current
assert (project/'project.godot').is_file() and (target/'.gdignore').is_file()
allowed={'.gdignore','editor','exported','global_script_class_cache.cfg','imported','uid_cache.bin'};assert set(x.name for x in target.iterdir()).issubset(allowed)
r={'scope':'Remove only an explicitly authorized, regenerable, inactive Godot generated cache directory; no source or evidence files','target':str(target),'current_shared_cache':str(current),'distinct_from_current_cache':True,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'preflight','reconstruction_basis':'Godot creates .godot generated imports, editor metadata, class/UID caches, and export intermediates from the associated project.godot and unchanged source assets; opening/importing this isolated project recreates the directory. No project/source/asset directory is deleted.','reconstruction_command':['bash','/workspace/gunman-rush-design/tools/godot.sh','--headless','--editor','--path',str(project),'--quit'],'command':'python3 build/integration01/cache-cleanup02/cleanup.py','authorized_deletion_operation':'shutil.rmtree(/tmp/gunman-forest-feedback-runtime/.godot)'}
def save():
 tmp=base/'receipt.json.tmp'
 with tmp.open('w') as f:json.dump(r,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(tmp,base/'receipt.json');fd=os.open(base,os.O_RDONLY);os.fsync(fd);os.close(fd)
# Reject every active process whose cwd, command, or open file depends on the associated old project.
handles=[];cwds=[];commands=[]
for proc in Path('/proc').iterdir():
 if not proc.name.isdigit() or int(proc.name)==os.getpid():continue
 try:
  state=(proc/'stat').read_text().split(') ',1)[1].split()[0]
  if state=='Z':continue
  try:
   cwd=(proc/'cwd').resolve()
   if cwd.is_relative_to(project):cwds.append({'pid':proc.name,'cwd':str(cwd)})
  except OSError:pass
  try:
   argv=[a.decode(errors='replace') for a in (proc/'cmdline').read_bytes().split(bytes([0])) if a]
   if any(a.startswith(str(project)) for a in argv):commands.append({'pid':proc.name,'argv':argv})
  except OSError:pass
  for fd in (proc/'fd').iterdir():
   try:
    p=fd.resolve()
    if p.is_relative_to(target):handles.append({'pid':proc.name,'fd':fd.name,'path':str(p)})
   except OSError:pass
 except OSError:pass
r['active_dependencies']={'cwd_in_project':cwds,'command_argument_in_project':commands,'open_target_handles':handles};save();assert not handles and not cwds and not commands
manifest=[]
for p in [target,*target.rglob('*')]:
 st=p.lstat();manifest.append({'path':str(p),'bytes':st.st_size,'allocated_bytes':st.st_blocks*512,'nlink':st.st_nlink,'type':'symlink' if p.is_symlink() else 'directory' if p.is_dir() else 'file'})
mp=base/'cache-manifest-before01.json';mp.write_text(json.dumps(manifest,indent=2)+'\n')
r.update(manifest_path=str(mp),manifest_sha256=hashlib.sha256(mp.read_bytes()).hexdigest(),entries=len(manifest),files=sum(x['type']=='file' for x in manifest),logical_file_bytes=sum(x['bytes'] for x in manifest if x['type']=='file'),allocated_scope_bytes_before=int(subprocess.check_output(['du','-s','-B1',str(target)],text=True).split()[0]),regular_files_with_multiple_links=[x['path'] for x in manifest if x['type']=='file' and x['nlink']>1],status='verified_authorized_cache_before_delete')
assert not r['regular_files_with_multiple_links'];save()
stat=os.statvfs(project);r['filesystem_available_bytes_immediately_before']=stat.f_bavail*stat.f_frsize
# Only deletion in this script; shutil.rmtree does not follow nested symlink targets.
shutil.rmtree(target)
stat=os.statvfs(project);r['filesystem_available_bytes_immediately_after']=stat.f_bavail*stat.f_frsize;r['filesystem_available_bytes_delta']=r['filesystem_available_bytes_immediately_after']-r['filesystem_available_bytes_immediately_before'];r['target_exists_after']=target.exists();assert not target.exists();assert Path('.godot').resolve()==current and current.is_dir()
r.update(status='completed',allocated_scope_bytes_after=0,released_exclusive_scope_bytes=r['allocated_scope_bytes_before'],finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),current_shared_cache_still_present=True);save();print(json.dumps(r,indent=2))
