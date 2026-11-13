"""Check measured production-terrain mapping, native density and support in real captures."""
import argparse,json,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--outdoor',action='store_true');args=p.parse_args()
folder=ROOT/'build/depth-lab'
if args.outdoor:folder=folder/'outdoor'
for name in ['capture.json','ortho-capture.json']:
    d=json.loads((folder/name).read_text());assert d['composition_schema']==2
    t=d['terrain'];assert t['renderer']=='TerrainComposer' and t['core_cells']>0 and t['union_edges']>0
    assert t['native_pixels']==t['world_bounds'][2:]
    def png_size(path):return list(struct.unpack('>II',path.read_bytes()[16:24]))
    assert png_size(folder/'terrain-front.png')==t['native_pixels']
    count=0
    for row in d['asset_placement']:
        assert png_size(ROOT/row['path'][6:])==row['size'] and row['world_units_per_pixel']==1,row
        if 'foot' in row:
            assert abs(row['foot'][1]-row['support_y'])<=2,row
            assert [row['foot'][i]-row['anchor'][i]+row['size'][i]/2 for i in range(2)]==row['at'],row
            count+=1
    assert count>=4
    assert d['frames']>=720 and len(d['samples'])==4
    print(name,t['core_cells'],'production cells;',t['union_edges'],'union edges;',count,'native anchored placements')
print('DEPTH LAB CAPTURE CONTRACT: passed')
