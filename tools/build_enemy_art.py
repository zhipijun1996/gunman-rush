#!/usr/bin/env python3
"""Rebuild original demo enemy SVG assets; no network or image dependencies."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/enemies/plains'
INK, BRASS, IVORY = '#292b29', '#a68143', '#e7dec4'

def wrap(body):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#d3b16b"/><stop offset=".5" stop-color="#9c7940"/><stop offset="1" stop-color="#554b35"/></linearGradient><linearGradient id="shell" x2="0" y2="1"><stop stop-color="#f0e6cd"/><stop offset="1" stop-color="#aaa78c"/></linearGradient></defs>
<g stroke="{INK}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>'''

def body(dead=False):
    return f'''<g id="body"><path d="M32 54 39 41 54 35 74 35 89 41 96 54 101 70 94 86 77 94 51 94 34 86 27 70Z" fill="url(#metal)"/>
<path d="M38 52 47 42 64 39 82 44 92 56 87 64 41 64Z" fill="url(#shell)"/>
<path d="M29 68 38 66 39 80 30 78ZM90 66 99 68 98 78 89 80Z" fill="{BRASS}"/>
<path d="M40 82 47 99 53 85 60 104 66 87 73 103 80 85 86 98 91 80" fill="{IVORY}"/>
<path d="M42 55 52 51M77 51 87 55" stroke="#685d40"/>
<circle cx="36" cy="73" r="3" fill="#d7b76a"/><circle cx="94" cy="73" r="3" fill="#d7b76a"/>
<path d="M47 89 55 91M73 91 82 88" stroke="#eee1b4"/>
{('<path d="M57 39 61 48 55 56 65 64 60 74" fill="none"/>' if dead else '')}</g>'''

def rotor(angle=0):
    return f'''<g id="rotor"><path d="M60 37V27H68V37" fill="{BRASS}"/><g transform="rotate({angle} 64 25)"><path d="M13 23 50 19 62 23 115 21 112 28 77 31 64 27 16 30Z" fill="url(#metal)"/><path d="M18 25 48 23M79 25 108 25" stroke="#efe2b7" stroke-width="2"/></g><circle cx="64" cy="25" r="6" fill="{IVORY}"/></g>'''

def eye(state='idle'):
    color = '#fff2ba' if state=='hit' else '#ff713d'
    pupil = '<path d="M55 64 73 76M73 64 55 76" stroke="#8a4f37"/>' if state=='dead' else '<path d="M57 70 63 62 72 70 63 78Z" fill="#ffefbf" stroke="#8a3529" stroke-width="2"/>'
    return f'''<g id="eye"><path d="M43 67 49 59 79 59 86 67 81 79 48 79Z" fill="#322f29"/><path d="M49 68 53 64 76 64 80 68 76 75 53 75Z" fill="{'#655946' if state=='dead' else color}" stroke-width="2"/>{pupil}</g>'''

def target(state):
    color={'active':'#e39c45','hit':'#fff5d5','dead':'#776e59'}[state]
    return f'''<g id="target"><path d="M57 79H71V105H57Z" fill="url(#metal)"/><path d="M37 108 45 101H83L91 108V116H37Z" fill="url(#metal)"/><path d="M34 36 45 24 83 24 95 36V74L83 86H45L34 74Z" fill="url(#shell)"/><path d="M41 38 49 31H79L88 39V70L79 79H49L41 70Z" fill="#514c39"/><circle cx="64" cy="55" r="20" fill="{color}"/><circle cx="64" cy="55" r="12" fill="none" stroke="#5a4931"/><path d="M64 32V43M64 67V78M41 55H52M76 55H87" stroke="#f3e7bf"/>{('<path d="M48 39 80 71M80 39 48 71" stroke="#4f483b" stroke-width="5"/>' if state=='dead' else '<circle cx="64" cy="55" r="4" fill="#5a4931"/>')}</g>'''

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    art = {
        'patrol_drone_idle':body()+rotor()+eye(),
        'patrol_drone_patrol':body()+rotor(9)+eye(),
        'patrol_drone_patrol_alt':body()+rotor(-9)+eye(),
        'patrol_drone_hit':body()+rotor()+eye('hit')+'<path d="M23 50 14 42M104 53 114 44M106 84 117 89" stroke="#f8d88a" stroke-width="4"/>',
        'patrol_drone_dead':body(True)+rotor(18)+eye('dead'),
        'patrol_drone_body':body(),
        'patrol_drone_rotor':rotor(),
        'patrol_drone_eye':eye(),
        'patrol_drone_telegraph_reserved':body()+rotor()+eye()+'<path d="M15 72 10 64 15 56M113 56 118 64 113 72" fill="none" stroke="#ef693b" stroke-width="4"/>',
        'training_target_active':target('active'),
        'training_target_hit':target('hit'),
        'training_target_dead':target('dead'),
        'health_pip_full':'<path d="M64 42 82 64 64 86 46 64Z" fill="#ed7548"/><path d="M64 51 73 63" stroke="#fff0c2"/>',
        'health_pip_empty':'<path d="M64 42 82 64 64 86 46 64Z" fill="#514b3f" stroke="#9c8b65"/>',
    }
    entries=[]
    for name, shape in art.items():
        svg=wrap(shape)
        ET.fromstring(svg)
        (OUT/f'{name}.svg').write_text(svg+'\n')
        entries.append({'asset_id':f'enemies.plains.{name}','path':f'assets/enemies/plains/{name}.svg','width':128,'height':128,'pivot_px':[64,64],'transparent':True,'collision':'owned_by_gameplay_scene; do_not_derive_from_alpha','layer_group':name if name in ['patrol_drone_body','patrol_drone_rotor','patrol_drone_eye'] else None,'reserved':name.endswith('reserved'),'provenance':{'method':'AI-authored procedural SVG','generator':'tools/build_enemy_art.py','reference':'assets/characters/courier/source/master.png','license':'project-original'}})
    (OUT/'manifest_fragment.json').write_text(json.dumps({'schema_version':1,'assets':entries},ensure_ascii=False,indent=2)+'\n')
    print(f'Validated {len(entries)} XML SVG assets and manifest; 128 x 128, center pivot.')

if __name__=='__main__':
    main()
