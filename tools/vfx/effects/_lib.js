// Project-authored pixel VFX. Uses pixelfx's MIT painter and deterministic code-as-clay workflow.
import { fit, WHITE, TAU } from "../../core/index.js";

export const WARM = ["#1a2524", "#766044", "#bc9155", "#e4be77", "#f5dda5", "#fff4d0", "#ffffff"];
const DUST = ["#252c28", "#4b5143", "#77775c", "#aaa184", "#cabb9c", "#e5d9bc", "#fff3cf"];
export const ICE = ["#122b43", "#285578", "#4086ae", "#71c5df", "#a2e5f2", "#e0faff", "#ffffff"];
const fract = x => x - Math.floor(x);
const noise = (i, seed) => fract(Math.sin(i * 127.1 + seed * 31.7) * 43758.5453);
const ease = t => 1 - (1-t)**3;

export function metadata(kind, name, size, origin, duration, loop = false) {
  return { name, desc: `Gunman Rush ${kind}: native-scale shaped pixels with a brief focal accent and a clean ${loop ? "seamless loop" : "empty ending"}.`, tags: ["gunman", kind, loop ? "loop" : "one-shot"], size, origin, duration, loop, fps: 60, bg: "dark", options: { palette: kind === "ice" || kind === "cold" ? ICE : kind === "dust" ? DUST : WARM, seed: 7 } };
}
function shard(p, x, y, length, width, angle, C, alpha = 1) {
  const c = Math.cos(angle), s = Math.sin(angle);
  const at = (u,v) => [x+u*c-v*s,y+u*s+v*c];
  p.poly([at(-length*.5,0),at(0,-width),at(length*.5,0),at(0,width)],C[1],alpha);
  p.poly([at(-length*.4,0),at(0,-width*.7),at(length*.4,0)],C[5],alpha);
  p.poly([at(-length*.4,0),at(length*.4,0),at(0,width*.7)],C[3],alpha);
}
function ray(p, angle, start, length, width, C, alpha) {
  const c=Math.cos(angle),s=Math.sin(angle);
  p.poly([[c*start-s*width,s*start+c*width],[c*(start+length),s*(start+length)],[c*start+s*width,s*start-c*width]],C[4],alpha);
  p.line(c*start,s*start,c*(start+length*.7),s*(start+length*.7),C[5],alpha);
}
function star(p,x,y,r,C,a=1) {
  p.line(x-r,y,x+r,y,C[4],a);p.line(x,y-r,x,y+r,C[4],a);
  p.dot(x,y,C[6],a); if(r>2) p.dot(x-1,y-1,C[5],a*.7);
}
function puff(p,x,y,r,C,a) {
  if(r<.5||a<=0)return;
  // Stepped warm shadow and a smaller top-left lobe retain volume at one pixel.
  p.disc(x,y,r,C[1],d=>a*(d<.72?.55:.22));
  p.disc(x-.5,y-1,r*.72,C[2],d=>a*(d<.7?.6:.25));
  p.disc(x-r*.2,y-r*.38,r*.48,C[3],d=>a*(1-d)*.55);
}
export function paint(kind,p,t,o) {
  const C=fit(o.palette,7),seed=o.seed,loop=["cold","charge","spark"].includes(kind);
  if(!loop&&(t<0||t>=1))return;
  const fade=(1-t)**1.35;
  if(kind==="muzzle") {
    const flash=Math.max(0,1-t/.45), L=17*(.7+.3*ease(Math.min(1,t*5)));
    if(flash>0) {
      for(const [a,l,w] of [[0,L,2.3],[-.63,10,1.4],[.54,8,1.2],[Math.PI,4,1]])ray(p,a,1,l*flash,w*flash,C,flash);
      p.poly([[-2*flash,0],[1,-2*flash],[6*flash,0],[1,2*flash]],WHITE);
      p.glow(4,0,11,C[4],.16*flash);
    }
    for(let i=0;i<4;i++){
      const a=(i-1.5)*.24,dist=5+ease(t)*19, x=Math.cos(a)*dist,y=Math.sin(a)*dist;
      p.line(x,y,x+4*fade,y+Math.sin(a)*3*fade,C[i%2?3:5],fade);
    }
    if(t>.1)for(let i=0;i<3;i++)puff(p,6+ease(t)*11-i*3,-t*8-i*2,1+t*2.4,C,Math.sin(t*Math.PI)*.28);
  } else if(kind==="impact") {
    const flash=Math.max(0,1-t/.26);
    if(flash>0){for(const [a,l,w] of [[0,17,1.6],[Math.PI,7,1.1],[-1.4,11,1.3],[1.6,7,1]])ray(p,a,0,l*(.65+.35*ease(t*3)),w*flash,C,flash);p.circle(0,0,Math.max(1,2*flash),WHITE);}
    for(let i=0;i<7;i++){
      const n=noise(i,seed),a=(n-.5)*1.8,d=(8+noise(i+9,seed)*18)*ease(t),x=Math.cos(a)*d,y=Math.sin(a)*d+t*t*5;
      p.line(x,y,x-3*fade*Math.cos(a),y-3*fade*Math.sin(a),i%3?C[3]:C[5],fade);
    }
  } else if(kind==="dust") {
    for(let i=0;i<8;i++){
      const side=i%2?1:-1,n=noise(i,seed),x=side*(3+ease(t)*(8+n*15)),y=-Math.sin(t*Math.PI)*(2+n*5)-1;
      puff(p,x,y,1.2+Math.sin(t*Math.PI)*(1+n*2),C,fade*.48);
      if(i<4)p.line(x,y-2,x-side*2,y-3,C[3],fade*.55);
    }
  } else if(kind==="recoil") {
    // Three unequal open air ribbons; no closed oval/arrow around the body.
    for(let i=0;i<3;i++){
      const x=3+ease(t)*(19+i*4),y=(i-1)*(6+Math.sin(t*Math.PI)*2),L=(9+i*3)*fade;
      p.poly([[x-L,y-1],[x,y],[x-L,y+1]],C[3],Math.min(1,fade*1.7));
      p.line(x-3*fade,y,x,y,C[5],fade*.65);
    }
    for(let i=0;i<3;i++)p.dot(6+ease(t)*(21+i*3),(i-1)*10,C[4],fade*.55);
  } else if(kind==="ice") {
    const core=Math.max(0,1-t/.2);if(core>0)star(p,0,0,4,C,core);
    for(let i=0;i<8;i++){
      const a=(i/8)*TAU+noise(i,seed)*.25,d=3+ease(t)*(9+noise(i+10,seed)*15);
      shard(p,Math.cos(a)*d,Math.sin(a)*d+t*t*4,(7+noise(i+20,seed)*7)*(1-t*.75),2.2*(1-t*.8),a+t*(i%2?2:-2),C,Math.min(1,fade*2));
    }
    if(t>.1)for(let i=0;i<3;i++)p.disc((i-1)*7,-t*6,1+t*4,C[3],(.1+.1*i)*fade);
  } else if(kind==="cold") {
    const ph=t*TAU;shard(p,0,0,13,2.6,0,C);
    p.line(-5,-1,5,-1,C[5]);p.dot(-2+Math.sin(ph)*4,0,WHITE);
    for(let i=0;i<4;i++){const k=fract(t+i/4),x=-4-k*17,y=Math.sin(k*4+i)*3;p.dot(x,y,C[4],(1-k)*.75);}
  } else if(kind==="collect") {
    for(let i=0;i<6;i++){
      const a=i*TAU/6-.3,d=3+ease(t)*17,x=Math.cos(a)*d,y=Math.sin(a)*d-t*7;
      star(p,x,y,(i%2?2:3)*fade,C,fade);
    }
    if(t<.28)star(p,0,0,3*(1-t/.28),C,1-t/.28);
  } else if(kind==="heal") {
    for(let side of [-1,1])for(let band=0;band<2;band++){
      const pts=[];for(let i=0;i<16;i++){const u=i/15,a=-.7+u*1.4,r=(7+ease(t)*27+band*3);pts.push([side*Math.cos(a)*r,Math.sin(a)*r*.7]);}
      for(let i=1;i<pts.length;i++)p.line(...pts[i-1],...pts[i],band?C[2]:C[5],fade*(.3+.5*Math.sin(i/16*Math.PI)));
    }
    for(let i=0;i<8;i++){const a=i*TAU/8+.2,d=6+ease(t)*29;star(p,Math.cos(a)*d,Math.sin(a)*d,1.5*fade,C,fade);}
  } else if(kind==="charge") {
    for(let i=0;i<12;i++){
      const u=fract(t+i/12),a=i*2.39996+.4*u,r=3+(1-u)*27,x=Math.cos(a)*r*.85,y=Math.sin(a)*r;
      p.line(x,y,x+Math.cos(a)*3,y+Math.sin(a)*3,C[3],Math.sin(u*Math.PI)*.55);p.dot(x,y,C[5],Math.sin(u*Math.PI));
    }
    p.circle(0,0,1.5+Math.sin(t*TAU)*.5,C[4]);p.dot(0,-1,C[5]);
  } else if(kind==="ember") {
    for(let i=0;i<9;i++){
      const a=i*TAU/9+noise(i,seed),d=(5+noise(i+9,seed)*20)*ease(t),x=Math.cos(a)*d,y=Math.sin(a)*d+t*t*10;
      p.line(x,y,x-Math.cos(a)*3*fade,y-Math.sin(a)*3*fade,C[i%3?3:5],fade);
    }
    for(let i=0;i<4;i++)puff(p,(i-1.5)*5*ease(t),-t*12,1+Math.sin(t*Math.PI)*4,C,fade*.32);
  } else if(kind==="dissolve") {
    for(let i=0;i<14;i++){
      const n=noise(i,seed),life=.5+n*.5;if(t>=life)continue;const u=t/life,x=(n-.5)*27+Math.sin(i+u*3)*u*7,y=-u*(10+noise(i+20,seed)*24),a=(1-u)**1.5;
      shard(p,x,y,1+2*a,1,i+u,C,a);if(i%5===0)star(p,x,y,2*a,C,a);
    }
  } else if(kind==="spark") {
    const ph=Math.floor(t*8);const pts=[];
    for(let i=0;i<9;i++)pts.push([-15+i*3.75,i===0||i===8?0:(noise(i+ph*11,seed)-.5)*6]);
    for(let i=1;i<pts.length;i++){p.line(...pts[i-1],...pts[i],C[2],.55);p.dot(...pts[i],C[5],.9);}
    const k=fract(t*2),x=-15+k*30;star(p,x,0,1.5,C,.8);
  }
}
