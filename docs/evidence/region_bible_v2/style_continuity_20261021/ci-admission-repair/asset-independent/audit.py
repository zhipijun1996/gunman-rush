import collections,copy,hashlib,json,re,subprocess,sys,wave
from pathlib import Path
from PIL import Image
ROOT=Path.cwd();OUT=ROOT/'build/region_bible_v2/asset-provenance-independent-first';sys.path.insert(0,str(ROOT/'tools'))
from quality import validate_asset
rows=[]
def sha(p):return hashlib.sha256((ROOT/p).read_bytes()).hexdigest()
def check(n,c,a=None):
 rows.append({'name':n,'passed':bool(c),'actual':a});assert c,n
ip='build/region_bible_v2/quality-asset-record-repair/inventory.json';inv=json.loads((ROOT/ip).read_bytes())
check('author_frozen_inventory_sha',sha(ip)=='5b30425773d584946a02149c0d667ff8ba955b51b87c1147798ae60cb45b6dd7')
cards={p.as_posix():json.loads(p.read_bytes()) for p in sorted(Path('docs/quality/asset_records').glob('forest-bible-v2-*.json'))};check('exact28cards',len(cards)==28)
check('card_inventory_exact',set(cards)=={r['path'] for r in inv['records']})
for r in inv['records']:check('frozen_card_sha:'+r['path'],sha(r['path'])==r['sha256'])
production_names=subprocess.check_output(['git','ls-files','scripts','resources','scenes','config','shaders'],text=True).splitlines()
load_refs={}
for name in production_names:
 if Path(name).suffix not in {'.gd','.tres','.tscn','.json','.cfg','.gdshader'}:continue
 text=(ROOT/name).read_text(errors='replace')
 for match in re.finditer(r'res://(assets/forest_bible_v2/[^"\s\)]+)',text):
  p=match.group(1)
  if Path(p).suffix in {'.png','.wav','.ogg','.json','.tres'}:load_refs.setdefault(p,[]).append(name)
runtime={p for d in cards.values() for p in d['runtime_paths']}
check('exact21runtime_loaders',len(runtime)==21 and runtime==set(load_refs),load_refs)
for name,d in cards.items():
 check('validate_actual_card:'+name,not validate_asset(d),validate_asset(d))
 check('unknown_rights_unverified_visual_no_user_claim:'+name,d['license_status']=='unknown' and d['visual_status']=='unverified' and d['user_acceptance_evidence']==[])
 check('source_exact_sha:'+name,sha(d['source_path'])==d['source_sha256'])
 for a in d.get('associated_files',[]):check('association_exact_sha:'+a['path'],sha(a['path'])==a['sha256'])
 for p in d['runtime_paths']:check('real_declared_consumer:'+p,bool(set(d.get('consumer_files',[]))&set(load_refs[p])))
 if d['disposition']!='runtime_candidate':check('nonruntime_boundary:'+name,d['runtime_paths']==[] and d.get('consumer_files',[])==[] and bool(d['non_runtime_reason']))
 if len(d['runtime_paths'])==1 and '/source/native_' in d['source_path'] and d['source_path'].endswith('.png'):
  check('literal_native_runtime_byte_copy:'+name,(ROOT/d['source_path']).read_bytes()==(ROOT/d['runtime_paths'][0]).read_bytes())
 # Existing validator must reject mutated evidence, not merely populated fields.
 for label,key,value in [('source_hash','source_sha256','0'*64),('false_visual_pass','visual_status','passed')]:
  m=copy.deepcopy(d);m[key]=value;check('reject_mutant_'+label+':'+name,bool(validate_asset(m)))
 if d['disposition']!='runtime_candidate':
  m=copy.deepcopy(d);m['runtime_paths']=['assets/forest_bible_v2/native/fruit.png'];check('reject_nonruntime_forged_runtime:'+name,bool(validate_asset(m)))
