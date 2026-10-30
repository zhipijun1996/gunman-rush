extends RefCounted
## Pinned artifact identity, shared by assembly and the native run manifest.
const ROOT := "res://third_party/mapgen/0.1.0"
const MAP_PATH := ROOT + "/maps/seed-930001.json"
const MANIFEST_SHA256 := "bef5b567fcd367913be474a02df3bdbb62cf8c8d2902c380861055f272e9cbc0"
const MAP_SHA256 := "fa0d6644187999252ce0fd6355ce58e8ba5533a0ec6d837516cab70fb65e3be4"

static func receipt() -> Dictionary:
	return {"delivery_version":"0.1.0", "seed":930001, "map_sha256":MAP_SHA256, "manifest_sha256":MANIFEST_SHA256}

static func host_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://config/mapgen_930001.json"))
