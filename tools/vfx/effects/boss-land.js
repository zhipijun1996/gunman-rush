import { meta as metadata, landing } from "./_renewal.js";
export const meta=metadata("boss-land",[256, 96],[128, 80],0.8,false);
export function draw(p,t,o){ landing(p,t/meta.duration,o); }
