from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import math
b=Path('build/p33-boundary');o=Path('build/opening-atmosphere/prepared-web/review/forecourt');o.mkdir(parents=True,exist_ok=True)
F=lambda n:ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',n)
raw=Image.open(b/'after-whole.png').convert('RGB');raw.save(o/'whole-room.jpg',quality=93)
raw.resize((1280,640),Image.Resampling.LANCZOS).save(o/'whole-room-preview.jpg',quality=90)
im=Image.new('RGB',(1280,1056),'#131c22');im.paste(raw.resize((1280,640),Image.Resampling.LANCZOS),(0,100));d=ImageDraw.Draw(im)
d.text((24,12),'P33 钟影前庭 · 整房空间与路线',font=F(31),fill='#ead5a7')
d.text((24,57),'实机场景检查总览（非正式镜头）｜主路金色 · 回环青色 · 反冲回升紫色',font=F(21),fill='#bbc9c6')
def xy(p):return (p[0]*.625,p[1]*.625+100)
def line(points,col):
 ps=[xy(p) for p in points];d.line(ps,fill=col,width=3)
 for a,z in zip(ps,ps[1:]):
  dx,dy=z[0]-a[0],z[1]-a[1];le=math.hypot(dx,dy)
  if le<20:continue
  ux,uy=dx/le,dy/le;t=(a[0]+dx*.7,a[1]+dy*.7)
  d.polygon([t,(t[0]-ux*10-uy*5,t[1]-uy*10+ux*5),(t[0]-ux*10+uy*5,t[1]-uy*10-ux*5)],fill=col)
line([(64,542),(864,542),(1184,542),(1536,542),(1536,472)],'#ebc477')
line([(1024,570),(1024,794),(1152,894),(1070,910),(1024,1010)],'#85cfc3')
line([(1140,875),(1035,794),(1035,595)],'#c1a6e1')
for i,p in enumerate([(416,492),(1024,506),(1664,472),(1264,842)],1):
 x,y=xy(p);d.ellipse((x-16,y-16,x+16,y+16),fill='#15252b',outline='#dfc38d',width=2);d.text((x-8,y-15),str(i),font=F(21),fill='#f1dbac')
for p,text in [((20,478),'← P32 悬铃长桥'),((1450,408),'↑ 交互进入 Z01'),((820,976),'↓ P35 下层汇口')]:
 x,y=xy(p);d.rounded_rectangle((x-5,y-2,x+202,y+31),radius=4,fill='#17272d');d.text((x,y),text,font=F(20),fill='#f1dbac')
info=[('① 开阔进场','长桥挑战后的舒缓段；低原野与流云','留出视野，让塔基逐步进入画面。'),('② 检修桥／分路','木踏板下＋跳进入塔基；主路直行','桥接草岸与石台，不新增支柱。'),('③ 钟心正门','塔门、扶壁和石台作为整体；上推','进Z01调查，剧情仍在室内发生。'),('④ 塔基回路','下层暖灯与承接岸；普通跳中台，','再下射反冲回前庭，井口接P35。'),('本房要素','3个连接 · 无怪物／Boss／收集物','无休息站；此处承担导航和缓冲。'),('检查范围','右上净空展开；三门与主支路保留；','正常机位与连续通行另见短片。')]
for i,(t,a,c) in enumerate(info):
 x=22+i%3*420;y=764+i//3*140
 d.rounded_rectangle((x-6,y-5,x+398,y+122),radius=6,fill='#1c2a30')
 d.text((x+4,y),t,font=F(23),fill='#e7c584');d.text((x+4,y+42),a,font=F(19),fill='#cbd8d4');d.text((x+4,y+73),c,font=F(19),fill='#b0bfba')
im.save(o/'space-map.png')
for name,i in [('portal-comparison',2),('east-comparison',3)]:
 im=Image.new('RGB',(960,1168),'#131c22');d=ImageDraw.Draw(im)
 for k,folder in enumerate(['before','after']):
  y=k*584;d.text((18,y+4),'修改前' if k==0 else '当前实机 · 同位置／同镜头',font=F(26),fill='#ead5a7')
  im.paste(Image.open(b/folder/f'{i}.png').convert('RGB').resize((960,540),Image.Resampling.LANCZOS),(0,y+44))
 im.save(o/(name+'.jpg'),quality=89)
