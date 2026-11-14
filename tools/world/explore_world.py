#!/usr/bin/env python3
"""Local-knowledge DFS audit of the candidate; not a physics or fun simulator.

Observe only current outgoing edges/actions. Prefer an untried local branch,
backtrack along discovered passages, and recheck remembered locks after gains.
No undiscovered-room pathfinding, rift teleport, remote pickups, or free tokens.
"""
from collections import deque
from pathlib import Path
import argparse, hashlib, json
from simulate_world import Model, State, holds
from spatial_adjustments import world_for_draft
ROOT=Path(__file__).resolve().parents[2]

class ExplorerModel(Model):
    def choice_snapshot(self, state, label):
        # Avoid omniscient all-world reachability scans on each pickup.
        return {'action':label,'room':state.room,'tokens':sorted(state.all_tokens())}

def explore(world, profile='curious', seed=0, forbidden=(), max_steps=6000):
    model=ExplorerModel(world);model.auto_switches=False
    state=State(model.start,model.start_section,tokens=model.initial_tokens.copy())
    known={};tried=set();stack=[];journey=[state.room];events=[];first={};silent=0;longest=0;segments=[];segment_start=0
    forbidden=set(forbidden);priority={};ingress={}
    # The authored signposts visible at F02, not an oracle for unseen rewards.
    if profile=='hook_first':priority={'F-R03':-10,'F-R16':10}
    if profile=='double_first':priority={'F-R16':-10,'F-R03':10}
    def permitted(t):
        boss=model.boss_locations.get(t['from'])
        if boss and boss['defeat_token'] not in state.tokens and t['to']!=ingress.get(t['from']):return False
        return holds(t['requires'],state.all_tokens(),state.inventory)
    def actions_here(loc):
        candidates=model.actions_by_location[loc]+model.actions_by_location[('@current','@current')]
        return [a for a in candidates if a['id'] not in forbidden and not (set(a.get('grants',[])) & forbidden)
                and not (a.get('type')=='equip' and set(a.get('grants',[]))<=state.all_tokens())
                and a.get('type')!='unequip' and (not a.get('repeat',False) or a.get('type')=='equip'
                    or a.get('type')=='rest' and not state.loadout_ready)
                and model.available(a,state)]
    def available_at(loc):
        old=state.room,state.section;state.room,state.section=loc
        result=any(a.get('type')!='rest' for a in actions_here(loc));state.room,state.section=old
        return result
    def frontier(loc):
        return available_at(loc) or any(permitted(t) and t['to'] not in known for t in known[loc])
    def rank(t):
        bias=priority.get(t['to'][0],0) if t['from'][0]=='F-R02' else 0
        if profile=='cautious' and t['to'] in model.boss_locations:bias+=5
        tie=hashlib.sha256(f'{seed}:{t["id"]}'.encode()).hexdigest()
        return bias,t['to'] in known,tie
    def known_path(goal):
        queue=deque([(state.location,[])]);seen={state.location}
        while queue:
            loc,path=queue.popleft()
            if loc!=state.location and goal(loc):return path
            for t in known.get(loc,[]):
                if permitted(t) and t['to'] in known and t['to'] not in seen:
                    seen.add(t['to']);queue.append((t['to'],path+[t]))
        return None
    def move(t,backtrack=False):
        nonlocal silent,longest
        assert t['from']==state.location and permitted(t)
        step={'kind':t['kind'],'transition_id':t['id'],'edge':t['public_id'],'from':t['from'][0],
              'from_section':t['from'][1],'to':t['to'][0],'to_section':t['to'][1]}
        # arrive(auto=False) is intentional: forbidden weapons must never auto-grant.
        ingress[t['to']]=t['from']
        state.room,state.section=t['to'];state.loadout_ready=False
        state.trace.append(step);model.arrive(state,auto=False)
        if t['kind']=='move':
            journey.append(state.room);silent+=1;longest=max(longest,silent)
        tried.add(t['id'])
    exhausted=False
    for _ in range(max_steps):
        loc=state.location;model.arrive(state,auto=False);known[loc]=list(model.adj[loc])
        before=set(state.done)
        while True:
            acts=actions_here(loc)
            if not acts:break
            action=sorted(acts,key=lambda a:(a.get('type')=='equip',a['id']))[0]
            model.perform(action,state)
            for token in action.get('grants',[]):first.setdefault(token,{'crossings':len(journey)-1,'room':state.room,'action':action['id']})
        gained=set(state.done)-before
        new_branches=[t for t in known[loc] if permitted(t) and t['id'] not in tried and t['to'] not in known]
        meaningful=[a for a in gained if model.actions[a].get('type') not in ('station','automatic_landmark','switch','quest_progress')]
        if meaningful or len(new_branches)>1:
            if len(journey)-1>segment_start:
                segments.append({'crossings':len(journey)-1-segment_start,'rooms':journey[segment_start:]})
            segment_start=len(journey)-1
            events.append({'room':state.room,'crossings':len(journey)-1,'actions':sorted(meaningful),'new_choices':len(new_branches)});silent=0
        options=sorted([t for t in known[loc] if permitted(t) and t['to'] not in known],key=rank)
        if options:
            t=options[0];stack.append(loc);move(t);continue
        # DFS returns to its ancestors through legal known passages; one-way
        # passages use only the already discovered graph to find that return.
        path=None
        while stack and not path:
            parent=stack.pop()
            if parent==loc or not frontier(parent):continue
            path=known_path(lambda pos:pos==parent)
        if not path:
            path=known_path(frontier)
        if not path:exhausted=True;break
        for t in path:move(t,True)
    obtained=[t for t in ['W','H','D','Q'] if t in first]
    obtained.sort(key=lambda t:first[t]['crossings'])
    if len(journey)-1>segment_start:segments.append({'crossings':len(journey)-1-segment_start,'rooms':journey[segment_start:]})
    return {'profile':profile,'seed':seed,'exhausted':exhausted,'rooms_seen':len(state.visited),'room_crossings':len(journey)-1,
            'revisit_crossings':len(journey)-len(set(journey)),'longest_no_reward_or_new_choice_crossings':longest,
            'ability_order':obtained,'first_gains':{k:v for k,v in first.items() if k in {'W','H','D','Q','smith','skill_tier_1','clock_P','boss_Z_KING_defeated','boss_Z_DEITY_defeated'}},
            'remembered_locks':len(state.seen_locks),'unlocked_remembered':len(state.unlocked_seen),
            'longest_return_segments':sorted(segments,key=lambda s:s['crossings'],reverse=True)[:3],
            'actions':sorted(state.done),'tokens':sorted(state.all_tokens()),'journey':journey,'events':events,
            'limits':'局部可知的离散DFS；战斗假定成功，不模拟动作距离、初见视线、玩家耗时或趣味评分。'}

