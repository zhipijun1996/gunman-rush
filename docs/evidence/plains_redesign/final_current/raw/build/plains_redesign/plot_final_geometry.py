"""Derived static geometry plots from actual native manifests, never gameplay screenshots."""
import argparse,gzip,hashlib,json,re
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
ROOT=Path.cwd()
def sha(data):return hashlib.sha256(data).hexdigest()
def read(path):
 b=path.read_bytes();return json.loads(gzip.decompress(b) if path.suffix=='.gz' else b)
def rects(text,key):
 match=re.search(r'^'+key+r'\s*=\s*([^\n]+)',text,re.M)
 return [[float(v) for v in x.split(',')] for x in re.findall(r'Rect2\(([^)]+)\)',match[1])] if match else []
def vectors(block,key):
 match=re.search(r'^'+key+r'\s*=\s*Vector2\(([^)]+)\)',block,re.M)
 return [float(x) for x in match[1].split(',')] if match else None
def get_geometry(node,sources,project,used):
 assert not node.get('mirrored'), 'Unsupported mirror: refuse misleading projection'
 if 'geometry' in node:return node['geometry']
 rel='resources/generation/modules/'+node['module_id']+'.tres';path=project/rel
 assert path.is_file() and sha(path.read_bytes())==sources[rel], 'Definition source drift/'+rel
 used[rel]=sources[rel];text=path.read_text();section=text.split('[resource]',1)[1]
 match=re.search(r'^one_way_platform_indices\s*=\s*PackedInt32Array\(([^)]*)\)',section,re.M)
 one_way=[int(x) for x in match[1].split(',') if x.strip()] if match else []
 ferries=[]
 for block in re.split(r'\n\[',text):
  a,b=vectors(block,'start'),vectors(block,'finish')
  if a is not None and b is not None:ferries.append({'start':a,'finish':b})
 return {'platforms':rects(section,'platforms'),'one_way':one_way,'ferries':ferries}
def draw(m,obs,sources,project,folder,origin,bounds=None):
 fig,ax=plt.subplots(figsize=(16,9),dpi=100);fig.patch.set_facecolor('#17262a');ax.set_facecolor('#17262a')
 used={};count=0
 for node in m['nodes']:
  geom=get_geometry(node,sources,project,used);ox,oy=node['offset']
  for i,(x,y,w,h) in enumerate(geom['platforms']):
   one=i in geom.get('one_way',[]);ax.add_patch(Rectangle((x+ox,y+oy),w,h,facecolor='#deb97f' if one else '#829a8b',edgecolor='none',zorder=2));count+=1
  for ferry in geom.get('ferries',[]):
   a,b=ferry['start'],ferry['finish'];ax.plot([a[0]+ox,b[0]+ox],[a[1]+oy,b[1]+oy],color='#76c5da',linestyle=':',linewidth=2,zorder=2)
 for x,y,w,h in m['ground_supports']:ax.add_patch(Rectangle((x,y),w,h,facecolor='#586d64',edgecolor='none',zorder=1))
 areas={a['id']:a for a in m['areas']}
 for e in m['connections']:
  ps=e.get('path',[areas[e['a']]['position'],areas[e['b']]['position']]);ax.plot([p[0] for p in ps],[p[1] for p in ps],color='#587477',linestyle='--' if e['condition']!='open' else '-',linewidth=.7,alpha=.8,zorder=0)
 for a in m['areas']:
  x,y=a['position'];ax.scatter(x,y,s=12,color='#e9e5cc',zorder=4)
  label=a['id'] if a['role']=='junction' else a['role']
  ax.text(x,y-70,label,color='#dce5d8',fontsize=6,ha='center',zorder=5)
 for r in m['rewards']:
  x,y=r['position'];ax.scatter(x,y,s=32,marker='D',color='#f1ce70',zorder=6);ax.text(x+35,y-25,r['tier'],fontsize=6,color='#f1ce70')
 for enemy in m['enemies']:
  x,y=enemy['position'];ax.scatter(x,y,s=9,color='#e78782',zorder=5)
 x,y,w,h=m['world_bounds'] if bounds is None else bounds;ax.set_xlim(x-80,x+w+80);ax.set_ylim(y+h+80,y-180);ax.set_aspect('equal');ax.tick_params(colors='#afc0bb',labelsize=7)
 for spine in ax.spines.values():spine.set_color('#465d5e')
 ax.set_title(f"Recorded static geometry | {m['version']} | map {obs['map_index']} | {m['family']}\n{m['seed']}",color='#eee1bd',fontsize=12)
 fig.text(.05,.05,'Solid: grey | one-way: ochre | moving deck range: dotted cyan | reward: gold diamond | enemy SPAWN: red\nNative geometry projection omits textures, fog, GUI, hazard/phases and live enemy state; not a gameplay screenshot or reachability/art approval.',color='#b1c3b8',fontsize=8)
 fig.tight_layout(rect=(.02,.11,.99,.98));name=f"map_{obs['map_index']}_{m['family']}";out=folder/(name+'.png');fig.savefig(out,facecolor=fig.get_facecolor());fig.savefig(folder/(name+'.svg'),facecolor=fig.get_facecolor());plt.close(fig)
 return {'image':str(out.relative_to(ROOT)),'sha256':sha(out.read_bytes()),'manifest_hash':m['manifest_hash'],'seed':m['seed'],'map_index':obs['map_index'],'family':m['family'],'native_observation':obs,'platform_count':count,'used_definition_sources':used,'plot_bounds':list((x,y,w,h)),'origin':origin}
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--receipt',type=Path,required=True);p.add_argument('--project',type=Path,default=ROOT);p.add_argument('--output',type=Path,required=True);a=p.parse_args();folder=a.output.resolve();assert folder.is_relative_to(ROOT/'build') and not folder.exists();folder.mkdir(parents=True)
 d=read(a.bundle);r=read(a.receipt);assert r['status']=='passed' and r['source_before']==r['source_after'];seen=set();rows=[]
 origin={'bundle':str(a.bundle),'bundle_sha256':sha(a.bundle.read_bytes()),'receipt':str(a.receipt),'receipt_sha256':sha(a.receipt.read_bytes()),'source_commit':r['source_commit'],'scope':'Actual final-source native recorded manifests with SHA-checked resource geometry. Static internal projection only, not gameplay/fog/art/physical acceptance.', 'producer_sha256':sha(Path(__file__).read_bytes())}
 for m,o in zip(d['manifests'],d['observations']):
  assert m['manifest_hash']==o['manifest_hash'];key=(o['map_index'],m['family'])
  if key in seen:continue
  rows.append(draw(m,o,r['source_before'],a.project,folder,origin));seen.add(key)
 assert len(rows)==6; (folder/'index.json').write_text(json.dumps({'scope':origin['scope'],'maps':rows},indent=2)+'\n');print('Derived',len(rows),'actual recorded static-geometry maps;',folder)
if __name__=='__main__':main()
