"""Reproduce mechanical native baking; all authored pixels originate in imagegen.
No painting, edge synthesis, compositing or background removal occurs here.
"""
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/art_rule_trial'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    inputs = json.loads((ASSETS/'source/generation.json').read_text())
    manifest = {'review_status': 'candidate', 'scope': 'isolated static Node2D trial; not user-approved or formal gameplay', 'viewport': [1280,720], 'assets': []}
    for item in inputs['generations']:
        target = ASSETS/'source'/item['file']
        original = Path(item['source'])
        if not target.exists():
            if not original.exists():
                raise SystemExit(f'Restore original generation to {target} before baking')
            shutil.copyfile(original, target)
        source = Image.open(target)
        record = {'source': 'source/'+item['file'], 'source_size': list(source.size), 'source_sha256': sha(target), 'role': item['kind']}
        if item['file'] in ('aqueduct.png','environment.png'):
            # Both sources are1672x941. A uniform width ratio160/209 has height
            # 720.38, rounded to720 pixels. Never independently fit silhouettes.
            width = 1280
            height = round(source.height*width/source.width)
            assert height == 720, 'Review camera/aspect before changing native footprint'
            baked = source.resize((width,height),Image.Resampling.NEAREST).convert('RGBA')
            if item['file'] == 'aqueduct.png':
                baked.putdata([(r,g,b,255) if a>=128 else (0,0,0,0) for r,g,b,a in baked.getdata()])
                alpha = baked.getchannel('A')
                assert alpha.getextrema() == (0,255)
                record['alpha'] = 'binary >=128; transparent RGB zero; authored opacity only'
            native = ASSETS/'native'/item['file']
            baked.save(native)
            record.update(native='native/'+item['file'],native_size=list(baked.size),native_sha256=sha(native),bake='one nearest width-ratio160/209; height rounded to720')
        manifest['assets'].append(record)
    (ASSETS/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Native baking: 2 independent layers; concept is never a runtime asset')

if __name__ == '__main__':
    main()