for r in inv['file_classification']:check('actual_inventory_sha:'+r['path'],sha(r['path'])==r['sha256'])
tracked=subprocess.check_output(['git','ls-files','assets/forest_bible_v2'],text=True).splitlines(); content={p for p in tracked if not p.endswith('.import')}
check('175_content_files_exact_excluding34_import_sidecars',len(content)==175 and content=={r['path'] for r in inv['file_classification']})
counts=collections.Counter(r['classification'] for r in inv['file_classification']);check('perfile_classification_exact',counts=={'runtime_candidate':21,'production_record_only':76,'rejected_evidence_only':78},dict(counts))
check('original_asset_source_checker_tests_no_worktree_delta',not subprocess.check_output(['git','diff','--name-only','HEAD','--','assets','scripts','resources','tools/quality.py','tools/check_quality.py','tools/check_quality_diff.py','tests/test_level_region_context.py'],text=True).strip())
recipe=json.loads((ROOT/'resources/forest_bible_v2/native_sprite_derivatives.json').read_bytes())['derivatives']
for d in cards.values():
 for deriv in d.get('derivatives',[]):
  check('derivative_exact_existing_recipe:'+deriv['id'],deriv in recipe)
  check('derivative_record_source_hash:'+deriv['id'],sha(deriv['source'])==deriv['source_sha256'])
  check('derivative_record_output_hash:'+deriv['id'],sha(deriv['output'])==deriv['output_sha256'])
  with Image.open(ROOT/deriv['source']) as src,Image.open(ROOT/deriv['output']) as dst:
   expected=src.convert('RGBA').crop(deriv['crop_xyxy']).resize(deriv['native_size_px'],Image.Resampling.NEAREST)
   check('actual_nearest_crop_pixels:'+deriv['id'],expected.size==dst.size and expected.tobytes()==dst.convert('RGBA').tobytes())
for p in Path('assets/forest_bible_v2/source').glob('*.receipt.json'):
 d=json.loads(p.read_bytes());source=p.as_posix().replace('.receipt.json','.original.png')
 if 'source_sha256' in d:check('original_generated_receipt_hash:'+p.name,sha(source)==d['source_sha256'])
 else:check('historical_receipt_has_no_hash_not_invented:'+p.name,p.name=='midtree_v1.receipt.json' and any(c['source_path']==source and c['source_sha256']==sha(source) for c in cards.values()))
 check('no_inferred_model_or_license:'+p.name,d['model']=='not_exposed' and d['license']=='unknown')
audio=json.loads((ROOT/'assets/forest_bible_v2/audio/provenance.json').read_bytes());check('original_audio_generator_sha',sha(audio['generator'])==audio['generator_sha256'])
for r in audio['files']:
 check('audio_actual_byte_sha:'+r['path'],sha(r['path'])==r['sha256'])
 with wave.open(str(ROOT/r['path'])) as f:check('audio_actual_pcm_header:'+r['path'],(f.getnchannels(),f.getframerate(),f.getsampwidth()*8,f.getnframes())==(r['channels'],r['sample_rate'],r['bits_per_sample'],r['frames']))
check('source_tree_excluded_from_import',(ROOT/'assets/forest_bible_v2/source/.gdignore').is_file())
report={'verdict':'ACCEPT_SCOPED','scope':'28 machine provenance registrations; actual source/association bytes and21 literal runtime loaders only. No art/license/formal admission or listening approval.','reviewer':'/root/bible_test_workflow_independent_review','inventory_sha256':sha(ip),'cards':{p:sha(p) for p in cards},'checks':rows,'counts':dict(counts),'limits':['Static literal loaders do not establish runtime reachability or every dynamic consumer.','34 tracked import sidecars excluded from175 content assets, not deleted or reclassified.','Historical candidate language inside frozen source provenance remains historical; new cards current disposition/consumer fields govern current registration.','No engine, source edit, image edit, asset generation, BGM or user acceptance performed.']}
(OUT/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n'); print(json.dumps({'verdict':report['verdict'],'checks':len(rows),'classifications':dict(counts)}))
