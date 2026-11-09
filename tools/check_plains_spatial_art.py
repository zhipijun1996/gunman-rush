"""Validate immutable AI originals and measured runtime sprite regions."""
import hashlib,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
pack=ROOT/'assets/plains_v4/spatial'
m=json.loads((pack/'manifest.json').read_text())
assert m['generator']=='OpenAI image_gen.imagegen' and m['source_unchanged']
for source in m['sources']:
    p=pack/source['file'];im=Image.open(p)
    assert hashlib.sha256(p.read_bytes()).hexdigest()==source['sha256']
    assert list(im.size)==source['size'] and im.mode==source['mode']
    assert (ROOT/source['reference']).is_file()
    assert 'compress/mode=1' in Path(str(p)+'.import').read_text()
    if source['file']=='actors.png':
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()[0]==0
        for key,(x,y,w,h) in m['regions'].items():
            assert x>=0 and y>=0 and w>0 and h>0 and x+w<=im.width and y+h<=im.height,key
            assert im.getchannel('A').crop((x,y,x+w,y+h)).getextrema()[1]>0,key
# The spatial chassis remains an immutable historical source. PR122 replaced
# its Boss consumer with the articulated rig; do not require that old body live.
assert m['mini_chassis']['source']=='chassis.png' and m['mini_chassis']['source_pixels_unchanged']
bell_presentation=(ROOT/'game/bosses/bellstrider/bellstrider_presentation.gd').read_text()
assert 'bellstrider_rig.tscn' in bell_presentation
for name in ('arch','bell','chassis','front_wheel','rear_wheel','cannon'):
    assert (ROOT/'assets/plains_boss_rigs_142'/f'bellstrider_{name}.png').is_file()
bell_scene=(ROOT/'scenes/bosses/bellstrider.tscn').read_text()
assert '[ext_resource type="Script" path="res://game/bosses/bellstrider/bellstrider_presentation.gd" id="4"]' in bell_scene
assert '[node name="Presentation" type="Node2D" parent="." node_paths=PackedStringArray("encounter")]\nscript = ExtResource("4")\nencounter = NodePath("../Encounter")' in bell_scene
assert 'chassis.svg' not in (ROOT/'game/bosses/bellstrider/bellstrider_presentation.gd').read_text()
assert 'spatial/actors.png' in (ROOT/'game/combat/projectiles/player_projectile.gd').read_text()
assert 'spatial/actors.png' in (ROOT/'game/enemies/presentation/enemy_presentation.gd').read_text()
assert 'smoothstep' in (ROOT/'game/presentation/world/art/plains_depth.gdshader').read_text()
print('PASS: immutable spatial originals (including historical chassis), alpha, 4 measured regions, player/drone source references and current Bell rig scene binding; runtime and subjective style require separate review.')
