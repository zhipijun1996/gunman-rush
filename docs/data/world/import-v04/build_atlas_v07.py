"""Human atlas compiled from the v04 world and its derived contracts."""
from pathlib import Path
import json, math, hashlib
from collections import Counter, defaultdict
from PIL import Image
import matplotlib
matplotlib.use('Agg')
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.pyplot as plt
import atlas_utils as U

R=Path(__file__).resolve().parent
D=json.loads((R/'world-room-layout-v04.json').read_text())
C=json.loads((R/'design/room-graybox-contracts-v04.json').read_text())
STATUS=json.loads((R/'handoff-status.json').read_text())
CR={r.get('room_id',r.get('id')):r for r in C['rooms']}
ROOM={r['id']:r for r in D['rooms']}
REG={r['code']:r for r in D['regions']}
ACT={a['id']:a for a in D['actions']}
BOSS={b['room_id']:b for b in D['boss_plan']['bosses']}
REPLAYS=json.loads((R/'simulation/route-replays-v04.json').read_text())['replays']
NMAP={n['id']:f'N{i:02d}' for i,n in enumerate(D['npcs'],1)}
CAM={'horizontal_follow':'横向跟随','vertical_follow':'纵向跟随','fixed_battle':'固定战斗构图','bounded_battle':'有限移动战斗构图'}
SHAPES={'boss_combat_plus_foyers':'战斗区与前庭','optional_pocket':'可选支路口袋','ordinary_route':'普通探索通路','safe_service':'安全服务空间','tutorial_gallery':'教程长廊','vertical_route':'纵向空间'}
ARENAS=dict(zip(['alternating_pair_court','bent_vertical_rail','bomb_marker_court','bounce_spore_arena','bridge_chain_platforms','compact_blade_duel','delayed_layer_arena','dry_islands_arena','final_gun_pendulum_court','ground_duel','gunline_duel','patrol_high_weakpoint','pendulum_court','phase_constellation_arena','ranged_duel','root_wall_court','slow_floating_platforms','star_track_court','two_lane_factory','two_level_phase_furnace','wall_layer_arena','wind_charge_arena'],['交替双敌庭','弯折竖轨','爆破标记庭','弹菇孢子场','吊桥锁链平台','紧凑剑刃决斗','延时分层场','安全岛屿场','终局枪线钟摆庭','地面决斗','枪线决斗','巡游与高处弱点','钟摆庭','相位星座场','远程决斗','根壁庭','缓行浮台','星轨庭','双层工厂','双层相位熔炉','墙面分层场','阵风冲锋场']))
SERVICES=dict(zip(['Q_practice','Q_trial','cemetery_guidance','climb_guidance','environment_equipment_shop','equipment_breakage_repair','equipment_gold_upgrade','equipment_shop','existing_cosmetic_service_if_retained','furnace_return_guidance','gear_delivery','high_altitude_guidance','local_guidance','local_record_interpretation','one_equipment_quest','one_equipment_supply_slot','one_health_shard_quest','one_time_capacity_fit','optional_story_interpretation','regional_missing_gear_hints','shared_weapon_skill_install','station_supply_shop','tool_explanation','underground_direction_hints','weapon_attack_upgrade','weapon_branch_forging','workshop_supply_shop'],['Q练习','Q试炼','墓园指引','登高指引','环境装备商店','损坏装备修理','付费装备升级','装备商店','外观服务（若保留）','熔火回程指引','交付时间齿轮','高空路线指引','地区指引','深部记录解读','装备任务','一个装备来源','血量碎片任务','一次负荷提升','可选剧情解读','地区漏收齿轮提示','共用武器技能安装','小站物资','工具讲解','地下方向提示','武器攻击升级','武器分支锻造','工房补给']))
ACTION_NAMES={'get_H':'取得H钩索','get_W':'取得W墙面移动','get_D':'取得D二段跳','get_Q':'取得Q相位反冲','get_shuriken':'取得手里剑','get_bomb':'取得炸弹','get_lamp':'取得蕈光灯','get_filter':'取得净毒滤芯','get_severance':'取得断契棱针','install_cores':'安装三枚核心','install_skill_core_1':'开放第1共用武器技能','install_skill_core_2':'开放第2共用武器技能'}
for i,attack in enumerate([9,13,17,21],1):ACTION_NAMES['upgrade_attack_rank_'+str(i)]='攻击升级至'+str(attack)
for b in D['boss_plan']['bosses']:ACTION_NAMES[b['defeat_action']]='击败'+b['name']
for a in D['weapon_major_rewards']+D['clock_repairs']+D['central_clock_operations']:ACTION_NAMES.setdefault(a['action_id'],a['name'])


