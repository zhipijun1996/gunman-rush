"""Read-only expansion of actual FoundryCatalog.basis inputs; never starts Godot."""
from pathlib import Path
import ast,collections,hashlib,json,re,subprocess
ROOT=Path.cwd();OUT=ROOT/'build/foundry_final_W10';REF='169ef171fee3f70911847fb2c2890351ee3468bb'
def command(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def digest(data):return hashlib.sha256(data).hexdigest()
old_names=command('ls-tree','-r','--name-only',REF).splitlines();cache={}
def old_bytes(path):
    if path not in cache:cache[path]=subprocess.check_output(['git','show',REF+':'+path],cwd=ROOT)
    return cache[path]
def read_at(path,old):return old_bytes(path) if old else (ROOT/path).read_bytes()
def members(directory,old,recursive):
    d=directory.removeprefix('res://')
    if old:
        files=[p for p in old_names if p.startswith(d+'/') and (recursive or '/' not in p[len(d)+1:])]
    else:
        files=[p.relative_to(ROOT).as_posix() for p in ((ROOT/d).rglob('*') if recursive else (ROOT/d).iterdir()) if p.is_file()]
    return sorted(files)
def expand(old):
    source=read_at('scripts/generation/foundry_catalog.gd',old).decode()
    body=source[source.index('\tvar files: Array[String] ='):source.index('\nstatic func _add_basis_tree')]
    config=re.search(r'const CONFIG := "([^"]+)"',source).group(1)
    initial=re.search(r'var files: Array\[String\] = (\[[^\n]+\])',body).group(1).replace('CONFIG',json.dumps(config))
    paths=ast.literal_eval(initial);reasons=collections.defaultdict(list)
    for p in paths:reasons[p].append('explicit initial input')
    catalog=json.loads(read_at(config.removeprefix('res://'),old))
    module_pattern=re.search(r'var path := "([^"]+%s[^"]+)" % id',body).group(1)
    for template in catalog['templates']:
        for variant in template['variants']:
            for identifier in variant:
                p=module_pattern%identifier
                if p not in paths:paths.append(p)
                reasons[p].append('catalog module '+identifier)
    for p in re.findall(r'files\.append\("([^"]+)"\)',body):
        paths.append(p);reasons[p].append('explicit appended input')
    directory_sets=[ast.literal_eval(s) for s in re.findall(r'for directory: String in (\[[^\n]+\]):',body)]
    assert len(directory_sets)==2
    for directory in directory_sets[0]:
        for p in members(directory,old,False):
            if p.endswith('.gd'):
                res='res://'+p
                if res not in paths:paths.append(res)
                reasons[res].append('nonrecursive direct .gd directory '+directory)
    for directory in directory_sets[1]:
        for p in members(directory,old,True):
            if p.endswith(('.gd','.tres')):
                res='res://'+p
                if res not in paths:paths.append(res)
                reasons[res].append('recursive .gd/.tres directory '+directory)
    assert len(paths)==len(set(paths)),'Native routine has duplicates; preserve instead of assuming set semantics'
    paths.sort();stamp=json.loads(read_at('resources/foundry/export_basis.json',old));engine=stamp['engine']
    entries=[{'path':p.removeprefix('res://'),'res_path':p,'sha256':digest(read_at(p.removeprefix('res://'),old)),'reasons':sorted(set(reasons[p]))} for p in paths]
    text='\n'.join([engine]+[r['res_path']+':'+r['sha256'] for r in entries]);basis=digest(text.encode())
    return {'engine_string_from_recorded_actual_stamp':engine,'basis':basis,'count':len(entries),'entries':entries,'directory_sets':directory_sets,'basis_source_sha256':digest(source.encode())}
a=expand(True);b=expand(False)
(OUT/'basis_R169_inputs.json').write_text(json.dumps(a,indent=2)+'\n');(OUT/'basis_current_inputs.json').write_text(json.dumps(b,indent=2)+'\n')
assert a==b,'Foundry actual source input set/content differs'
assert a['basis']=='f3e060598385696137aa40910811fcbfed931853fe7f4c9992b11cf1af0263cb'
original=json.loads((OUT/'baseline_inventory.json').read_text());resources=[]
for row in original['files']:
    data=(ROOT/row['path']).read_bytes();assert digest(data)==row['sha256']==digest(old_bytes(row['path']))
    resources.append(row['path'])
current_stamp=json.loads((ROOT/'resources/foundry/export_basis.json').read_text())
assert current_stamp['basis']==b['basis'] and current_stamp['schema']==1
for path,h in current_stamp['configs'].items():assert digest((ROOT/path.removeprefix('res://')).read_bytes())==h
source_names={x['path'] for x in b['entries']}
changed_commit=command('diff','--name-only',REF,'HEAD').splitlines();dirty=command('diff','--name-only','HEAD').splitlines()
assert not source_names.intersection(changed_commit+dirty)
assert 'scripts/art/avatar_presentation.gd' in changed_commit and 'scripts/art/avatar_presentation.gd' not in source_names
assert 'scripts/art/player_visual_adapter.gd' in source_names
result={'status':'SOURCE_EQUIVALENT_FOR_FOUNDRY_BASIS__W10_REBUILD_CANCELLED','read_only':True,'native_executed':False,'tracked_writes':False,'baseline_commit':REF,'current_head':command('rev-parse','HEAD'),'actual_native_basis_input_count':b['count'],'actual_native_basis_input_paths_and_content_equal':True,'native_basis_reconstructed_exactly':b['basis'],'original_R169_recorded_basis_equal':True,'template_stamp_schema_and_recorded_engine_unchanged':True,'all4_template_config_hashes_equal':True,'resources56_byte_exact_to_R169':True,'resource_paths':resources,'avatar_presentation_is_basis_input':False,'player_visual_adapter_is_basis_input':True,'changed_basis_inputs':[],'changed_committed_paths_since_R169':changed_commit,'dirty_worktree_paths_at_audit':dirty,'reason':'basis() hashes its explicit file list, selected module catalog paths, four direct .gd directories and seven recursive .gd/.tres directories. scripts/art/avatar_presentation.gd is not listed and is outside those trees. Hashing player_visual_adapter.gd does not recursively hash its preload/class dependencies. F1 therefore does not change native/editor basis. Cooked branch validates recorded engine and four configuration hashes; all remain byte-identical.','correction':'The earlier W10 premise that F1 must change Foundry basis was incorrect. Its expected-different-basis rebuild plan is cancelled, not relaxed. Existing56 R169 resource bytes and original W9 native proof are preserved; no new Foundry validation is claimed.','scope_limit':'This proves equality of the actual Foundry basis source set/content, record schema/config stamp and existing artifacts. F1 changes runtime avatar UI source outside that hash set; this report does not claim full-game runtime identity, new native/browser/device validation or redesign the original validator.'}
(OUT/'source-equivalence-report.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['status','current_head','actual_native_basis_input_count','native_basis_reconstructed_exactly','resources56_byte_exact_to_R169','avatar_presentation_is_basis_input']},indent=2))
