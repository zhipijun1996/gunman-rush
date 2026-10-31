from pathlib import Path
import subprocess,json,math,hashlib
R=Path('/workspace/gunman-rush');BASE='840108da9ae91e412dc9f1d8a38ccdad0229bb11'
def raw(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
t=json.loads(raw('config/player_tuning.json'))
# Reduced 60Hz vertical ordering from JumpAbility.update_hold -> PlayerMotor.step.
# No collision/ceiling/airfocus/recoil. This is a source planning model, not a game test.
def jump(release_at):
 dt=1/t['physics_hz'];v=t['jump_speeds'][0];y=0.;remain=t['jump_hold_duration'];elapsed=0.;rows=[];owns=True
 for frame in range(120):
  tm=frame*dt;released=release_at is not None and tm>=release_at
  if released and owns and v<0 and (elapsed+1e-9>=t['jump_min_hold_duration'] or remain<=0):v=max(v,t['jump_release_speed']);remain=0
  if not t['variable_jump_enabled'] or v>=0:owns=False;remain=0
  elif released and elapsed+1e-9>=t['jump_min_hold_duration']:v=max(v,t['jump_release_speed']);remain=0
  elif remain>0:
   held=min(dt,remain);v=v+(t['jump_speeds'][0]-v)*(held/dt);elapsed+=held;remain=max(0.,remain-dt)
  v=min(v+t['gravity']*dt,t['max_normal_fall_speed']);y+=v*dt;rows.append({'frame':frame+1,'seconds':(frame+1)*dt,'height':-y,'velocity_y':v})
  if y>=0 and frame>0:break
 return {'release_at':release_at,'apex':max(x['height'] for x in rows),'flight_seconds':rows[-1]['seconds'],'above_54_frames':sum(x['height']>54 for x in rows),'above_110_frames':sum(x['height']>110 for x in rows),'trajectory':rows}
models={'tap_release_next_frame':jump(1/t['physics_hz']),'hold_full':jump(None)}
paths=['scripts/bosses/bellstrider_encounter.gd','scripts/bosses/windkeeper_encounter.gd','scripts/bosses/windkeeper_damageable.gd','scripts/bosses/boss_arena.gd','scripts/bosses/boss_motor.gd','scripts/bosses/boss_encounter.gd','scripts/bosses/boss_projectile.gd','scripts/bosses/bellstrider_bell_projectile.gd','scripts/bosses/bellstrider_presentation.gd','scripts/combat/damageable.gd','scripts/damage/frame_damage_policy.gd','scripts/combat/player_projectile.gd','scripts/combat/weapon_action_runtime.gd','scripts/combat/weapon_entity.gd','scripts/combat/weapon_definition.gd','scripts/combat/shoot_ability.gd','scripts/combat/shot_energy_policy.gd','scripts/combat/recoil_ability.gd','scripts/combat/action_resources.gd','scripts/player/player_motor.gd','scripts/player/player_controller.gd','scripts/player/jump_ability.gd','scripts/player/traversal_ability.gd','scripts/items/v5/item_runtime.gd','scripts/items/v5/item_active_effects.gd','scripts/items/v5/item_combat_effects.gd','scripts/items/v5/item_companion_effects.gd','scripts/items/v5/item_defense_effects.gd','scripts/items/v5/item_economy_effects.gd','scripts/items/v5/item_time_effects.gd','config/player_tuning.json','scenes/player/player.tscn','scenes/bosses/bellstrider.tscn','resources/bosses/bellstrider.tres']
inputs={p:hashlib.sha256(raw(p)).hexdigest() for p in paths}
# Exhaustively enumerate direct player damage producers at the immutable baseline.
allpaths=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'scripts'],cwd=R,text=True).splitlines();producers=[]
for p in allpaths:
 if p.endswith('.gd'):
  b=raw(p).decode()
  if 'receiver.receive_damage(' in b:producers.append(p)
result={'baseline_commit':BASE,'kind':'Read-only source-derived planning model; not engine execution or G1 timing proof','inputs_sha256':inputs,'player_damage_producers':producers,'physics':t,'ground_recoil_distance_nominal':t['shot_burst_speed']*t['shot_burst_duration']*t['ground_recoil_multiplier'],'two_shots_earliest_last_recoil_end':t['shot_cooldown']+t['shot_burst_duration'],'third_shot_earliest_last_recoil_end':2*t['shot_cooldown']+t['shot_burst_duration'],'two_shots_nominal_recoil_sum':2*t['shot_burst_speed']*t['shot_burst_duration']*t['ground_recoil_multiplier'],'jump_models':models,'limitations':['Model excludes floor/ceiling/one-way platforms, player horizontal movement, real collision contact and InputRouter order details outside the copied vertical logic.','Tap/hold distinction invalidates the assertion that basic jump apex is always85wu; native proof is still required.','Recoil distance is the nominal vector budget, not guaranteed horizontal displacement after oblique aim/terrain collision.','Air shot capacity1 does not erase the actual committed-hit round refund.','No production or tests authored by reviewer.']}
Path('/tmp/bellstrider_g0_source_model.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['physics','inputs_sha256','jump_models']},ensure_ascii=False,indent=2));print({k:{n:v for n,v in x.items() if n!='trajectory'} for k,x in models.items()})
