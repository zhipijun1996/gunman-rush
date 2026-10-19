#!/usr/bin/env python3
"""Reuse the preserved strict PR82 pack producer with explicit places entry bindings."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
BASE = ROOT / 'docs/evidence/p1_environment/delivery/producers/prepare_local_review_bundle.py'
source = BASE.read_text()
replacements = {
    'tools/plains_environment_preview.gd': 'tools/plains_places_preview.gd',
    'tools/plains_environment_capture.gd': 'tools/plains_places_capture.gd',
    'resources/visual_development/p1_environment_assets.json': 'resources/visual_development/p1_places_assets.json',
    'PLAINS ENVIRONMENT REVIEW READY: ': 'PLAINS PLACES REVIEW READY: ',
    'PLAINS ENVIRONMENT AVATAR READY: ': 'PLAINS PLACES AVATAR READY: ',
    'Failed whole-environment art candidate (REWORK), golden not admitted; local manual review only, not formal release or artistic/user/device acceptance': 'Joint-source candidate: actual shared geometry/composition/consumer experiment; local manual review only, not golden, formal release or user/device/commercial acceptance',
    "'art_verdict': 'REWORK'": "'art_verdict': 'UNVERIFIED'",
    '风铃平原整体环境失败候选评审': '风铃平原共同场所计划候选评审',
    '完整空间艺术独审结论为REWORK，黄金未准入；本轮已停止当前端肩接法，没有扩不同结构或多Seed。这是原样失败候选手动试玩': '本包验证共同场所计划驱动的实际候选，默认places-contract-01；艺术黄金未准入，完整地区、用户画风定稿、设备与商业品质未验证。实机独审和Seed范围见本轮报告。本包是同冻结源码的候选手动试玩',
    '游戏资产沿原项目来源，不新增商店发布授权': '新图像工具未披露模型与商用许可，许可状态unknown；保留来源谱系，不据本包声称商店发行授权',
}
for old, new in replacements.items():
    if old not in source:
        raise RuntimeError('Preserved producer interface changed: ' + old)
    source = source.replace(old, new)
# The shared far texture is declared by the actual resolved-plan recipe.
# Traverse that current JSON root as well; omitted/count/SHA checks stay exact.
closure_old = "pending = ['resources/art/avatars.json', 'resources/visual_development/p1_places_assets.json', 'resources/visual_development/p1_candidate.json']"
closure_new = "pending = ['resources/art/avatars.json', 'resources/visual_development/p1_places_assets.json', 'resources/visual_development/p1_candidate.json', 'resources/generation/environment_grammar/places_v1.json']"
if source.count(closure_old) != 1:
    raise RuntimeError('Preserved producer closure interface changed')
source = source.replace(closure_old, closure_new)
replacements[closure_old] = closure_new
# This evaluates the unchanged strict pack/entry-SHA/empty-cwd/GUI/teardown
# implementation, rather than copying a second producer or weakening gates.
namespace = {'__name__': '_places_pack_producer', '__file__': str(Path(__file__).resolve())}
exec(compile(source, str(BASE), 'exec'), namespace)
# Explicit seed binding: the original shared producer checks this exact plan.
namespace['SMOKE'] = namespace['SMOKE'].replace('\tawait super.run()', '\treview_seed = "places-contract-01"\n\tawait super.run()', 1)
namespace['PLAY'] = namespace['PLAY'].replace(' -- "$@"', ' -- --seed=places-contract-01 "$@"')
replacements['explicit_smoke_and_manual_default_seed'] = 'places-contract-01; user CLI may override manual seed'
if __name__ == '__main__':
    print(json.dumps({'shared_producer': str(BASE), 'shared_producer_sha256': hashlib.sha256(BASE.read_bytes()).hexdigest(), 'explicit_bindings': replacements, 'strict_checks_changed': False}))
    raise SystemExit(namespace['main']())
