#!/usr/bin/env python3
"""Reconstruct the selected Underworld material from preserved publisher pixels.

No image generation or repainting: crop native quarters and copy losslessly.
--check compares all outputs without writes. Production reads terrain_build.json.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = Path('assets/underworld_plains/terrain')
def sha(data): return hashlib.sha256(data).hexdigest()
def build(check=False):
    recipes = json.loads((ROOT/'assets/style_exploration/anchors.json').read_text())
    anchor = recipes['styles']['underworld']
    data = (ROOT/'assets/style_exploration/underworld/source/TileSet.png').read_bytes()
    assert sha(data) == anchor['source_sha256']
    source = Image.open(io.BytesIO(data)).convert('RGBA')
    atlas = Image.new('RGBA', (128, 96))
    for mask in recipes['masks']:
        tile = Image.new('RGBA', (16,16))
        for patch in anchor['recipes'][str(mask)]:
            x,y,_,_ = patch['destination']
            tile.paste(source.crop(tuple(patch['source'])), (x,y))
        x,y=anchor['mask_to_atlas'][str(mask)]
        atlas.paste(tile, (x*16,y*16))
    stream=io.BytesIO();atlas.save(stream,format='PNG');atlas_data=stream.getvalue()
    assert sha(atlas_data)==anchor['atlas_sha256']
    tres='[gd_resource type="TileSet" format=3]\n\n[ext_resource type="Texture2D" path="res://'+str(OUT/'terrain.png')+'" id="1"]\n\n[sub_resource type="TileSetAtlasSource" id="Atlas"]\ntexture = ExtResource("1")\ntexture_region_size = Vector2i(16, 16)\n'
    for mask in recipes['masks']:
        x,y=anchor['mask_to_atlas'][str(mask)];tres+=f'{x}:{y}/0 = 0\n'
    tres+='\n[resource]\ntile_size = Vector2i(16, 16)\nsources/0 = SubResource("Atlas")\n'
    meta={'schema':'underworld-terrain-build-v1','mode':'blob47_core_with_exact_boundary_adapter','tile_px':16,'world_tile_wu':32,'source_texture':'res://'+str(OUT/'source.png'),'source_sha256':sha(data),'atlas':'res://'+str(OUT/'terrain.png'),'atlas_sha256':sha(atlas_data),'tileset':'res://'+str(OUT/'terrain.tres'),'mask_to_atlas':anchor['mask_to_atlas'],'source_regions':anchor['recipes'],'native_regions':anchor['coords'],'license':'Custom permissive publisher statement; not CC0','license_evidence':'res://assets/style_exploration/underworld/source/licenses/publisher_page.txt','reference_url':'https://asouris.itch.io/underworld-tileset','builder':'tools/build_underworld_terrain.py','consumer_scripts':['game/presentation/world/underworld_plains/underworld_terrain.gd'],'operations':['lossless original-source copy','native 8px quarter crops','47 canonical mask assembly'],'formal_boundary_claim':'Exact union quad clipping with source-native edges/corners; not a complete formal 47-cell TileMap or a collision conversion.'}
    outputs={OUT/'source.png':data,OUT/'terrain.png':atlas_data,OUT/'terrain.tres':tres.encode(),OUT/'terrain_build.json':(json.dumps(meta,ensure_ascii=False,indent=2)+'\n').encode()}
    for rel,content in outputs.items():
        if check: assert (ROOT/rel).read_bytes()==content, str(rel)+' differs'
        else: (ROOT/rel).write_bytes(content)
    print('UNDERWORLD TERRAIN BUILD: 47 native quarter masks reproduced; no repaint; '+('CHECK PASSED (no writes)' if check else 'BUILT'))
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');build(p.parse_args().check)
