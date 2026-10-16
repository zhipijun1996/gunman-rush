#!/usr/bin/env python3
"""Read-only measurement of the unchanged AI source; never writes image pixels."""
import hashlib
import json
from pathlib import Path

from PIL import Image


def measure():
    family = Path(__file__).resolve().parents[1]
    source = family / "source.png"
    contract = json.loads((family / "production/frozen_contract.json").read_text())
    image = Image.open(source)
    alpha = image.getchannel("A")
    width, height = image.size
    measurements = {}
    split = height // 2 - 64  # 448 at this source: within the observed alpha>=2 gap.
    for threshold in contract["alpha_measurements"]:
        binary = alpha.point(lambda value: 255 if value >= threshold else 0)
        rows = [binary.crop((0, y, width, y + 1)).getbbox() is not None for y in range(height)]
        runs = []
        start = None
        for y, occupied in enumerate(rows + [False]):
            if occupied and start is None:
                start = y
            elif not occupied and start is not None:
                runs.append([start, y])
                start = None
        upper = binary.crop((0, 0, width, split)).getbbox()
        lower_local = binary.crop((0, split, width, height)).getbbox()
        lower = (lower_local[0], lower_local[1] + split, lower_local[2], lower_local[3] + split)
        measurements[str(threshold)] = {
            "whole_bbox_xyxy": binary.getbbox(),
            "occupied_row_runs_half_open": runs,
            "upper_bbox_xyxy": upper,
            "lower_bbox_xyxy": lower,
            "clear_fullwidth_rows_between_observed_main_bands": max(0, lower[1] - upper[3]),
        }
    body = measurements["128"]
    heights = {}
    for key, bbox_key in [("far", "upper_bbox_xyxy"), ("middle_far", "lower_bbox_xyxy")]:
        x0, y0, x1, y1 = body[bbox_key]
        definition = contract[key]
        value = definition["world_width"] * (y1 - y0) / (x1 - x0)
        heights[key] = {"world_width": definition["world_width"], "world_height": value,
                        "frozen_range": definition["world_visible_height_range"],
                        "passed": definition["world_visible_height_range"][0] <= value <= definition["world_visible_height_range"][1]}
    whole = measurements["1"]["whole_bbox_xyxy"]
    padding = [whole[0], whole[1], width - whole[2], height - whole[3]]
    return {"schema_version": 1, "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "source_dimensions": list(image.size), "source_mode": image.mode,
            "alpha_extrema": alpha.getextrema(), "split_y_for_measurement_only_not_crop": split,
            "alpha": measurements, "strict_alpha0_outer_padding_ltrb": padding,
            "strict_padding_minimum": contract["required_outer_strict_alpha0_padding_px_at_width1536"] * width / 1536,
            "strict_gap_minimum": contract["required_strict_alpha0_fullwidth_gap_px_at_width1536"] * width / 1536,
            "visible_height_at_uniform_world_width": heights,
            "result": "REJECT", "failure_reasons": [
                "Strict alpha>=1 tails overlap across both body bands and touch bottom canvas; outer padding fails.",
                "Alpha>=2 gutter is only2px and alpha>=128 gutter15px, below frozen120px; no threshold relaxed.",
                "Both visible bodies exceed their frozen uniform-scale world-height ranges."
            ], "image_mutation_performed": False,
            "scope": "Original-source numeric gate only; no Godot/Atlas extraction/GPU/gameplay acceptance."}


if __name__ == "__main__":
    print(json.dumps(measure(), ensure_ascii=False, indent=2))
