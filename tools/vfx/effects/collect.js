import { metadata, paint } from "./_lib.js";
export const meta = metadata("collect", "Accepted pickup", [64, 64], [32, 34], 0.36, false);
export function draw(p, t, o) { paint("collect", p, t / meta.duration, o); }
