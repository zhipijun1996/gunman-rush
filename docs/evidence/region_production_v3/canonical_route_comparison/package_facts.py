import collections,gzip,hashlib,json,math,os,re,time,zipfile
from pathlib import Path
from PIL import Image,ImageDraw
B=Path('/workspace/gunman-rush/build/region_production_v3'); O=B/'route_comparison_facts'
NAMES={'pr68':'pr68_content_same_postdraw_map2','v3_before_ivy':'current_canonical_postdraw_map2','v3_current':'current_canonical_after_ivy'}
C={k:json.loads((B/v/'capture.json').read_text()) for k,v in NAMES.items()};V={k:json.loads((B/v/'visual_capture.json').read_text()) for k,v in NAMES.items()}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def diff(a,b,p=''):
 if type(a)!=type(b):yield (p,a,b)
 elif isinstance(a,dict):
  for k in sorted(set(a)|set(b)):
   if k not in a or k not in b:yield(p+'/'+k,a.get(k,{'absent':True}),b.get(k,{'absent':True}))
   else:yield from diff(a[k],b[k],p+'/'+k)
 elif isinstance(a,list):
  if len(a)!=len(b):yield(p+'/length',len(a),len(b))
  for i,(x,y) in enumerate(zip(a,b)):yield from diff(x,y,p+'/'+str(i))
 elif a!=b:yield(p,a,b)
