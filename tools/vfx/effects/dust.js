import { metadata, paint } from "./_lib.js";
export const meta = metadata("dust", "Grounded dust", [72, 40], [36, 30], 0.36, false);
export function draw(p, t, o) { paint("dust", p, t / meta.duration, o); }
