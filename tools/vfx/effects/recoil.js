import { metadata, paint } from "./_lib.js";
export const meta = metadata("recoil", "Recoil air", [80, 48], [40, 24], 0.22, false);
export function draw(p, t, o) { paint("recoil", p, t / meta.duration, o); }
