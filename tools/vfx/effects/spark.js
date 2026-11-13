import { metadata, paint } from "./_lib.js";
export const meta = metadata("spark", "Contact current", [48, 24], [24, 12], 0.8, true);
export function draw(p, t, o) { paint("spark", p, t / meta.duration, o); }
