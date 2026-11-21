import { metadata, paint } from "./_lib.js";
export const meta = metadata("ember", "Warm blast debris", [80, 80], [40, 36], 0.5, false);
export function draw(p, t, o) { paint("ember", p, t / meta.duration, o); }
