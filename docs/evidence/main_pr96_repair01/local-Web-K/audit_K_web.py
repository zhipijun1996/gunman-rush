from pathlib import Path
import json,hashlib,subprocess,zipfile,csv
R=Path.cwd();D=R/'build/forest_revision04/final-F2-local-web';O=R/'build/forest_revision04/fix-F2-review';Z=R/'build/forest_revision04/final-F2-local-web-delivery'
def load(p):return json.loads(Path(p).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
def file_sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  while b:=f.read(1024*1024):h.update(b)
 return h.hexdigest()
K='8f803e2f04b17db3ed725df9071669fe78cadeea';H='562542bd458f25c8fb5f6e56e74c69d363976735'
g=load(D/'gui/report.json');s=load(D/'selector-popup/report.json');summary=load(Z/'summary.json');frozen=load(D/'local-frozen-bundle.json')
assert g['status']=='passed' and len(g['checks'])==20 and len(g['identities'])==8 and g['errors']==[]
identity=frozen['identity'];assert identity['source_commit']==K and identity['pack_sha256']=='1630e2150b599c6f316fe57a5b81f1a063f83aadd9c948213c11b62d77213cf2' and identity['pack_bytes']==141171220
assert all(row['identity']==identity for row in g['identities']) and s['identity_before']==s['identity_after']==identity
assert s['errors']==s['failed_requests']==[] and s['source_head_before']==s['source_head_after']==K and s['source_stable'] and s['source_before']==s['source_after']
steps={}
for phase in ['build','browser','selector']:
 r=load(D/(phase+'-outer.json'));assert r['exit_code']==0 and r['execution_head']==K and r['source_stable'] and r['source_before']==r['source_after'] and r['extra_total_timer'] is None
 assert r['source_before']['head']==K and r['source_before']['status']==''
 assert r['log_sha256']==file_sha(D/(phase+'.log'))
 steps[phase]={'seconds':r['seconds'],'original_caps':r['original_caps'],'exit':r['exit_code']}
inv=load(D/'browser-outer.json')['source_before']['inventory'];assert inv==s['source_before'] and len(inv)==3249
for phase in ['build','selector']:assert load(D/(phase+'-outer.json'))['source_before']['inventory']==inv
# Reuse the independently verified immutable H full-Git inventory, then verify every differing blob against K.
prior_audit=R/'build/forest_revision04/movie-final-H-review/independent-media-and-source-audit.json';pa=load(prior_audit);assert pa['all3249_source_guard_entries_equal_actual_H_Git_blobs'] and pa['source_head']==H
prior=load(R/'build/forest_revision04/movie-final-H/map1/receipt.json')['source_before'];assert set(prior)==set(inv)
changed=[p for p in inv if prior[p]!=inv[p]];git_changed=subprocess.check_output(['git','diff',H,K,'--name-only'],text=True).splitlines();assert set(changed)==set(git_changed).intersection(inv)
assert len(changed)==4
for p in changed:assert sha(subprocess.check_output(['git','show',K+':'+p]))==inv[p]
for p,h in s['source_bindings'].items():assert inv[p]==h
for p in ['bundle-after-gui.json','local-bundle-after.json']:
 a=load(D/p)
 for k in ['build_info','identity','pack_sha256','pack_bytes','html_sha256','build_info_sha256','worker_sha256']:assert a[k]==frozen[k]
assert file_sha(R/'build/web'/identity['pack'])==identity['pack_sha256']
assert (R/'build/web'/identity['pack']).stat().st_size==identity['pack_bytes']
expected={(d,r,m) for d in ['mouse','touch'] for r in ['plains','thorn_forest'] for m in [1,2]}
for e in ['debug_entry','region_assembled']:
 rows=[x for x in g['events'] if x['event']==e];assert len(rows)==8 and {(x['device'],x['region'],x['map_index']) for x in rows}==expected
for x in g['events']:
 if x['event']=='region_assembled' and x['region']=='thorn_forest':assert x['layout_version']=='forest-fruit-routes-v14' and x['content_version']=='thorn-forest-region-v2' and x['abilities']==['grapple']
headings=[]
for p in (D/'gui').glob('*-entry-actual-heading-receipt.json'):
 r=load(p);matches=[x for x in r['observations'] if x['exact_complete_match']];assert r['status']=='passed' and r['match_count']==len(matches)==1
 row=matches[0]
 with (p.parent/row['ocr']).open() as f:words=[r['text'] for r in csv.DictReader(f,delimiter='\t') if r['level']=='5' and r['text'].strip()]
 assert ' '.join(words)==row['rendered']==r['expected'] and not row['cut_boundary_ink'];headings.append(r['expected'])
assert len(headings)==8
assert s['input_trace'][-2]['kind']=='mouse_click' and s['input_trace'][-1]['key']=='Escape'
# Verify exact original CLI retained, including actual mouse/touch and pause/resume actions.
driver=(R/'tools/verify_forest_browser.py').read_bytes();assert sha(driver)==s['source_bindings']['tools/verify_forest_browser.py']
for text in [b'await page.touchscreen.tap(*point)',b'await page.mouse.click(*point)',b'await click_text("MENU","pause-button")',b'await click_text("RESUME","pause")']:assert text in driver
idx=load(Z/'file-index.json')['files'];zip_path=Z/'local-Web-K-selected.zip';assert zip_path.stat().st_size==7602552 and file_sha(zip_path)=='52936a53aa1f6540acea4b7116954180b9b81967bd48342580f628647760d0d0'
pngs=[]
with zipfile.ZipFile(zip_path) as z:
 assert len(z.namelist())==87 and z.testzip() is None
 for r in idx:
  b=z.read(r['archive_path']);assert sha(b)==r['sha256']==file_sha(R/r['original_path']) and len(b)==r['bytes']
  if r['original_path'].endswith('.png'):pngs.append({'path':r['original_path'],'sha256':r['sha256'],'actually_viewed_by_reviewer':True})
assert len(pngs)==19
server=(D/'local-server.log').read_text();assert 'GET /favicon.ico HTTP/1.1" 404' in server
result={'status':'PASS','source_commit':K,'inventory_3249_equal_across_all_phases':True,'prior_full_git_inventory_independent_audit':str(prior_audit.relative_to(R)),'prior_audit_sha256':file_sha(prior_audit),'H_to_K_changed_source_blobs_checked_against_Git':changed,'pack':identity,'pack_current_bytes_hash_verified':True,'bundle_before_after_equal':True,'steps':steps,'original_GUI':{'checks':20,'identities':8,'unique_event_pairs':8,'complete_headings_independently_TSV_checked':8,'errors':[],'actual_unique_driver_mouse_touch_menu_resume_retained':True,'gestures_report_array':g['gestures'],'scope':'DOM emulation/debug entries, not physical device or natural progression; original report does not persist per-case full input trace'},'selector':{'seconds':s['seconds'],'actual_mouse_click_and_Escape_trace':True,'errors':[],'failed_requests':[],'console_scope':'One recorded console error HTTP404; original server log attributes favicon.ico. No SCRIPT/PAGE/SHADER error observed; do not call all console messages error-free.'},'selected_zip':{'sha256':file_sha(zip_path),'bytes':7602552,'entries':87,'all_indexed_bytes_verified':len(idx),'all19_png_actually_viewed':pngs},'reviewer_ran_native_or_browser':False}
(O/'K_independent_web_audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'status':'PASS','source_inventory':len(inv),'changed_source_blobs':len(changed),'PNG':len(pngs),'ZIP_verified':len(idx)}))
