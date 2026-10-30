from pathlib import Path
import hashlib,json,math,re,subprocess
R=Path('/workspace/gunman-rush');BASE='e20dea03b7b54eff1f706ab48e5a6f177851de24';checks=[]
def read(p):return(R/p).read_text()
def sha(p):return hashlib.sha256((R/p).read_bytes()).hexdigest()
def ck(n,v):checks.append({'check':n,'passed':bool(v)})
def before(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=R)
def body(s,name):
 m=re.search(r'^func '+re.escape(name)+r'\(',s,re.M);assert m,name;n=re.search(r'^func ',s[m.end():],re.M);return s[m.start():m.end()+n.start()] if n else s[m.start():]
e=read('scripts/bosses/bellstrider_encounter.gd');em=read('scripts/damage/demo_contact_emitter.gd');app=read('scripts/demo/demo_app.gd');d=read('scripts/bosses/bellstrider_definition.gd');sweep=body(e,'body_contact_sweep');enable=body(e,'body_contact_enabled');config=lambda key:float(re.search(r'@export var '+key+r' := ([\d.]+)',d)[1])
ck('review_baseline_e20',subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==BASE)
ck('shorter_aim035_lock035',config('lob_aim_seconds')==.35 and config('lob_lock_seconds')==.35)
ck('flight110_lower127_gravity1935',config('lob_flight_seconds')==1.10 and config('lob_lower_flight_seconds')==1.27 and config('lob_gravity')==1935)
ck('existing_resource_does_not_override_new_default_timing',all(x not in read('resources/bosses/bellstrider.tres') for x in ['lob_aim_seconds =','lob_flight_seconds =','lob_lower_flight_seconds =','lob_gravity =']))
ck('launch_consumes_new_gravity_and_duration','shot.gravity = _config().lob_gravity' in body(e,'_launch') and 'var duration := lob_duration_for(point)' in body(e,'_launch'))
ck('barrel_aim_consumes_same_gravity','_config().lob_gravity' in body(e,'_aim_launcher'))
ck('launch_lock_remains_fixed_point', '_aim_launcher' not in body(e,'physics_tick').split('&"lob_lock":',1)[1].split('&"neck":',1)[0])
ck('contact_exact_admission_optin_only_Bell_App',app.count('contact_test_provider =')==1 and 'if encounter is BellstriderEncounter:\n\t\t\t_boss_contact.contact_test_provider = encounter.body_contact_sweep' in app)
ck('App_only_provider_install_diff',before('scripts/demo/demo_app.gd').decode().replace('\t\t_boss_contact.enabled = not generated_plains','\t\tif encounter is BellstriderEncounter:\n\t\t\t_boss_contact.contact_test_provider = encounter.body_contact_sweep\n\t\t_boss_contact.enabled = not generated_plains')==app)
ck('relative_sweep_anchored_to_stable_Motor','if contact_test_provider.is_valid(): source_center = global_position' in em and 'var relative := controller.motor.global_position - source_center' in em)
ck('provider_passes_previousrelative_currentworld_actual_actor_half','contact_test_provider.call(source_center, _previous_relative, controller.motor.global_position, actor_half_size)' in em)
ck('provider_exact_sweep_not_expanded_rect','source_center + previous_relative' in sweep and 'current_world - start' in sweep and 'Rect2' not in sweep and sweep.count('collide_with_motion')==2)
ck('provider_uses_real_hull_and_actual_wheel_shapes','hull.shape,hull.global_transform,Vector2.ZERO' in sweep and 'wheel.shape,wheel.global_transform,Vector2.ZERO' in sweep)
ck('provider_actor_box_actual_dimensions','var size := actor_half * 2.0' in sweep and '_contact_actor_box.size = size' in sweep)
ck('provider_rejects_nonfinite_and_badsize',all(x in sweep for x in ['not source_center.is_finite()','not previous_relative.is_finite()','not current_world.is_finite()','not actor_half.is_finite()','actor_half.x<=0.0','actor_half.y<=0.0']))
ck('generic_nonoptin_old_path_retained','else:\n\t\t\ttouching = physical_contact or segment_intersects_bounds(_previous_relative, relative, Rect2(-size, size * 2.0))' in em)
ck('precise_path_not_ORed_with_old_AABB','touching = bool(contact_test_provider.call' in em and 'physical_contact or segment_intersects_bounds' not in em.split('if contact_test_provider.is_valid():\n\t\t\ttouching =',1)[1].split('\n\t\telse:',1)[0])
ck('ownhook_protection_before_geometry','if enabled and not protected:' in em and 'controller.traversal.protects_contact(get_parent())' in em)
ck('epoch_resets_previous_and_touching','if _last_actor_epoch != life.actor_epoch:\n\t\t_previous_relative = relative\n\t\t_was_touching = false' in em)
ck('previous_relative_updated_even_when_disabled','\n\t_previous_relative = relative\n\tif not touching:' in em)
ck('cadence_and_event_identity_retained',all(x in em for x in ['var interval := 0.7','_next_pulse = policy.player_clock() + maxf(interval, 0.01)','life.actor_epoch, _exposure, _pulse','request.actor_epoch = life.actor_epoch','request.health_epoch = controller.actor_resources.health.epoch','request.token = life.token()','policy.submit(request)']))
ck('Bell_phase_transition_now_real_contact', 'return active and not health.terminal and mode not in [&"intro",&"dead"]' in enable and 'super.body_contact_enabled()' not in enable)
for p in ['scripts/bosses/windkeeper_damageable.gd','scripts/combat/damageable.gd','scripts/damage/frame_damage_policy.gd','scripts/player/traversal_ability.gd','scripts/player/player_motor.gd','scripts/player/player_controller.gd','scripts/combat/weapon_action_runtime.gd','scripts/items/v5/item_runtime.gd','scripts/bosses/windkeeper_encounter.gd','scripts/bosses/bellstrider_rig_pose.gd','scripts/bosses/bellstrider_bell_projectile.gd']:
 ck('related_policy_and_weakpoint_bytes_unchanged/'+p,(R/p).read_bytes()==before(p))
