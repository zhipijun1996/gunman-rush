#!/usr/bin/env python3
"""Compile the authored room world into explicit door/room-section topology.

The input snapshot is historical provenance, not a second runtime authority.
Requirements are positive DNF. Mobility predicates describe authored geometry;
they must never become an invisible player-ability check in the game runtime.
"""
from __future__ import annotations
from collections import defaultdict, Counter, deque
from copy import deepcopy
from itertools import product
from pathlib import Path
import argparse, hashlib, json, re, shutil

ROOT = Path(__file__).resolve().parent
ABILITY_ORDER = ('H','W','D','Q')
ABILITIES = set(ABILITY_ORDER)
SOURCE = ROOT / 'source_inputs/world-room-layout-v03.json'
OUTPUT = ROOT / 'world-room-layout-v04.json'
REPORT = ROOT / 'qa/section-migration-v04.json'

def clauses(value):
    if value is None or value == []: return [[]]
    if isinstance(value, str): return [[value]]
    if all(isinstance(x,str) for x in value): return [value]
    return value

def canonical_dnf(value):
    out=[]
    for cc in clauses(value):
        row=list(dict.fromkeys(cc))
        if not any(set(old)==set(row) for old in out):out.append(row)
    # Positive monotonic DNF: more restrictive clauses are redundant.
    return [row for row in out if not any(set(other)<set(row) for other in out)]

def and_dnf(a,b):
    return canonical_dnf([aa+bb for aa in clauses(a) for bb in clauses(b)])

def split_dnf(value):
    full=canonical_dnf(value)
    mobility=canonical_dnf([[t for t in cc if t in ABILITIES] for cc in full])
    nonmob=canonical_dnf([[t for t in cc if t not in ABILITIES] for cc in full])
    combined=and_dnf(mobility,nonmob)
    if {frozenset(c) for c in full}!={frozenset(c) for c in combined}:
        raise ValueError('Nonfactorable DNF needs a manually paired physical branch: '+repr(value))
    return mobility, nonmob

def has_mobility(req):
    return any(t in ABILITIES for cc in clauses(req) for t in cc)

def holds_mobility(req,tokens):
    # Other flags deliberately relaxed for a conservative necessary-capability proof.
    return any(all(t in tokens or t not in ABILITIES for t in cc) for cc in clauses(req))

def directions(edge):
    d=edge.get('direction','both')
    if d in ('both','forward','a_to_b','a->b','one_way'):yield edge['a'],edge['b']
    if d in ('both','reverse','b_to_a','b->a'):yield edge['b'],edge['a']

def mobility_reachability(world, front=True, bosses=True):
    guards={r['id']:g['front_requires'] for r in world['rooms'] for g in r.get('internal_gate_contracts',[]) if g.get('front_requires')}
    encounters={b['room_id']:b['encounter_requirements'] for b in world['boss_plan']['bosses']}
    adjacency=defaultdict(list)
    for e in world['connections']:
        for a,b in directions(e):adjacency[a].append((b,e))
    result=defaultdict(list)
    for bits in product((False,True),repeat=4):
        state={a for a,b in zip(ABILITY_ORDER,bits) if b}
        seen={world['start_room']};todo=deque(seen)
        while todo:
            r=todo.popleft()
            for dest,e in adjacency[r]:
                if dest in seen or not holds_mobility(e.get('requires'),state):continue
                if front and not holds_mobility(guards.get(dest),state):continue
                if bosses and not holds_mobility(encounters.get(dest),state):continue
                seen.add(dest);todo.append(dest)
        for r in seen:result[r].append(state)
    return result

def implied_at_room(room_id, req, reach):
    states=reach.get(room_id,[])
    return bool(states) and all(holds_mobility(req,ss) for ss in states)

def ability_label(req):
    return ' 或 '.join('+'.join(c) if c else '基础移动' for c in clauses(req))

def profile(req):
    kinds={'H':'可见索点与基础跳跃/反冲无法直达的接续落点',
           'W':'可辨认的攀墙/墙跳面与对应高度差',
           'D':'二段跳所需的断桥、抬升落点或空中接续',
           'Q':'相位光幕（非熔岩、荆棘、齿轮或毒水）；真实落脚台与2秒冷却节奏'}
    return [{'abilities':cc,'fixtures':[kinds[t] for t in cc]} for cc in clauses(req)]

def point_inside_polygon(point, polygon):
    x,y=point;inside=False
    for (ax,ay),(bx,by) in zip(polygon,polygon[1:]+polygon[:1]):
        if min(ax,bx)-1e-7<=x<=max(ax,bx)+1e-7 and min(ay,by)-1e-7<=y<=max(ay,by)+1e-7:
            cross=(x-ax)*(by-ay)-(y-ay)*(bx-ax)
            if abs(cross)<1e-7:return True
        if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:inside=not inside
    return inside