def short(value,limit=220):
    if isinstance(value,dict):value=json.dumps(value,ensure_ascii=False)
    if isinstance(value,list):value='；'.join(str(x) for x in value)
    return str(value)


def req(value):
    if value is None:return '基础通行'
    if not isinstance(value,list):return str(value)
    return U.clauses(value)


def section(o):
    return o.get('section_id',o.get('preview_section_id',o.get('section',o.get('location',{}).get('section_id','main'))))


def named_action(action_id):
    a=ACT.get(action_id,{})
    return ACTION_NAMES.get(action_id,a.get('name',a.get('label',action_id)))


def pressure(value):
    return '/'.join(str(x) for x in value) if isinstance(value,list) else short(value)


def rows_pages(title,subtitle,heads,widths,rows,chapter,size=10.3,min_row=6.2):
    if not rows:return
    chunks=U.split_table_rows(rows,widths,min_row=min_row,size=size)
    for i,chunk in enumerate(chunks):
        _,ax=U.page(title+(f' · {i+1}/{len(chunks)}' if len(chunks)>1 else ''),subtitle,chapter)
        U.table(ax,heads,widths,chunk,min_row=min_row,size=size)


def plate(title,filename,subtitle,chapter='世界地图'):
    fig,ax=U.page(title,subtitle,chapter)
    a=fig.add_axes([.035,.09,.93,.76]);a.imshow(Image.open(R/filename));a.axis('off')


def norm_interactions(room_id):
    out=[]
    for n in D['npcs']:
        if n['room_id']==room_id:out.append(NMAP[n['id']]+' '+n['display_name'])
    for a in D['weapon_major_rewards']:
        if a['room_id']==room_id:out.append(a['id']+' '+a['name'])
    for a in D['clock_repairs']:
        if a['room_id']==room_id:out.append(a['name'])
    b=BOSS.get(room_id)
    if b:out.append('Boss '+b['name']+' → '+b.get('reward_summary',b['primary_reward']['reward']))
    return '；'.join(out) or '普通探索 / 奖励详见逐房数据'


def cover():
    _,ax=U.page('世界结构灰盒 · 开发交接','16区域 / 216房间 / 最新操作规则、房内能力通路与永久事件统一为v04','开工说明')
    ready=STATUS.get('ready_for_world_structure_graybox',False)
    U.card(ax,0,14,48,24,'当前结论：'+('可以开始结构灰盒' if ready else '仍有结构阻塞'),
        '房间场景、跨房落脚、入口预览、房内通路、\nBoss与服务占位、永久奖励和结局流程可据此制作。\n具体跳距、敌人招式、镜头参数在首批样房中校准。',U.TEAL)
    U.card(ax,52,14,48,24,'图与数据的职责',
        '世界图：区域位置、房号、重要内容与回访地标。\n主数据：连接、分区、条件、事件和永久ID。\n逐房合同：施工工作值、接口、镜头与难度职责。',U.BLUE)
    U.card(ax,0,42,48,26,'本轮已经落实',
        'H/W/D/Q条件移至房内路线，普通门可入预览区。\n左右步行、向上自动落侧台、向下安全台、交通交互。\n地形1/2HP，Q仅敌人与光幕保护并有2秒冷却。\n已发现与已深入分开统计。',U.TEAL)
    U.card(ax,52,42,48,26,'开发中完成的标定',
        '工作尺寸与门坐标可调整，不是实测物理结论。\n首批校准镜头、真实落脚、Q厚度/冷却与Boss场地。\n具体敌人、装备效果、价格和美术音频逐项实现。\n这些不改变本版已明确的世界结构。',U.GOLD)
    U.section_note(ax,'唯一有效入口','先读START_HERE.txt；规则读design/world-graybox-bible-v02.txt；当前世界用world-room-layout-v04.json；施工用design/room-graybox-contracts-v04.json。source_inputs仅为重建输入，不是第二套生效规则。',78)


def governance():
    _,ax=U.page('资料分工与施工顺序','项目管理、设计规则、具体数据三类；修改主数据后重建派生件','开工说明')
    U.table(ax,['阶段','制作内容','本阶段结束应当能看到'],[12,43,45],[
        ['1 基础样房','教程→小站；横/纵跨房；Q光幕；基础Boss场地；保存与重载','现有操作不变，新镜头可读；落脚、失败、休息状态正确'],
        ['2 全世界外框','216房场景、288连接、房内分区与可视通路占位','能按真实条件走完A/B/C，并从能力预览区安全折返'],
        ['3 永久内容','NPC、16武器成长来源、40齿轮、修钟、捷径与结局','领取与消费按唯一ID保存，死亡和重载不复制奖励'],
        ['4 逐房深化','以房间职责逐步补平台、敌人、Boss招式、装饰和声音','每次改房保持跨房接口与永久ID；只重验受影响路线']
    ],min_row=12,size=11)
    U.section_note(ax,'允许局部调整','工作宽高、平台、镜头区与落脚坐标允许在样房后修订；房号、奖励ID、连接去向和主线前置变化需要同步主数据与路线验证。用可视的实体占位表现能力阻隔，不能用无形能力检查墙代替关卡。',79)


