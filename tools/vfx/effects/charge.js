import { metadata, paint } from "./_lib.js";
export const meta = metadata("charge", "Inward resonance", [80, 80], [40, 40], 0.8, true);
export function draw(p, t, o) { paint("charge", p, t / meta.duration, o); }
