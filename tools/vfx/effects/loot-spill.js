import { meta as metadata, spill } from "./_renewal.js";
export const meta=metadata("loot-spill",[96, 80],[48, 48],0.38,false);
export function draw(p,t,o){ spill(p,t/meta.duration,o); }