def rules():
    rows=[
      ['普通手感','采用当前角色移动、跳跃与射击反冲参数；地区加速/停时/缓时主要体现在视听、敌人与机关'],
      ['左右门','步行连接，门两端为地面；进入不等于休息'],
      ['上跳门','短暂接管，自动跳到目的入口侧真实平台，落地后归还控制'],
      ['下落门','入口下方保证安全平台，先落脚再进入本房通路'],
      ['交通','对话式交互触发；不回血、不重置周期或普通敌人'],
      ['地形失败','普通1HP，特别危险2HP；回本次挑战实际来向入口；HP归零则死亡'],
      ['Q','仅反冲位移期保护怪物/光幕；实体危险照伤；真实落地资格与2秒冷却同时满足'],
      ['Q与射击','2秒只限制Q保护，普通射击、普通反冲的既有节奏保持'],
      ['装备','保留换装规则，灯/滤芯可重新装备；不能借换装或过房清Q冷却'],
      ['永久状态','能力、唯一奖励、Boss、修钟和捷径永久；实际休息才触发约定的休息周期']]
    rows_pages('操作与状态规则','本轮用户确认优先；详细状态边界见设计规则',['项目','规则'],[18,82],rows,'操作与状态',11,7)
    _,ax=U.page('进入房间 ≠ 穿过房间','普通门连接入口；能力条件属于内部环境通路','能力预览与回访')
    U.table(ax,['例子','可先进入','获得能力后的通路'],[19,39,42],[
       ['F-R04 空心树干','L03进入底部入口台，见铜环与树冠；无H能退回','H进入主体；后续W支路与其他出口按所在分区开放'],
       ['I-R11 镜脊侧回廊','L08进入断桥近端，见霜镜桥和奖励方向','HWD桥段连主体；三个深部出口不随进入口一并开放'],
       ['E-R12 熔火入口','保留武器匠剧情联锁；进门落在入口台','HDQ环境路线入主体；Q挑战使用光幕，熔岩仍伤害'],
       ['地图统计','已发现只记录预览；回访标记只记录实际看过的地标','已深入、地区钟、深部记录分别保存；真结局不以探头计数']
    ],min_row=12,size=11)
    U.section_note(ax,'路线验证单位','模拟位置为房号+分区。奖励、Boss、NPC、休息与裂缝必须绑定具体分区。普通无阻隔房只用main；不会把每房都复杂化。',81)


def camera():
    _,ax=U.page('镜头与房间尺寸','玩家物理保持；镜头按空间组织，工作尺寸在样房后统一校准','空间与镜头')
    U.table(ax,['配置','适用','构图目标'],[21,24,55],[
      ['横向跟随','普通走廊、地面探索','跟实际移动趋势，避免跟枪口；小跳稳定，前方落点可见'],
      ['纵向跟随','树干、峡谷、浮岛','上升提前展示索点/落脚层；下落看见安全平台'],
      ['固定战斗构图','紧凑Boss/决斗','关键预警、敌我及主要躲避位置同屏'],
      ['有限移动战斗构图','冲锋/大型/多平台Boss','局部跟随受战斗区限制；按阶段交接，不随每次冲刺缩放']
    ],min_row=11,size=11)
    U.card(ax,0,66,48,26,'工作值的含义','逐房宽高是世界单位施工候选；1280×720是参考视口。\n1.60仅用于首轮比较，一屏约800×450世界单位。\n世界图轮廓不是按统一比例放大的碰撞图。',U.BLUE)
    U.card(ax,52,66,48,26,'Boss场地从动作倒推','主要招式 → 玩家躲避/攻击 → 有效战斗区 → 镜头。\n前庭、奖励区和竞技区分别记录。\n异形房使用多个相机区，避免大外接框造成黑空。',U.TEAL)


