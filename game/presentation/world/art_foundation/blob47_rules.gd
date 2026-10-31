class_name Blob47Rules
extends RefCounted
## This bit order is a public, versioned atlas contract. Never use old catalogs.
const VERSION := "blob47-v1"
const CELL := 32
const SOURCE_SIZE := 64
const GUTTER := 2
const PITCH := SOURCE_SIZE + GUTTER * 2
const COLUMNS := 8
const VARIANTS := 3
const DECORATION_PROFILE := {
	"id": "garden-sparse-v1", "threshold_per_thousand": 590,
	"min_spacing": 46.0, "screen_cells": Vector2i(40, 23),
	"max_props_per_screen_bucket": 12, "max_lamps_per_screen_bucket": 2,
	"lamp_spacing": 160.0, "glow_radius": 50.0, "glow_alpha": .25
}
const OFFSETS := [Vector2i(0,-1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
const CORNERS := [[2,1,4], [8,4,16], [32,16,64], [128,64,1]]

static func canonical_mask(raw: int) -> int:
	var mask := raw & 255
	for rule: Array in CORNERS:
		if (mask & int(rule[1])) == 0 or (mask & int(rule[2])) == 0:
			mask &= ~int(rule[0])
	return mask

static func catalog_masks() -> Array[int]:
	var result: Array[int] = []
	for raw: int in 256:
		if canonical_mask(raw) == raw:
			result.append(raw)
	return result

static func mask_at(cells: Dictionary, cell: Vector2i) -> int:
	if not cells.has(cell): return 0
	var raw := 0
	for index: int in OFFSETS.size():
		var other: Vector2i = cell + OFFSETS[index]
		# Different materials do not silently join a terrain family.
		if cells.has(other) and cells[other] == cells[cell]: raw |= 1 << index
	return canonical_mask(raw)

static func atlas_index(mask: int) -> int:
	return catalog_masks().find(mask)

static func variant_at(seed_text: String, cell: Vector2i) -> int:
	return posmod((seed_text + ":tile:" + str(cell.x) + ":" + str(cell.y)).hash(), VARIANTS)

static func atlas_coords(mask: int, variant: int = 0) -> Vector2i:
	var index := atlas_index(mask)
	assert(index >= 0 and variant >= 0 and variant < VARIANTS)
	return Vector2i(index % COLUMNS, index / COLUMNS + variant * 6)
