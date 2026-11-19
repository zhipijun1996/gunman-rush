// Faceted shaft / moving highlight adapted from pixelfx ice/ice-lance.
// MIT Patch / Hugo Duprez, with the upstream energy-bolt attribution retained.
// Only the spear and its local cold-air shears are baked. Godot owns the real trail.
import { meta as reference } from '../ice/ice-lance.js';
import { fit, WHITE, TAU } from '../../core/index.js';
export const meta={...reference,name:'Gunman glacial lance',size:[96,48],origin:[66,24],fps:30,options:{...reference.options,length:34}};
export function draw(p,t,o){
 const C=fit(o.palette,8),L=o.length,phase=t/meta.duration,pulse=-L+(phase%1)*L,glint=-L+(1-phase%1)*L;
 p.shade(-L-1,-6,2,6,(x,y,out)=>{
  if(x>0||x<-L)return;
  const h=x>-15?3.6*(-x/15)+.3:3.6,v=y/h;
  if(Math.abs(y)>h+.7)return;
  if(Math.abs(y)>h){out.c=C[0];return;}
  out.c=v<-.72?C[6]:v<-.35?C[5]:v<.35?C[4]:v<.78?C[2]:C[1];
  if((v>-.3&&v<.3&&Math.abs(x-pulse)<2)||(v<-.35&&Math.abs(x-glint)<1))out.c=WHITE;
 });
 p.glow(-10,0,12,C[4],.2);
 for(let i=0;i<3;i++){
  const u=(phase+i/3)%1,x=-u*18,r=3+u*7,a=(1-u)*.7;
  let prev;
  for(let j=0;j<15;j++){const g=-Math.PI/2+j*Math.PI/14,q=[x-Math.cos(g)*2,Math.sin(g)*r];if(prev)p.line(...prev,...q,C[5],a);prev=q;}
 }
}
