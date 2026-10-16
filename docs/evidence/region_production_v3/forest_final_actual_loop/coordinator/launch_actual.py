from pathlib import Path
import subprocess,os,json,datetime,hashlib
root=Path.cwd();folder=root/'build/forest_final_actual_loop';env=os.environ.copy();env.update(GODOT_BIN='/workspace/toolchains/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64',GUNMAN_ENGINE_LOCK='/workspace/gunman-rush/build/region_production_v3/engine.lock',LP_NUM_THREADS='1',OMP_NUM_THREADS='1')
cmd=['python3','tools/harness.py','--mission','build/forest_final_actual_loop/mission.json','--execute','--worker-mode','host','--evidence-dir','build/verification/forest_final_actual_loop']
with (folder/'controller.stdout.log').open('xb') as stream:
 p=subprocess.Popen(cmd,cwd=root,env=env,stdout=stream,stderr=subprocess.STDOUT,start_new_session=True)
launch={'kind':'actual_harness_controller_launch_no_background_model_service','pid':p.pid,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':cmd,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'mission_sha256':hashlib.sha256((folder/'mission.json').read_bytes()).hexdigest(),'explicit_environment':{k:env[k] for k in ['GODOT_BIN','GUNMAN_ENGINE_LOCK','LP_NUM_THREADS','OMP_NUM_THREADS']}}
(folder/'controller_launch.json').write_text(json.dumps(launch,indent=2)+'\n');print(json.dumps(launch,indent=2))
