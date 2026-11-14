import { meta as metadata, coin } from "./_renewal.js";
export const meta=metadata("coin-turn",[24, 24],[12, 12],1.0,true);
export function draw(p,t,o){ coin(p,t/meta.duration,o); }
