# Painted plains object candidates

These three PNGs are original unchanged image_gen outputs for the polished plains golden sample, not final user-approved runtime replacements. `generation_inputs.json` records exact prompts, generated source paths and flower retries; `manifest.json` records hashes, measured alpha bounds and candidate anchors.

| Asset | Canvas | Candidate anchor | Intended use |
| --- | --- | --- | --- |
| saw.png | 1254 × 1254 | (626.5, 617.5), wheel center | Programmatically rotated circular hazard skin; existing collision unchanged |
| checkpoint.png | 1312 × 1199 | (656, 1125), base center | Segment maintenance checkpoint; distinct from Home flower meaning |
| flowers.png | 1329 × 1183 | (727.5, 1130), base center | Sparse plains floral decoration; not a checkpoint or resource indicator |

## Verification and remaining work

Pillow was used only to inspect dimensions, alpha histogram and alpha ≥128 bounds. All delivered PNGs were byte-for-byte copied; no cropping, recoloring, compositing or alpha repair was performed. Alpha values ≥250 cover most visible painted interiors; full-alpha255 counts alone would be misleading. Low-alpha dust and colored edge fringe remain, requiring deep/light background and actual scale review. Texture regions may exclude distant dust without editing originals.

The first flower candidate and one AI editing retry retained a broad luminous halo and were not selected. A fresh botanical generation removed the broad aura; its more natural flower styling still needs visual review within a complete gameplay scene. Original retries remain in generated_images with provenance recorded.

Saw highlights are directional and will rotate with the painted texture; rotation-center accuracy and lighting consistency remain unverified in the game. Checkpoint chimes are painted as one static object, not separated animation parts. Neither dimensions nor alpha bounds define collision, checkpoint interactions or resource semantics. Random-map placement must use declared decorative safe zones and existing functional instance anchors. Device performance and final visual approval remain pending.
