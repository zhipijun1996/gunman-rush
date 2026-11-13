import { metadata, paint } from "./_lib.js";
export const meta = metadata("impact", "Directional contact", [72, 64], [32, 30], 0.26, false);
export function draw(p, t, o) { paint("impact", p, t / meta.duration, o); }
