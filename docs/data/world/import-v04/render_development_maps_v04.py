from pathlib import Path
from collections import defaultdict
import json,math,io,importlib.util
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.path import Path as MPath
from matplotlib.patches import Polygon,Circle,Rectangle,FancyArrowPatch,PathPatch
from matplotlib.font_manager import FontProperties
import matplotlib.patheffects as pe
import xml.etree.ElementTree as ET
R=Path(__file__).resolve().parent
D=json.loads((R/'world-room-layout-v04.json').read_text());G=json.loads((R/'geometry-layout-v04.json').read_text())
ROOMS={r['id']:r for r in D['rooms']};BOSSES={b['room_id']:b for b in D['boss_plan']['bosses']};REGS={r['code']:r for r in D['regions']}
NAMES={n['id']:n for n in D['npcs']};CODES={n['id']:f'N{i:02}' for i,n in enumerate(D['npcs'],1)}
BG='#080e16';FG='#e2e8ed';MUTED='#92a5b5';GOLD='#efc471';CYAN='#81dce1';GREEN='#a5dbb8';PINK='#e1a2d8';PURPLE='#bdb0f0'
F=FontProperties(fname=str(R/'assets/foundry_notes.otf'));plt.rcParams.update({'svg.fonttype':'path','pdf.fonttype':3,'axes.unicode_minus':False})
LABELS=json.loads((R/'layouts/region-labels-v02.json').read_text());LABELS.update({'N':[1460,1400]})
REGCOLOR={r['code']:r.get('color','#9babb5') for r in D['regions']}
def rgb(h):return np.array([int(h[i:i+2],16)/255 for i in (1,3,5)])
def txt(ax,x,y,t,size=10,c=FG,ha='center',z=15):
 t=str(t).replace('–','-').replace('—','-')
 a=ax.text(x,y,t,fontproperties=F,fontsize=size*.72,color=c,ha=ha,va='center',zorder=z)
 a.set_path_effects([pe.withStroke(linewidth=2.3,foreground=BG)]);return a

def bounds(r):
 p=np.array(r['polygon']);return p[:,0].min(),p[:,1].min(),p[:,0].max(),p[:,1].max()
def path(polys):
 v=[];c=[]
 for p in polys:
  if len(p)<3:continue
  v+=p+[p[0]];c +=[MPath.MOVETO]+[MPath.LINETO]*(len(p)-1)+[MPath.CLOSEPOLY]
 return MPath(np.array(v),c)
def basemap(ax,region=None):
 for code,polys in G['display_surfaces'].items():
  al=1 if region is None or code==region else .12
  ax.add_patch(PathPatch(path(polys),facecolor=rgb(BG)*.78+rgb(REGCOLOR[code])*.22,edgecolor='none',alpha=al,zorder=1))
 for line in G['display_outline_runs']:
  p=np.array(line['points']);al=.9 if region is None or line['region']==region else .16
  ax.plot(p[:,0],p[:,1],color=REGCOLOR[line['region']],lw=.75,alpha=al,zorder=2)
def bench(ax,x,y,new=False):
 c=GREEN if new else FG
 ax.plot([x-5,x+5],[y,y],c=c,lw=1.6,zorder=12)
 for dx in [-3.5,3.5]:ax.plot([x+dx,x+dx],[y,y+3.5],c=c,lw=.8,zorder=12)
 if new:ax.add_patch(Circle((x,y-.7),7.1,facecolor='none',edgecolor=c,lw=.55,alpha=.8,zorder=11))
def ring(ax,x,y):
 ax.add_patch(Circle((x,y),4,facecolor='none',edgecolor=CYAN,lw=.85,zorder=12));ax.plot([x-2,x+2],[y+4.5,y-4.5],c=CYAN,lw=.8,zorder=12)
def badge(ax,x,y,label,c,shape='square',size=8):
 if shape=='diamond':p=[[x,y-7],[x+7,y],[x,y+7],[x-7,y]]
 elif shape=='triangle':p=[[x,y-7],[x+6,y+5],[x-6,y+5]]
 else:p=[[x-6,y-6],[x+6,y-6],[x+6,y+6],[x-6,y+6]]
 ax.add_patch(Polygon(p,facecolor=BG,edgecolor=c,lw=.8,zorder=14));txt(ax,x+9,y,label,size,c,ha='left',z=16)
