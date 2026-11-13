"""Mechanically bake the production painting; never redraw or separate pixels.
The complementary rendering masks originate in Godot before generation.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT/'assets/engine_first_2d'
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    source = ASSETS/'source/painting.png'
    image = Image.open(source)
    width = 1280
    height = round(image.height*width/image.width)
    assert height == 720, 'Review aspect/camera before baking'
    native = image.resize((width,height),Image.Resampling.NEAREST).convert('RGBA')
    native.save(ASSETS/'native/painting.png')
    mask = Image.open(ASSETS/'native/structure-mask.png')
    assert mask.size == native.size
    manifest = {
        'review_status':'candidate',
        'scope':'fixed-camera engine-first2D representative; not a general modular art library',
        'source':{'file':'source/painting.png','size':list(image.size),'sha256':sha(source)},
        'native':{'file':'native/painting.png','size':list(native.size),'sha256':sha(ASSETS/'native/painting.png'),'bake':'single uniform width ratio; rounded height; nearest'},
        'structure_mask':{'file':'native/structure-mask.png','sha256':sha(ASSETS/'native/structure-mask.png'),'origin':'authored Godot geometry before generation'},
        'composition':'same native texture, complementary masks at same coordinates; no independent AI layer redraw',
        'independent_parallax':False,'hidden_background_restored':False,'formal_gameplay_verified':False
    }
    (ASSETS/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Engine-first painting baked; all slices share identical native pixels')
if __name__ == '__main__': main()
