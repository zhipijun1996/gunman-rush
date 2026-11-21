import { metadata, paint } from "./_lib.js";
export const meta = metadata("ice", "Faceted ice burst", [80, 80], [40, 38], 0.3, false);
export function draw(p, t, o) { paint("ice", p, t / meta.duration, o); }
