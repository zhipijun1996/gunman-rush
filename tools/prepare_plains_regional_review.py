#!/usr/bin/env python3
"""Reuse the preserved strict pack producer with actual complete-region bindings."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
BASE = ROOT / 'docs/evidence/p1_environment/delivery/producers/prepare_local_review_bundle.py'
source = BASE.read_text()
bindings = {
    "ROOT = Path(__file__).resolve().parents[2]": "ROOT = Path(__file__).resolve().parents[1]",
    'tools/plains_environment_preview.gd': 'tools/plains_regional_art_preview.gd',
    'tools/plains_environment_capture.gd': 'tools/plains_regional_art_capture.gd',
    'resources/visual_development/p1_environment_assets.json': 'resources/visual_development/p1_regional_assets.json',
    'PLAINS ENVIRONMENT REVIEW READY: ': 'PLAINS REGIONAL ART REVIEW READY: ',
    'PLAINS ENVIRONMENT AVATAR READY: ': 'PLAINS REGIONAL ART AVATAR READY: ',
    'build/plains_environment': 'build/plains_regional_art',
    'plains-environment-candidate-linux-x86_64': 'plains-regional-candidate-linux-x86_64',
    'Failed whole-environment art candidate (REWORK), golden not admitted; local manual review only, not formal release or artistic/user/device acceptance': 'Experimental complete randomized region; local manual review only, not golden, formal release, user preference, commercial or device acceptance',
    '风铃平原整体环境失败候选评审': '风铃平原完整随机区域候选评审',
    '完整空间艺术独审结论为REWORK，黄金未准入；本轮已停止当前端肩接法，没有扩不同结构或多Seed。这是原样失败候选手动试玩': '这是完整正式拓扑上的联合美术候选，艺术黄金未准入；默认regional-art-01，可加--seed=regional-art-02。真实整区路线与艺术独审另见本轮报告。本包是同冻结源的手动试玩',
    '游戏资产沿原项目来源，不新增商店发布授权': '新图像模型与商用许可未知，保留源与派生记录，不声称获得商店发行授权',
}
for old,new in bindings.items():
    if old not in source:
        raise RuntimeError('Preserved strict producer interface changed: '+old)
    source=source.replace(old,new)
old = """        if actual.get('environment_plan') != native['manifest']['environment_plan'] or actual.get('manifest_hash') != native['manifest_hash']:
            raise ValueError('Packed real environment differs from captured shared plan')
        if actual.get('production_pool') is not False or not actual.get('solid_polygons') or not actual.get('saws'):
            raise ValueError('Packed real environment consumer incomplete')
        expected_art = native['environment_initial_physics']['art']
        for key in ('catalog_path', 'catalog_sha256', 'plan_contract_sha256'):"""
new = """        expected = native['regional_art_initial']
        if actual.get('art_plan') != expected['art_plan'] or actual.get('manifest_hash') != native['manifest_hash']:
            raise ValueError('Packed full region differs from captured shared plan')
        if actual.get('production_pool') is not False or actual.get('ready') is not True or actual.get('art_plan', {}).get('layout_source') != 'formal_full_region':
            raise ValueError('Packed full-region art consumer incomplete')
        for key in ('actual_modules', 'actual_enemies', 'actual_chests', 'actual_boss'):
            if not expected.get(key) or actual.get(key) != expected[key]:
                raise ValueError('Packed actual full-region gameplay consumer differs: ' + key)
        expected_art = expected['art']
        for key in ('catalog_path', 'catalog_sha256', 'plan_hash'):"""
if source.count(old)!=1:
    raise RuntimeError('Preserved actual-consumer interface changed')
source=source.replace(old,new)
namespace={'__name__':'_regional_pack_producer','__file__':str(Path(__file__).resolve())}
exec(compile(source,str(BASE),'exec'),namespace)
# Seed is the actual root input, not a cosmetic label. CLI may override manual play.
namespace['SMOKE']=namespace['SMOKE'].replace('\tawait super.run()','\treview_seed = "regional-art-01"\n\tawait super.run()',1)
namespace['PLAY']=namespace['PLAY'].replace(' -- "$@"',' -- --seed=regional-art-01 "$@"')
if __name__=='__main__':
    print(json.dumps({'shared_producer':str(BASE.relative_to(ROOT)),'sha256':hashlib.sha256(BASE.read_bytes()).hexdigest(),'bindings':bindings,'checks':'Original byte-exact PCK, source/capture, empty-cwd GUI/headless, raw resource closure, logs/audio/teardown preserved; only actual regional snapshot fields rebound.'}))
    raise SystemExit(namespace['main']())