def difficulty():
    cat=C.get('region_difficulty_catalog',{})
    if isinstance(cat,list):cat={r.get('code',r.get('region')):r for r in cat}
    rows=[]
    for code,r in REG.items():
        x=cat.get(code,{})
        rows.append([code+' '+r['name'],pressure(x.get('front',x.get('front_C_T',x.get('front_route',{})))),pressure(x.get('deep',x.get('deep_C_T',x.get('deep_route',{})))),x.get('rhythm',x.get('notes',x.get('note',r.get('play',''))))])
    rows_pages('16区难度职责','C=战斗压力；T=平台压力。普通通路上限，不要求每房做满；Boss峰值另列',['区域','前段C/T','深段C/T','节奏职责'],[21,13,13,53],rows,'区域难度',10.5,7)


def routes():
    rows=[]
    for x in STATUS.get('route_summaries',[]):
        rows.append([x.get('name',x['id']),str(x.get('discovered_regions','')),str(x.get('deep_regions','')),str(x.get('bosses','')),str(x.get('attack_rank','')),x.get('result','')])
    rows_pages('通关路线与收集审计','使用v04分区位置与实际动作记录；不把入口预览当主体探索',['路线','发现区','深入区','Boss','攻击阶','结果与用途'],[29,10,10,10,10,31],rows,'路线验证',10.8,12)
    _,ax=U.page('路线差异与验证边界','保持先W、先D、真结局与收集路线的不同体验','路线验证')
    U.card(ax,0,14,48,27,'先W：较早纵向探索','森林与圣殿较早进入。\n早访圣殿允许较低攻击；之后工房升级再进地穴。\n晚访区域更轻松是成长结果，不自动抬高敌人HP。',U.TEAL)
    U.card(ax,52,14,48,27,'先D：较早地下与炸弹','地穴、矿井与爆破回环较早展开。\n无W的HDQ配置必须能完成首次熔火路径。\n武器匠剧情联锁仍要求首次进熔火前见到武器匠。',U.BLUE)
    U.card(ax,0,46,48,27,'真结局与全收集不同','真线覆盖16区深部、15地方钟、16深部记录。\n不要求22Boss全清或50装备全部购买。\n收集审计另验40齿轮及16武器成长来源。',U.TEAL)
    U.card(ax,52,46,48,27,'本轮未冒充实机通过','抽象图验证条件、收据、库存与路径。\nBoss战在满足前置后视作胜利，不证明战斗平衡。\nQ冷却/厚度、跳距、镜头与自然回访记忆需试玩。\n商店未定金币价，拜访不等于已经购买。',U.GOLD)
    U.section_note(ax,'普通结局与真结局','普通路线按实际深入覆盖核对；真线沿用15钟+16记录等条件。死亡、休息、传送不撤销唯一进度；神战失败不强迫重打已击败的王。',81)
    for replay in REPLAYS:
        key_steps=[]
        for m in replay['milestones']:
            aid=m['after_action']
            a=ACT.get(aid,{})
            if aid.startswith('get_') or aid.startswith('install_') or aid.startswith('upgrade_attack_') or a.get('type') in ('ending','central_clock_operation') or aid in ('defeat_Z_KING','defeat_Z_DEITY'):
                key_steps.append(m)
        if not key_steps:key_steps=replay['milestones']
        rr=[]
        for i,m in enumerate(key_steps,1):
            choices=m.get('regional_choices',{})
            branches='；'.join(REG[k]['name']+'：'+named_action(v[0]) for k,v in choices.items() if v)
            rr.append([str(i),named_action(m['after_action']),m['room']+' / '+m.get('section','main'),'+'.join(m['abilities']) or '基础',str(m['attack_value']),branches or '按结局/收集目标继续'])
        summary=next(s for s in STATUS['route_summaries'] if s['id']==replay['id'])
        rows_pages(summary['name']+' · 成长主干','按动作重放顺序；中间走房、修钟、NPC和收集的完整轨迹见simulation/route-evidence-v04.txt',['序','关键获得/操作','位置/分区','能力','攻击','当时其他可去的目标示例'],[5,23,22,10,7,33],rr,'路线验证',9.7,7)
    rr=[]
    for replay in REPLAYS[:3]:
        samples=[x for x in replay['revisited_unlocked_routes'] if x.get('kind')=='internal']
        for x in samples[:4]:
            rr.append([replay['id'].split('_')[0],x['from_room']+' / '+x['from_section'],str(x['first_seen_step']),named_action(x['unlock_action']),str(x['first_used_after_unlock'])])
    rows_pages('看见阻隔，再取得能力，再回来','下列是实际回放闭环；步数是日志事件序号，不是分钟数，也不等于真人自然记忆',['路线','原先受阻位置','初见步骤','解锁动作','真正返回步骤'],[9,35,15,26,15],rr,'路线验证',10.5,7)


