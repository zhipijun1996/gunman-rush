#!/usr/bin/env python3
"""Thin binding of the preserved strict local producer to the failed v4 joint candidate."""
from pathlib import Path
import hashlib
import json
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools'))
BASE = ROOT / 'docs/evidence/p1_environment/delivery/producers/prepare_local_review_bundle.py'
source = BASE.read_text()

def bind(old, new):
    global source
    if old not in source:
        raise RuntimeError('Preserved strict producer interface changed: ' + old)
    source = source.replace(old, new)

for old, new in {
    'ROOT = Path(__file__).resolve().parents[2]': 'ROOT = Path(__file__).resolve().parents[4]',
    'tools/plains_environment_preview.gd': 'tools/plains_joint_recoil_preview.gd',
    'tools/plains_environment_capture.gd': 'tools/plains_joint_recoil_capture.gd',
    'resources/visual_development/p1_environment_assets.json': 'resources/visual_development/p1_joint_recoil_assets.json',
    'PLAINS ENVIRONMENT REVIEW READY: ': 'PLAINS JOINT RECOIL REVIEW READY: ',
    'PLAINS ENVIRONMENT AVATAR READY: ': 'PLAINS JOINT RECOIL AVATAR READY: ',
    'build/plains_environment': 'build/plains_joint_recoil',
    'plains-environment-candidate-linux-x86_64': 'plains-joint-recoil-failed-v4-linux-x86_64',
    'Failed whole-environment art candidate (REWORK), golden not admitted; local manual review only, not formal release or artistic/user/device acceptance': 'Failed v4 joint recoil art candidate (REWORK), golden not admitted; actual full first-region runtime with one bounded experimental challenge; startup package proof, not whole-region art or route acceptance',
    '风铃平原整体环境失败候选评审': '风铃平原单挑战 v4 失败候选评审',
    '完整空间艺术独审结论为REWORK，黄金未准入；本轮已停止当前端肩接法，没有扩不同结构或多Seed。这是原样失败候选手动试玩': '艺术独审REWORK，黄金未准入。默认joint-recoil-01；这是完整第一张随机地图中的单个反冲挑战实验，非完整地区美术完成。录像另证真实8段路线，不代表本包启动测试已重放路线。候选停止扩产；正常角色和操作保留，这是失败候选手动试玩',
    '非正式发布、完整地区、艺术定稿或设备认可': '非正式发布、整区美术验收、Boss击败、艺术定稿、真人或设备认可',
    '游戏资产沿原项目来源，不新增商店发布授权': '模型生成源图与编辑关系另存证据；图像模型及商用许可未知，不声称新增商店发行授权',
}.items(): bind(old,new)
# The opt-in consumer extends the regional composer and reads that catalog too.
bind("'resources/visual_development/p1_joint_recoil_assets.json', 'resources/visual_development/p1_candidate.json'", "'resources/visual_development/p1_joint_recoil_assets.json', 'resources/visual_development/p1_regional_assets.json', 'resources/visual_development/p1_candidate.json'")
old = """        if actual.get('environment_plan') != native['manifest']['environment_plan'] or actual.get('manifest_hash') != native['manifest_hash']:
            raise ValueError('Packed real environment differs from captured shared plan')
        if actual.get('production_pool') is not False or not actual.get('solid_polygons') or not actual.get('saws'):
            raise ValueError('Packed real environment consumer incomplete')
        expected_art = native['environment_initial_physics']['art']
        for key in ('catalog_path', 'catalog_sha256', 'plan_contract_sha256'):"""
new = """        expected = native['joint_initial']
        if actual.get('manifest_hash') != native['manifest_hash'] or actual.get('art_plan') != expected['art_plan']:
            raise ValueError('Packed actual joint source plan differs from captured source')
        if actual.get('production_pool') is not False or actual.get('joint_ready') is not True or actual.get('ready') is not True:
            raise ValueError('Packed actual joint consumer not ready')
        for key in ('actual_modules','actual_enemies','actual_chests','actual_boss','joint_collisions'):
            if not expected.get(key) or actual.get(key) != expected[key]:
                raise ValueError('Packed actual consumer differs: ' + key)
        collisions = actual.get('joint_collisions', [])
        if len(collisions) != 2 or any(c.get('build_mode') != 0 or c.get('disabled') or c.get('one_way') or c.get('collision_layer') != 1 for c in collisions):
            raise ValueError('Packed actual joint polygons do not own solid collision')
        for collision in collisions:
            replaced = collision.get('replaced_slabs', [])
            if len(replaced) != 3 or any(s.get('disabled') is not True or s.get('one_way') for s in replaced):
                raise ValueError('Packed joint original three slabs are not disabled')
        if row('JOINT PACK ACTUAL DECOR COLLISIONS: ') != []:
            raise ValueError('Packed art unexpectedly owns physical collision')
        expected_art = expected['art']
        if len(actual.get('art',{}).get('joint_terrain',[])) != 2 or actual['art']['joint_terrain'] != expected_art['joint_terrain']:
            raise ValueError('Packed actual painted mesh differs from captured source')
        for key in ('catalog_path', 'catalog_sha256', 'plan_hash', 'joint_catalog_path', 'joint_catalog_sha256'):"""
bind(old,new)
# Storage only: identical verified PCK bytes, system-temp backing avoids workspace duplication.
bind("        pack = bundle / 'environment-review.pck'", """        pack = bundle / 'environment-review.pck'
        temporary_pack = Path(tempfile.mkdtemp(prefix='gunman-joint-review-')) / 'environment-review.pck'
        pack.symlink_to(temporary_pack)
        receipt['temporary_pack_storage'] = {'logical_path':str(pack),'backing_file':str(temporary_pack),'scope':'Identical verified bytes; ZIP embeds the full PCK, not this symlink'}""")
namespace = {'__name__':'_joint_pack_producer','__file__':str(Path(__file__).resolve()),'tempfile':tempfile}
exec(compile(source,str(BASE),'exec'),namespace)
smoke=namespace['SMOKE']
smoke=smoke.replace('\tawait close_review()', '\tvar decoration_rows: Array=[]\n\tif is_instance_valid(app.stage.regional_art_renderer): _decorations(app.stage.regional_art_renderer,decoration_rows)\n\tprint("JOINT PACK ACTUAL DECOR COLLISIONS: ",JSON.stringify(decoration_rows))\n\tawait close_review()',1)
smoke+='''\nfunc _decorations(node:Node, rows:Array)->void:
\tif node is CollisionObject2D or node is CollisionShape2D or node is CollisionPolygon2D: rows.append({"path":str(node.get_path()),"class":node.get_class()})
\tfor child:Node in node.get_children(): _decorations(child,rows)
'''
namespace['SMOKE']=smoke
if __name__=='__main__':
    print(json.dumps({'shared_producer':str(BASE.relative_to(ROOT)),'sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'binding':'Failed v4 joint recoil candidate only; all original PCK closure, source/capture, empty-cwd GUI/headless, audio and cleanup checks retained'}))
    raise SystemExit(namespace['main']())