def collect_markers():
 marks=defaultdict(list)
 for npc in D['npcs']:marks[npc['room_id']].append((CODES[npc['id']],CYAN,'triangle','npc'))
 ui=si=0
 for a in D['weapon_major_rewards']:
  if a['kind']=='attack_alloy':lab='A'+a['id'][-1];c=GOLD
  elif a['kind']=='branch_material':ui+=1;lab='U'+str(ui);c=PURPLE
  else:si+=1;lab='S'+str(si);c=PINK
  marks[a['room_id']].append((lab,c,'diamond','material'));a['legend_tag']=lab
 for a in D['important_markers']:
  label=a['map_label'];
  if label in ['H','W','D','Q','刃','弹','灯','净']:marks[a['room_id']].append((label,'#e5efc2','square','ability'))
 for a in D['clock_repairs']:marks[a['room_id']].append(('钟'+a['region'],GOLD,'square','clock'))
 for a in D['central_clock_operations']:
  if a['action_id']=='install_cores':marks[a['room_id']].append(('装核',GOLD,'square','clock'))
 return marks
MARKERS=collect_markers()

def draw_annotations(ax,numbered=False,region=None,shortcuts=False):
 for r in D['rooms']:
  if region and r['region']!=region:continue
  rid=r['id'];x,y=r['map_centre'];x0,y0,x1,y1=bounds(r)
  if numbered:
   ax.add_patch(Polygon(r['polygon'],facecolor='none',edgecolor=REGCOLOR[r['region']],lw=.33,ls=(0,(2,3)),alpha=.45,zorder=3))
   txt(ax,x,y,rid,10 if region else 9,c='#d7dfe5',z=12)
  if rid in BOSSES:
   yy=y-11 if numbered else y
   ax.add_patch(Circle((x,yy),4.6,facecolor=BG,edgecolor=GOLD,lw=.9,zorder=12))
   ax.add_patch(Polygon([[x,yy-2.5],[x+2.5,yy],[x,yy+2.5],[x-2.5,yy]],facecolor=GOLD,edgecolor='none',zorder=13))
  if r['rest_point']:bench(ax,x-8,y+12,r.get('rest_is_new',False))
  if r['rift_machine']:ring(ax,x+6,y+12)
  if not shortcuts:
   mm=MARKERS[rid];n=len(mm)
   for i,(lab,c,shape,kind) in enumerate(mm):
    row=i//2;col=i%2;xx=x-18+col*38;yy=y-15-row*15 if numbered else y-8-row*15
    if n==1:xx=x-13
    if rid in BOSSES:yy-=6
    badge(ax,xx,yy,lab,c,shape,9.6 if region else 8.7)
 # Intro arrow explicitly ends in the first station, never starts there.
 for rid in ['S-R10','R-R06']:
  r=ROOMS[rid]
  if region and r['region']!=region:continue
  x,y=r['map_centre'];txt(ax,x+11,y+20,'暗渠 A',8.7,CYAN,ha='left')
 if not region or region=='P':
  a=ROOMS['P-R03']['map_centre'];b=ROOMS['P-R01']['map_centre']
  ax.add_patch(FancyArrowPatch((a[0]+12,a[1]),(b[0]-15,b[1]+1),arrowstyle='-|>',mutation_scale=10,lw=1.5,color=GREEN,zorder=16))
  txt(ax,a[0]-6,a[1]+23,'起点 / 教程',11.5,GREEN)
  txt(ax,b[0]+4,b[1]+27,'钟外小站',11.5,'#ecdab4')
 if shortcuts:
  for j,s in enumerate(D['shortcuts']):
   aa,bb=ROOMS[s['a']],ROOMS[s['b']]
   if region and region not in [aa['region'],bb['region']]:continue
   a=np.array(aa['map_centre'],float);b=np.array(bb['map_centre'],float)
   control=np.array(ROOMS[s['open_from_room']]['map_centre'],float)
   if s['open_from_room']==s['b'] or (s['open_from_room'] not in [s['a'],s['b']] and ROOMS[s['open_from_room']]['region']==bb['region']):a,b=b,a
   c=PINK if s.get('is_new') else '#85cbd7';rad=(.18 if j%2 else -.15)
   ax.add_patch(FancyArrowPatch(a,b,arrowstyle='-|>',mutation_scale=8,lw=.85,color=c,alpha=.8,linestyle=(0,(3,3)),connectionstyle=f'arc3,rad={rad}',zorder=5))
   ax.add_patch(Rectangle((control[0]-3,control[1]-3),6,6,facecolor=c,edgecolor=BG,lw=.5,zorder=9))
   if s['open_from_room'] not in [s['a'],s['b']]:
    ax.plot([control[0],a[0]],[control[1],a[1]],c=c,lw=.7,ls=(0,(1,3)),alpha=.8,zorder=5)
   m=(a+b)/2;txt(ax,m[0],m[1]-7,s['id'],8.2,c,z=11)
  for card in D['memory_gates']:
   rr=ROOMS[card['preview_room']]
   if region and rr['region']!=region:continue
   x,y=rr['map_centre'];badge(ax,x+8,y-12,card['id'].replace('MEM','M'),GOLD,'square',8.8)