def audit(world, baseline=None):
    runs=[explore(world,p,s,forbidden=('shuriken',) if p=='no_shuriken' else ())
          for p in ['hook_first','double_first','curious','cautious','no_shuriken'] for s in range(3)]
    model=Model(world);metrics={}
    for room,prior in (baseline or {}).get('door_counts',{}).items():
        state=State('P-R01',tokens={'gun','station_briefed','intro_complete','clockheart_briefed'})
        path=model.search(state,targets=[(room,'main')],allow_teleport=False)
        metrics[room]={'before':prior,'after':sum(t['kind']=='move' for t in path['steps']) if path else None}
    return {'method':'局部已知图上的深度优先探索；本地操作和获取，新资格后复查记住的岔路；返程只用已发现的合法通路。',
            'limits':'战斗假定成功；不模拟物理、初见视线、耗时或人类偏好。探索倾向不保证获取顺序，门数不等于游戏体验。',
            'before_source':(baseline or {}).get('source'),'metrics':metrics,'runs':runs}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=ROOT/'build/world-review/exploration.json');args=parser.parse_args()
    world=world_for_draft(ROOT,json.loads((ROOT/'config/world/world.json').read_text()))
    manifest=json.loads((ROOT/'config/world/spatial_layout.json').read_text())
    report=audit(world,manifest.get('progression_baseline'))
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    for r in report['runs']:print(r['profile'],r['seed'],r['rooms_seen'],r['room_crossings'],r['ability_order'],r['exhausted'])
if __name__=='__main__':main()
