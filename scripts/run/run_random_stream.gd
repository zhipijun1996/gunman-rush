class_name RunRandomStream
extends RefCounted

# Counter-mode SHA256; the first 52 bits are exact on JS-number platforms.
const ALGORITHM := "sha256_counter_52_v1"
const DERIVATION_VERSION := 1
var _key := ""
var _counter := 0

func _init(root_seed := "0", stream_namespace := "map", stable_stage_id := "stage_1", content_version := "demo_v1") -> void:
	_key = JSON.stringify([root_seed, stream_namespace, stable_stage_id, content_version, DERIVATION_VERSION])

func next_int(limit: int) -> int:
	if limit <= 0:
		return -1
	var digest := (_key + ":" + str(_counter)).sha256_text()
	_counter += 1
	return digest.substr(0, 13).hex_to_int() % limit

func position() -> int:
	return _counter
