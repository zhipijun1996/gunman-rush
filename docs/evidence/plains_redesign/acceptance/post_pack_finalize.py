from pathlib import Path
import json,subprocess,time,hashlib,sys
R=Path('/workspace/gunman-rush');B=R/'build/plains_redesign';P=B/'post_pack_execution.json';assert not P.exists()
D={'status':'running','scope':'Final portable byte archive, quality/knowledge/doc updates and future forest PLAN ONLY; no gameplay or media rerun.','started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'commands':[]}
def save():P.write_text(json.dumps(D,ensure_ascii=False,indent=2)+'\n')
save()
steps=[('storage',['python3',str(B/'archive_portable_primary_raws.py')]),('quality_metadata',['python3',str(B/'update_final_quality_records.py')]),('knowledge',['python3',str(B/'apply_final_knowledge.py')]),('delivery_docs',['python3',str(B/'finalize_delivery_docs.py')]),('forest_route',['python3','tools/level_design.py','route','--request','制作荆棘森林，遵循已确定S2/H能力与树冠穿梭、美术标准，仅演练新地区生产流程，不实现地区或授予能力。','--mode','new_region','--output',str(B/'final_forest_closure/mission.json')]),('forest_plan',['python3','tools/harness.py','--mission',str(B/'final_forest_closure/mission.json'),'--plan'])]
try:
 for name,argv in steps:
  log=B/('final_forest_closure/'+('plan.log' if name=='forest_plan' else 'route.log')) if name.startswith('forest_') else B/('post_'+name+'.log');log.parent.mkdir(parents=True,exist_ok=True)
  with log.open('w') as h:p=subprocess.run(argv,cwd=R,stdout=h,stderr=subprocess.STDOUT,timeout=240)
  D['commands'].append({'name':name,'argv':argv,'exit_code':p.returncode,'log':str(log.relative_to(R)),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'finished_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())});save()
  if p.returncode:raise RuntimeError('Actual nonzero '+name)
 D['status']='completed_metadata_and_plan_only'
except Exception as e:
 D['status']='blocked';D['error']=str(e)
finally:
 D['finished_utc']=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime());save()
raise SystemExit(0 if D['status']=='completed_metadata_and_plan_only' else 1)
