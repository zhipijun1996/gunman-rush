import { metadata, paint } from "./_lib.js";
export const meta = metadata("muzzle", "Brass muzzle", [64, 40], [20, 20], 0.18, false);
export function draw(p, t, o) { paint("muzzle", p, t / meta.duration, o); }
