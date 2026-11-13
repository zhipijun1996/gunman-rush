import { metadata, paint } from "./_lib.js";
export const meta = metadata("cold", "Ice core and wake", [56, 24], [32, 12], 0.8, true);
export function draw(p, t, o) { paint("cold", p, t / meta.duration, o); }
