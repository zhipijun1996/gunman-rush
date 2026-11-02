class_name WindchimeTerrain
extends RefCounted
## New visual family, shared topology and collision implementation.
const ATLAS := preload("res://assets/windchime_plains/limestone_blob47.svg")

static func build(cells: Dictionary, seed_text: String) -> TileMapLayer:
	return Blob47Terrain.build(cells, seed_text, ATLAS, &"windchime_stone")
