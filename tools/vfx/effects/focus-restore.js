import { meta as metadata, restore } from "./_renewal.js";
export const meta=metadata("focus-restore",[112, 96],[56, 72],0.46,false);
export function draw(p,t,o){ restore(p,t/meta.duration,o); }
