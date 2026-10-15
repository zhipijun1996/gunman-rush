from pathlib import Path
import importlib.util,copy,json,sys,hashlib,ast,subprocess
ROOT=Path('/workspace/gunman-rush');spec=importlib.util.spec_from_file_location('independent_quality_test_fixture',ROOT/'tests/test_quality.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
rows=[]
def probe(name,mutate,expected_reject=True):
 t=m.QualityTests();t.setUp()
 try:
  base,asset=t.asset_diff_fixture();mutate(t,asset)
  (t.root/'docs/quality/asset_records/test.json').write_text(json.dumps(asset));errors,changed=m.validate_diff(base,t.root)
  result={'name':name,'expected_reject':expected_reject,'actual_errors':errors,'changed':changed,'actual_rejected':bool(errors),'temp_git_base':base,'metadata':asset,'consumer':(t.root/'scripts/consumer.gd').read_text()}
  rows.append(result)
 except Exception as e:rows.append({'name':name,'expected_reject':expected_reject,'actual_rejected_by_exception':repr(e)})
 finally:t.doCleanups()

def precise_scope(t):
 p=t.root/'docs/quality/records/test.json';rec=json.loads(p.read_text());rec['affected_paths']=[f.relative_to(t.root).as_posix() for d in ['assets','scripts','scenes','resources'] for f in (t.root/d).rglob('*') if f.is_file()] + (['project.godot'] if (t.root/'project.godot').exists() else []);p.write_text(json.dumps(rec))
def dynamic_family(t,a,unknown=False,runtime=False):
 folder=t.root/'assets/region_production_v3/spaces/probe_grove';folder.mkdir(parents=True)
 png=folder/'source.png';png.write_bytes((ROOT/'assets/plains_v3/background_layers/sky.png').read_bytes());pn=png.relative_to(t.root).as_posix();fp=folder/'family.json';fp.write_text(json.dumps({'path':pn,'sha256':hashlib.sha256(png.read_bytes()).hexdigest()}));fn=fp.relative_to(t.root).as_posix()
 script=t.root/'scripts/art/plains_semantic_landscape.gd';script.parent.mkdir(parents=True);script.write_text('extends RefCounted\nconst PILOT_FAMILIES := ["probe_grove"]\nconst FAMILY_ROOT := "res://assets/region_production_v3/spaces/"\nfunc read_family(family_id):\n\treturn JSON.parse_string(FileAccess.get_file_as_string(FAMILY_ROOT+family_id+"/family.json"))\n'+('func arbitrary(selection):\n\treturn read_family(selection)\n' if unknown else ''))
 orig=a['source_path'];a.update(source_path=pn,source_sha256=hashlib.sha256(png.read_bytes()).hexdigest(),disposition='runtime_candidate' if runtime else 'production_record_only',runtime_paths=[pn,fn,script.relative_to(t.root).as_posix()] if runtime else [],non_runtime_reason='probe only offline claim');a['associated_files'] +=[{'path':orig,'sha256':hashlib.sha256((t.root/orig).read_bytes()).hexdigest(),'role':'reference'},{'path':fn,'sha256':hashlib.sha256(fp.read_bytes()).hexdigest(),'role':'source_contract'}];precise_scope(t)
probe('dynamic_family_offline_known_conflict',lambda t,a:dynamic_family(t,a))
probe('dynamic_family_unknown_call_unresolved',lambda t,a:dynamic_family(t,a,unknown=True))
probe('dynamic_family_real_runtime_positive',lambda t,a:dynamic_family(t,a,runtime=True),False)
def guide(t,a):
 f=t.root/'assets/production/guide.png';f.write_bytes((ROOT/'assets/plains_v3/background_layers/sky.png').read_bytes());a['associated_files'].append({'path':f.relative_to(t.root).as_posix(),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'role':'reference'});precise_scope(t)
probe('valid_offline_original_PNG_guide',guide,False)
probe('unknown_generic_dynamic_template',lambda t,a:(t.root/'scripts/consumer.gd').write_text('extends Node\nfunc fetch(id):\n\treturn load("res://assets/%s.png" % id)\n'))
probe('unknown_directory_concatenation',lambda t,a:(t.root/'scripts/consumer.gd').write_text('extends Node\nfunc fetch(id):\n\treturn load("res://assets/"+id+".png")\n'))
# Contract boundary only: full namespace construction is outside declared finite/literal adapter domain.
probe('boundary_split_res_namespace_not_detected',lambda t,a:((t.root/'scripts/consumer.gd').write_text('extends Node\nfunc fetch(id):\n\treturn load("res://"+"assets/source.png")\n'),a.update(disposition='rejected_evidence_only',runtime_paths=[],non_runtime_reason='Counterexample outside recognized literal namespace')),False)
out=ROOT/'build/region_production_v3/independent/asset_provenance_independent/r2/additional_probe_results.json';out.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(json.dumps([{'name':x['name'],'rejected':x.get('actual_rejected'),'expected':x['expected_reject'],'errors':x.get('actual_errors',[])[:3]} for x in rows],ensure_ascii=False,indent=2))
