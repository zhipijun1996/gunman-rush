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
probe('valid_exact_positive',lambda t,a:None,False)
probe('associated_path_list_type',lambda t,a:a['associated_files'][0].update(path=['assets/source.png']))
probe('associated_hash_dict_type',lambda t,a:a['associated_files'][0].update(sha256={'fake':'hash'}))
probe('associated_bad_hash',lambda t,a:a['associated_files'][0].update(sha256='a'*64))
probe('associated_missing_path',lambda t,a:a['associated_files'][0].update(path='assets/absent.png'))
probe('associated_unknown_role',lambda t,a:a['associated_files'][0].update(role='render_runtime'))
probe('runtime_label_without_consumers',lambda t,a:a.update(disposition='limited_preview',runtime_paths=[]))
probe('runtime_paths_string',lambda t,a:a.update(runtime_paths='scripts/consumer.gd'))
probe('disposition_dict_type',lambda t,a:a.update(disposition={'bypass':True}))
probe('nonruntime_visual_pass',lambda t,a:a.update(disposition='rejected_evidence_only',runtime_paths=[],non_runtime_reason='must stay failed',visual_status='passed'))
probe('associated_omitted_file',lambda t,a:(t.root/'assets/production/omitted.txt').write_text('not referenced'))
def active_main(t):
 (t.root/'scenes').mkdir(exist_ok=True)
 (t.root/'scenes/main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/consumer.gd" id="1"]\n[node name="Live" type="Node"]\nscript = ExtResource("1")\n')
 (t.root/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://scenes/main.tscn"\n')
 record_path=t.root/'docs/quality/records/test.json';record=json.loads(record_path.read_text());record['affected_paths']+=['scenes/main.tscn','project.godot'];record_path.write_text(json.dumps(record))
def liar(t,a):
 active_main(t)
 (t.root/'assets/source.png').write_bytes((ROOT/'assets/plains_v3/background_layers/sky.png').read_bytes())
 a['source_sha256']=hashlib.sha256((t.root/'assets/source.png').read_bytes()).hexdigest()
 (t.root/'scripts/consumer.gd').write_text('extends Node\nconst LIVE_ART = preload("res://assets/source.png")\n')
 a.update(disposition='rejected_evidence_only',runtime_paths=[],non_runtime_reason='False claim: rejected evidence only, but actual source contains explicit runtime preload')
probe('nonruntime_lie_obvious_preload',liar)
def associated_lie(t,a):
 active_main(t)
 source=t.root/'assets/live.png';source.write_bytes((ROOT/'assets/plains_v3/background_layers/sky.png').read_bytes());(t.root/'scripts/consumer.gd').write_text('extends Node\nconst LIVE_ART = preload("res://assets/live.png")\n')
 record_path=t.root/'docs/quality/records/test.json';record=json.loads(record_path.read_text());record['affected_paths'].append('assets/live.png');record_path.write_text(json.dumps(record))
 a['associated_files'].append({'path':'assets/live.png','sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'role':'documentation'})
probe('associated_documentation_can_cover_runtime_PNG',associated_lie)
out=ROOT/'build/region_production_v3/independent/asset_provenance_independent/r2/probe_results.json';out.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n');print(json.dumps([{'name':x['name'],'rejected':x.get('actual_rejected'), 'exception':x.get('actual_rejected_by_exception'),'expected':x['expected_reject']} for x in rows],ensure_ascii=False,indent=2))
