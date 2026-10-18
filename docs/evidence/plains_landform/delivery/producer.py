#!/usr/bin/env python3
"""Bind the existing strict joint producer to the environment-first candidate."""
from pathlib import Path
import hashlib
import json
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[4]
PRIOR = ROOT / 'docs/evidence/plains_joint_recoil/delivery/producer.py'
prior = {'__name__': '_retained_joint_binding', '__file__': str(Path(__file__).resolve())}
exec(compile(PRIOR.read_text(), str(PRIOR), 'exec'), prior)
source = prior['source']


def bind(old, new):
    global source
    if old not in source:
        raise RuntimeError('Preserved strict producer interface changed: ' + old)
    source = source.replace(old, new)


bind('resources/visual_development/p1_joint_recoil_assets.json',
     'resources/visual_development/p1_landform_assets.json')
bind('build/plains_joint_recoil', 'build/plains_landform')
bind('plains-joint-recoil-failed-v4-linux-x86_64', 'plains-landform-candidate-linux-x86_64')
bind('Failed v4 joint recoil art candidate (REWORK), golden not admitted; actual full first-region runtime with one bounded experimental challenge; startup package proof, not whole-region art or route acceptance',
     'Environment-first ridge and paired-creek candidate, golden not admitted; actual full first-region runtime with bounded experimental construction; startup package proof, not whole-region art or route acceptance')
bind('风铃平原单挑战 v4 失败候选评审', '风铃平原联合地貌候选评审')
bind("'art_verdict': 'REWORK'", "'art_verdict': 'NOT_ADMITTED'")
bind('艺术独审REWORK，黄金未准入。默认joint-recoil-01；这是完整第一张随机地图中的单个反冲挑战实验，非完整地区美术完成。录像另证真实8段路线，不代表本包启动测试已重放路线。候选停止扩产；正常角色和操作保留，这是失败候选手动试玩',
     '黄金未准入。默认joint-recoil-01；完整第一张随机地图中联合设计上层岩脊裂隙与下层渡船溪洞，其他构造仍有旧实现，非完整地区美术完成。录像另证真实8段路线；包启动测试未重放路线。正常角色和操作保留，这是可逆候选手动试玩')
bind("if not out.is_relative_to(ROOT / 'build/plains_landform') or out.exists():",
     "if not (out.is_relative_to(ROOT / 'build/plains_landform') or (out.parent.parent == Path(tempfile.gettempdir()).resolve() and out.parent.name.startswith('plains-landform-review-') and out.parent.is_dir() and out.name == 'delivery')) or out.exists():")
bind("        if len(collisions) != 2 or any(",
     "        expected_modules = expected['art_plan']['joint_modules']\n        expected_body_count = sum(len(m['terrain_bodies']) for m in expected_modules)\n        expected_owned_count = len(expected_modules[0]['region_context']['owned_slabs'])\n        if len(collisions) != expected_body_count or any(")
bind("            if len(replaced) != 3 or any(",
     "            if len(replaced) != expected_owned_count or any(")
bind('Packed joint original three slabs are not disabled',
     'Packed source-owned original slabs are not disabled')
bind("        if len(actual.get('art',{}).get('joint_terrain',[])) != 2 or actual['art']['joint_terrain'] != expected_art['joint_terrain']:",
     "        for field in ('joint_rear_walls','joint_rear_openings','joint_structural_pieces'):\n            if not expected_art.get(field) or actual.get('art',{}).get(field) != expected_art[field]:\n                raise ValueError('Packed actual environmental consumer differs: ' + field)\n        if len(actual.get('art',{}).get('joint_terrain',[])) != expected_body_count or actual['art']['joint_terrain'] != expected_art['joint_terrain']:")
namespace = {'__name__': '_landform_pack_producer', '__file__': str(Path(__file__).resolve()), 'tempfile': tempfile}
exec(compile(source, str(prior['BASE']), 'exec'), namespace)
# Keep the original joint smoke's actual decoration-collision readback.
namespace['SMOKE'] = prior['namespace']['SMOKE']
if __name__ == '__main__':
    print(json.dumps({'shared_producer': str(prior['BASE'].relative_to(ROOT)),
                      'shared_sha256': hashlib.sha256(prior['BASE'].read_bytes()).hexdigest(),
                      'retained_joint_binding': str(PRIOR.relative_to(ROOT)),
                      'retained_joint_sha256': hashlib.sha256(PRIOR.read_bytes()).hexdigest(),
                      'scope': 'Candidate landform; original strict PCK/source/GUI/headless/audio/cleanup checks retained; temporary output only in a dedicated newly created review directory'}))
    raise SystemExit(namespace['main']())