def export(fig,base,svg=False):
 out=R/base;out.parent.mkdir(exist_ok=True,parents=True)
 buf=io.BytesIO();fig.savefig(buf,format='png',dpi=230,facecolor=BG);data=buf.getvalue();Image.open(io.BytesIO(data)).load();tmp=out.with_suffix('.png.tmp');tmp.write_bytes(data);tmp.replace(out.with_suffix('.png'))
 if svg:
  buf=io.StringIO();fig.savefig(buf,format='svg',facecolor=BG);s=buf.getvalue();ET.fromstring(s);out.with_suffix('.svg').write_text(s)
 plt.close(fig)

def fullmap(numbered=False,shortcuts=False):
 fig,ax=plt.subplots(figsize=(20,16.4),dpi=100);fig.patch.set_facecolor(BG);ax.set_facecolor(BG);fig.subplots_adjust(0,0,1,1)
 ax.set_xlim(0,2000);ax.set_ylim(1640,0);ax.set_aspect('equal');ax.axis('off');basemap(ax);draw_annotations(ax,numbered,shortcuts=shortcuts)
 for code,(x,y) in LABELS.items():txt(ax,x,y,REGS[code]['name'],18 if not numbered else 15,REGCOLOR[code],z=18)
 title='捷径与房内回访点' if shortcuts else '世界结构灰盒总图'
 txt(ax,65,57,'失序之钟 · '+title,29,c='#e9ddbf',ha='left')
 txt(ax,65,89,'216 房间 / 16 区域 / 22 BOSS   ·   开局：平原教程 → 钟外小站',13,c=MUTED,ha='left')
 txt(ax,1930,57,'40 休息点 · 16 裂缝 · 14 NPC',15,c=FG,ha='right');txt(ax,1930,83,'v04 / 房间编号版' if numbered else 'v04 / 开发标注版',12,c=MUTED,ha='right')
 ax.plot([65,1930],[1430,1430],c='#304353',lw=.7)
 if shortcuts:
  txt(ax,65,1455,'粉虚线：15 条新增捷径   青虚线：11 条原有背开机关   方点：首次开门控制侧   箭头：首次回程方向；开启后双向',12.5,ha='left')
  txt(ax,65,1483,'M01–M12：房内可观察的能力阻隔与地标。入口可预览，深入另计；只点亮已经见过的位置。',12,c=MUTED,ha='left')
  txt(ax,65,1512,'虚线表示成对门的关系，不代表已验证的实体通道。具体门、升降机、开关与存档条件见图册和逐房合同。',12,c=MUTED,ha='left')
  txt(ax,65,1552,'休息恢复 / 重置普通敌人；地形失败扣1HP（特殊2HP）并回本次挑战入口；Boss与唯一领取、修钟、已开捷径永久保存。',12,ha='left')
 else:
  txt(ax,65,1455,'长凳：休息（绿色圈为新增）  裂环：传送  圆纹：BOSS  N：NPC  A1–A8：攻击合金  U1–U6：分支部件  S1–S2：技能芯  钟：修钟',12.5,ha='left')
  txt(ax,65,1483,'H 钩索 / W 墙面移动 / D 二段跳 / Q 相位反冲    攻击合金按 1 / 2 / 2 / 3 消耗；八个分支与技能大奖另算。',12,c=MUTED,ha='left')
  for i,n in enumerate(D['npcs']):
   xx=65+(i%7)*267;yy=1523+(i//7)*29;txt(ax,xx,yy,CODES[n['id']]+' '+n['display_name']+(' · 商' if n.get('shop_reward_slots') else ''),11.2,CYAN,ha='left')
  txt(ax,65,1591,'门负责跨房；H/W/D/Q阻隔位于房内。门位与房间轮廓为示意，实际尺寸见逐房施工工作值。',11.5,MUTED,ha='left')
 base='world-shortcuts-v04' if shortcuts else 'world-room-map-numbered-v04' if numbered else 'world-room-map-v04'
 export(fig,base,svg=not shortcuts);print('rendered',base,flush=True)

def regionmap(code):
 rr=[r for r in D['rooms'] if r['region']==code];bb=np.array([bounds(r) for r in rr]);xmin,ymin,xmax,ymax=bb[:,0].min()-26,bb[:,1].min()-36,bb[:,2].max()+28,bb[:,3].max()+34
 fig,ax=plt.subplots(figsize=(11,7.3),dpi=100);fig.patch.set_facecolor(BG);ax.set_facecolor(BG);fig.subplots_adjust(.02,.02,.98,.94)
 ax.set_xlim(xmin,xmax);ax.set_ylim(ymax,ymin);ax.set_aspect('equal');ax.axis('off');basemap(ax,code);draw_annotations(ax,True,code,False)
 fig.text(.025,.97,REGS[code]['name']+'  /  '+code+' · 逐房标记',fontproperties=F,color=FG,fontsize=14,va='top')
 export(fig,'maps/region-'+code+'-v04')

def previewmap():
 fig,ax=plt.subplots(figsize=(20,16.4),dpi=100);fig.patch.set_facecolor(BG);ax.set_facecolor(BG);fig.subplots_adjust(0,0,1,1)
 ax.set_xlim(0,2000);ax.set_ylim(1640,0);ax.set_aspect('equal');ax.axis('off');basemap(ax)
 for code,(x,y) in LABELS.items():txt(ax,x,y,REGS[code]['name'],18,REGCOLOR[code],z=18)
 for card in D['memory_gates']:
  rid=card.get('preview_room');r=ROOMS.get(rid)
  if r is None:continue
  x,y=r['map_centre'];ax.add_patch(Circle((x,y),12,facecolor=BG,edgecolor=GOLD,lw=1.1,zorder=10))
  txt(ax,x,y,card['id'].replace('MEM','M'),10,GOLD,z=12)
  txt(ax,x+18,y-4,card.get('unlock_label',''),11,FG,ha='left',z=12)
 txt(ax,65,57,'失序之钟 · 能力预览与回访地标',29,c='#e9ddbf',ha='left')
 txt(ax,65,89,'普通门可进入口区；房内环境阻断深入路线。标记对应可观察的空间，不是门锁。',13,c=MUTED,ha='left')
 txt(ax,1930,57,'v04 / 入口预览图',15,c=FG,ha='right')
 ax.plot([65,1930],[1430,1430],c='#304353',lw=.7)
 for i,card in enumerate(D['memory_gates']):
  xx=65+(i%3)*630;yy=1460+(i//3)*33
  txt(ax,xx,yy,card['id'].replace('MEM','M')+' '+card.get('preview_room','')+' · '+card.get('landmark',''),11.6,GOLD,ha='left')
 txt(ax,65,1610,'已发现、已深入、已修钟、深部记录分别统计。自动上跳只落到入口侧，不越过能力挑战。',12,c=MUTED,ha='left')
 export(fig,'world-preview-locks-v04',svg=True)

def main():
 # Persist legend tags so the report and map use exactly the same identifiers.
 (R/'design/map-legend-v04.json').write_text(json.dumps({'npcs':CODES,'materials':[{k:a[k] for k in ['id','name','room_id','kind','legend_tag']} for a in D['weapon_major_rewards']]},ensure_ascii=False,indent=2))
 fullmap();fullmap(True);fullmap(False,True);previewmap()
 for code in REGS:regionmap(code)
if __name__=='__main__':main()