def compile_world():
    if not SOURCE.exists():
        previous=ROOT.parent/'world-room-layout-v03/world-room-layout-v03.json'
        if not previous.exists():raise FileNotFoundError('Missing historical input snapshot '+str(SOURCE))
        SOURCE.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(previous,SOURCE)
    source_bytes=SOURCE.read_bytes();old=json.loads(source_bytes);world=deepcopy(old)
    report={'schema':'gunman-rush.section-migration-audit.v04','source_sha256':hashlib.sha256(source_bytes).hexdigest(),
        'source':'source_inputs/world-room-layout-v03.json','rule_source':'2026-11-06用户确认：门可预览，能力由房内环境阻隔。',
        'edge_migrations':[],'shortcut_implications':[],'action_bindings':[],'room_guard_migrations':[],
        'boss_access_proofs':[],'invariants':{},'validation_scope':'静态数据与逻辑迁移；不是实机动作、镜头、战斗或时长验收。'}
    old_rooms={r['id']:r for r in old['rooms']};old_edges={e['id']:e for e in old['connections']}
    old_actions={a['id']:a for a in old['actions']}
    rooms={r['id']:r for r in world['rooms']};edges={e['id']:e for e in world['connections']}
    actions={a['id']:a for a in world['actions']}
    reach=mobility_reachability(old)
    without_boss=mobility_reachability(old,bosses=False)
    without_front=mobility_reachability(old,front=False,bosses=False)
    shortcuts={s['id']:s for s in old['shortcuts']}
    for r in world['rooms']:
        r['sections']=[{'id':'main','kind':'main','name':'房间主体','map_anchor_candidate':r['map_centre'],
            'counts_as_room_main_visit':True,'placement_status':'主体逻辑分区；具体可走轮廓由灰盒细化'}]
        r['internal_routes']=[]
        r['rest_section_id']='main' if r.get('rest_point') else None
        r['rift_section_id']='main' if r.get('rift_machine') else None
        r['entry_preview_policy']='门可进入对应安全落脚区；能力阻隔由房内环境通路实现；未通过时可沿来门安全返回。'
        r['gate_summary_scope']='房内能力路线与物理门锁分别以internal_routes和connections.requires为准。'
        r['macro_gate_policy']='保留宏观方位、房间ID与连接；能力条件移至房内路线，门仅检查道具/剧情/机关资格。'
        r['geometry_status']='房间轮廓为世界地图定位；场景尺寸与门落脚工作值见v04逐房合同，待实机标定。'
        r['collectible_status']='唯一奖励通过reward_id绑定具体section_id；进入入口预览区不等于取得主体奖励。'
        r['gate_summary']='基础通路；房内分区与实际门锁见下列合同。'
        r.pop('previous_polygon',None)
        r['internal_gate_contracts']=[]

    def section(rid,sid,kind='entrance_preview',edge=None):
        r=rooms[rid]
        found=next((x for x in r['sections'] if x['id']==sid),None)
        if found:return found
        anchor=list(r['map_centre'])
        if edge:
            pts=edge.get('polyline') or edge.get('manual_polyline')
            if pts:
                p=pts[0] if edge['a']==rid else pts[-1]
                anchor=[round(p[0]*.72+anchor[0]*.28,3),round(p[1]*.72+anchor[1]*.28,3)]
        x={'id':sid,'kind':kind,'name':'入口安全台' if kind=='entrance_preview' else '既有奖励/机关可达区',
            'map_anchor_candidate':anchor,'counts_as_room_main_visit':kind!='entrance_preview',
            'safe_return_required':True,'not_a_new_room':True,
            'placement_status':'逻辑可达分区；入口台、通路与目标实物在本房灰盒内实现'}
        if edge:x['door_edge_id']=edge['id']
        r['sections'].append(x);return x

    def connect_internal(rid,sid,req,origin,reverse_requires=None):
        mob,nonmob=split_dnf(req)
        if has_mobility(nonmob):raise AssertionError('Bad mobility split')
        rr=rooms[rid]['internal_routes']
        ident='IR:'+rid+':'+sid
        existing=next((x for x in rr if x['id']==ident),None)
        if existing:
            existing['requires']=and_dnf(existing['requires'],req)
            existing['source_refs'].append(origin)
            # A shared entrance guard only adds requirements to an existing segment.
            rev=next(x for x in rr if x['id']==ident+':return')
            rev['requires']=and_dnf(rev['requires'],reverse_requires if reverse_requires is not None else req)
            existing['physical_variants']=profile(split_dnf(existing['requires'])[0])
            rev['physical_variants']=profile(split_dnf(rev['requires'])[0])
            return ident
        base={'id':ident,'from_section':sid,'to_section':'main','requires':canonical_dnf(req),
            'kind':'environment_traversal','implementation':'以真实索点、墙面、高差、断桥或相位光幕实现；不在玩家面前生成隐藏能力检查墙。',
            'physical_variants':profile(mob),'source_refs':[origin],'reverse_route_id':ident+':return',
            'map_marker':{'room_id':rid,'section_id':sid,'inside_room':True,'kind':'environment_capability_obstacle'},
            'failure_anchor_section':sid,'normal_hazard_damage':1,'special_hazard_damage':2,
            'q_contract':{'cooldown_seconds':2,'landing_required':True,'entities_immune':['enemy_damage','phase_light_curtain'],
                'environment_hazards_immune':False},
            'status':'结构灰盒必须实现的通路；具体动作尺寸与难度待房内测试'}
        rr.append(base)
        rev=deepcopy(base);rev.update(id=ident+':return',from_section='main',to_section=sid,
            requires=canonical_dnf(reverse_requires if reverse_requires is not None else req),reverse_route_id=ident)
        rev['physical_variants']=profile(split_dnf(rev['requires'])[0]);rr.append(rev)
        return ident

    for e in world['connections']:
        effective=and_dnf(e.get('requires'),e.pop('room_guard',None))
        mob,door=split_dnf(effective)
        e.update(requires=door,effective_door_requires=deepcopy(door),a_section='main',b_section='main',
            condition_format='OR of AND groups',requirement_scope='physical_item_story_switch_door',
            condition_text='基础通行' if door==[[]] else '物理门条件：'+' 或 '.join('+'.join(c) for c in door))
        e['transition_contract']='左右步行；向上接管并落入口侧台后交还；向下入口下必有安全台；交通交互不休息。'
        e['ability_gate_in_door']=False
        e['geometry_status']='房间连接已定；两端门方向、入口台和过门控制按v04逐房合同实施。'
        if not has_mobility(mob):continue
        sc=shortcuts.get(e['id']); redundant=False
        if sc:
            op=old_actions[sc['open_action_id']]
            opening_mob,_=split_dnf(op.get('requires'))
            redundant=all(any(set(need)<=set(have) for need in clauses(mob)) for have in clauses(opening_mob))
            if redundant:
                proof={'edge_id':e['id'],'open_action_id':op['id'],'open_token':sc['open_token'],
                    'opening_mobility':opening_mob,'removed_traversal_mobility':mob,
                    'all_open_alternatives_imply_a_traversal_alternative':True,
                    'ability_permanence':'H/W/D/Q永久持有，开关仅由指定实际交互授予；没有初始开关旗标。',
                    'consequence':'开门后不重复考核已经证明的能力；真正道具/剧情/装备门条件仍保留。'}
                report['shortcut_implications'].append(proof)
                e['shortcut_mobility_policy']='proven_at_opening_no_repeat_challenge'
                e['opening_action_ref']=op['id']
        if redundant:
            report['edge_migrations'].append({'edge_id':e['id'],'kind':'shortcut_redundant_capability_removed','door_requires':door})
            continue
        rid=e['b'];sid='entry:'+e['id'];section(rid,sid,edge=e);e['b_section']=sid
        ir=connect_internal(rid,sid,mob,'connection:'+e['id'])
        e['environment_route_id']=ir;e['environment_room_id']=rid
        report['edge_migrations'].append({'edge_id':e['id'],'kind':'door_to_room_environment',
            'host_room':rid,'preview_section':sid,'internal_route_id':ir,'mobility_requires':mob,'door_requires':door})

    # Materialise pre-existing whole-room front guards as actual entrance passages.
    # Guards already entailed by the exterior graph need no repeated room challenge.
    guard_targets=[]
    for r in old['rooms']:
        for g in r.get('internal_gate_contracts',[]):
            if 'front_requires' not in g:continue
            mob,items=split_dnf(g['front_requires'])
            needed=has_mobility(mob) and not implied_at_room(r['id'],mob,without_front)
            guard_targets.append((r['id'],mob,items,needed,'previous_front_contract'))
    for b in old['boss_plan']['bosses']:
        mob,items=split_dnf(b['encounter_requirements'])
        needed=has_mobility(mob) and not implied_at_room(b['room_id'],mob,without_boss)
        report['boss_access_proofs'].append({'boss_id':b['id'],'room_id':b['room_id'],
            'mobility':mob,'exterior_graph_already_implies_mobility':not needed,
            'added_room_entry_environment':needed})
        if needed:guard_targets.append((b['room_id'],mob,items,True,'boss_arena_entry'))
    for rid,mob,items,needed,origin in guard_targets:
        affected=[]
        for e in world['connections']:
            if rid not in (e['a'],e['b']):continue
            e['requires']=and_dnf(e['requires'],items);e['effective_door_requires']=deepcopy(e['requires'])
            if not needed:continue
            side='a' if e['a']==rid else 'b';field=side+'_section'
            sid=e[field]
            if sid=='main':sid='entry:'+e['id'];e[field]=sid;section(rid,sid,edge=e)
            ir=connect_internal(rid,sid,mob,origin+':'+rid)
            affected.append({'edge_id':e['id'],'section':sid,'route_id':ir})
        report['room_guard_migrations'].append({'room_id':rid,'origin':origin,'mobility':mob,
            'door_conditions':items,'requires_distinct_environment':needed,'entrances':affected})

    # Bind interactions to existing main space when approach paths already prove
    # capability. Otherwise one shared section per room+capability clause suffices.
    access_sections={}
    for a in world['actions']:
        rid=a.get('room_id');mob,nonmob=split_dnf(a.get('requires'))
        a['requires']=nonmob;a['section_id']='@current' if rid=='@current' else 'main'
        a['ability_qualification_at_interaction']=False
        if not has_mobility(mob):continue
        implied=rid!='@current' and implied_at_room(rid,mob,reach)
        if a['type']=='boss_defeat':implied=True
        if not implied and rid in rooms:
            key=(rid,tuple(sorted(tuple(sorted(c)) for c in mob)))
            if key not in access_sections:
                sig='_OR_'.join('_'.join(t for t in ABILITY_ORDER if t in c) for c in mob)
                sid='access:'+sig;access_sections[key]=sid;section(rid,sid,'environment_access')
                # main -> access is the challenge, reverse is a safe return.
                ir=connect_internal(rid,sid,[[]],'shared_action_access:'+rid,reverse_requires=mob)
                safe=next(rr for rr in rooms[rid]['internal_routes'] if rr['id']==ir)
                approach=next(rr for rr in rooms[rid]['internal_routes'] if rr['id']==ir+':return')
                safe.update(id=ir+':return',reverse_route_id=ir+':approach',implementation='从既有奖励/机关区域安全返回房间主体；不新增能力考核。')
                approach.update(id=ir+':approach',reverse_route_id=ir+':return',implementation='通往本房既有奖励/机关的可见环境支路；同条件的多项交互共用此段。')
                rooms[rid]['sections'][-1]['shared_action_ids']=[]
            a['section_id']=access_sections[key]
            sec=next(x for x in rooms[rid]['sections'] if x['id']==a['section_id']);sec['shared_action_ids'].append(a['id'])
            a['spatial_access_route_id']='IR:'+rid+':'+a['section_id']+':approach'
        a['authored_mobility_access']=mob
        a['mobility_requirement_resolution']='approach_path_already_guarantees' if implied else 'shared_visible_room_section'
        report['action_bindings'].append({'action_id':a['id'],'room_id':rid,'section_id':a['section_id'],
            'mobility':mob,'resolution':a['mobility_requirement_resolution'],
            'proof_method':'16个HWDQ组合；其他旗标放宽的旧图保守可达分析，Boss/已有前厅条件纳入；必要时显式环境分区。'})

    for b in world['boss_plan']['bosses']:
        mob,items=split_dnf(b['encounter_requirements'])
        b['encounter_requirements']=items;b['combat_mobility_requirements']=mob
        b['encounter_section_id']='main';b['arena_sections']=['main']
        b['entry_policy']='可进入入口安全台观察；主体战斗区不得作为活Boss的中转通道。'
        b['requirements_scope']='encounter_requirements为剧情/道具条件；combat_mobility_requirements由到场环境与战斗动作实现，不是奖励领取检查。'
        rooms[b['room_id']]['encounter_requirements']=deepcopy(items)
        rooms[b['room_id']]['combat_mobility_requirements']=deepcopy(mob)
        rooms[b['room_id']]['encounter_section_id']='main'
        b['primary_reward']['section_id']=actions[b['primary_reward']['action']]['section_id']
        for field in ('first_reward_demonstration','unlock_summary','combat_identity'):
            if isinstance(b.get(field),str):
                b[field]=b[field].replace('窄热幕','相位光幕（非熔岩/实体热障）').replace('落地刷新后的第二次穿越','落地且2秒冷却结束后的第二次穿越').replace('稳定落地能重新触发 Q','稳定落地恢复资格，2秒冷却结束可再次触发 Q')
        b['encounter_design']=[t.replace('窄热幕','相位光幕（非熔岩/实体热障）') if isinstance(t,str) else t for t in b.get('encounter_design',[])]

    # Synchronise all read models to the single canonical interaction location.
    def rebind_tree(value):
        if isinstance(value,list):
            for item in value:rebind_tree(item)
        elif isinstance(value,dict):
            aid=value.get('action_id') or value.get('source_action_ref') or (value.get('id') if value.get('id') in actions else None)
            if aid in actions:
                a=actions[aid];value['room_id']=a['room_id'];value['section_id']=a['section_id'];value['requires']=deepcopy(a.get('requires',[[]]))
                value['access_mobility']=deepcopy(a.get('authored_mobility_access',[[]]))
            elif value.get('room_id') in rooms and 'section_id' not in value:
                value['section_id']='main'
            for child in value.values():
                if isinstance(child,(dict,list)):rebind_tree(child)
    for name in ('weapon_major_rewards','clock_repairs','central_clock_operations','important_markers','collectibles','quests','service_actions','shop_inventory'):
        rebind_tree(world.get(name))
    for npc in world['npcs']:
        npc['section_id']='main'
        for field in ('visible_when','services_when'):
            mob,items=split_dnf(npc['availability'].get(field))
            npc['availability'][field]=items
            if has_mobility(mob):npc['availability'][field+'_spatial_mobility']=mob
        npc['position_scope']='本房section内的交互占位；精确坐标见灰盒工作值。'
    for stock in world['shop_inventory']:
        mob,items=split_dnf(stock.get('source_requires'))
        stock['source_requires']=items
        stock['source_access_mobility']=mob
        stock['source_requirements_scope']='商品/服务只检查实际剧情与支付；行动能力由商人所在房间的可达环境保证。'
    for s in world['shortcuts']:
        e=edges[s['id']];a=actions[s['open_action_id']]
        s['open_section_id']=a['section_id'];s['open_requires']=deepcopy(a['requires'])
        s['opening_environment_access']=deepcopy(a.get('authored_mobility_access',[[]]))
        s['requires_after_open']=deepcopy(e['requires']);s['a_section']=e['a_section'];s['b_section']=e['b_section']
        s['control_side_contract']='亲到指定房间与分区的可见控制装置，明确交互后永久打开；不远程自动开门。'
        s['measurement_scope']='原绕行房序列保留为设计意图；v04分区路线与重试计数由新模拟报告核对。'
        s.pop('retained_hard_conditions',None);s.pop('detour_path_macro_conditions',None)
        s['geometry_status']='既有捷径连接；真实门方向与落脚工作值见v04逐房合同。'
        e['open_requires']=deepcopy(a['requires']);e['open_section_id']=a['section_id']
        e['opening_environment_access']=deepcopy(a.get('authored_mobility_access',[[]]))
    for mem in world['memory_gates']:
        e=edges[mem['edge_id']]
        unlocked_by_ability=any(t in ABILITIES for t in re.findall(r'\b[HWDQ]\b',mem.get('unlock_label','')))
        if e.get('environment_route_id') and unlocked_by_ability:
            mem['preview_room']=e['environment_room_id'];mem['preview_section_id']=e['b_section']
            mem['beyond_room']=e['environment_room_id'];mem['beyond_section_id']='main'
            mem['internal_route_id']=e['environment_route_id'];mem['observed_route']=e['environment_route_id']
            mem['marker_type']='inside_room_environment'
            mem['seen_condition']='实际到达本房入口安全区并看见地标/环境阻隔；不因远处房门存在而自动记忆。'
        else:
            pr=mem['preview_room'];side='a' if e['a']==pr else 'b'
            mem['preview_section_id']=e[side+'_section'];mem['marker_type']='physical_item_or_story_door'
            mem['seen_condition']='实际到达门所在分区并观察实体门锁；记录所缺物品/剧情条件。'
        mem['map_memory']='保存实际看见的环境地标或道具门；获得相关能力/物品后提示已观察过的位置，不替玩家揭露未见房间。'
    cues={'MEM01':'空心树干入口侧，抬头能看见悬挂铜环、树冠方向与根井支路。',
          'MEM02':'进入地穴入口台后，看见倒悬蕈灯与下层可落脚位置。',
          'MEM05':'进入镜脊侧回廊入口台，看见断裂霜镜桥、深部出口方向与远处奖励轮廓。',
          'MEM09':'进入熔火入口侧平台，看见相位光幕后的卸料厅；旁侧熔岩仍然伤害。'}
    for mem in world['memory_gates']:
        if mem['id'] in cues:mem['cue']=cues[mem['id']]

    deep_anchors={'P':['P1','P2','P3'],'F':['F1','F2','F3','F4'],'M':['M1','M2','M3'],
        'S':['S1','S2'],'Y':['Y1'],'I':['I1'],'C':['C1','C2'],'K':['K1','K2','Kq','K3'],
        'G':['G0','G1'],'N':['N1','N2','N3'],'E':['E1','E2'],'T':['T1','T2'],
        'R':['R1','R2'],'A':['A1','A2'],'V':['V1','V2'],'Z':['Z1','Z2','Z3','Z4']}
    difficulty={'P':([1,1],[2,2]),'F':([1,2],[2,3]),'M':([1,2],[2,2]),'S':([1,1],[2,2]),
        'Y':([1,2],[2,3]),'I':([2,2],[3,3]),'C':([1,1],[2,2]),'K':([2,1],[3,2]),
        'G':([2,2],[3,2]),'N':([1,1],[2,2]),'E':([3,2],[3,3]),'T':([1,2],[2,2]),
        'R':([2,1],[3,2]),'A':([2,2],[3,3]),'V':([2,2],[2,2]),'Z':([2,1],[3,3])}
    for reg in world['regions']:
        code=reg['code'];reg['development_status']='structure_graybox_specification_not_runtime_implemented'
        reg['status']='v04房间分区、预览与主体通路规划；实机尺寸、镜头和战斗待实施。'
        reg['exploration_main_locations']=[{'room_id':r['id'],'section_id':'main'} for r in world['rooms'] if r['region']==code and r['parent_anchor'] in deep_anchors[code]]
        reg['exploration_counting']='入口预览只记发现；到达exploration_main_locations才记深入；修钟和深部记录另计。'
        reg['difficulty_target']={'front_C_T':difficulty[code][0],'deep_C_T':difficulty[code][1],
            'scope':'普通通路制作上限候选；Boss峰值另列，未做实机难度验收'}
        reg['clock_change_contract']={'primary':['区域美术','BGM','时间现象与环境音'],
            'navigation':['打开既有捷径','恢复便利交通','旧路更易通过'],
            'dedicated_challenge_rooms':'保留原能力要求、主要挑战布局与失败伤害',
            'player_physics':'沿用统一玩家参数，不随地区时间主题改变'}
        reg['visual_audio_after_repair']='区域美术、BGM、环境音与时间现象的主要变化；具体延续本区钟修复叙事。'
        reg['traversal_after_repair']='打开既有捷径、恢复交通与便利旧路；不改写本区专门挑战房的要求。'
        reg['dedicated_challenges_unchanged']=True
    splits={
        'P':'从平原教程进入钟外小站，再展开主体探索；高台、根井口和回程在房内以环境能力路线区分，主体保持早期安全回访用途。',
        'F':'可进入林缘与空心树干入口台预览；H通路抵达树冠工坊，取得W后探索根井后半，并接向峡谷和圣殿。',
        'M':'可先看见封井与地穴入口空间；H房内路线通向灯与D，HD开启后庭；灯的识读、菌钟和道具门检查当前装备。',
        'S':'干岸入口可先到，能看见对岸地标；房内H路线接入横贯干岸，深区的装备门与毒水按抗毒规则处理，再连遗迹/矿井。',
        'Y':'谷底先展示冰川山麓远景；房间内部的W攀升与风口路线接向主体，高处有分层落脚与回程。',
        'I':'山麓与镜脊入口台可预览；HW通路接近正式登高段，HWD阻隔布置在房内长登高开始前，未具备时可直接折返。',
        'C':'外园与墓室入口可先进入；主体地形提供HW或HD两条机动解法，地下礼拜堂用发光装备识读并开启对应道具门。',
        'K':'可进入古堡外院预览；王室纹章控制实体门，内廷房内通路提供HW或HD解法；骑士胜利后取Q，再经相位光幕后厅接向浮岛。档案另受本地钟与深段环境路线限制。',
        'G':'工房是可实际使用的早期服务主体；H、HW或HD要求落实在相邻房间环境通路。首次进入炉区保留见武器匠的剧情联锁，再在炉区入口完成HDQ路线。',
        'N':'上矿道作为跨区中转；深矿房内HD路线连接遗迹和熔火。炸弹锁位于采时井与材料侧柜的实体薄壁/门，取炸弹的前路不要求炸弹。',
        'E':'首次从工城经武器匠联锁进入炉口预览台；HDQ通路通向主炉，Q只处理光幕，熔岩按2HP危险。修炉后从炉侧开通回矿井/遗迹的便利通路。',
        'T':'三个入口先展示门厅；外庭可取得环境工具，HW房内根井路线进入圣殿主体，不把工具藏在自身锁后。',
        'R':'干燥外环与入口可先探索；HD房内通路进入中庭，发光装备作用于识读与相关道具门，修复后接通地下回环。',
        'A':'先进入下岛安全台观看浮岛；HDQ房内通路通向下岛主体，HWDQ通路进入上岛。校相后解开钟心外壳，天门仍是普通结局可跳过的深线。',
        'V':'观测前庭可先抵达；桥台/观测室的剧情门依据古堡与墓园线索，HWD组合落实在房内短段，主体以观景和真相收束为主。',
        'Z':'门厅早期可见，中环连接回访。三类核心材料控制主轴联锁门；Q及HWD通路布置在门后的房内，侧门均位于最终封印前。王后前室与真结局神战资格分开。'}
    for reg in world['regions']:reg['split']=splits[reg['code']]
    # All live summaries now point at v04; retain historical checks only in snapshot.
    world['schema']='gunman-rush.room-world.v04'
    world['source_sha256']=report['source_sha256']
    world['status']='全世界结构灰盒设计数据；门/分区/永久交互已具体化，物理与战斗仍待Godot实施验证。'
    world['start_section']='main'
    world['coordinate_system']['scale_status']='地图轮廓用于世界定位；逐房施工工作值在v04合同中独立声明，不是本图固定比例放大。'
    world['passage_contract']='房门连通性以connections为准；门条件与房内环境条件分别记录，示意接廊不产生额外连接。'
    world['graybox_global'].update(
        door_load_contract='普通门可进入指定安全入口分区；左右步行，上跳接管后落入口旁台，下落入口下必有安全台；道具/剧情门按明确条件开启。',
        terrain_failure='普通危险扣1HP、特殊危险如熔岩扣2HP；扣血后未死亡则回本挑战进入侧锚点，不治疗、不重置休息周期。',
        q='仅反冲位移阶段保护敌人伤害与光幕；真实落地资格及2秒冷却同时满足；实体危险仍伤害。',
        loadout='沿用休息区换装边界；卸下环境装备后可重新装备，不新增特殊退路系统。',
        camera='普通镜头基准按既有玩家参数重新标定；按房间用途设置跟随/纵向/固定战斗/有限移动战斗相机区。',
        ability_gates='H/W/D/Q由房内环境通路实现；门只检查道具、剧情、机关等真正门锁。',
        world_build_gate='可据分区与连接开展全世界结构灰盒；先校准代表房的镜头/尺度，再批产真实地形；不把候选空间当物理验收。')
    world['runtime_rules']={
        'movement':'沿用当前游戏参数；地区时间异常主要体现在美术、BGM、敌人和机关',
        'q':{'cooldown_seconds':2,'landing_required':True,'only_during_recoil_displacement':True,
            'immune_to':['enemy_damage','phase_light_curtain'],'not_immune_to':['spikes','gears','lava','toxic_water','solid_terrain'],
            'cooldown_does_not_limit_normal_fire_or_recoil':True,'transitions_do_not_reset_cooldown':True},
        'terrain_damage':{'normal':1,'special':2,'special_example':'lava','once_per_failure':True,'zero_hp_uses_death':True},
        'attacks':{'one_complete_attack':'one_shot','triple_laser_complete_single_target_multiplier':1.5,'safe_boss_window_shots':2,'greedy_shots':3,'weakest_ordinary_enemy_hp':9},
        'rest':'明确休息恢复HP、刷新普通敌人与休息周期；交通不等于休息',
        'clock_repair':'视听变化为主，开捷径/便利旧路，专门挑战房不改难度'}
    for r in world['rooms']:
        r.pop('v04_purpose',None)
        for a in r.get('challenge_anchors',[]):
            a['section_id']='main';a['normal_failure_damage']=1;a['special_failure_damage']=2
        for c in r.get('shortcut_controls',[]):
            if not isinstance(c,dict):continue
            aid=c.get('action_id') or c.get('open_action_id')
            if aid in actions:c['section_id']=actions[aid]['section_id'];c['requires']=deepcopy(actions[aid]['requires'])
        for hint in r.get('exploration_guidance',[]):
            if isinstance(hint,dict):hint['scope']='在实际可达分区显示；不能从入口自动看到房间全部锁或奖励。'
        routes=[x for x in r['internal_routes'] if has_mobility(x['requires'])]
        if routes:r['gate_summary']='房内环境：'+'；'.join(dict.fromkeys(ability_label(x['requires']) for x in routes))
        r['section_count']=len(r['sections'])
    purpose_updates={
        'F-R04':'进入树干入口台观察铜环与高处树冠；H环境接续通主体，W后根井支路复用本房侧区，未具备能力可原路返回。',
        'I-R11':'先进入镜脊入口安全台，观察断桥与远处深部出口；HWD房内桥段之后才到主体及奖励侧，能力未齐可折返。',
        'E-R12':'工城经武器匠剧情联锁进入的炉口安全台；房内HDQ光幕与接续通向卸料厅，熔岩仍伤害，首次通路不要求W。',
        'K-R05':'Q后厅含入口安全台、相位光幕与主体；穿过光幕后接向浮岛，入口自动落脚不越过能力阻隔。',
        'A-R11':'巨像战前可到的校相台安全外缘与休息点；HWDQ接续落实在入口至主体，钟修复交互仍位于胜利后的可达台。',
        'A-R12':'多入口观测浮桥；各入口安全台与主体分开，HWDQ短段通主体，安全落点兼顾Q的2秒冷却，校相后的奖励/回程另有交互条件。',
        'V-R05':'天门主钟与守门战的实际主体；可从门进入前庭观察，以HWD房内接续到战斗区；战斗胜利后修钟。'}
    for rid,text in purpose_updates.items():rooms[rid]['purpose']=text
    report['display_anchor_adjustments']=[]
    for r in world['rooms']:
        for sec in r['sections']:
            before=sec['map_anchor_candidate']
            if point_inside_polygon(before,r['polygon']):continue
            centre=r['map_centre'];after=None
            for ratio in (.10,.20,.35,.50,.70,1.0):
                candidate=[round((1-ratio)*before[i]+ratio*centre[i],3) for i in (0,1)]
                if point_inside_polygon(candidate,r['polygon']):after=candidate;break
            if after is None:raise ValueError('No safe diagram marker inside '+r['id']+' '+sec['id'])
            sec['map_anchor_candidate']=after
            report['display_anchor_adjustments'].append({'room_id':r['id'],'section_id':sec['id'],'before':before,'after':after,'scope':'仅示意符号内移，不变更场景连通或地形尺寸'})
    # Drop stale verification payloads instead of carrying contradictory authority.
    for field in ('route_plans','state_verification','development_artifacts'):
        world.pop(field,None)
    world['validation_source']={'status':'external_v04_reports_are_authoritative','room_routes':'simulation/route-replays-v04.json',
        'section_migration':'qa/section-migration-v04.json','scope':'逻辑连通/状态/唯一奖励；物理、镜头与战斗另做实机验收。'}
    world['validation_scope']='分区拓扑与永久交互可机器验证；不能据此宣称跳跃、Q冷却节奏、Boss战或真实时长已通过。'
    for key in ('minimum_count_proof','route_replays','checks','summary'):
        world['boss_plan'].pop(key,None)
    world['boss_plan']['status']='22场战斗的角色/奖励与分区绑定；v04验证在外部报告中，真实战斗待灰盒。'
    world['boss_plan']['validation_source']='simulation/route-replays-v04.json'
    world['boss_plan']['validation_scope']='Boss主体与胜利交互的分区绑定及剧情/道具前置；实际路线覆盖由v04报告验证。最低Boss数量为设计目标，不把旧图下界当作新图证明；战斗和物理仍待实机。'
    world['boss_plan']['boss_actions']=[deepcopy(a) for a in world['actions'] if a.get('type')=='boss_defeat']
    world['boss_plan'].pop('action_requirement_increments',None)
    world['boss_plan']['macro_graph_contract']='门物品锁与房内能力通路拆开；Boss主体不可借道；永久奖励绑定胜利后的实际交互。'
    for key in ('boss_retry_coverage','validation','shortcut_gate_implication_checks'):
        world['rest_plan'].pop(key,None)
    world['rest_plan']['status']='40个休息点结构位置保留；v04分区重试距离另行核对，不沿用旧房门图通过结论。'
    world['rest_plan']['validation_source']='simulation/route-evidence-v04.json'
    world['rest_plan']['internal_gate_overrides']=[]
    world['rest_plan']['connection_overrides']=[]
    for rp in world['rest_plan'].get('rest_points_added',[]):rp['section_id']=rooms[rp['room_id']]['rest_section_id']
    for name in ('new_shortcuts','existing_shortcuts'):
        world['rest_plan'][name]=[deepcopy(s) for s in world['shortcuts'] if bool(s.get('is_new'))==(name=='new_shortcuts')]
    world['provenance']={'iteration':'v04：普通门预览、房内能力通路、最新Q/伤害/镜头规则',
        'historical_input':'source_inputs/world-room-layout-v03.json','historical_input_sha256':hashlib.sha256(source_bytes).hexdigest(),
        'rebuild':'python migrate_world_v04.py','canonical_role':'current_structure_specification'}
    world['source_macro_edges']=[{'id':e['id'],'a':e['a'],'b':e['b'],'reference_scope':'仅历史宏观锚点身份；当前门锁与能力路线以connections/rooms.internal_routes为准。'} for e in old['source_macro_edges']]
    world['paired_depth_passage'].pop('source_conditions_unchanged',None)
    world['paired_depth_passage']['conditions_ref']='connections:C30'
    for ending in ('normal','true'):
        end=world['endings'][ending];action=actions[end['action']]
        end['requires']=deepcopy(action['requires']);end['room_id']=action['room_id'];end['section_id']=action['section_id']
        end['mobility_reached_via_environment']=deepcopy(action.get('authored_mobility_access',[[]]))
        end['count_status']='地区/Boss数量是规划目标；v04实际路线与主体覆盖以新模拟报告为准。'
    if isinstance(world.get('memory_support'),dict):
        world['memory_support']['observation_scope']='只记录实际到达分区后能观察的地标或道具门。'
    if isinstance(world.get('pacing_guidance'),dict):
        world['pacing_guidance']['schema']='world.pacing-guidance.v04'
        world['pacing_guidance']['source_diagnostic']='simulation/route-evidence-v04.json'
        world['pacing_guidance']['rest_count_decision']='保留40处休息点；入口预览与主体分区拆分后的实际重试距离由v04模拟报告重算。休息分岔导视与真实失败疲劳须在灰盒中核对。'
    # Refresh named gate descriptions; no old ability symbol is left on a door.
    world['critical_gate_positions']={e['id']:{'door_endpoints':{'a':{'room_id':e['a'],'section_id':e['a_section']},'b':{'room_id':e['b'],'section_id':e['b_section']}},
        'door_requires':e['requires'],'environment_room_id':e.get('environment_room_id'),
        'environment_route_id':e.get('environment_route_id'),'scope':'图中能力符号绘在房内路线，道具/剧情符号绘在门上'}
        for e in world['connections'] if e['requires']!=[[]] or e.get('environment_route_id')}
    # Derived totals and elementary referential checks.
    all_routes=[(r['id'],t) for r in world['rooms'] for t in r['internal_routes']]
    report['counts']={'rooms':len(rooms),'connections':len(edges),'actions':len(actions),
        'original_mobility_connections':sum(has_mobility(e.get('requires')) for e in old['connections']),
        'physical_environment_edge_sites':sum(x['kind']=='door_to_room_environment' for x in report['edge_migrations']),
        'shortcut_redundant_ability_removals':len(report['shortcut_implications']),
        'sections':sum(len(r['sections']) for r in world['rooms']),
        'entry_preview_sections':sum(s['kind']=='entrance_preview' for r in world['rooms'] for s in r['sections']),
        'shared_action_sections':len(access_sections),'internal_directed_routes':len(all_routes),
        'abilities_removed_from_action_checks':len(report['action_bindings'])}
    section_ids={rid:{s['id'] for s in r['sections']} for rid,r in rooms.items()}
    report['invariants']={
        'same_room_ids':set(rooms)==set(old_rooms),
        'same_connection_ids':set(edges)==set(old_edges),
        'same_connection_endpoints':all((e['a'],e['b'])==(old_edges[e['id']]['a'],old_edges[e['id']]['b']) for e in world['connections']),
        'same_action_ids':set(actions)==set(old_actions),
        'same_action_grants':all(a.get('grants')==old_actions[a['id']].get('grants') for a in world['actions']),
        'no_door_mobility_predicates':all(not has_mobility(e['requires']) for e in world['connections']),
        'no_action_mobility_checks':all(not has_mobility(a.get('requires')) for a in world['actions']),
        'all_connection_sections_exist':all(e['a_section'] in section_ids[e['a']] and e['b_section'] in section_ids[e['b']] for e in world['connections']),
        'all_action_sections_exist':all(a['room_id']=='@current' or a['section_id'] in section_ids[a['room_id']] for a in world['actions']),
        'all_internal_route_endpoints_exist':all(t['from_section'] in section_ids[rid] and t['to_section'] in section_ids[rid] for rid,t in all_routes),
        'all_boss_arenas_main':all(b['encounter_section_id']=='main' and actions[b['defeat_action']]['section_id']=='main' for b in world['boss_plan']['bosses']),
        'ability_tokens_never_removed':all(not (ABILITIES & set(a.get('removes',[])+a.get('consumes_story_items',[]))) for a in world['actions']),
        'all_regions_have_main_exploration_locations':all(r['exploration_main_locations'] for r in world['regions'])}
    if not all(report['invariants'].values()):raise AssertionError(report['invariants'])
    report['passed']=True
    world['counts'].update(sections=report['counts']['sections'],internal_directed_routes=len(all_routes),
        environment_connection_sites=report['counts']['physical_environment_edge_sites'],shared_action_access_sections=len(access_sections))
    OUTPUT.write_text(json.dumps(world,ensure_ascii=False,indent=2)+'\n')
    REPORT.parent.mkdir(parents=True,exist_ok=True);REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'output':str(OUTPUT),'counts':report['counts'],'invariants':report['invariants']},ensure_ascii=False))

if __name__=='__main__':compile_world()