# Independent finite geometry model, not Godot or production test execution.
points=[tuple(map(float,x)) for x in re.findall(r'Vector2\((-?[\d.]+), (-?[\d.]+)\)',read('scripts/bosses/bellstrider_rig_pose.gd').split('const HULL_POINTS := [',1)[1].split(']',1)[0])]
def rect(center,half=(12.,18.)):
 x,y=center;hx,hy=half;return[(x-hx,y-hy),(x+hx,y-hy),(x+hx,y+hy),(x-hx,y+hy)]
def polygon_overlap(a,b):
 for poly in [a,b]:
  for p,q in zip(poly,poly[1:]+poly[:1]):
   axis=(-(q[1]-p[1]),q[0]-p[0]);aa=[x*axis[0]+y*axis[1] for x,y in a];bb=[x*axis[0]+y*axis[1] for x,y in b]
   if max(aa)<min(bb) or max(bb)<min(aa):return False
 return True
def wheel_overlap(center,wheel):
 x,y=center;wx,wy=wheel;px=max(x-12,min(wx,x+12));py=max(y-18,min(wy,y+18));return (px-wx)**2+(py-wy)**2<=21**2
def exact_current(center):return polygon_overlap(rect(center),points) or any(wheel_overlap(center,w) for w in [(-49,44),(49,44)])
def aggregate_AABB(center):return polygon_overlap(rect(center),[(-70,-5),(70,-5),(70,65),(-70,65)])
ck('model_clear_bevel_actual_polygons_nohit',aggregate_AABB((70,-20)) and not exact_current((70,-20)))
ck('model_chassis_wheel_gap_negative',aggregate_AABB((0,69)) and not exact_current((0,69)))
ck('model_outer_wheel_positive',exact_current((81.9,44)))
ck('model_real_hull_positive',exact_current((0,15)))
ck('model_mast_bell_gap_not_contact_hull',not exact_current((0,-60)))
ck('model_fast_cross_endpoints_clear_midpoint_hit',not exact_current((-140,44)) and not exact_current((140,44)) and exact_current((0,44)))
# Relative translation identity is algebraic: C1+(P0-C0) -> P1 is exactly
# old-world actor segment P0 -> P1 translated by source movement C1-C0.
c0=(10,20);p0=(-190,64);c1=(110,20);p1=(-90,64);prev=(p0[0]-c0[0],p0[1]-c0[1]);start=(c1[0]+prev[0],c1[1]+prev[1]);ck('model_comoving_no_invented_relative_travel',start==p1)
normal_ratio=config('lob_gravity')*config('lob_flight_seconds')**2/(860*1.65**2);lower_ratio=config('lob_gravity')*config('lob_lower_flight_seconds')**2/(860*1.9**2);ck('model_normalized_arc_preserved',abs(normal_ratio-1)<1e-12 and abs(lower_ratio-1)<.006)
paths=['scripts/bosses/bellstrider_definition.gd','scripts/bosses/bellstrider_encounter.gd','scripts/damage/demo_contact_emitter.gd','scripts/demo/demo_app.gd'];source={p:sha(p) for p in paths}
result={'verdict':'ACCEPT_BOUNDED_SOURCE_DESIGN_PENDING_NATIVE_FREEZE' if all(x['passed'] for x in checks) else'REWORK','reviewer':'/root/guard_review_recovery','independence':'No reviewed production or current contact tests authored by reviewer. No engine/test execution.','baseline_commit':BASE,'source_state':'Uncommitted in-progress candidate; exact4 production leaf SHA only, not final frozen pass.','source_SHA':source,'checks':checks,'passed':sum(x['passed'] for x in checks),'failed':sum(not x['passed'] for x in checks),'independent_model':{'body':'Identity canonical shared hull and two21-radius wheel circles; actor24x36. SAT/closest-point model only; not native or formal App.','clear_bevel_actor_center':[70,-20],'gap_actor_center':[0,69],'gap_fixture_limit':'Below floor in a normal standing scene, intentionally geometry-only negative.','wheel_positive_actor_center':[81.9,44],'through_body_endpoints':[[-140,44],[140,44]],'arc_height_ratios_new_old':{'raised':normal_ratio,'lower':lower_ratio}},'findings':[{'severity':'BOUNDARY_NOT_NATIVE_DEFECT','id':'current_pose_translational_sweep','finding':'Relative translation is correct for moving player/carriage and exact current hull/wheel geometry. Shape transforms are sampled only at current rig pose. It does not integrate continuous angular old->new articulated shape motion. No reproduced native gameplay false positive is claimed; new tests must not describe a proof of that broader contract.'},{'severity':'MINOR_COMMENT_ONLY','id':'curvature_comment','finding':'Existing BellProjectile comment says120Hz chord error below.01wu. With new gravity1935, theoretical bound g*(1/120)^2/8 is.016796875wu, still far below1wu pixel. This is a stale numerical comment, not demonstrated gameplay failure.'}], 'not_accepted':['New contact_edges test while its author is writing it','Final8consumer/native contact pass','Old276 log as exact final frozen pass','Updated video/audio/art/fairness/user or G1-G5 acceptance'],'actual_command':'python3 /tmp/review_bellstrider_review02_source.py > /tmp/bellstrider-review02-source-proof.log','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()};Path('/tmp/bellstrider-review02-source-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('CHECKS',result['passed'],result['failed']);print('FAILURES',[x for x in checks if not x['passed']]);print(result['verdict'])