def npcs_rewards():
    rows=[]
    for n in D['npcs']:
        rows.append([NMAP[n['id']]+' '+n['display_name'],n['room_id']+' / '+section(n),'；'.join(SERVICES.get(s,s) for s in n.get('services',[])),','.join(n.get('shop_reward_slots',[])) or '-',n.get('story_role','')])
    rows_pages('14位NPC与服务','9位有装备商品；访问、解锁服务、领取与付费是不同动作',['NPC','位置/分区','服务','商品槽','角色职责'],[19,19,23,17,22],rows,'NPC与奖励',9.5,8)
    rows=[]
    for a in D['weapon_major_rewards']:
        rows.append([a['id'],a['name'],a['room_id']+' / '+section(a),{'attack_alloy':'攻击合金','branch_material':'分支部件','skill_material':'共享技能芯','skill_core':'共享技能芯'}.get(a['kind'],a['kind']),req(a.get('requires')),a.get('description',a.get('source',''))])
    rows_pages('16处武器成长来源','攻击合金8枚，按1/2/2/3消费；分支部件6种、共享技能芯2枚另计',['ID','奖励','位置/分区','用途','领取条件','取得方式'],[10,18,20,15,20,17],rows,'NPC与奖励',9.7,7)
    rows=[]
    for a in D['shop_inventory']:
        n=next(n for n in D['npcs'] if n['id']==a['merchant_id'])
        rows.append([a['id'],a['name'],NMAP[n['id']]+' '+n['display_name'],a['room_id'],str(a.get('price_tier','')), '金币价待灰盒收入标定；唯一库存'])
    rows_pages('12个商店装备来源','当前为唯一来源槽。价格与最终装备效果后续落入数据；不会假定免费获得',['ID','商品职责','商人','房间','价格档','实施说明'],[16,25,21,12,9,17],rows,'NPC与奖励',10,7)


def collection():
    _,ax=U.page('收集与成长系统总览','来源、数量与服务保留；效果和经济按试制状态分别标注','收集来源')
    U.table(ax,['系统','数量与规则','交接边界'],[21,42,37],[
        ['攻击成长','8枚攻击合金；四次消耗1/2/2/3；档位5/9/13/17/21','永久强化，交武器匠；具体战斗节奏仍需实测'],
        ['武器分支与技能','6种分支部件；2枚共用技能芯；每个武器家族2个技能','技能级数全局共享，后来取得的武器继承'],
        ['装备来源50处','地图28 + 商店12 + NPC任务6 + 齿轮回收4','含灯/滤芯；48件其余旧装备的具体取舍/效果未定稿'],
        ['生命与共鸣','12血量碎片、6共鸣碎片；保留当前来源ID','HP5→8、4片合1；共鸣100→160、2片加20为试制默认'],
        ['装备负荷','6次永久扩容，每次+1；初始8、最终14为试制默认','1商店、2地图、2齿轮回收、1工房服务；不重复领取'],
        ['时间齿轮','40枚；在小站回收匠累计交付，不作为消费货币','40枚用于完整演出/尾声，不是普通或真结局硬门槛'],
        ['休息与升级','本局/每图/锁装以实际休息为周期边界；重复成长走NPC金币升级','装备具体效果、金币价和升级细则在后续系统开发定稿']
    ],min_row=9.7,size=10.5)
    U.section_note(ax,'完整系统说明','design/COLLECTION_SYSTEMS-v04.txt与collection-catalog-v04.json保留规则来源、试制默认和50个来源槽；当前世界JSON负责位置与领取前置。没有把来源占位说成50件定稿装备。',88)
    groups=[('map_equipment_slots','28个地图装备来源'),('gear_sites','40枚时间齿轮'),('growth_minor_sources','血量 / 共鸣 / 负荷成长来源'),('quest_equipment_rewards','NPC任务装备来源')]
    for key,title in groups:
        rr=[]
        for a in D['collectibles'][key]:
            rr.append([a.get('id',a.get('reward_id','')),a.get('name',a.get('kind','')),a.get('room_id','')+' / '+section(a),req(a.get('requires')),a.get('source',a.get('interaction',''))])
        rows_pages(title,'每个ID是唯一领取来源；跨房、死亡、读档与休息均不复制',['ID','内容','位置/分区','条件','来源'],[19,22,24,23,12],rr,'收集来源',9.8,6)
    rewards=[]
    for group in [D['collectibles']['gear_milestone_rewards'],D['collectibles']['growth_minor_sources'],D['weapon_major_rewards']]:
        for a in group:
            if a.get('source')=='gear_delivery':
                threshold=max(int(t.split('>=')[1]) for c in a['requires'] for t in c if t.startswith('delivered_gears>='))
                rewards.append((threshold,a))
    rr=[[str(n),a['id'],a['name'],a['room_id']+' / '+section(a)] for n,a in sorted(rewards,key=lambda x:x[0])]
    rows_pages('时间齿轮交付里程碑','钟外小站累计交付；后续里程碑不扣掉前面已经交过的齿轮',['累计枚数','奖励ID','奖励','领取位置'],[13,22,42,23],rr,'收集来源',10.5,7)
    rr=[[a['id'],a['room_id']+' / '+section(a),a['description'],req(a['requires']),', '.join(a['grants'])] for a in D['quests']]
    rows_pages('NPC任务目标与永久记录','目标动作与领取奖励分别保存；对白可以后写，完成条件和位置保留',['任务动作','位置/分区','玩家实际要做什么','条件','写入进度'],[25,20,29,14,12],rr,'NPC任务',9.6,8)


