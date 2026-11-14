import { metadata, paint } from "./_lib.js";
export const meta = metadata("dissolve", "Clockwork dissolve", [64, 80], [32, 58], 0.9, false);
export function draw(p, t, o) { paint("dissolve", p, t / meta.duration, o); }
