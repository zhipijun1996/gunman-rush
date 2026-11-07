#!/usr/bin/env python3
"""Build editable Godot nodes from the shared art-study data and native sprites."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
from PIL import Image
from pathlib import Path

HERE = Path(__file__).resolve().parent


def q(value):
    return json.dumps(str(value), ensure_ascii=False)


def num(value):
    value = float(value)
    return str(int(value)) if value.is_integer() else format(value, ".8g")


def rnd(value):
    return math.floor(float(value) + 0.5)


def vec(value):
    return "Vector2(" + ", ".join(num(x) for x in value) + ")"


def poly(value):
    return "PackedVector2Array(" + ", ".join(num(c) for p in value for c in p) + ")"


def color(value, alpha=1):
    if isinstance(value, str):
        value = value.lstrip("#")
        value = [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return "Color(" + ", ".join(num(x) for x in value[:3]) + ", " + num(alpha) + ")"


def identifier(value):
    return re.sub(r"[^A-Za-z0-9_]", "_", value)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize_mask(mask):
    for corner, a, b in [(2, 1, 4), (8, 4, 16), (32, 16, 64), (128, 64, 1)]:
        if not mask & a or not mask & b:
            mask &= ~corner
    return mask


def grid_for(data, region):
    return region.get("terrainGrid", data.get("terrainGrid"))


def geometry_for(data, region):
    grid = grid_for(data, region)
    if not grid:
        bodies = region.get("terrain", data.get("terrain", []))
        return {"grid": False, "bodies": bodies, "surfaces": [{"left": t["top"][0][0], "right": t["top"][-1][0], "y": t["top"][0][1]} for t in bodies]}
    tile, origin = int(grid.get("tile", 32)), grid.get("origin", [0, 0])
    cells = set(tuple(c) for c in grid["cells"])
    rows, tops = {}, {}
    for x, y in cells:
        rows.setdefault(y, []).append(x)
        if (x, y - 1) not in cells:
            tops.setdefault(y, []).append(x)

    def runs(collection):
        result = []
        for y, xs in sorted(collection.items()):
            xs = sorted(set(xs))
            left, right = xs[0], xs[0] + 1
            for x in xs[1:]:
                if x == right:
                    right += 1
                else:
                    result.append([left, y, right])
                    left, right = x, x + 1
            result.append([left, y, right])
        return result

    rectangles, active = [], {}
    for x, y, right in runs(rows):
        key = (x, right)
        prior = active.get(key)
        if prior is not None and prior[3] == y:
            prior[3] += 1
        else:
            rect = [x, y, right, y + 1]
            rectangles.append(rect)
            active[key] = rect
    bodies = []
    for i, r in enumerate(rectangles):
        left, top = origin[0] + r[0] * tile, origin[1] + r[1] * tile
        right, bottom = origin[0] + r[2] * tile, origin[1] + r[3] * tile
        bodies.append({"id": "grid-" + str(i), "top": [[left, top], [right, top]], "points": [[left, top], [right, top], [right, bottom], [left, bottom]]})
    surfaces = [{"left": origin[0] + x * tile, "right": origin[0] + right * tile, "y": origin[1] + y * tile} for x, y, right in runs(tops)]
    return {"grid": True, "tile": tile, "origin": origin, "bodies": bodies, "surfaces": surfaces}


class Builder:
    def __init__(self, data, manifest):
        self.data, self.manifest = data, manifest
        self.externals, self.subresources, self.nodes = [], [], []
        self.cache, self.regions = {}, {}
        self.placements, self.sprite_count = [], 0
        self.light_records, self.occluder_records, self.layer_records = [], [], []
        self.material_cache, self.light_texture_cache = {}, {}
        self.geometry = {r["id"]: geometry_for(data, r) for r in data["regions"]}
        self.collision_count = 0

    def ext(self, resource, kind="Texture2D"):
        key = (resource, kind)
        if key not in self.cache:
            ref = "Resource_" + str(len(self.externals))
            self.externals.append(f'[ext_resource type={q(kind)} path={q(resource)} id={q(ref)}]')
            self.cache[key] = f'ExtResource({q(ref)})'
        return self.cache[key]

    def sub(self, kind, values):
        ref = "Sub_" + str(len(self.subresources))
        text = [f'[sub_resource type={q(kind)} id={q(ref)}]']
        text.extend(f'{key} = {value}' for key, value in values.items())
        self.subresources.append("\n".join(text))
        return f'SubResource({q(ref)})'

    def node(self, name, kind, parent=".", **values):
        header = f'[node name={q(name)} type={q(kind)}'
        if parent is not None:
            header += " parent=" + q(parent)
        header += "]"
        self.nodes.append(header + "\n" + "\n".join(f'{key} = {value}' for key, value in values.items()))

    def texture(self, asset, crop=None):
        frame = self.manifest["sprites"][asset]
        base = self.ext("res://" + frame["file"])
        if crop is None:
            return base
        key = (asset, tuple(crop))
        if key not in self.regions:
            self.regions[key] = self.sub("AtlasTexture", {
                "atlas": base,
                "region": "Rect2(" + ", ".join(num(x) for x in crop) + ")",
                "filter_clip": "true",
            })
        return self.regions[key]

    def sprite(self, name, parent, asset, origin, crop=None, flip=False, **extra):
        self.node(name, "Sprite2D", parent, position=vec(origin), centered="false", texture=self.texture(asset, crop), flip_h="true" if flip else "false", **extra)
        self.sprite_count += 1

    def terrain_spec(self, region):
        if grid_for(self.data, region):
            return self.manifest["terrain47"]["regions"][region["id"]]
        return self.manifest.get("terrains", {}).get(region["id"], self.manifest.get("terrain"))

    def grid_terrain(self, region, parent):
        grid, spec = grid_for(self.data, region), self.terrain_spec(region)
        tile, origin = int(grid.get("tile", 32)), grid.get("origin", [0, 0])
        self.node("Terrain47", "TileMapLayer", parent,
                  position=vec((origin[0], origin[1] - spec.get("surfaceY", 0))),
                  tile_set=self.ext("res://terrain47/" + region["id"] + ".tres", "TileSet"),
                  script=self.ext("res://grid_terrain.gd", "Script"), region_id=q(region["id"]),
                  collision_enabled="false", occlusion_enabled="false", navigation_enabled="false")
        cells = set(tuple(c) for c in grid["cells"])
        neighbors = [(0, -1, 1), (1, -1, 2), (1, 0, 4), (1, 1, 8), (0, 1, 16), (-1, 1, 32), (-1, 0, 64), (-1, -1, 128)]
        for cx, cy in grid["cells"]:
            mask = normalize_mask(sum(bit for dx, dy, bit in neighbors if (cx + dx, cy + dy) in cells))
            atlas = spec["maskToAtlas"][str(mask)]
            self.placements.append({"region": region["id"], "terrain": "grid", "asset": "terrain47_" + region["id"], "x": origin[0] + cx * tile, "y": origin[1] + cy * tile - spec.get("surfaceY", 0), "source": [atlas[0] * tile, atlas[1] * tile, tile, tile], "cell": [cx, cy], "mask": mask, "pass": "terrain47"})

    def depth_material(self, layer, region):
        mask = layer.get("mask")
        if not mask:
            return self.unshaded()
        # These pixels encode clipping geometry, not environment artwork.
        width, height = int(self.data["viewport"]["width"]), int(self.data["viewport"]["height"])
        image = Image.new("RGBA", (width + 128, height), (255, 255, 255, 255))
        spans = self.geometry[region["id"]]["surfaces"]
        if mask.get("type") == "platform_band" and spans:
            under = [s for s in spans if s["left"] <= layer["x"] <= s["right"]]
            surface = mask.get("surfaceY", min(under or spans, key=lambda s: abs(s["y"] - layer["y"]))["y"])
            fade, above, below = max(1, mask.get("edgeFade", 8)), mask.get("above", 72), mask.get("below", 72)
            clamp = lambda n: max(0, min(1, n))
            horizontal = []
            for x in range(-64, width + 64):
                support = 0
                for s in spans:
                    if abs(s["y"] - surface) > 16:
                        continue
                    left, right = (-64 if s["left"] <= 0 else s["left"]), (width + 64 if s["right"] >= width else s["right"])
                    support = max(support, min(clamp((x - left) / fade), clamp((right - x) / fade)))
                horizontal.append(support)
            pixels = image.load()
            for y in range(height):
                vertical = clamp((y - (surface - above)) / fade) * clamp((surface + below - y) / fade)
                base = clamp((y - surface + 12) / 20)
                row_intervals = []
                for body in self.geometry[region["id"]]["bodies"]:
                    if body["points"][0][1] <= y < body["points"][2][1]:
                        row_intervals.append([body["points"][0][0], body["points"][1][0]])
                merged = []
                for interval in sorted(row_intervals):
                    if merged and interval[0] <= merged[-1][1]:
                        merged[-1][1] = max(merged[-1][1], interval[1])
                    else:
                        merged.append(interval[:])
                for x, support in enumerate(horizontal):
                    if y >= surface:
                        world_x, solid = x - 64, 0
                        for x0, x1 in merged:
                            left, right = (-64 if x0 <= 0 else x0), (width + 64 if x1 >= width else x1)
                            solid = max(solid, min(clamp((world_x - left) / fade), clamp((right - world_x) / fade)))
                        support = min(support, solid)
                    pixels[x, y] = (255, 255, 255, rnd(255 * vertical * (1 - base + base * support)))
        relative = "generated/masks/" + region["id"] + "_" + identifier(layer["id"]) + ".png"
        target = HERE / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        reveal = mask.get("heroReveal", {})
        return self.sub("ShaderMaterial", {
            "shader": self.ext("res://depth_mask.gdshader", "Shader"),
            "shader_parameter/platform_mask": self.ext("res://" + relative),
            "shader_parameter/mask_origin": vec((-64, 0)),
            "shader_parameter/mask_size": vec((width + 128, height)),
            "shader_parameter/hero_center": vec((self.data["hero"]["x"] - 8, self.data["hero"]["y"] - 22)),
            "shader_parameter/hero_radius": vec((reveal.get("radiusX", 30), reveal.get("radiusY", 48))),
            "shader_parameter/hero_min_alpha": num(reveal.get("minAlpha", 0.15)),
            "shader_parameter/has_reveal": "true" if reveal else "false",
        })

    def unshaded(self, additive=False):
        if additive not in self.material_cache:
            self.material_cache[additive] = self.sub("CanvasItemMaterial", {
                "light_mode": "1",
                "blend_mode": "1" if additive else "0",
            })
        return self.material_cache[additive]

    def radial_texture(self, glow=False):
        if glow not in self.light_texture_cache:
            values = [1.0, 0.65, 0.18, 0.0]
            colors = []
            for value in values:
                colors.extend([1.0, 1.0, 1.0, value] if glow else [value, value, value, 1.0])
            gradient = self.sub("Gradient", {
                "offsets": "PackedFloat32Array(0, 0.25, 0.6, 1)",
                "colors": "PackedColorArray(" + ", ".join(num(x) for x in colors) + ")",
            })
            self.light_texture_cache[glow] = self.sub("GradientTexture2D", {
                "gradient": gradient,
                "width": "256",
                "height": "256",
                "fill": "1",
                "fill_from": vec((0.5, 0.5)),
                "fill_to": vec((1.0, 0.5)),
            })
        return self.light_texture_cache[glow]

    def terrain(self, terrain, region, parent):
        if self.terrain_spec(region):
            self.native_terrain(terrain, region, parent)
            return
        frame = self.manifest["sprites"][region["terrainAsset"]]
        name = identifier(terrain["id"])
        left = rnd(min(p[0] for p in terrain["points"]))
        right = rnd(max(p[0] for p in terrain["points"]))
        bottom = rnd(max(p[1] for p in terrain["points"]))
        surface = rnd(terrain["top"][0][1])
        if any(rnd(p[1]) != surface for p in terrain["top"]):
            raise ValueError("This local art-study builder expects flat top edges: " + terrain["id"])
        w, h = int(frame["w"]), int(frame["h"])
        surface_y = int(frame.get("surfaceY", 12))
        asset = region["terrainAsset"]
        path = parent + "/" + name
        self.node(name, "Node2D", parent)
        self.node("Body", "Polygon2D", path, polygon=poly(terrain["points"]), color=color(region["palette"]["ground"]), clip_children="2")
        self.node("GrassEdge", "Node2D", path)
        origin_x = left + rnd(terrain.get("textureOffsetX", 0))
        for index, x in enumerate(range(origin_x, right, w)):
            y = surface - surface_y
            self.sprite("Slab" + str(index), path + "/Body", asset, (x, y))
            clipped_x = max(left, x)
            width = min(right, x + w) - clipped_x
            source_x = clipped_x - x
            if width > 0:
                self.sprite("Tip" + str(index), path + "/GrassEdge", asset, (clipped_x, y), crop=(source_x, 0, width, min(h, surface_y + 1)))
            self.placements.append({"region": region["id"], "terrain": terrain["id"], "asset": asset, "x": x, "y": y, "native_width": w, "native_height": h, "surfaceY": surface_y})
            # Extend deep interiors only with the existing slab's body pixels.
            body_y = min(h - 1, surface_y + 4)
            body_h = h - body_y
            row = 0
            next_y = y + h
            while next_y < bottom:
                self.sprite("Depth" + str(index) + "_" + str(row), path + "/Body", asset, (x, next_y), crop=(0, body_y, w, body_h))
                next_y += body_h
                row += 1

    def native_terrain(self, terrain, region, parent):
        spec = self.terrain_spec(region)
        tile, bank = int(spec["tile"]), int(region.get("terrainBank", spec.get("bank", 0)))
        left, right = rnd(terrain["top"][0][0]), rnd(terrain["top"][-1][0])
        surface = rnd(terrain["top"][0][1])
        if any(rnd(p[1]) != surface for p in terrain["top"]) or right - left < tile * 2:
            raise ValueError("Native tile study requires a horizontal platform at least two tiles wide.")
        top = surface - int(spec["surfaceY"])
        bottom = rnd(max(p[1] for p in terrain["points"]))
        path = parent + "/" + identifier(terrain["id"])
        self.node(identifier(terrain["id"]), "Node2D", parent)
        records = []

        def add(kind, x, y, w=tile, h=tile):
            coord = spec["coords"][kind]
            source = [(coord[0] + bank * int(spec.get("bankColumns", 8))) * tile, coord[1] * tile, w, h]
            records.append({"terrain": terrain["id"], "asset": spec["asset"], "x": x, "y": y, "source": source, "pass": "native-tile"})

        def row(y, h, left_kind, center_kind, right_kind):
            add(left_kind, left, y, tile, h)
            for x in range(left + tile, right - tile, tile):
                add(center_kind, x, y, min(tile, right - tile - x), h)
            add(right_kind, right - tile, y, tile, h)

        row(top, tile, "tl", "t", "tr")
        for y in range(top + tile, bottom, tile):
            row(y, min(tile, bottom - y), "l", "i", "r")
        row(bottom, tile, "bl", "b", "br")
        for i, record in enumerate(records):
            self.sprite("Tile" + str(i), path, spec["asset"], (record["x"], record["y"]), crop=record["source"])
            self.placements.append({"region": region["id"], **record})
            width = int(self.data["viewport"]["width"])
            if record["x"] == 0:
                self.sprite("CameraPadLeft" + str(i), path, spec["asset"], (-record["source"][2], record["y"]), crop=record["source"], flip=True)
            if record["x"] + record["source"][2] == width:
                self.sprite("CameraPadRight" + str(i), path, spec["asset"], (width, record["y"]), crop=record["source"], flip=True)

    def prop(self, instance, parent):
        frame = self.manifest["sprites"][instance["asset"]]
        pivot_x = int(instance.get("pivotX", frame.get("pivotX", rnd(frame["w"] / 2))))
        pivot_y = int(instance.get("pivotY", frame.get("pivotY", frame["h"])))
        flip = bool(instance.get("flip"))
        x, y = rnd(instance["x"]) - (int(frame["w"]) - pivot_x if flip else pivot_x), rnd(instance["y"]) - pivot_y
        name = identifier(instance["id"])
        metadata = {"metadata/asset": q(instance["asset"]), "metadata/anchor": vec((instance["x"], instance["y"])), "metadata/landmark": "true" if instance.get("landmark") else "false"}
        if "opacity" in instance:
            metadata["modulate"] = color([1, 1, 1], instance["opacity"])
        if instance.get("sway", 0):
            h = int(frame["h"])
            tip = max(1, math.floor(h * 0.55))
            self.node(name, "Node2D", parent, position=vec((x, y)), script=self.ext("res://pixel_sway.gd", "Script"), amplitude=num(instance["sway"]), phase=num(instance.get("phase", 0)), sprite_height=str(h), world_anchor_x=num(instance["x"]), top_y=num(y), **metadata)
            for row in range(tip):
                self.sprite("Row" + str(row), parent + "/" + name, instance["asset"], (0, row), crop=(0, row, int(frame["w"]), 1), flip=bool(instance.get("flip")), **{"metadata/base_position": vec((0, row))})
            self.sprite("Root", parent + "/" + name, instance["asset"], (0, tip), crop=(0, tip, int(frame["w"]), h - tip), flip=bool(instance.get("flip")), **{"metadata/base_position": vec((0, tip))})
        else:
            self.sprite(name, parent, instance["asset"], (x, y), flip=flip, **metadata)

    def depth_layer(self, layer, region, parent):
        frame = self.manifest["sprites"][layer["asset"]]
        px = layer.get("pivotX", frame.get("pivotX", rnd(frame["w"] / 2)))
        py = layer.get("pivotY", frame.get("pivotY", frame["h"]))
        flip = bool(layer.get("flip", False))
        origin = (rnd(layer["x"]) - (int(frame["w"]) - px if flip else px), rnd(layer["y"]) - py)
        parallax = float(layer.get("parallax", 1.10 if layer["kind"] == "near" else 0.45))
        tint, opacity = layer.get("tint", [1, 1, 1]), float(layer.get("opacity", 1))
        name = identifier(layer["id"])
        self.sprite(name, parent, layer["asset"], origin, flip=flip, material=self.depth_material(layer, region), light_mask="0", visible="true" if layer.get("visible", True) else "false", modulate=color(tint, opacity), **{
            "metadata/asset": q(layer["asset"]), "metadata/layer_id": q(layer["id"]), "metadata/base_position": vec(origin), "metadata/parallax": num(parallax), "metadata/base_tint": color(tint, opacity), "metadata/layer_ambient": color(layer.get("ambient", region.get("lighting", {}).get("backgroundAmbient", [1, 1, 1])))})
        self.layer_records.append({"region": region["id"], "id": layer["id"], "asset": layer["asset"], "kind": layer["kind"], "x": origin[0], "y": origin[1], "parallax": parallax, "tint": tint, "opacity": opacity, "mask": layer.get("mask")})

    def lighting(self, region, parent):
        spec = region.get("lighting", {})
        self.node("Lighting", "Node2D", parent)
        path = parent + "/Lighting"
        self.node("Lights", "Node2D", path)
        self.node("Occluders", "Node2D", path)
        self.node("Cores", "Node2D", path, z_index="24")
        self.node("Beams", "Node2D", path, z_index="-35")
        for i, light in enumerate(spec.get("lights", [])):
            name = identifier(light.get("id", "Light" + str(i)))
            origin = (rnd(light["x"]), rnd(light["y"]))
            self.node(name, "PointLight2D", path + "/Lights", position=vec(origin), texture=self.radial_texture(), texture_scale=num(float(light["radius"]) / 128.0), color=color(light.get("color", [1, 1, 1])), energy=num(light.get("energy", 1.0)), shadow_enabled="true" if light.get("shadow", True) else "false", shadow_filter="0", range_item_cull_mask="1", range_z_min="-30", range_z_max="22", **{"metadata/light_index": str(i), "metadata/base_energy": num(light.get("energy", 1)), "metadata/flicker": num(light.get("flicker", 0)), "metadata/light_id": q(light.get("id", name))})
            self.light_records.append({"region": region["id"], "id": light.get("id", name), "x": origin[0], "y": origin[1], "radius": light["radius"], "color": light.get("color", [1, 1, 1]), "energy": light.get("energy", 1), "shadow": light.get("shadow", True)})
            if light.get("visible", True) and float(light.get("coreRadius", 2)) > 0:
                core_parent = path + "/Cores/" + name
                self.node(name, "Node2D", path + "/Cores", position=vec(origin), **{"metadata/light_index": str(i), "metadata/flicker": num(light.get("flicker", 0))})
                radius = min(float(light["radius"]) * 0.22, 28.0)
                self.node("AirGlow", "Sprite2D", core_parent, texture=self.radial_texture(True), scale=vec((radius / 128.0, radius / 128.0)), material=self.unshaded(True), modulate=color(light.get("color", [1, 1, 1]), min(0.2, 0.10 * float(light.get("energy", 1)))))
                core = max(1, rnd(light.get("coreRadius", 2)))
                self.node("Core", "Polygon2D", core_parent, polygon=poly([(-core, -core), (core, -core), (core, core), (-core, core)]), color=color([min(1.0, 0.75 + 0.25 * x) for x in light.get("color", [1, 1, 1])]), material=self.unshaded())
        inset = float(spec.get("shadowInset", 10))
        side_inset = float(spec.get("shadowSideInset", 2))
        occluders = []
        geometry = self.geometry[region["id"]]
        for terrain in geometry["bodies"]:
            if geometry["grid"]:
                left, top = terrain["points"][0]
                right, bottom = terrain["points"][2]
                exposed = [s for s in geometry["surfaces"] if s["y"] == top and s["right"] > left and s["left"] < right]
                cuts = sorted(set([left, right] + [p for s in exposed for p in [max(left, s["left"]), min(right, s["right"])]]))
                for part, (x0, x1) in enumerate(zip(cuts, cuts[1:])):
                    middle = (x0 + x1) / 2
                    is_open = any(s["left"] <= middle < s["right"] for s in exposed)
                    y = top + (min(inset, bottom - top - 1) if is_open else 0)
                    occluders.append({"id": terrain["id"] + "-" + str(part), "points": [(x0, y), (x1, y), (x1, bottom), (x0, bottom)]})
                continue
            left, right = rnd(terrain["top"][0][0] + (0 if geometry["grid"] else side_inset)), rnd(terrain["top"][-1][0] - (0 if geometry["grid"] else side_inset))
            top = rnd(terrain["top"][0][1] + (0 if geometry["grid"] else inset))
            bottom = rnd(max(p[1] for p in terrain["points"]))
            if not geometry["grid"]:
                bottom = max(bottom, int(self.data["viewport"]["height"]) + 256)
            occluders.append({"id": terrain["id"], "points": [(left, top), (right, top), (right, bottom), (left, bottom)]})
        for i, extra in enumerate(spec.get("occluders", [])):
            points = extra.get("points", []) if isinstance(extra, dict) else extra
            occluders.append({"id": extra.get("id", "extra" + str(i)) if isinstance(extra, dict) else "extra" + str(i), "points": points})
        for i, occluder in enumerate(occluders):
            points = [(rnd(p[0]), rnd(p[1])) for p in occluder["points"]]
            if len(points) < 3:
                continue
            shape = self.sub("OccluderPolygon2D", {"polygon": poly(points), "closed": "true", "cull_mode": "0"})
            self.node("Occluder" + str(i), "LightOccluder2D", path + "/Occluders", occluder=shape, occluder_light_mask="1", **{"metadata/occluder_id": q(occluder["id"])})
            self.occluder_records.append({"region": region["id"], "id": occluder["id"], "points": points})
        for i, beam in enumerate(spec.get("beams", [])):
            points = [(rnd(p[0]), rnd(p[1])) for p in beam["points"]]
            min_y, max_y = min(p[1] for p in points), max(p[1] for p in points)
            colors = []
            for point in points:
                colors.extend([1, 1, 1, 1 - (point[1] - min_y) / max(1, max_y - min_y)])
            self.node("Beam" + str(i), "Polygon2D", path + "/Beams", polygon=poly(points), color=color(beam.get("color", [1, 1, 1]), beam.get("alpha", 0.06)), vertex_colors="PackedColorArray(" + ", ".join(num(v) for v in colors) + ")", material=self.unshaded(True))

    def contact_shadows(self, region, parent):
        self.node("ContactShadows", "Node2D", parent, z_index="2")
        for index, terrain in enumerate(self.geometry[region["id"]]["surfaces"]):
            left, right, surface = float(terrain["left"]), float(terrain["right"]), float(terrain["y"])
            name = "Surface" + str(index)
            path = parent + "/ContactShadows/" + name
            self.node(name, "Polygon2D", parent + "/ContactShadows", polygon=poly([(left, surface), (right, surface), (right, surface + 4), (left, surface + 4)]), color=color([1, 1, 1]), clip_children="1")
            for instance in region.get("instances", []):
                if not (left <= float(instance["x"]) <= right and abs(float(instance["y"]) - surface) <= 10):
                    continue
                frame = self.manifest["sprites"][instance["asset"]]
                w, h = int(frame["w"]), int(frame["h"])
                pivot = int(instance.get("pivotX", frame.get("pivotX", rnd(w / 2))))
                flip = bool(instance.get("flip"))
                x = rnd(instance["x"]) - (w - pivot if flip else pivot)
                strip_h = min(h, 8)
                self.sprite("Foot_" + identifier(instance["id"]), path, instance["asset"], (x, rnd(surface) - 1), crop=(0, h - strip_h, w, strip_h), flip=flip, scale=vec((1, 3 / strip_h)), modulate=color([4 / 255, 8 / 255, 13 / 255], 0.32), material=self.unshaded())

    def build(self):
        self.node("ArtStudy", "Node2D", None, texture_filter="1", script=self.ext("res://study.gd", "Script"))
        initial_region = next((region for region in self.data["regions"] if region["id"] == self.data.get("defaultRegion", "mushroom_caverns")), self.data["regions"][0])
        initial_lighting = initial_region.get("lighting", {})
        self.node("Ambient", "CanvasModulate", color=color(initial_lighting.get("ambient", [1, 1, 1])))
        self.node("Camera", "Camera2D", position=vec((self.data["viewport"]["width"] / 2, self.data["viewport"]["height"] / 2)), position_smoothing_enabled="false")
        self.node("Geometry", "Node2D")
        for region in self.data["regions"]:
            region_path = "Geometry/" + identifier(region["id"])
            self.node(identifier(region["id"]), "Node2D", "Geometry")
            for terrain in self.geometry[region["id"]]["bodies"]:
                name = identifier(terrain["id"])
                self.node(name, "StaticBody2D", region_path, collision_layer="1" if region["id"] == initial_region["id"] else "0", collision_mask="0", **{"metadata/terrain_id": q(terrain["id"])})
                self.node("Collision", "CollisionPolygon2D", region_path + "/" + name, polygon=poly(terrain["points"]))
                self.collision_count += 1
        self.node("Regions", "Node2D")
        group_z = {"structure": -20, "terrain": 0, "detail": 4, "attached": 12, "foreground": 18}
        for i, region in enumerate(self.data["regions"]):
            name = identifier(region["id"])
            parent = "Regions/" + name
            self.node(name, "Node2D", "Regions", visible="true" if region["id"] == initial_region["id"] else "false", **{"metadata/region_id": q(region["id"])})
            background = self.manifest["backgrounds"][region["background"]]
            self.node("Background", "Sprite2D", parent, centered="false", texture=self.ext("res://" + background["file"]), z_index="-40", material=self.unshaded(), light_mask="0", modulate=color(region.get("lighting", {}).get("backgroundAmbient", [1, 1, 1])))
            self.sprite_count += 1
            bg_texture = self.ext("res://" + background["file"])
            width, height = int(background["w"]), int(background["h"])
            for edge, sx, dx in [("Left", 0, -32), ("Right", width - 32, width)]:
                strip = self.sub("AtlasTexture", {"atlas": bg_texture, "region": f"Rect2({sx}, 0, 32, {height})", "filter_clip": "true"})
                self.node("CameraPad" + edge, "Sprite2D", parent + "/Background", position=vec((dx, 0)), centered="false", texture=strip, flip_h="true", material=self.unshaded(), light_mask="0")
                self.sprite_count += 1
            self.node("Midground", "Node2D", parent, z_index="-34")
            self.node("Nearground", "Node2D", parent, z_index="30")
            for layer in region.get("layers", []):
                self.depth_layer(layer, region, parent + ("/Nearground" if layer["kind"] == "near" else "/Midground"))
            for group, z_index in group_z.items():
                self.node(group.title(), "Node2D", parent, z_index=str(z_index))
            if grid_for(self.data, region):
                self.grid_terrain(region, parent + "/Terrain")
            else:
                for terrain in self.geometry[region["id"]]["bodies"]:
                    self.terrain(terrain, region, parent + "/Terrain")
            for instance in region["instances"]:
                self.prop(instance, parent + "/" + instance["group"].title())
            self.contact_shadows(region, parent)
            self.lighting(region, parent)
            self.node("Particles", "Node2D", parent, z_index="20", material=self.unshaded(True), script=self.ext("res://wind_particles.gd", "Script"), region_id=q(region["id"]))
        hero = self.data["hero"]
        frame = self.manifest["sprites"][hero["asset"]]
        shape = self.sub("RectangleShape2D", {"size": vec((18, 40))})
        self.node("Traveler", "CharacterBody2D", z_index="8", script=self.ext("res://traveler.gd", "Script"), spawn_position=vec((hero["x"], hero["y"])), world_width=num(self.data["viewport"]["width"]), fall_limit=num(self.data["viewport"]["height"] + 90), collision_layer="2", collision_mask="1", floor_snap_length="6.0")
        self.node("Collision", "CollisionShape2D", "Traveler", position=vec((0, -20)), shape=shape)
        self.node("Visual", "Node2D", "Traveler")
        self.sprite("Sprite2D", "Traveler/Visual", hero["asset"], (-frame["pivotX"], -frame["pivotY"]), light_mask="3")
        self.node("ReadabilityFill", "PointLight2D", "Traveler/Visual", position=vec((-8, -22)), color=color([1, 0.96, 0.86]), texture=self.radial_texture(), texture_scale="0.5", energy=num(initial_lighting.get("heroFill", 0.25)), range_item_cull_mask="2", shadow_enabled="false", **{"metadata/purpose": q("Readability fill restricted to hero mask; no visible air halo")})
        self.node("Interface", "CanvasLayer")
        self.node("RegionSelect", "OptionButton", "Interface", offset_left="10.0", offset_top="8.0", offset_right="210.0", offset_bottom="38.0", focus_mode="0", **{"theme_override_font_sizes/font_size": "13"})
        self.node("Help", "Label", "Interface", offset_left="10.0", offset_top="43.0", offset_right="628.0", offset_bottom="94.0", text=q(""), **{"theme_override_colors/font_color": color("f0e3c8"), "theme_override_colors/font_shadow_color": color("172b35"), "theme_override_constants/shadow_offset_x": "1", "theme_override_constants/shadow_offset_y": "1", "theme_override_font_sizes/font_size": "13"})
        count = len(self.externals) + len(self.subresources) + 1
        return f'[gd_scene load_steps={count} format=3]\n\n' + "\n\n".join(self.externals + self.subresources + self.nodes) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path)
    parser.add_argument("--manifest", type=Path)
    options = parser.parse_args()
    data_path = options.data or (HERE.parent / "study.json" if (HERE.parent / "study.json").exists() else HERE / "assets/study.json")
    manifest_path = options.manifest or (HERE.parent / "assets/pixel/manifest.json" if (HERE.parent / "assets/pixel/manifest.json").exists() else HERE / "assets/pixel/manifest.json")
    data, manifest = json.loads(data_path.read_text()), json.loads(manifest_path.read_text())
    source_root = manifest_path.resolve().parents[2]
    has_grid = any(grid_for(data, region) for region in data["regions"])
    if has_grid:
        atlas_file = source_root / "assets/terrain47/manifest.json"
        if not atlas_file.is_file():
            atlas_file = HERE / "assets/terrain47-manifest.json"
        manifest["terrain47"] = json.loads(atlas_file.read_text())
        (HERE / "assets").mkdir(exist_ok=True)
        (HERE / "assets/terrain47-manifest.json").write_text(json.dumps(manifest["terrain47"], ensure_ascii=False, indent=2) + "\n")
    used_sprites = {data["hero"]["asset"]}
    used_backgrounds = set()
    for region in data["regions"]:
        if not grid_for(data, region):
            used_sprites.add(manifest["terrains"][region["id"]]["asset"])
        used_sprites.update(i["asset"] for i in region.get("instances", []))
        used_sprites.update(i["asset"] for i in region.get("layers", []))
        used_backgrounds.add(region["background"])
    files = [manifest["sprites"][name]["file"] for name in sorted(used_sprites)] + [manifest["backgrounds"][name]["file"] for name in sorted(used_backgrounds)]
    copied = {}
    for relative in sorted(set(files)):
        source, target = source_root / relative, HERE / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.resolve() != target.resolve():
            shutil.copyfile(source, target)
        copied[relative] = digest(target)
    (HERE / "assets").mkdir(exist_ok=True)
    for source, target in [(data_path, HERE / "assets/study.json"), (manifest_path, HERE / "assets/pixel/manifest.json")]:
        if source.resolve() != target.resolve():
            shutil.copyfile(source, target)
    builder = Builder(data, manifest)
    (HERE / "study.tscn").write_text(builder.build())
    (HERE / "assets/geometry.json").write_text(json.dumps(builder.geometry, ensure_ascii=False, indent=2) + "\n")
    (HERE / "terrain-placements.json").write_text(json.dumps(builder.placements, ensure_ascii=False, indent=2) + "\n")
    (HERE / "lighting-placements.json").write_text(json.dumps({"lights": builder.light_records, "occluders": builder.occluder_records}, ensure_ascii=False, indent=2) + "\n")
    (HERE / "depth-placements.json").write_text(json.dumps(builder.layer_records, ensure_ascii=False, indent=2) + "\n")
    info = {"data_sha256": digest(data_path), "manifest_sha256": digest(manifest_path), "viewport": data["viewport"], "sprites": builder.sprite_count, "regional_collision_bodies": builder.collision_count, "active_collision_bodies": len(builder.geometry[data.get("defaultRegion", data["regions"][0]["id"])]["bodies"]), "region_count": len(data["regions"]), "terrain47_layers": sum(bool(grid_for(data, r)) for r in data["regions"]), "independent_depth_layers": len(builder.layer_records), "point_lights": len(builder.light_records) + 1, "light_occluders": len(builder.occluder_records), "files": copied, "scene_sha256": digest(HERE / "study.tscn")}
    (HERE / "build-info.json").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"scene": str(HERE / "study.tscn"), "sprites": builder.sprite_count, "regions": len(data["regions"]), "point_lights": len(builder.light_records) + 1, "light_occluders": len(builder.occluder_records), "regional_collision_bodies": builder.collision_count}, ensure_ascii=False))


if __name__ == "__main__":
    main()
