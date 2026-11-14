// Shape/timing studies adapted from patch-gg/pixelfx's holy/heal,
// impacts/ground-slam, pickups/chest-open, pickups/coin-spin and spawn/coin-drop.
// MIT, Patch / Hugo Duprez; project-specific shapes, no stock bodies or fake loot.
import { sparkle, WHITE, TAU, fit } from "../../core/index.js";
import { cloud } from "../projectiles/_lib.js";
export const GOLD=fit(["#291a13","#704121","#b77724","#edac36","#ffda6a","#fff1b5","#ffffff"],7);
const MINT=fit(["#173c41","#26777b","#45b6ab","#92e1be","#d6ffd8","#fff5cf","#ffffff"],7);
const DUST=fit(["#303331","#555544","#7d7960","#b0a080","#d6c4a0","#e9dcc0","#ffffff"],7);
const clamp=t=>Math.max(0,Math.min(1,t)), out=t=>1-(1-clamp(t))**3;
const rand=i=>{const n=Math.sin(i*127.1+52.17)*43758.5453;return n-Math.floor(n);};
export function meta(kind,size,origin,duration,loop=false){return {name:`Gunman ${kind}`,desc:`Authored ${kind} from rendered pixelfx references; distinct primary silhouette, phased secondary motion.`,tags:["gunman",kind],size,origin,duration,loop,fps:30,bg:"dark",options:{seed:19,design:2}};}
function oval(p,x,y,rx,ry,c,a=1,start=0,end=TAU){
 let last;for(let i=0;i<=64;i++){const g=start+(end-start)*i/64,at=[x+Math.cos(g)*rx,y+Math.sin(g)*ry];if(last)p.line(...last,...at,c,a);last=at;}
}
function petal(p,x,y,a,L,W,C,alpha){
 const c=Math.cos(a),s=Math.sin(a),at=(u,v)=>[x+c*u-s*v,y+s*u+c*v];
 p.poly([at(0,0),at(L*.3,-W),at(L,0),at(L*.4,W)],C[2],alpha*.5);
 p.poly([at(0,0),at(L*.3,-W),at(L,0),at(L*.45,0)],C[4],alpha);
 p.line(...at(1,0),...at(L,0),C[5],alpha);
}
function puff(p,x,y,r,C,a){
 if(r<.5||a<=0)return;
 p.disc(x+r*.12,y+r*.16,r,C[0],a*.7);
 p.disc(x,y,r*.9,C[1],a);
 p.disc(x-r*.12,y-r*.18,r*.72,C[2],a*.9);
 p.disc(x-r*.3,y-r*.4,r*.36,C[3],a*.75);
}
export function gather(p,t,o){
 if(t>=1||t<0)return;
 const C=MINT,build=out(t),phase=t*3.4;
 // Braided inward arcs with staggered heads; center stays open for the face.
 for(let band=0;band<3;band++){
  const a=band*TAU/3+phase,rx=37-22*build,ry=28-17*build;
  const tilt=(o.design===0?0:band*.37),pts=[];
  for(let j=0;j<30;j++){
   const k=j/29,g=a-k*(o.design===1?2.1:3.5),r=1+k*.3;
   const x=Math.cos(g)*rx*r,y=Math.sin(g)*ry*r-9+Math.sin(g*2+tilt)*4;
   pts.push([x,y]);if(j)p.line(...pts[j-1],x,y,C[j<6?5:j<16?3:1],(1-k)*(.5+.5*t));
  }
  sparkle(p,...pts[0],2+build*1.5,WHITE,C[3],.35);
 }
 for(let i=0;i<19;i++){
  const u=(t*1.6+i/19)%1,a=i*2.399,r=4+(1-u)**1.6*(35+rand(i)*12);
  const x=Math.cos(a)*r,y=Math.sin(a)*r*.8-9;
  p.line(x,y,x+Math.cos(a)*4,y+Math.sin(a)*4,C[3],Math.sin(u*Math.PI)*.8);
  p.dot(x,y,C[5],Math.sin(u*Math.PI));
 }
 // Increasing pulse, no tall enclosing shell or eight-way radiation.
 const pulse=.6+.4*Math.sin(t*18);p.glow(0,-9,12+build*6,C[3],(.10+.18*build)*pulse);
 p.poly([[-3,-9],[0,-13],[3,-9],[0,-5]],C[4],.5+.4*build);
}
export function restore(p,t,o){
 if(t>=1||t<0)return;
 const C=MINT,fade=(1-t)**1.2,bloom=Math.sin(Math.min(1,t*3)*Math.PI*.5)*fade;
 // Foot-rooted lotus, perspective-compressed to the actual courier scale.
 for(let i=0;i<8;i++){
  const a=i*TAU/8+.2,near=Math.sin(a)>0,L=(19+(i%2)*7)*bloom;
  petal(p,Math.cos(a)*4,Math.sin(a)*2,a-1.1,L,5*bloom,C,near?fade:fade*.65);
 }
 const lift=out(t/.72),y=6-lift*47,r=22-5*lift;
 if(t<.80){oval(p,0,y,r,4,C[2],fade*.8);oval(p,0,y-1,r,4,C[5],fade);p.glow(0,y,22,C[3],.25*fade);}
 for(let i=0;i<14;i++){
  const u=clamp((t-i*.014)/.76),a=i*2.399+u*3.5,x=Math.cos(a)*(19-u*7),y=5-u*(35+rand(i)*22);
  if(u>0&&u<1){p.line(x,y,x-Math.cos(a)*2,y+4,C[3],(1-u)*fade);sparkle(p,x,y,(i%5===0?2.4:1.0)*(1-u),WHITE,C[4],.3*fade);}
 }
 if(t<.15)p.glow(0,-16,28,C[4],.4*(1-t/.15));
}
export function landing(p,t,o){
 if(t>=1||t<0)return;
 const fade=(1-t)**1.5,C=DUST,travel=out(t);
 // Two unequal moving pressure crescents and rolling dust ridges.
 for(const side of [-1,1]){
  const x=side*(8+travel*(side<0?106:120)),h=(18+Math.sin(t*Math.PI)*14)*fade;
  const pts=[];for(let i=0;i<20;i++){const u=i/19;pts.push([x-side*Math.sin(u*Math.PI)*12*fade,-u*h]);}
  for(let i=1;i<pts.length;i++){p.line(...pts[i-1],...pts[i],C[3],fade*.8);p.line(pts[i-1][0]-side,pts[i-1][1],pts[i][0]-side,pts[i][1],C[4],fade*.65);}
 }
 const dust=[];
 for(let i=0;i<34;i++){
  const side=i%2?1:-1,n=rand(i),x=side*(7+travel*(10+n*84)),y=-Math.sin(t*Math.PI)*(2+n*11);
  dust.push({x,y,r:3+Math.sin(t*Math.PI)*(5+n*6),a:fade*.85,b:.8+n*.2,w:Math.max(0,1-t*7)*.12});
 }
 cloud(p,dust,C,GOLD,{dens:1.35,max:.67,lit:1.2});
 for(let i=0;i<16;i++){
  const a=-Math.PI+rand(i+80)*Math.PI,v=25+rand(i+60)*67,x=Math.cos(a)*v*t*2,y=Math.sin(a)*v*t*1.3+72*t*t;
  if(y<0)petal(p,x,y,t*(i%2?5:-7),2+rand(i+9)*4,1.5,C,fade);
 }
 if(t<.15){oval(p,0,0,8+out(t/.15)*58,2+out(t/.15)*4,GOLD[5],1-t/.15);p.glow(0,-3,46,GOLD[4],.35*(1-t/.15));}
}
export function treasure(p,t,o){
 if(t>=1||t<0)return;
 const C=GOLD,fade=(1-t)**1.4,open=out(t/.18);
 for(let i=0;i<7;i++){
  const a=-Math.PI/2+(i-3)*.19,L=(43+rand(i)*26)*open*(.85+.15*Math.sin(t*13+i)),w=(2+rand(i+8)*3)*fade;
  const x=Math.cos(a)*L,y=Math.sin(a)*L;
  const dx=Math.cos(a),dy=Math.sin(a),spread=.025+w*.009;
  p.shade(-72,-86,72,2,(px,py,out)=>{
   const d=px*dx+py*dy,q=Math.abs(px*dy-py*dx),half=.6+d*spread;
   if(d<0||d>L||q>half+2)return;
   out.l=C[i%2?4:5];out.k=fade*.48*Math.max(0,1-q/(half+2))*(1-d/L)**1.2;
  });
  if(i%2===0)p.line(0,-2,x,y,C[4],fade*.3);
 }
 for(let i=0;i<19;i++){
  const u=clamp((t-rand(i)*.1)/.88),a=-Math.PI+rand(i+10)*Math.PI,v=20+rand(i+21)*39;
  const x=Math.cos(a)*v*out(u),y=-8-u*(35+rand(i)*30)+u*u*30;
  sparkle(p,x,y,(i%3?1.2:2.8)*Math.sin(u*Math.PI),WHITE,C[4],fade*.6);
 }
 if(t<.22){p.glow(0,-5,32,C[4],.7*(1-t/.22));sparkle(p,0,-3,8*(1-t/.22),WHITE,C[5],.5);}
}
export function spill(p,t,o){
 if(t>=1||t<0)return;const fade=(1-t)**1.7;
 for(let i=0;i<7;i++){const a=i*TAU/7,r=out(t)*(12+rand(i)*8);puff(p,Math.cos(a)*r,Math.sin(a)*r*.5,2+Math.sin(t*Math.PI)*4,DUST,fade*.6);}
 for(let i=0;i<9;i++){const a=-Math.PI+rand(i)*Math.PI,r=out(t)*(15+rand(i+8)*15);sparkle(p,Math.cos(a)*r,Math.sin(a)*r-t*7,1.6*fade,WHITE,GOLD[4],fade*.4);}
}
export function coin(p,t,o){
 const C=GOLD,c=Math.cos(t*TAU),sx=Math.abs(c),r=8,hw=Math.max(1,r*sx);
 // Lit beveled rim, recessed face, reeded edge and stamped star.
 for(let y=-9;y<=9;y++)for(let x=-10;x<=10;x++){
  const d=(x/hw)**2+(y/r)**2;if(d>1.25)continue;
  const edge=d>.78,col=edge?(x+y<0?C[5]:C[1]):y<-3?C[4]:C[3];
  p.dot(x,y,col);
  if(edge&&sx<.4&&y%2===0)p.dot(x+1,y,C[2]);
 }
 if(sx>.32){
  oval(p,-.4,-.5,hw*.72,6,C[2]);
  const pts=[];for(let i=0;i<10;i++){const a=-Math.PI/2+i*Math.PI/5,r=i%2?1.6:4;pts.push([Math.cos(a)*r*sx,Math.sin(a)*r]);}
  p.poly(pts,C[5]);p.dot(-1,-2,WHITE);
 }
 if(sx>.94){p.line(-hw*.45,-5,hw*.35,2,C[6],.65);p.glow(-2,-3,5,C[4],.2);}
}
