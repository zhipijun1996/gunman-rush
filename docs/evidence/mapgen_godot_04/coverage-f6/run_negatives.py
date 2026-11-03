from pathlib import Path
import copy,hashlib,json,os,subprocess,time
E=Path('/tmp/mapgen-v4-actual-coverage-8ms');I=Path('/tmp/mapgen-v4-actual-inputs-8ms');W=Path('/tmp/map-edit-runtime-audit-v04');N=E/'negative-inputs';N.mkdir(exist_ok=True);L=E/'negative-logs';L.mkdir(exist_ok=True)
h=lambda b:hashlib.sha256(b).hexdigest();rows=[]
# Hard-link immutable original inputs once; mutate only new per-case files.
for p in I.rglob('*'):
 if p.is_file():
  q=N/p.relative_to(I);q.parent.mkdir(parents=True,exist_ok=True)
  if not q.exists():os.link(p,q)
source_before={str(p.relative_to(I)):h(p.read_bytes())for p in I.rglob('*')if p.is_file()}
cases=['result-sha','result-schema','request-fingerprint','missing-content-ref','orphan-content-ref','missing-moving-field','empty-moving-array','missing-hazards-field','unknown-content-field','unknown-mechanism','duplicate-instance','duplicate-connection','missing-endpoint-instance','missing-endpoint-port','content-version','source-sha','unknown-module','protocol-payload-newline','old-algorithm']
for name in ['default','gears']:
 profile=json.loads((I/(name+'-profile.json')).read_text());original=json.loads((I/profile['files']['result']['path']).read_text())
 for case in cases:
  key=name+'-'+case;folder=N/'probes'/key;folder.mkdir(parents=True,exist_ok=True);changed=copy.deepcopy(original);lock=copy.deepcopy(profile)
  store=changed['content_store'];instances=changed['map']['instances'];connections=changed['map']['connections'];first=instances[0];content=store[first['content_ref']];expected='AssertionError'
  if case=='result-sha':changed['metrics']['negative_probe_only']=True;expected='ACTUAL_INPUT_SHA_MISMATCH'
  elif case=='result-schema':changed['schema']='wrong'
  elif case=='request-fingerprint':changed['request_fingerprint']='0'*64
  elif case=='missing-content-ref':store.pop(first['content_ref']);expected='ACTUAL_STORE_REFS_MISMATCH'
  elif case=='orphan-content-ref':store['content/orphan.json']={};expected='ACTUAL_STORE_REFS_MISMATCH'
  elif case=='missing-moving-field':content.pop('moving_platforms');expected='ACTUAL_CONTENT_FIELDS_MISMATCH'
  elif case=='empty-moving-array':next(c for c in store.values()if c['moving_platforms'])['moving_platforms']=[];expected='ACTUAL_ARRAY_LENGTH_MISMATCH'
  elif case=='missing-hazards-field':content.pop('hazards');expected='ACTUAL_CONTENT_FIELDS_MISMATCH'
  elif case=='unknown-content-field':content['unexpected_component']=[];expected='ACTUAL_CONTENT_FIELDS_MISMATCH'
  elif case=='unknown-mechanism':
   c=next(c for c in store.values()if c.get('latches'));c['latches'][0]['kind']='unregistered_mechanism'
  elif case=='duplicate-instance':instances.append(copy.deepcopy(first));expected='DUPLICATE_ACTUAL_INSTANCE_ID'
  elif case=='duplicate-connection':connections.append(copy.deepcopy(connections[0]))
  elif case=='missing-endpoint-instance':connections[0]['a']['instance_id']='does_not_exist';expected='KeyError'
  elif case=='missing-endpoint-port':connections[0]['a']['port_id']='does_not_exist'
  elif case=='content-version':first['content_version']='sha256:'+'0'*64
  elif case=='source-sha':content['source_sha256']='0'*64
  elif case=='unknown-module':first['module_id']='missing-module';expected='KeyError'
  elif case=='old-algorithm':changed['map']['generator']['algorithm']='stable-v2'
  result=folder/'result.json';result.write_text(json.dumps(changed))
  lock['files']['result']['path']=str(result.relative_to(N))
  if case!='result-sha':lock['files']['result']['sha256']=h(result.read_bytes())
  if case=='protocol-payload-newline':
   payload=folder/'protocol_payload.json';payload.write_bytes((I/profile['files']['protocol_payload']['path']).read_bytes()+b'\n');lock['files']['protocol_payload']={'path':str(payload.relative_to(N)),'sha256':h(payload.read_bytes())}
  lockfile=folder/'profile.json';lockfile.write_text(json.dumps(lock,indent=2)+'\n');out=E/'negative-outputs'/key;assert not out.exists()
  argv=['python3','-B','tools/runtime_audit/check_930001.py','--actual-profile',str(lockfile),'--inputs',str(N),'--zip110','/tmp/gunman-rush-mapgen-04/resources/mapgen/module-pack-1.1.0.zip','--out',str(out)]
  start=time.monotonic();r=subprocess.run(argv,cwd=W,capture_output=True,text=True,timeout=30);elapsed=time.monotonic()-start
  log=L/(key+'.log');log.write_text(r.stdout+r.stderr)
  row={'profile':name,'case':case,'argv':argv,'exit_code':r.returncode,'expected_error':expected,'expected_error_seen':expected in r.stderr,'no_output':not out.exists(),'elapsed_seconds':elapsed,'log_sha256':h(log.read_bytes()),'mutated_profile_sha256':h(lockfile.read_bytes())};rows.append(row)
  assert r.returncode!=0 and row['expected_error_seen'] and row['no_output'],row
assert source_before=={str(p.relative_to(I)):h(p.read_bytes())for p in I.rglob('*')if p.is_file()}
report={'status':'ACTUAL_PROFILE_NEGATIVES_38_OF_38','producer_sha256':h((W/'tools/runtime_audit/check_930001.py').read_bytes()),'original_actual_inputs_unchanged':True,'cases':rows,'permission_scope':'Not tested as rejected: this inventory producer checks referenced ports exist but does not validate INOUT/INPUT/OUTPUT permission semantics. Actual host Provider/schema validation owns that boundary; no compatibility claim.'}
(E/'negative-summary.json').write_text(json.dumps(report,indent=2)+'\n');print('negative',len(rows),'all rejected; original inputs unchanged')
