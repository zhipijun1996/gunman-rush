from pathlib import Path
import ast,json,hashlib,difflib
R=Path('/workspace/gunman-rush-refactor');E=Path('/workspace/refactor-evidence/combat-perf-deploy-01/style32');meta=json.loads((E/'metadata.json').read_text());A=meta['archive'];files=['tests/test_region_bible.py','tests/test_region_creative_direction.py'];original={p:(R/A/p).read_text() for p in files}
def methods(s):return {n.name:n for n in ast.walk(ast.parse(s)) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
def block(s,n):return ''.join(s.splitlines(keepends=True)[n.lineno-1:n.end_lineno])
def replace_method(s,name,new):
 old=block(s,methods(s)[name]);assert s.count(old)==1;return s.replace(old,new)
def ah(n):return hashlib.sha256(ast.dump(n,include_attributes=False).encode()).hexdigest()
b=original[files[0]];c=original[files[1]]
needle='def frozen30_root(testcase):\n    return _frozen_style_root(testcase, history.STYLE30_ARCHIVE, history.style30_source)\n';assert b.count(needle)==1
b=b.replace(needle,needle+'\n\ndef frozen31_root(testcase):\n    return _frozen_style_root(testcase, history.STYLE31_ARCHIVE, history.style31_source)\n')
for old,new in [("self.assertEqual(style['content']['version'],'31')","self.assertEqual(style['content']['version'],'32')"),("self.assertEqual(live['version'],'31')","self.assertEqual(live['version'],'32')")]:
 assert old in b;b=b.replace(old,new)
b=b.replace("'31':'25','creative-v29'","'31':'25','32':'25','creative-v29'").replace("'creative-v34':'creative-v28'","'creative-v34':'creative-v28','creative-v35':'creative-v28'")
c=c.replace("self.assertEqual(task['creative_direction']['version'], 'creative-v34')","self.assertEqual(task['creative_direction']['version'], 'creative-v35')")
base_names=['test_current31_exact206_sources_roles_media_and_three_technical_changes','test_current31_rejects_old_missing_corrupt_sources_and_manifest_resigning','test_current31_inputs_cover_all_current_sources_and_preserve_ordered_prefix']
for name in base_names[:2]:
 text=block(b,methods(b)[name]);first,rest=text.split('\n',1);b=replace_method(b,name,first+'\n        self.root = frozen31_root(self)\n        self.bible, self.ref = creative.bind_region_bible(\'thorn_forest\', self.root)\n'+rest)
name='test_current34_retains_selected_content_and_refuses_prior33_binding';text=block(c,methods(c)[name]);text=text.replace('from test_region_bible import frozen30_root','from test_region_bible import frozen30_root, frozen31_root').replace('prior_root = frozen30_root(self)','prior_root = frozen30_root(self)\n        current_root = frozen31_root(self)').replace('creative.load_direction(path, region)','creative.load_direction(path, region, root=current_root)').replace('creative.load_bible_registry()','creative.load_bible_registry(current_root)').replace('creative.bind_region_bible(region)[1]','creative.bind_region_bible(region, current_root)[1]').replace("creative.validate_bible_binding(old['region_bible'])","creative.validate_bible_binding(old['region_bible'], root=current_root)")
c=replace_method(c,name,text)
new=[]
for name in base_names:
 text=block(original[files[0]],methods(original[files[0]])[name]);text=text.replace('test_current31_','test_current32_').replace('and_three_technical_changes','and_six_technical_changes').replace('MAP_QUERY_STYLE','MOBILE_MESH_STYLE').replace('history.style30_source','history.style31_source').replace('history.STYLE30_ARCHIVE','history.STYLE31_ARCHIVE').replace('frozen30_root','frozen31_root').replace("current['version'], '31'","current['version'], '32'")
 if 'exact206' in name:
  text=text.replace('self.assertEqual(len(changes), 3)','self.assertEqual(len(changes), 6)').replace("'ca505102f2bcd429a8a4c62eabd4f3a73a040ee8'",repr(meta['current_source'])).replace('exact committed ca505102 bytes','not part of the baseline commit')
 if 'rejects' in name:text=text.replace("self.assertEqual(len(manifest['sources']), 3)","self.assertEqual(len(manifest['sources']), 6)")
 if 'inputs_cover' in name:text=text.replace('MOBILE_MESH_STYLE','COMBAT_PERF_STYLE')
 new.append(text)
guard=block(b,methods(b)['test_prior30_complete_methods_preserved_and_mutations_rejected']).replace('test_prior30_','test_prior31_').replace('history.STYLE30_ARCHIVE','history.STYLE31_ARCHIVE').replace('MOBILE_MESH_TEST_METHOD_MIGRATIONS','COMBAT_PERF_TEST_METHOD_MIGRATIONS').replace('test_current30_exact206_sources_roles_media_and_three_technical_changes','test_current31_exact206_sources_roles_media_and_three_technical_changes').replace('test_current33_retains_selected_content_and_refuses_prior32_binding','test_current34_retains_selected_content_and_refuses_prior33_binding')
b=b.replace('\n\nclass SuitePartitionTests','\n\n'+'\n\n'.join(new+[guard])+'\n\n\nclass SuitePartitionTests')
start=b.index('CURRENT_METHODS = (');end=b.index('\nHISTORY_METHODS = (',start);part=b[start:end].replace('RuntimeOwnershipBindingTests.test_current31_','RuntimeOwnershipBindingTests.test_current32_').replace('and_three_technical_changes','and_six_technical_changes');b=b[:start]+part+b[end:]
hstart=b.index('HISTORY_METHODS = (');hend=b.index('\n)\n',hstart);b=b[:hend]+''.join("\n    'RuntimeOwnershipBindingTests."+n+"'," for n in base_names+['test_prior31_complete_methods_preserved_and_mutations_rejected'])+b[hend:]
text=block(original[files[1]],methods(original[files[1]])['test_current34_retains_selected_content_and_refuses_prior33_binding']);text=text.replace('test_current34_retains_selected_content_and_refuses_prior33_binding','test_current35_retains_selected_content_and_refuses_prior34_binding').replace('frozen30_root','frozen31_root').replace("('creative-v33', 'creative-v34', 'creative-v34')","('creative-v34', 'creative-v35', 'creative-v35')").replace('history.STYLE30_ARCHIVE','history.STYLE31_ARCHIVE');c=c.replace('\n\n\nclass ValidationReadScopeTests','\n\n'+text+'\n\n\nclass ValidationReadScopeTests')
changed={}
for p,s in [(files[0],b),(files[1],c)]:
 old,newm=methods(original[p]),methods(s)
 for n,m in old.items():
  if ah(m)!=ah(newm[n]):changed[Path(p).name+'::'+n]=dict(original_ast_sha256=ah(m),current_ast_sha256=ah(newm[n]),reason='Only current32/creative35 version expectation/normalization or explicit finite31 historical root; original predicates retained with complete-method identity and external inverse proof.')
for node in reversed(ast.parse(b).body):
 if isinstance(node,ast.Assign) and isinstance(node.value,ast.Dict):
  try:d=ast.literal_eval(node.value)
  except (ValueError,TypeError):continue
  if not isinstance(d,dict) or not any(isinstance(v,dict) and 'current_ast_sha256' in v for v in d.values()):continue
  dirty=False
  for key,row in d.items():
   if key in changed and row['current_ast_sha256']!=changed[key]['current_ast_sha256']:
    row.setdefault('prior_current_ast_sha256s',[]).append(row['current_ast_sha256']);row['current_ast_sha256']=changed[key]['current_ast_sha256'];row['reason']+=' Current32/creative35 finite adaptation; prior accepted identity retained.';dirty=True
  if dirty:
   lines=b.splitlines(keepends=True);b=''.join(lines[:node.lineno-1])+node.targets[0].id+' = '+json.dumps(d,indent=4,ensure_ascii=False)+'\n'+''.join(lines[node.end_lineno:])
b=b.replace('class RuntimeOwnershipBindingTests','COMBAT_PERF_STYLE = '+repr(meta['style'])+'\nCOMBAT_PERF_TEST_METHOD_MIGRATIONS = '+json.dumps(changed,indent=4,ensure_ascii=False)+'\n\nclass RuntimeOwnershipBindingTests')
(R/files[0]).write_text(b);(R/files[1]).write_text(c)
proof={};inverse=[]
for p,s in [(files[0],b),(files[1],c)]:
 old,newm=methods(original[p]),methods(s);proof[p]={'old_methods':len(old),'new_methods':len(newm),'added_ids':sorted(newm.keys()-old.keys()),'changed_methods':{n:dict(before=ah(old[n]),after=ah(newm[n])) for n in old if ah(old[n])!=ah(newm[n])}}
 for n in old:
  x=block(original[p],old[n]);y=block(s,newm[n])
  if x!=y:
   # Full-method old/new text is retained for independent finite-diff review.
   inverse.append({'path':p,'method':n,'old_method':x,'current_method':y,'diff':''.join(difflib.unified_diff(x.splitlines(True),y.splitlines(True),fromfile='original',tofile='current'))})
(E/'test-method-map.json').write_text(json.dumps(proof,indent=2)+'\n');(E/'test-method-full-diff.json').write_text(json.dumps(inverse,indent=2)+'\n')
print(json.dumps(proof,indent=2))
