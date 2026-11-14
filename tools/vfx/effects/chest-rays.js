import { meta as metadata, treasure } from "./_renewal.js";
export const meta=metadata("chest-rays",[144, 112],[72, 96],0.9,false);
export function draw(p,t,o){ treasure(p,t/meta.duration,o); }
