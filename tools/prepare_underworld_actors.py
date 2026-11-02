"""Organize genuine generated RGBA sprites; crop/nearest resize only, no repaint."""
from pathlib import Path
import hashlib
import json
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/underworld_plains/actors'

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    recipes = []
    groups = [('source_enemies.png',['patrol','hopper','charger','aerial','sentry','root_bell'],40,None),
              ('source_bosses.png',['bellstrider'],128,[0]),
              ('source_items.png',['merchant','chest','coin','heart','door','bell'],48,None),
              ('source_windkeeper_edit.png',['windkeeper'],128,[1])]
    for filename, ids, limit, selected in groups:
        source = Image.open(OUT / filename).convert('RGBA')
        occupied = (np.array(source)[:, :, 3] > 8).any(axis=0)
        starts = np.flatnonzero(occupied & ~np.r_[False, occupied[:-1]])
        ends = np.flatnonzero(occupied & ~np.r_[occupied[1:], False]) + 1
        # Ignore isolated near-transparent generation dust without changing retained pixels.
        spans = [(int(a), int(b)) for a,b in zip(starts, ends) if b-a > 20]
        if selected is not None:
            assert len(spans)==2, (filename,spans)
            spans=[spans[i] for i in selected]
        assert len(spans) == len(ids), (filename, spans)
        for name, (a,b) in zip(ids, spans):
            part = source.crop((a,0,b,source.height))
            py,px = np.where(np.array(part)[:,:,3] > 8)
            bounds = (int(px.min()),int(py.min()),int(px.max()+1),int(py.max()+1))
            part = part.crop(bounds)
            scale = limit / max(part.size)
            size = tuple(max(1, round(v*scale)) for v in part.size)
            part = part.resize(size, Image.Resampling.NEAREST)
            part.save(OUT / (name+'.png'))
            recipes.append({'id': name, 'source': filename, 'source_region': [a+bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]], 'operation': 'RGBA crop at alpha>8 bounds then nearest resize; retained RGBA unchanged before resizing, no recolor or repaint', 'output_size': list(size), 'sha256': hashlib.sha256((OUT/(name+'.png')).read_bytes()).hexdigest()})
    (OUT/'actors_build.json').write_text(json.dumps({'schema':'underworld-actors-v1','recipes':recipes,'consumer_scripts':['game/presentation/actors/underworld_plains/underworld_actors.gd','game/presentation/actors/underworld_plains/underworld_enemy.gd'], 'animation_scope':'state-driven pose, squash, stride and overlay; not a complete painted frame animation set'},indent=2)+'\n')

if __name__ == '__main__':
    main()
