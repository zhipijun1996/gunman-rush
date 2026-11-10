"""World review truth, disconnected trial scope, and exact source import gates."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/world"))
import workbench_apply as importer
from workbench_review import make_review_context
from workbench_scope import SCOPE_PATH, editable_room_ids, preview_navigation_geometry
from workbench_seed import CONFIG_FILES, digest


class WorldReviewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        read = lambda path: json.loads(path.read_text())
        cls.world = read(ROOT / "config/world/world.json")
        cls.construction = read(ROOT / "config/world/construction.json")
        cls.contracts = read(ROOT / "build/world/contracts.json")
        cls.runtime = read(ROOT / "build/world/runtime.json")
        cls.plains = {room["room_id"] for room in cls.construction["rooms"] if room["room_id"].startswith("P-R")}
        cls.review = cls.make_review()

    @classmethod
    def make_review(cls, **overrides):
        args = dict(root=ROOT, world=cls.world, construction=cls.construction,
                    contracts=cls.contracts, runtime=cls.runtime, editable_rooms=editable_room_ids(ROOT, cls.construction),
                    baseline="a" * 40)
        return make_review_context(**(args | overrides))

    def test_complete_authoritative_region_graph_is_only_a_summary(self):
        review = self.review
        self.assertEqual((16, 309, 38, 37, 6), tuple(review["counts"][key] for key in (
            "regions", "rooms", "region_connections", "editable_rooms", "implemented_rooms")))
        expected = {row["id"] for row in self.world["connections"]
                    if review["rooms"][row["a"]]["region"] != review["rooms"][row["b"]]["region"]}
        self.assertEqual(expected, {row["id"] for row in review["region_connections"]})
        for room in review["rooms"].values():
            self.assertNotIn("properties", room)
            self.assertNotIn("nodes", room)
        for region, original in zip(review["regions"], self.world["regions"]):
            self.assertEqual(original["pos"], region["pos"])

    def test_all_eight_plains_interfaces_have_real_paired_doors_and_no_fake_travel(self):
        links = [row for row in self.review["region_connections"] if "P" in (row["a_region"], row["b_region"])]
        self.assertEqual({"C01", "C02", "C03", "C04", "C05", "C06", "C07", "CITY-P-G-WEST"},
                         {row["id"] for row in links})
        for link in links:
            a, b = (link["endpoints"][side] for side in ("a", "b"))
            self.assertEqual((a["target_door_id"], b["target_door_id"]), (b["door_id"], a["door_id"]))
            self.assertFalse(link["implemented"])
            self.assertEqual(link["id"]=="C07",link["preview_available"])
            plains, outside = (a, b) if a["region"] == "P" else (b, a)
            self.assertTrue(plains["editor_available"])
            self.assertEqual(link["id"]=="C07",outside["editor_available"])
            self.assertFalse(outside["implemented"])
            self.assertIn(link["id"], self.review["rooms"][plains["room_id"]]["boundary_connection_ids"])
        c01 = next(link for link in links if link["id"] == "C01")["endpoints"]["a"]
        self.assertEqual(([1024, 1280], [128, 64], [1152, 1166]),
                         (c01["position"], c01["opening"], c01["landing_position"]))
        self.assertTrue(c01["coordinates_are_candidate"])

    def test_unknown_room_or_broken_pair_fails_closed(self):
        with self.assertRaisesRegex(ValueError, "unknown editable"):
            self.make_review(editable_rooms=editable_room_ids(ROOT, self.construction) | {"V-R999"})
        contracts = copy.deepcopy(self.contracts)
        room = next(row for row in contracts["rooms"] if row["room_id"] == "P-R04")
        door = next(row for row in room["doors"] if row["edge_id"] == "C01")
        door["target_door_id"] = "C01:wrong"
        with self.assertRaisesRegex(ValueError, "door pair disagrees"):
            self.make_review(contracts=contracts)

    def test_registered_trial_does_not_mark_its_neighbors_playable(self):
        review = self.make_review(editable_rooms=self.plains | {"V-R12","Z-R01"})
        self.assertEqual(37, review["counts"]["editable_rooms"])
        self.assertTrue(review["rooms"]["V-R12"]["preview_available"])
        self.assertFalse(review["rooms"]["V-R12"]["implemented"])
        self.assertFalse(review["rooms"]["V-R11"]["preview_available"])
        self.assertEqual(1, next(r for r in review["regions"] if r["code"] == "V")["preview_room_count"])

    def test_motion_evidence_keeps_measured_commit_and_rejects_changed_sources(self):
        motion = {"samples": [{"label": "existing measurement"}],
                  "source_hashes": {"config/player_tuning.json": digest(ROOT / "config/player_tuning.json")}}
        previous = {"source_commit": "b" * 40, "motion_reference": motion}
        review = self.make_review(previous=previous)
        self.assertEqual("b" * 40, review["motion_reference"]["measured_source_commit"])
        self.assertEqual("a" * 40, review["source_commit"])
        previous["motion_reference"]["source_hashes"]["config/player_tuning.json"] = "0" * 64
        self.assertNotIn("motion_reference", self.make_review(previous=previous))

    def test_projection_never_changes_source_or_formal_runtime(self):
        originals = [self.world, self.construction, self.contracts, self.runtime]
        before = copy.deepcopy(originals)
        self.make_review(editable_rooms=self.plains | {"V-R12","Z-R01"})
        self.assertEqual(before, originals)


class WorkbenchScopeTests(unittest.TestCase):
    def test_registry_admits_only_known_explicit_rooms(self):
        construction = {"rooms": [{"room_id": room_id} for room_id in ("P-R01", "V-R12", "F-R01")]}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.assertEqual({"P-R01"}, editable_room_ids(root, construction))
            path = root / SCOPE_PATH
            path.parent.mkdir(parents=True)
            for additional, expected in [(["V-R12"], {"P-R01", "V-R12"}), (["V-R99"], None),
                                         (["P-R01"], None), (["V-R12", "V-R12"], None)]:
                path.write_text(json.dumps({"schema": 1, "additional_room_ids": additional}))
                if expected is None:
                    with self.assertRaises(ValueError): editable_room_ids(root, construction)
                else:
                    self.assertEqual(expected, editable_room_ids(root, construction))

    def test_disconnected_trial_uses_its_own_component_origin(self):
        def room():
            return {"doors": [], "world_geometry": {"space_rects": [[0, 0, 320, 320]], "bounds_world_units": [0, 0, 320, 320]}}
        geometry = preview_navigation_geometry({"P-R03": room(), "V-R12": room()}, "P-R03")
        self.assertEqual([0, 0], geometry["P-R03"]["origin"])
        self.assertEqual([0, 0], geometry["V-R12"]["origin"])
        self.assertEqual(("P-R03", "V-R12"), (geometry["P-R03"]["map_component"], geometry["V-R12"]["map_component"]))

    def test_original_plains_seam_conflicts_are_still_rejected(self):
        contracts = json.loads((ROOT / "build/world/contracts.json").read_text())
        rooms = {row["room_id"]: row for row in contracts["rooms"] if row["room_id"].startswith("P-R")}
        door = next(row for row in rooms["P-R22"]["doors"] if row["target_room"] == "P-R23")
        door["position_candidate"]["local_world_units"][1] += 16
        with self.assertRaisesRegex(ValueError, "seam conflicts"):
            preview_navigation_geometry(rooms, "P-R03")

    def test_import_admits_registered_trial_and_requires_its_scope_hash(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            files = ["config/world/" + name for name in CONFIG_FILES] + ["v12.tscn", "v13.tscn"]
            for relative in files:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(relative)
            (root / SCOPE_PATH).parent.mkdir(parents=True)
            (root / SCOPE_PATH).write_text(json.dumps({"schema": 1, "additional_room_ids": ["V-R12"]}))
            (root / "build/world").mkdir(parents=True)
            (root / "build/world/runtime.json").write_text(json.dumps({"content_version": "original"}))
            construction = {"rooms": [{"room_id": room_id, "scene_ref": "res://" + path}
                                       for room_id, path in (("V-R12", "v12.tscn"), ("V-R13", "v13.tscn"))]}
            hashes = {relative: digest(root / relative) for relative in files + [SCOPE_PATH]}
            package = {"schema": importer.SCHEMA, "revision": 1, "baseline": "a" * 40,
                       "source_hashes": hashes, "base_content_version": "original", "rooms": {"V-R12": {
                           "schema": 1, "room_id": "V-R12", "revision": 1, "base_content_version": "original",
                           "source_hash": hashes["v12.tscn"]}}}
            with patch.object(importer.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
                self.assertIn("V-R12", importer.verify_baseline(root, package, construction))
                del hashes[SCOPE_PATH]
                with self.assertRaisesRegex(importer.ImportRejected, "required source hashes"):
                    importer.verify_baseline(root, package, construction)
                hashes[SCOPE_PATH] = digest(root / SCOPE_PATH)
                package["rooms"]["V-R13"] = {**package["rooms"]["V-R12"], "room_id": "V-R13", "source_hash": hashes["v13.tscn"]}
                with self.assertRaisesRegex(importer.ImportRejected, "out-of-scope"):
                    importer.verify_baseline(root, package, construction)


if __name__ == "__main__":
    unittest.main()
