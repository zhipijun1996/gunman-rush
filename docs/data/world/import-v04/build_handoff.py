"""Check current sources and generate the consolidated handoff status.

This is a data handoff check, not an engine or physical playtest.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).resolve().parent


def read(name):
    return json.loads((ROOT / name).read_text())


def raw_hash(name):
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def main():
    world = read('world-room-layout-v04.json')
    legacy = read('source_inputs/world-room-layout-v03.json')
    contracts = read('design/room-graybox-contracts-v04.json')
    room_audit = read('qa/room-contract-audit-v04.json')
    route_audit = read('simulation/contract-audit-v04.json')
    replays = read('simulation/route-replays-v04.json')
    evidence = read('simulation/route-evidence-v04.json')
    world_hash = raw_hash('world-room-layout-v04.json')
    semantic_hash = hashlib.sha256(json.dumps(world, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    checks = []

    def check(name, passed, details):
        checks.append({'id': name, 'passed': bool(passed), 'evidence': details})

    check('stable_room_ids', {r['id'] for r in world['rooms']} == {r['id'] for r in legacy['rooms']}, '保留全部216个房号')
    check('stable_connection_ids', {x['id'] for x in world['connections']} == {x['id'] for x in legacy['connections']}, '保留全部288个连接ID')
    check('stable_action_ids', {x['id'] for x in world['actions']} == {x['id'] for x in legacy['actions']}, '保留全部248个交互动作ID')
    check('simulation_hash_matches', all(x['source_world_sha256'] == world_hash for x in [replays, route_audit, evidence]), world_hash)
    check('contracts_source_hash_matches', contracts['canonical_sha256'] == world_hash, {'expected': world_hash, 'actual': contracts['canonical_sha256']})
    check('room_contract_checks_passed', room_audit['passed'] and all(room_audit['checks'].values()), room_audit['checks'])
    check('route_contract_checks_passed', route_audit['passed'] and all(c['passed'] for c in route_audit['checks']), route_audit['check_count'])
    check('all_planned_replays_succeed', len(replays['replays']) == 4 and all(r['success'] for r in replays['replays']), [r['id'] for r in replays['replays']])
    rooms = {r['id']: r for r in world['rooms']}
    section_ids = {r['id']: {s['id'] for s in r['sections']} for r in world['rooms']}
    doors = {d['id']: d for r in contracts['rooms'] for d in r['doors']}
    spawns = {s['id'] for r in contracts['rooms'] for s in r['entry_spawns']}
    opposite = {'left': 'right', 'right': 'left', 'up': 'down', 'down': 'up'}
    issues = []
    for door in doors.values():
        target = doors.get(door['target_door_id'])
        if not target or target['target_door_id'] != door['id']:
            issues.append([door['id'], 'unpaired'])
        if target and opposite.get(door['direction']) != target['direction']:
            issues.append([door['id'], 'direction'])
        if door['target_spawn'] not in spawns:
            issues.append([door['id'], 'spawn'])
        if door['section'] not in section_ids[door['room_id']] or door['target_section'] not in section_ids[door['target_room']]:
            issues.append([door['id'], 'section'])
    check('all_576_interfaces_resolve', len(doors) == 576 and len(spawns) == 576 and not issues, issues)
    forbidden = {'H', 'W', 'D', 'Q'}
    bad = [d['id'] for d in doors.values() if any(forbidden.intersection(clause) for clause in d['requires'])]
    check('no_ability_checks_on_physical_doors', not bad, bad)
    check('current_section_counts', sum(len(r['sections']) for r in rooms.values()) == 310 and sum(len(r['internal_routes']) for r in rooms.values()) == 188, {'sections': 310, 'directed_internal_routes': 188})
    check('current_collection_source_counts', len(world['weapon_major_rewards']) == 16 and len(world['collectibles']['gear_sites']) == 40 and len(world['shop_inventory']) == 12, {'weapon_growth_sources': 16, 'time_gears': 40, 'shop_equipment_slots': 12})
    catalog = read('design/collection-catalog-v04.json')
    action_ids = {a['id'] for a in world['actions']}
    stock_ids = {s['id'] for s in world['shop_inventory']}
    slots = catalog['equipment_sources']
    catalog_ok = catalog['canonical_reference']['sha256'] == world_hash and len(slots) == 50 and len({s['reward_id'] for s in slots}) == 50
    catalog_ok = catalog_ok and all((s.get('action_ref') in action_ids) if 'action_ref' in s else (s.get('stock_ref') in stock_ids) for s in slots)
    check('equipment_catalog_refs_match', catalog_ok, {'source_slots': len(slots), 'effects_complete': False})
    ready = all(c['passed'] for c in checks)
    integrity = {'schema': 'world.handoff-integrity.v04', 'source_world_sha256': world_hash, 'source_world_semantic_sha256': semantic_hash, 'passed': ready, 'check_count': len(checks), 'checks': checks, 'scope': '跨文件版本、稳定ID与接口一致性；不验证引擎物理或完整游戏体验'}
    (ROOT / 'qa/final-data-integrity-v04.json').write_text(json.dumps(integrity, ensure_ascii=False, indent=2) + '\n')

    names = {'A_normal_w_first': 'A 先W普通结局', 'B_normal_d_first': 'B 先D普通结局', 'C_true_16_regions': 'C 真结局', 'D_all_unique_rewards': 'D 成长材料与齿轮审计'}
    results = {'A_normal_w_first': '普通结局；较早森林/圣殿', 'B_normal_d_first': '普通结局；较早地下/炸弹；无W可先入熔火', 'C_true_16_regions': '真结局；15地区钟、16深部记录', 'D_all_unique_rewards': '40齿轮交付；16武器来源与全部分支/技能升级'}
    summaries = []
    for r in replays['replays']:
        rank = max([int(t.rsplit('_', 1)[-1]) for t in r['tokens'] if t.startswith('attack_rank_')] + [0])
        summaries.append({'id': r['id'], 'name': names[r['id']], 'success': r['success'], 'discovered_regions': len(r['discovered_regions']), 'deep_regions': len(r['deep_regions']), 'subject_rooms': r['subject_rooms'], 'bosses': len(r['bosses_defeated']), 'attack_rank': rank, 'attack_value': [5,9,13,17,21][rank], 'door_crossings': r['move_steps'], 'internal_segments': r['internal_steps'], 'teleports': r['teleports'], 'result': results[r['id']]})

    human_checks = [
        ('01','规模和稳定身份','16区、216房、288连接；旧房号和唯一动作ID保留'),
        ('02','能力阻隔进入房间内部','310分区、188有向内部路线；物理门不检查H/W/D/Q'),
        ('03','跨房与真实落脚合同','576门、576入口出生点成对；左右/向上/向下行为明确'),
        ('04','四条分区路线','A/B/C/D全部成功；深入区域分别12/14/16/16'),
        ('05','能力取得与无能力反例','H/W/D/Q无自身能力自锁；树干/冰川/熔火预览可退回'),
        ('06','首次熔火必经武器匠','B先工房解放、武器匠对话，再以HDQ且无W进入熔火主体'),
        ('07','休息与Boss接近','22场Boss均有合法休息分区；图距离至战场不超过两次过门'),
        ('08','实际回访链','A/B/C/D有5/4/5/6个先看见、离开、解锁、返回、领奖的地标样本'),
        ('09','材料库存与消费','攻击材料8枚按1/2/2/3消费；6分支、2共用技能芯；40齿轮实际交付'),
        ('10','服务与唯一交互','14NPC、9商人、248动作按房内分区绑定；12装备商品保留唯一库存'),
        ('11','修钟与结局','真线15地方钟+16深部记录；不要求先普通结局，也不要求22Boss全清'),
        ('12','状态与版本一致','模拟、地图主数据、施工合同引用当前世界；唯一动作收据不重复'),
    ]
    status = {
        'schema': 'world.handoff-readiness.v04', 'date': '2026-11-06',
        'ready_for_world_structure_graybox': ready,
        'meaning': '可以开始整个世界的结构灰盒：先共享样房标定，再216房结构与真实条件占位，之后逐房深化。',
        'not_a_claim_of': ['Godot已实现', '房间尺寸已经实机定稿', '全部战斗/跳跃/镜头通过', '商店经济或50装备效果完成'],
        'canonical': 'world-room-layout-v04.json', 'canonical_sha256': world_hash,
        'authorities': {'start': 'START_HERE.txt', 'rules': 'design/world-graybox-bible-v02.txt', 'world': 'world-room-layout-v04.json', 'construction': 'design/room-graybox-contracts-v04.json', 'readable': 'world-development-atlas-v07.pdf'},
        'counts': contracts['counts'], 'route_summaries': summaries,
        'checks': [{'id': k, 'name': n, 'status': '通过' if ready else '须核对', 'evidence': e} for k,n,e in human_checks],
        'machine_checks': {'route_and_state': route_audit['check_count'], 'room_contract': len(room_audit['checks']), 'cross_file_integrity': len(checks)},
        'reports': ['simulation/contract-audit-v04.json','qa/room-contract-audit-v04.json','qa/final-data-integrity-v04.json','simulation/route-evidence-v04.txt','simulation/nonpriced-acquisition-audit-v04.json'],
        'remaining_first_development_tasks': [
            '用当前角色控制器实测横门、上跳自动落台、下落安全平台及死亡/休息/存档。',
            '校准四类相机、普通视觉尺度、门口前庭与有意义的可见范围。',
            '用实际H/W/D/Q完成代表性环境阻隔；Q验证2秒、真实落地、敌人与实体危险分类。',
            '先验证普通Boss与大型Boss的候选场地，再并行铺全部房间外框。'
        ],
        'later_details': ['房内精细地形与敌人组合','22Boss完整动作、HP和安全输出窗口','50装备效果与商店金币价格','任务对白、美术、BGM与修钟表现','真实游玩时间、认路和重试疲劳'],
        'price_boundary': '12装备商品与HP09/HP10/CAP01未定金币价，未模拟购买；占位来源不等于实际经济完成。',
        'historical_inputs': 'source_inputs只用于重建和迁移追溯，不是另一版生效规则。'
    }
    (ROOT / 'handoff-status.json').write_text(json.dumps(status, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'ready': ready, 'machine_checks': status['machine_checks'], 'failed': [c['id'] for c in checks if not c['passed']]}, ensure_ascii=False))
    if not ready:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
