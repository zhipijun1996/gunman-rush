// Flash lobes and merged curling smoke adapted from pixelfx projectiles/muzzle-pistol.
// Sprite Fusion muzzle-flash, MIT, Copyright (c) 2026 Hugo Duprez.
import { Rng, rng, WHITE, fit } from '../../core/index.js';
import { flashShape, flash, Smoke, cloud } from '../projectiles/_lib.js';
export const meta={name:'Ragged pistol ignition',desc:'White core, orange ragged lobes, dark red rim; curling gas and independently dying embers.',tags:['gunman','muzzle'],size:[112,80],origin:[32,44],duration:.32,loop:false,fps:60,bg:'dark',options:{seed:19,design:2}};
export function create(o){
 const R=new Rng(o.seed),S=new Smoke(R),C=fit(['#3d211c','#7c3320','#d36423','#f5a237','#ffe49a','#fff6ce',WHITE],7);
 for(let i=0;i<11;i++)S.add({x:2,y:0,vx:100-i*5,vy:-5-i*2,r0:1,r1:3.5+i*.12,life:.24+i*.005,a:.58,drag:7,rise:32,curl:-3.5,delay:i*.004,warm:.7});
 let t=0;return {update(dt){t+=dt;S.update(dt);},draw(p){if(t>=meta.duration)return;
  const fade=(1-t/meta.duration)**1.1;
  cloud(p,S.puffs(),fit(['#302e34','#504750','#72616a','#a3938b','#d9b88e'],5),C,{dens:1.5,max:.65,lit:1.4});
  if(t<.075){const f=t<.033?1:2,shape=flashShape(rng(77),f,{size:o.design===0?.9:o.design===1?1.25:1.05,spike:[24,33],diag:[11,17],cross:[7,10],back:[3,5]});flash(p,0,0,-.05,shape,f===1?[WHITE,C[5],C[4],C[2]]:[C[5],C[4],C[3],C[1]],f+o.seed);}
  for(let i=0;i<7;i++){const a=(i-3)*.18,dist=7+t*(65+i*12),x=Math.cos(a)*dist,y=Math.sin(a)*dist+t*t*35;p.line(x,y,x-3*fade,y,C[i%3?3:5],fade);}
  p.glow(7,0,24,C[3],.55*Math.exp(-t/.028));
 }};
}