def story():
    _,ax=U.page('世界灾变与两种结局','地区美术、修钟、核心材料和主线探索围绕同一因果组织','修钟与剧情')
    U.card(ax,0,14,48,28,'灾变的原因','王希望让国民长生，听信某个神的建议，\n尝试控制世界钟心。王反受控制，灾变破坏世界，\n不同地区出现加速、缓时和停时。\n前期先让玩家理解王的善意，再逐步揭露代价。',U.GOLD)
    U.card(ax,52,14,48,28,'贯穿探索的工作','修复地区时钟，取回根/冰/熔火三枚核心材料，\n由地方的异常追索世界钟心失序的原因。\n能力和道具分别打开新地形与实体门；\n修钟主要恢复视听节律并便利已走过的路线。',U.TEAL)
    U.card(ax,0,47,48,28,'普通结局','完成三核安装、钟心前置与王战等既定条件。\nA/B是两种已重放的普通路线，深入12/14区。\n普通结局不要求全部地区、全部Boss或全收集；\n结束后保留进度，继续完成遗漏的真线内容。',U.BLUE)
    U.card(ax,52,47,48,28,'真结局','深入16区，修复15地方钟，取得16深部记录，\n获得断契棱针，并完成神的终局事件。\n不要求先普通结局，也不要求22Boss全清；\n40齿轮尾声和装备全收集是独立完成目标。',U.TEAL)
    U.section_note(ax,'施工时怎样落位','修钟台、核心取得、安装台、记录、Boss胜利、剧情钥匙和结局演出各有独立永久事件。触发演出前提交收据；死亡不清除已经完成的世界修复。',82)


def clocks():
    rows=[]
    for a in D['clock_repairs']:
        rr=REG[a['region']]
        rows.append([a['region']+' '+rr['name'],a['room_id']+' / '+section(a),req(a.get('requires')),rr.get('time_state',''),rr.get('clock_repair',a.get('environment_change',''))])
    rows_pages('15个地区钟：修复前与修复后','主要反馈为美术、BGM与时间现象；通行侧打开捷径、便利旧路，挑战房保留',['区域','修钟位置','条件','修复前','修复后'],[18,21,18,21,22],rows,'修钟与剧情',9.8,8)
    rows=[]
    for a in D['central_clock_operations']:
        rows.append([a.get('action_id',a['id']),a.get('name',''),a.get('room_id','')+' / '+section(a),req(a.get('requires')),', '.join(a.get('grants',[]))])
    rows_pages('世界钟心与结局操作','中央装核、终局状态与地方修钟分别记录',['动作','内容','位置/分区','条件','结果'],[18,18,21,29,14],rows,'修钟与剧情',9.7,10)


def bosses():
    rows=[]
    for b in D['boss_plan']['bosses']:
        c=CR[b['room_id']];arena=c.get('boss_arena',{})
        archetype=arena.get('archetype','')
        rows.append([b['name'],b['room_id'],{'normal_required':'普通必经','true_required_optional_normal':'真线必经/普通可选','true_final':'真结局终战','fully_optional':'完全可选'}.get(b.get('ending_class'),b.get('ending_class','')),req(b.get('combat_mobility_requirements',b.get('encounter_requirements'))),b['primary_reward']['reward'],ARENAS.get(archetype,archetype),short(arena.get('combat_bounds_world_units',''))])
    rows_pages('22场Boss与大奖励','场地工作值按特色分型；数值与招式仍需实测，胜利/奖励使用独立永久收据',['Boss','房间','路线职责','最低动作配置','主要奖励','场地类型','竞技区候选'],[16,11,12,15,20,13,13],rows,'Boss与场地',9.5,8)
    _,ax=U.page('战斗标定的共同参照','一枪是一次完整攻击；安全窗口通常2枪，第3枪承担贪刀风险','Boss与场地')
    U.table(ax,['类别','第一轮候选','说明'],[24,26,50],[
        ['最简单普通敌人','9HP','攻击5时2枪，首次升至9后1枪'],
        ['轻量Boss','18-28次普通枪命中','短守卫战与轻量支线'],
        ['标准Boss','36-48次普通枪命中','约18-24个两枪输出窗口'],
        ['较长关键战','48-64次普通枪命中','需要阶段变化支撑，不用于所有后期Boss'],
        ['40次命中举例','200 / 360 / 520 / 680 / 840HP','分别对应预期攻击5/9/13/17/21；不是随玩家自动变血'],
        ['三连 / 激光','完整单目标1.5B','一枪总预算；不逐弹/逐tick重复发整份伤害']
    ],min_row=10,size=11)
    U.section_note(ax,'参考范围','《空洞骑士》社区数据仅作普通流程血量与命中数参照；不同阶段、独立血池及神居数据分开。完整来源与解释见设计规则文件。',84)


