import { metadata, paint } from "./_lib.js";
export const meta = metadata("heal", "Resonance release", [96, 80], [48, 40], 0.44, false);
export function draw(p, t, o) { paint("heal", p, t / meta.duration, o); }
