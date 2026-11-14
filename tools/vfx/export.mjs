#!/usr/bin/env node
// Godot SpriteFrames export, with anchors and optional independent render passes.
// The upstream Aseprite JSON is retained; Godot does not import it by itself.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve, join, relative, sep } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";
import { createHash } from "node:crypto";

const root = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const checkout = process.argv[2];
if (!checkout) throw new Error("Use python3 tools/vfx/pixelfx.py export <effect id> [--split]");
const { loadEffect, resolveIds, renderFrames, spriteSheet, save } = await import(pathToFileURL(join(checkout, "tools/lib/fxlib.mjs")));
const { createFrame, clearFrame, createFx, composite } = await import(pathToFileURL(join(checkout, "src/core/index.js")));
const ids = [], flags = {};
for (let i = 3; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a === "--split") flags.split = true;
  else if (["--out", "--opts", "--fps", "--seed"].includes(a)) flags[a.slice(2)] = process.argv[++i];
  else if (a.startsWith("--")) throw new Error(`Unknown export option: ${a}`);
  else ids.push(a);
}
if (!ids.length) throw new Error("Choose effect IDs or the gunman category; exporting all references is not a game build.");
const output = resolve(flags.out ?? join(root, "assets/vfx"));
if (!output.startsWith(root + sep)) throw new Error("Export destination must be inside the project.");
const opts = { ...(flags.fps ? { fps: +flags.fps } : {}), ...(flags.seed ? { seed: +flags.seed } : {}), options: JSON.parse(flags.opts ?? "{}"), actor: false };
if (opts.fps !== undefined && (!Number.isInteger(opts.fps) || opts.fps < 1 || opts.fps > 120)) throw new Error("fps must be an integer from 1 to 120");
if (opts.seed !== undefined && !Number.isFinite(opts.seed)) throw new Error("seed must be finite");
let count = 0;

function dependencies(file, result = {}) {
  const key = relative(checkout, file).split(sep).join("/");
  if (result[key]) return result;
  const source = readFileSync(file, "utf8");
  result[key] = createHash("sha256").update(source).digest("hex");
  for (const match of source.matchAll(/from\s+["'](\.[^"']+)["']/g)) dependencies(fileURLToPath(new URL(match[1], pathToFileURL(file))), result);
  return result;
}

function resource(fx, name, r, filename) {
  const lines = [`[gd_resource type="SpriteFrames" load_steps=${r.n + 2} format=3]`, "", `[ext_resource type="Texture2D" path="res://${relative(root, filename).split(sep).join("/")}" id="1"]`, ""];
  const sheet = spriteSheet(fx, r, name);
  sheet.json.frames.forEach((frame, i) => {
    const f = frame.frame;
    lines.push(`[sub_resource type="AtlasTexture" id="Frame_${i}"]`, 'atlas = ExtResource("1")', `region = Rect2(${f.x}, ${f.y}, ${f.w}, ${f.h})`, "filter_clip = true", "");
  });
  lines.push("[resource]", "animations = [{", '"frames": [', ...sheet.json.frames.map((_, i) => `{ "duration": 1.0, "texture": SubResource("Frame_${i}") }${i < r.n - 1 ? "," : ""}`), '],', `"loop": ${fx.meta.loop},`, '"name": &"default",', `"speed": ${r.fps}.0`, "}]", `metadata/pivot = Vector2(${fx.meta.origin.join(", ")})`, `metadata/frame_size = Vector2(${fx.meta.size.join(", ")})`, "");
  return { sheet, tres: lines.join("\n") };
}

function splitFrames(fx, r) {
  const [w, h] = fx.meta.size, [x, y] = fx.meta.origin;
  const inst = createFx(fx.mod, { x, y, ...(opts.seed !== undefined ? { seed: opts.seed } : {}), ...opts.options });
  const frame = createFrame(w, h), empty = new Uint32Array(w * h), passes = {};
  for (const side of ["back", "front"]) for (const buffer of ["color", "light"]) passes[`${side}-${buffer}`] = { ...r, frames: [] };
  for (let i = 0; i < r.n; i++) {
    if (i) inst.update(1 / r.fps);
    for (const side of ["back", "front"]) {
      clearFrame(frame); inst.draw(frame, side);
      for (const buffer of ["color", "light"]) {
        const isolated = { ...frame, [buffer === "color" ? "light" : "color"]: empty };
        passes[`${side}-${buffer}`].frames.push({ clear: composite(isolated, new Uint8ClampedArray(w * h * 4), null) });
      }
    }
  }
  return passes;
}

for (const id of resolveIds(ids)) {
  const fx = await loadEffect(id);
  if (fx.mod.act?.onBody) throw new Error(`${id} paints a stock body. Adapt it to the project silhouette before export.`);
  const r = renderFrames(fx, opts), name = id.split("/").join("-"), directory = join(output, name);
  mkdirSync(directory, { recursive: true });
  const manifest = { upstream: "https://github.com/patch-gg/pixelfx", revision: "5294518ce7c72e48b6100a744596e0acf57f2826", effect: id, source_sha256: createHash("sha256").update(readFileSync(fx.file)).digest("hex"), source_dependencies: dependencies(fx.file), options: opts, pivot: fx.meta.origin, passes: {} };
  const passes = { combined: r, ...(flags.split ? splitFrames(fx, r) : {}) };
  for (const [pass, frames] of Object.entries(passes)) {
    const basename = pass === "combined" ? name : `${name}-${pass}`, png = join(directory, `${basename}.png`);
    const { sheet, tres } = resource(fx, basename, frames, png);
    save(png, sheet.png); save(join(directory, `${basename}.json`), JSON.stringify(sheet.json, null, 2) + "\n");
    save(join(directory, `${basename}.tres`), tres);
    manifest.passes[pass] = `${basename}.tres`;
  }
  writeFileSync(join(directory, "source.json"), JSON.stringify(manifest, null, 2) + "\n");
  console.log(`${id}: ${r.n} frames, pivot ${fx.meta.origin}, ${Object.keys(passes).length} pass(es) -> ${relative(root, directory)}`);
  count++;
}
if (!count) throw new Error("No effects matched.");