def memories_shortcuts():
    rows=[]
    for m in D['memory_gates']:
        rows.append([m['id'],m['preview_room']+' / '+section(m),m['landmark'],m.get('unlock_label',''),m.get('return_reason',''),m.get('reward_action','')])
    rows_pages('12个可记住的能力阻隔','抵达可观察分区才记住地标；获得能力后只提示已见位置',['ID','观察位置','地标','能力','回访理由','后续回报'],[9,24,24,8,21,14],rows,'捷径与回访',10,7)
    rows=[]
    for s in D['shortcuts']:
        rows.append([s['id'],s.get('name',''),s['a']+' ↔ '+s['b'],s.get('open_from_room','')+' / '+section(s),req(s.get('open_requires')),req(s.get('requires_after_open')),str(s.get('saved_room_transitions',''))])
    rows_pages('26条永久捷径','从指定一侧实际开通；开后双向。表中节省房数为结构参照，不是秒数',['ID','名称','连接','首次开关位置','开关条件','开后条件','省房数'],[10,21,22,18,11,11,7],rows,'捷径与回访',9.2,8)
    rows=[]
    for r in D['rooms']:
        if r.get('rest_point') or r.get('rift_machine'):
            rows.append([r['id'],r['name'],'休息' if r.get('rest_point') else '-', '裂缝' if r.get('rift_machine') else '-',str(r.get('rest_section_id',r.get('rest_section','main'))),r.get('rest_position','安全平台')])
    rows_pages('休息与裂缝位置','休息点40处；裂缝16处。走到地点与实际休息/激活分别处理',['房间','名称','休息','交通','所在分区','位置意图'],[12,20,9,9,20,30],rows,'休息与交通',10,7)


def region_pages():
    for code,reg in REG.items():
        fig,ax=U.page(reg['name']+' · 区域开发卡',code+' / '+reg.get('time_state',''), '区域地图与职责')
        im=Image.open(R/f'maps/region-{code}-v04.png')
        a=fig.add_axes([.04,.32,.63,.53]);a.imshow(im);a.axis('off')
        x=70
        y=15
        y=U.para(ax,x,y,29,'玩法：'+reg.get('play',''),11)+3
        y=U.para(ax,x,y,29,'前后半：'+reg.get('split',''),11)+3
        y=U.para(ax,x,y,29,'修钟：'+reg.get('clock_repair',''),11)+3
        U.para(ax,x,y,29,'剧情：'+reg.get('story',''),11)
        names=[r['id']+' '+r['name'] for r in D['rooms'] if r['region']==code]
        U.section_note(ax,'房间索引',' / '.join(names),80,U.BLUE)
    for code,reg in REG.items():
        rows=[]
        for r in D['rooms']:
            if r['region']!=code:continue
            c=CR[r['id']];g=c.get('world_geometry',{});dif=c.get('difficulty',{});cam=c.get('camera',{})
            bb=g.get('bounds_world_units',[])
            dim=(str(bb[-2])+' × '+str(bb[-1])) if isinstance(bb,list) and len(bb)>=4 else short(bb)
            routes=c.get('internal_routes',r.get('internal_routes',[]))
            route_text='\n'.join(x.get('from_section','')+' → '+x.get('to_section','')+': '+req(x.get('requires')) for x in routes)
            if not route_text:route_text='单主体区，自由连通'
            door_text=' / '.join(x.get('id',x.get('door_id',''))+'→'+x.get('target_room',x.get('to_room','')) for x in c.get('doors',[]))
            shape=g.get('shape_class',r.get('shape',''))
            rows.append([r['id']+'\n'+r['name'],r.get('purpose',''),dim+'\n'+SHAPES.get(shape,shape),CAM.get(cam.get('profile'),cam.get('profile',''))+'\nC'+str(dif.get('main_C','?'))+' / T'+str(dif.get('main_T','?')),route_text,norm_interactions(r['id'])+'\n'+door_text])
        rows_pages(reg['name']+' · 逐房施工摘要','工作尺寸可校准；入口落脚和详细门/出生点坐标见同ID的逐房JSON',['房号/名称','职责','世界单位候选','镜头/压力','房内通路','关键内容与门'],[13,21,12,14,20,20],rows,'逐房施工摘要',9.3,9)


