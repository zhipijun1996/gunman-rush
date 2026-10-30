"""Read a delivery package into map-gen's prototype.model template convention.

Does not call generate.prepare_library (which replaces templates with mocks).
map-gen owns complete-content mirroring, Port selection and gear closures.
Structural validation never certifies a newly generated placement.
"""

import hashlib, json
from pathlib import Path

ABILITY = {"shot_recoil": "recoil"}


def read_library(root):
    root = Path(root)
    manifest = json.loads((root / "manifest.json").read_text())
    for name, digest in manifest["files"].items():
        if Path(name).is_absolute() or ".." in Path(name).parts:
            raise ValueError("unsafe_package_path")
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != digest:
            raise ValueError("changed_package_file:" + name)
    catalog = json.loads((root / "catalog.json").read_text())
    result = {}
    for entry in catalog["modules"]:
        mid = entry["id"]
        if mid in result:
            raise ValueError("duplicate_module_id:" + mid)
        bs = entry["blockSize"]
        bounds = entry["bounds"]
        ports = []
        for p in entry["ports"]:
            at = p["position"]
            xy = [at[k] for k in ["x", "y"]] if isinstance(at, dict) else at
            local2 = [2 * (xy[i] - bounds[k]) / bs for i, k in enumerate(["x", "y"])]
            if any(abs(v - round(v)) > 1e-8 for v in local2):
                raise ValueError("non_block_port:" + mid + ":" + p["id"])
            ports.append(
                dict(
                    id=p["id"],
                    face=p["face"],
                    local2=[round(v) for v in local2],
                    surface=p["surface"],
                    permission=p["permission"],
                    closure=None,
                    initial_permission_conditions={
                        **p.get("initialPermissionConditions", {}),
                        **(
                            {
                                "availableAbilitiesExact": [
                                    ABILITY.get(v, v)
                                    for v in p["initialPermissionConditions"][
                                        "availableAbilitiesExact"
                                    ]
                                    if v != "move"
                                ]
                            }
                            if p.get("initialPermissionConditions", {}).get(
                                "availableAbilitiesExact"
                            )
                            is not None
                            else {}
                        ),
                    },
                )
            )
        pp = {p["id"]: p for p in ports}
        routes = []
        for r in entry["routes"]:
            a, b = pp[r["from"]], pp[r["to"]]
            # Initial one-way interfaces are not inferred from later mechanism states.
            if a["permission"] == "OUTPUT" or b["permission"] == "INPUT":
                continue
            caps = r["validation"]["availableAbilities"]
            routes.append(
                dict(
                    id=r["id"],
                    from_port=r["from"],
                    to_port=r["to"],
                    displacement=[
                        (b["local2"][i] - a["local2"][i]) / 2 for i in [0, 1]
                    ],
                    required_abilities=[ABILITY.get(v, v) for v in caps if v != "move"],
                    action_tags=r.get("actionTags", []),
                    difficulty=r["difficulty"].get("score"),
                    estimated_duration=r.get("durationSeconds"),
                    resource_profile=r.get("resourceProfile"),
                    initial_conditions=r.get("initialConditions"),
                    entry_exit_contract=r.get("transfer"),
                    validation=r["validation"],
                    capability_requirements=r["capabilityRequirements"],
                )
            )
        result[mid] = dict(
            id=mid,
            name=entry["title"],
            size_blocks=entry["sizeBlocks"],
            ports=ports,
            routes=routes,
            reward_sites=entry["reward_sites"],
            reward=bool(entry["reward_sites"]),
            purpose=entry["purpose"],
            entry_port_ids=entry["entryPortIds"],
            certification=dict(
                status="NATIVE_SCOPED",
                routes=True,
                seams=False,
                closures="UNKNOWN",
                mirror="UNKNOWN",
                configurations=entry["configurations"],
            ),
            content_version=entry["contentVersion"],
            scene=entry["scene"],
            scene_origin_offset=entry["sceneOriginOffsetPixels"],
            block_size=bs,
            package_version=manifest["version"],
            initial_configuration=entry["initialConfiguration"],
            host_profile=entry["hostProfile"],
        )
    return result


def validate_placement(
    template, connected_port_ids, mirror=False, relocations=(), closures=()
):
    """Check IDs only. map-gen must materialize and validate its complete instance."""
    if relocations:
        raise ValueError("unknown_interface_layout")
    if not isinstance(mirror, bool):
        raise ValueError("mirror_must_be_boolean")
    if len(connected_port_ids) != len(set(connected_port_ids)):
        raise ValueError("duplicate_connected_port")
    all_ports = {p["id"] for p in template["ports"]}
    connected = set(connected_port_ids)
    if not connected <= all_ports:
        raise ValueError("unknown_connected_port")
    if (
        len(closures) != len(set(closures))
        or not set(closures) <= all_ports - connected
    ):
        raise ValueError("invalid_unused_port_closure")
    return "base"


def routes_for_abilities(
    template, available, native_profile_id=None, connected_port_ids=None, mirror=False
):
    """Only exact witnessed ability sets; minimum requirements are not certified."""
    available = set(available) - {"move"}
    config = template["initial_configuration"]
    profile = config.get("nativeFixture") or config.get("nativeTuning")
    if profile and profile.get("id") != native_profile_id:
        return []
    ports = {p["id"]: p for p in template["ports"]}
    connected = set(ports) if connected_port_ids is None else set(connected_port_ids)
    validate_placement(template, list(connected), mirror=mirror)
    candidates = [
        r
        for r in template["routes"]
        if r["from_port"] in connected
        and r["to_port"] in connected
        and set(r["required_abilities"]) == available
        and all(
            p.get("initial_permission_conditions", {}).get("availableAbilitiesExact")
            is None
            or set(p["initial_permission_conditions"]["availableAbilitiesExact"])
            == available
            for p in [ports[r["from_port"]], ports[r["to_port"]]]
        )
    ]
    if mirror or connected != set(ports):
        return [
            {
                **r,
                "validation": {
                    **r["validation"],
                    "status": "UNKNOWN",
                    "originalStatus": r["validation"]["status"],
                    "configurationNote": "Endpoint filter only: map-gen must mirror complete content and check gear closures against the remaining route. Original evidence is unchanged.",
                },
            }
            for r in candidates
        ]
    return candidates
