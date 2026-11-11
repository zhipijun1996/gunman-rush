from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,re
b=Path('build/p32-structure');out=Path('build/opening-atmosphere/prepared-web/review/longbridge');out.mkdir(exist_ok=True,parents=True)
font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';F=lambda n:ImageFont.truetype(font,n)
raw=Image.open(b/'after-whole.png').convert('RGB');raw.save(out/'whole-room.jpg',quality=92)
im=Image.new('RGB',(1280,1188),'#131c22');im.paste(raw,(0,98));d=ImageDraw.Draw(im)
d.text((28,13),'P32 悬铃长桥 · 整房空间与路线',font=F(32),fill='#ead5a7');d.text((28,58),'实际场景总览／检查缩放 0.38　｜　主路金色 · H回访紫色 · 检修支路青色',font=F(21),fill='#b7c1bf')
def xy(p):return ((p[0]-1536)*.38+640,(p[1]-672)*.38+360+98)
def line(points,color):
 ps=[xy(p) for p in points];d.line(ps,fill=color,width=3)
 for i in range(1,len(ps)):
  a,z=ps[i-1],ps[i];dx,dy=z[0]-a[0],z[1]-a[1];l=math.hypot(dx,dy)
  if l<20:continue
  ux,uy=dx/l,dy/l;t=(a[0]+dx*.7,a[1]+dy*.7)
  d.polygon([t,(t[0]-ux*9-uy*4,t[1]-uy*9+ux*4),(t[0]-ux*9+uy*4,t[1]-uy*9-ux*4)],fill=color)
line([(64,984),(672,984),(880,850),(1184,916),(1440,916),(1560,708),(1904,780),(2096,780),(2224,700),(2336,580),(2680,590),(3072,590)],'#e5b96a')
line([(2240,1006),(2144,1014),(1792,1014)],'#83c4b9');line([(2240,1014),(2432,1200),(2304,1280),(2304,1344)],'#83c4b9')
line([(1184,910),(1200,680),(1104,602),(960,416),(960,224),(960,142),(960,0)],'#b2a2d8')
points=[(360,920),(1280,860),(1840,710),(2750,440),(1840,980),(2240,1192),(1160,176)]
for i,p in enumerate(points,1):
 x,y=xy(p);d.ellipse([x-15,y-15,x+15,y+15],fill='#16222b',outline='#ebce8d',width=2);d.text((x-8,y-14),str(i),font=F(21),fill='#f1dbac')
for p,label in [((64,1024),'← P31 旧集'),((3072,640),'P33 钟心 →'),((960,0),'↑ P15 修钟回程'),((2304,1344),'↓ P35 汇口')]:
 x,y=xy(p);x=max(8,min(x-70,1100));y=y+8 if p[1]==1344 else y-33;d.rounded_rectangle([x-5,y-2,x+170,y+29],radius=4,fill='#18252b');d.text((x,y),label,font=F(19),fill='#f1dbac')
s=Path('game/world/regions/P/rooms/P-R32.tscn').read_text();rows=json.loads(re.search(r'enemy_placements = Array\[Dictionary\]\((\[.*?\])\)',s,re.S)[1])
for r in rows:
 x,y=xy(r['point']);d.ellipse([x-5,y-13,x+5,y-3],fill='#d18473')
info=[('① 西桥头','连续石桥头；冲锋怪迫使进退。','入口安全岸与第一起跳点分开。'),('② 双断口与残墩','荆棘生于下陷渠槽；反冲过断口。','中段残墩供落脚、回枪和对空。'),('③ 东桥台／吊架','厚桥台容纳藏室，台上应对守卫。','跳起回射风铃，反冲登检修吊台。'),('④ 东侧远眺岸','升降台送到安全岸，远眺钟心。','保留剧情与东口，草地在自然岸外。'),('⑤ 桥墩藏室','低矮检修间嵌入桥体；巡逻守箱。','10金币；原路回到可穿越检修台。'),('⑥ 敞开检修井','破损后侧挡墙与藏室同一结构。','下＋跳进入，安全岸承接通往汇口。'),('⑦ 上层钟井回访','H锚点连接旧检修岸与P15上口。','接收台可下穿，维持原能力回访。'),('本房要素','4个出口 · 4只怪 · 1个10金币箱','无Boss／休息站；红点为源配置怪位。'),('读图说明','背景墙没有碰撞；亮边为实际岸面。','总览用于审核空间，不代表正式镜头。')]
for i,(title,a,c) in enumerate(info):
 x=24+(i%3)*420;y=832+(i//3)*116
 d.rounded_rectangle([x-5,y-5,x+400,y+103],radius=7,fill='#1c2a30')
 d.text((x+6,y),title,font=F(24),fill='#e7c584');d.text((x+6,y+38),a,font=F(18),fill='#cfdbd8');d.text((x+6,y+66),c,font=F(18),fill='#aebdbc')
im.save(out/'space-map.png')
for name,i in [('bridge-comparison',1),('cache-comparison',5),('service-comparison',6)]:
 im=Image.new('RGB',(960,1168),'#131c22');d=ImageDraw.Draw(im)
 for row,path in enumerate([Path('build/p32-composition/after')/f'{i}.png',b/'after'/f'{i}.png']):
  y=row*584;d.text((18,y+5),'上一版' if row==0 else '当前实机 · 同机位（敌人隔离）',font=F(26),fill='#ecd9aa');im.paste(Image.open(path).convert('RGB').resize((960,540),Image.Resampling.LANCZOS),(0,y+44))
 im.save(out/(name+'.jpg'),quality=89)
for name,i in [('upper-return',7),('service',6),('vista',4)]:Image.open(b/'after'/f'{i}.png').convert('RGB').save(out/(name+'.jpg'),quality=90)
# The old vista comparison belongs to the previous delivered revision; the vista is unchanged here.
(out/'vista-comparison.jpg').unlink(missing_ok=True)
