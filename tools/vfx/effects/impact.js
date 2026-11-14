// Direct recipe adaptation of pixelfx impacts/hit-spark, MIT Patch / Hugo Duprez.
import { create as hit, meta as reference } from '../impacts/hit-spark.js';
export const meta={...reference,name:'Tearing directional impact',desc:'Asymmetric cross flare, flying hot chips, direction preserved.',size:[136,112],origin:[48,56],duration:.28,fps:60,options:{...reference.options,height:0,aim:0,seed:4}};
export function create(o){const fx=hit(o);let t=0;return{update(dt){t+=dt;fx.update(dt*.5/.28);},draw(p){if(t<meta.duration)fx.draw(p);}};}
