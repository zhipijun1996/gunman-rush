# Underworld reference evidence

## Pinned repository baseline

- Repository: https://github.com/zhipijun1996/gunman-rush
- Latest main verified through GitHub branch endpoint: `7d73389feab22224d0f8bd7c09325420a7605980`.
- Commit date: 2026-11-06T09:06:04Z.
- Commit: Merge PR #139, docs: 明确内容独立/共用边界与固定世界实施路线.
- Last modification of formal fine terrain PNG: `5ce3cd3d8771d6e44d00cc600b0a73ddb1e6b0a8`, 2026-10-22T18:57:06Z, “art: adopt fine pixel presentation and layered formal environments”.
- All repository source files in this directory were fetched read-only at the pinned main commit, not from a generated prior room mockup.

## Three distinct provenance categories

1. **Publisher original source retained in the repository**: Asouris, *Underworld Tileset*, https://asouris.itch.io/underworld-tileset . The repository's original source PNG is `assets/style_exploration/underworld/source/TileSet.png`; copied here as `asouris-underworld-original-tileset.png`. It is 176×144 RGBA and represents an original 16×16 tile language.
2. **Project derivative used by current formal terrain**: `assets/underworld_plains/terrain/fine_32/source.png` and `terrain.png`, copied here as `project-formal-fine32-source.png` and `project-formal-fine32-terrain.png`. These are authored/generated edits referring to the original source and game appearance, processed into native 32px source regions and 47-mask atlases. They are not Asouris's untouched 32px artwork. Exact generation/provenance is preserved in `project-authored-terrain-provenance.json`.
3. **Prior conversation room/region experiments**: sprites, paired backdrops and style-study scenes generated during our previous iterations. They are our candidate additions, not publisher originals and not evidence of formal game adoption.

## Representative pixel files

| Local file | Repository path | Native dimensions | SHA-256 |
|---|---|---|---|
| asouris-underworld-original-tileset.png | assets/style_exploration/underworld/source/TileSet.png | 176×144 | a369175ccef5fca5ab363f140252d1f0f38b5eafb5d541605c601ea4ac56f88c |
| project-formal-fine32-source.png | assets/underworld_plains/terrain/fine_32/source.png | 1056×288 | d08218cddd5b463a0ff033e3e5b1a260ed1280691d0b93d4565421c2f0f71431 |
| project-formal-fine32-terrain.png | assets/underworld_plains/terrain/fine_32/terrain.png | 768×192 | 267ba0fa45ec8c909d245d3d7a7b74aa98f464e9e6ac8bc1d671d180e35dd5de |

All three PNGs were opened and visually inspected. No image was repainted or edited for this reference set.

## Current runtime binding

The current `game/presentation/world/underworld_plains/underworld_terrain.gd` explicitly loads `fine_32/terrain_build.json`. Its opening lines are preserved in `underworld-terrain-consumer-excerpt.gd`.

- Texture region in `formal-fine32-terrain.tres`: Vector2i(32, 32).
- Manifest: tile_px 32, world_tile_wu 32.0, variant_count 3.
- 47 canonical neighbor masks per variant; three grass banks.
- Native sampling: 1 source px per world unit, nearest.
- Runtime mode: blob47 core with exact-boundary adapter.
- The old 16px source and old manifest remain historical sources; the top-level production manifest's historical path alone must not be treated as the live binding.
- A technical source binding and hash match are not evidence of user aesthetic acceptance.

## Shared region style, exact repository intent

`docs/bible/visual_bible.md` describes the common style as fine-grained fairy-tale pixel art, native32px/32wu terrain, 1wu world sampling and nearest, retaining Underworld material/lighting and the 47-neighbor/exact-boundary family.

`docs/data/creative_direction/bibles/style-continuity-20261102-v34-death-runtime.json` requires:
- Underworld family character/material/outline language, restrained warm point light, cool gray atmospheric perspective.
- Differentiate layers by value, saturation, silhouette, detail and parallax.
- Do not replace composition with fine noise and decoration everywhere.
- Forest regional character should come from bark, moss, thorns, organic roots/branches and regional colors. It needs related new materials and boundary matrices; recoloring plains stone is not sufficient.

Selected shared fields are saved in `shared-style-extract.json`.

## Visual observations (our analysis)

The direct formal fine32 reference is a restrained navy-charcoal mass with olive-gold grass on upward surfaces. Most of the terrain interior is quiet. Blue-slate material flecks are concentrated at outside edges and concave corners; the sides and underside do not carry a continuous bright green rim. Grass has small readable clustered growth and sparse bright tips. This supports a fusion based on refined local edge/corner pixel work plus deliberate larger room silhouettes. It does not support covering all surfaces with realistic pebble textures, carved gold pattern, bright moss borders or uniform microdetail.

## Publisher attribution and licensing evidence

Official publisher: Asouris. Official asset page: https://asouris.itch.io/underworld-tileset .

The repository's `source/licenses/NOTICE.md` states that the original archive supplied no standalone LICENSE; the author gave permissive use wording on the publisher page. The repository therefore labels the record “Custom permissive publisher statement; not CC0”. The text snapshot is preserved in `asouris-publisher-page-repository-snapshot.txt`.

The official page retrieved now also contains the CC BY 4.0 badge image `https://i.creativecommons.org/l/by/4.0/88x31.png`. The HTML snapshot is preserved as `asouris-official-page.html`; the badge appears as an image without an enclosing license hyperlink in the retrieved HTML. This additional current-page evidence is not reflected in the repository's older plain-text record. Do not describe the original asset as CC0. Keep publisher attribution and the source link when redistributing derivative references.

## Main source links

- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/assets/style_exploration/underworld/source/TileSet.png
- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/assets/style_exploration/underworld/source/licenses/NOTICE.md
- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/assets/underworld_plains/terrain/fine_32/terrain_build.json
- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/assets/authored_terrain_study/provenance.json
- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/game/presentation/world/underworld_plains/underworld_terrain.gd
- https://github.com/zhipijun1996/gunman-rush/blob/7d73389feab22224d0f8bd7c09325420a7605980/docs/data/creative_direction/bibles/style-continuity-20261102-v34-death-runtime.json