def compare(left,right):
 a,b=C[left],C[right];counts=collections.Counter();examples={};total=0
 with gzip.open(O/f'{left}__{right}.raw_deepdiff.jsonl.gz','wt') as f:
  for path,x,y in diff(a,b):
   f.write(json.dumps({'path':path,'before':x,'after':y},separators=(',',':'))+'\n');total+=1;key=re.sub(r'/\d+(?=/|$)','/*',path);counts[key]+=1;examples.setdefault(key,{'path':path,'before':x,'after':y})
 summary={'left':left,'right':right,'exact_capture_equal':a==b,'raw_leaf_difference_count':total,'grouped_leaf_differences':dict(counts),'examples':examples,'manifest_exact_diff':[{'path':p,'before':x,'after':y} for p,x,y in diff(a['manifest'],b['manifest'])],'run_manifest_initial_exact_diff':[{'path':p,'before':x,'after':y} for p,x,y in diff(a['formal_run_manifest_initial'],b['formal_run_manifest_initial'])],'capture_source_exact_diff':[{'path':p,'before':x,'after':y} for p,x,y in diff(a['capture_source_hashes'],b['capture_source_hashes'])], 'frame_field_mismatch_counts':{k:sum(x.get(k)!=y.get(k) for x,y in zip(a['frames'],b['frames'])) for k in sorted(set(a['frames'][0])|set(b['frames'][0]))}, 'edges_exact_equal':a['edges']==b['edges'],'initial_capability_exact_equal':a['initial_capability']==b['initial_capability'],'final_capability_exact_equal':a['final_capability']==b['final_capability'],'camera_initial_exact_equal':a['initial_runtime']['camera']==b['initial_runtime']['camera'],'camera_final_exact_equal':a['final_runtime']['camera']==b['final_runtime']['camera'],'per_tick_camera_available':any('camera' in f for f in a['frames']),'position_max_distance_world':max(math.dist(x['position'],y['position']) for x,y in zip(a['frames'],b['frames'])),'velocity_max_distance_world':max(math.dist(x['velocity'],y['velocity']) for x,y in zip(a['frames'],b['frames'])),'limits':'Diagnostic comparison only; no keys removed from production comparator, no new PASS, no inference of full camera registration or aesthetic approval.'}
 (O/f'{left}__{right}.summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
 return summary
comparisons=[compare('pr68','v3_current'),compare('v3_before_ivy','v3_current')]
indices=[600,840,1320,1440,1800,3000]
labels={600:'windmill highland/main route',840:'rock enclosure/main platform route',1320:'actual repair camp frontage',1440:'repair camp departure',1800:'actual descent toward lower creek route',3000:'lower creek ascent toward main route'}
selected=[]
for i in indices:
 image=Image.new('RGB',(1280,3*(720+30)),(20,20,20));draw=ImageDraw.Draw(image)
 for j,(k,folder) in enumerate(NAMES.items()):
  p=B/folder/'video_frames'/f'video_frame_{i:06}.png';im=Image.open(p);assert im.size==(1280,720);image.paste(im,(0,j*750+30));draw.text((10,j*750+8),f'{k} | actual video frame {i} at {i/60:g}s | {labels[i]} | NOT physics tick',fill='white')
 image.save(O/f'comparison_video_frame_{i:06}.jpg',quality=92)
 selected.append({'video_frame_index_zero_based':i,'video_time_seconds':i/60,'visible_window':labels[i],'physics_tick_mapping':'not available; do not equate video index with capture tick','comparison_jpeg':f'comparison_video_frame_{i:06}.jpg'})
inputs=[]
for tag,name in NAMES.items():
 for fn in ['capture.json','visual_capture.json','capture.log','encode.log','extract.log']:
  inputs.append(B/name/fn)
 if tag!='v3_before_ivy':inputs.append(B/name/'gameplay.mp4')
 for i in indices:inputs.append(B/name/'video_frames'/f'video_frame_{i:06}.png')
for rel in ['pr68_same_protocol_overlay/actual_overlay.json','pr68_same_protocol_overlay/exact_overlay.diff','pr68_same_protocol_overlay/strict_art_only_comparison.json','pr68_same_protocol_overlay/tests__level_formal_trace.gd.before','pr68_same_protocol_overlay/tools__level_formal_capture.gd.before','final_native/ivy_same_protocol_comparison.json']:
 inputs.append(B/rel)
index={'schema_version':1,'scope':'Fact packaging, not independent pixel approval. Author implemented ivy and cannot independently approve it.','recordings':{},'selected_video_frames':selected,'strict_pr68_result':json.loads((B/'pr68_same_protocol_overlay/strict_art_only_comparison.json').read_text()),'strict_same_v11_ivy_result':json.loads((B/'final_native/ivy_same_protocol_comparison.json').read_text()),'archive_members':[]}
for k,v in V.items():
 a=C[k];index['recordings'][k]={'original_directory':str(B/NAMES[k]),'source_commit':a['source_commit'],'recorded_source_inventory':v['source_before'],'source_stable':v['source_before']==v['source_after'],'root_seed':a['root_seed'],'seed':a['seed'],'map_index':a['map_index'],'strategy':a['strategy'],'outcome':a['outcome'],'tick_count':a['tick_count'],'manifest_version':a['manifest']['version'],'manifest_hash':a['manifest_hash'],'video_frame_count':v['media']['streams'][0].get('nb_frames'),'mp4_sha256':sha(B/NAMES[k]/'gameplay.mp4'),'mp4_archived':k!='v3_before_ivy','subjective_acceptance':v['subjective_acceptance'],'limits':'Recorded source_commit alone is not full content fingerprint; exact source_before map preserved.'}
with zipfile.ZipFile(O/'original_evidence.zip','w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in inputs:
  rel=str(p.relative_to(B));z.write(p,rel);index['archive_members'].append({'original_path':str(p),'member':rel,'size':p.stat().st_size,'sha256':sha(p)})
with zipfile.ZipFile(O/'original_evidence.zip') as z:
 assert z.testzip() is None
 for row in index['archive_members']:
  data=z.read(row['member']);assert len(data)==row['size'] and hashlib.sha256(data).hexdigest()==row['sha256']
index['archive_sha256']=sha(O/'original_evidence.zip');index['archive_crc_and_every_member_byte_sha256_verified']=True
(O/'index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
size=sum(p.stat().st_size for p in O.rglob('*') if p.is_file());assert size<=120_000_000,size
print(json.dumps({'total_bytes':size,'archive_bytes':(O/'original_evidence.zip').stat().st_size,'comparisons':[{'left':x['left'],'right':x['right'],'diffs':x['raw_leaf_difference_count'],'position_delta':x['position_max_distance_world'],'frame_mismatch':x['frame_field_mismatch_counts']} for x in comparisons]},indent=2))