def validation():
    rows=[]
    for ch in STATUS.get('checks',[]):
        rows.append([ch.get('id',''),ch.get('name',''),ch.get('status',''),ch.get('evidence','')])
    rows_pages('结构交接验收','结论只覆盖列出的自动/静态检查，操作手感与战斗不能由图验证替代',['编号','检查','结果','证据'],[9,33,12,46],rows,'验证与边界',10.1,7)
    _,ax=U.page('开发边界与变更规则','保留稳定ID，控制修改范围；不需要先补完所有细节才开始结构开发','验证与边界')
    U.table(ax,['当前交付覆盖','后续开发中完成'],[49,51],[
        ['全部房间、分区、跨房接口和内部能力路线','实际碰撞地形、跳距、机关时机、门落脚最终坐标'],
        ['22Boss位置、奖励、最低动作配置、场地候选','每场Boss动作、节奏、HP与实战镜头'],
        ['NPC、收集来源、唯一收据和服务关系','50装备最终效果映射、商店价格、任务对白与经济'],
        ['15地区钟、中央装核、普通/真结局事件','修钟前后美术、BGM混音、环境机关的具体表现'],
        ['四类镜头职责、参考视口与候选尺寸','实际zoom、跟随速度、前瞻和移动端可读性'],
        ['自动状态图、路线和永久结果一致性','真人首次理解、自然记忆、重试疲劳和完整体验']
    ],min_row=10,size=11)
    U.section_note(ax,'开工口径','本版允许开始全世界结构灰盒，包含可走占位与真实条件。开发先做共享基础样房，再铺开房间场景；不能将候选数值直接宣称为实机完成。',85)


def main():
    cover()
    _,toc_ax=U.page('阅读导航','先看开工说明与规则；区域图和逐房摘要供实施时查阅','目录')
    governance();rules();camera();difficulty()
    for title,fn,sub in [
        ('世界开发总图','world-room-map-v04.png','位置、主要内容、开局与服务点'),
        ('房间编号总图','world-room-map-numbered-v04.png','房号稳定；轮廓不按统一比例换成场景像素'),
        ('能力预览与回访地标','world-preview-locks-v04.png','标记位于房内可观察空间，普通门本身不锁H/W/D/Q'),
        ('捷径与回访关系','world-shortcuts-v04.png','开关一侧、永久回程与已观察地标')]:plate(title,fn,sub)
    routes();npcs_rewards();collection();story();clocks();bosses();memories_shortcuts();region_pages();validation()
    seen={}
    for p in U.PAGE_META:
        if p['section']!='目录':seen.setdefault(p['section'],p['page'])
    items=list(seen.items());half=math.ceil(len(items)/2)
    toc_rows=[]
    for i in range(half):
        left=items[i];right=items[i+half] if i+half<len(items) else ('','')
        toc_rows.append([left[0],str(left[1]),'',right[0],str(right[1])])
    U.table(toc_ax,['章节','起始页','','章节','起始页'],[40,8,4,40,8],toc_rows,min_row=6.8,size=11)
    out=R/'world-development-atlas-v07.pdf'
    with PdfPages(out) as pdf:
        for fig in U.PAGES:pdf.savefig(fig,facecolor=U.BG)
    try:
        import fitz
        doc=fitz.open(out);doc.set_toc([[1,k,v] for k,v in seen.items()]);doc.set_metadata({'title':'失序之钟 世界结构灰盒交接 v04','author':'世界规划','subject':'完整结构资料与逐房开发摘要'})
        tmp=out.with_suffix('.bookmarked.pdf');doc.save(tmp);doc.close();tmp.replace(out)
    except ImportError:pass
    (R/'qa').mkdir(exist_ok=True)
    (R/'qa/atlas-pages-v07.json').write_text(json.dumps(U.PAGE_META,ensure_ascii=False,indent=2))
    print(json.dumps({'pdf':str(out),'pages':len(U.PAGES),'bytes':out.stat().st_size,'sections':seen},ensure_ascii=False))
    plt.close('all')

if __name__=='__main__':main()
