"""Counterexamples for exact source import and all-or-nothing publication."""
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
from workbench_seed import CONFIG_FILES, digest, reward_view


class WorkbenchApplyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = ROOT / "config/world"
        cls.world = json.loads((source / "world.json").read_text())
        cls.design = json.loads((source / "collection_design.json").read_text())
        cls.construction = json.loads((source / "construction.json").read_text())

    def test_geometry_update_preserves_authored_camera_zones_and_links(self):
        construction = copy.deepcopy(self.construction)
        row = next(r for r in construction["rooms"] if r["room_id"] == "P-R22")
        camera = copy.deepcopy(row["camera"])
        # Door-free fixture isolates geometry ownership from door relocation.
        row["doors"] = []
        row["entry_spawns"] = []
        row["terrain_failure"]["challenge_entries"] = []
        package = {"rooms": {"P-R22": {"geometry": {
            "bounds": [0, 0, *row["extent"]], "space_rects": row["space_rects"], "doors": []}}}}
        importer.update_geometry(construction, package, {"rooms": {"P-R22": {"doors": []}}})
        self.assertEqual(camera, row["camera"])
        self.assertNotIn("zone_intents", row["camera"])

    def reward_fixture(self, reward_id="TG01"):
        world, design = copy.deepcopy(self.world), copy.deepcopy(self.design)
        acquisition = next(r for r in design["acquisition_contracts"] if r["reward_id"] == reward_id)
        room_id = acquisition["room_id"]
        action = next(a for a in world["actions"] if a.get("reward_id") == reward_id)
        node = {"path": "Pickup", "type": "WorldRoomInteraction",
                "properties": {"action_id": action["id"], "section_id": acquisition["section_id"], "position": [320, 500]}}
        rooms = {room_id: {"id": room_id, "properties": {}, "nodes": [node]},
                 "P-R22": {"id": "P-R22", "properties": {}, "nodes": []}}
        seed = {"rooms": rooms, "rewards": reward_view(world, design, rooms)}
        package = {"rooms": {}, "rewards": copy.deepcopy(seed["rewards"])}
        return world, design, seed, package

    def relocate(self, seed, package, reward_id):
        reward = next(r for r in package["rewards"] if r["id"] == reward_id)
        source = reward["room_id"]
        package["rooms"] = {rid: copy.deepcopy(room) for rid, room in seed["rooms"].items()}
        old_room = package["rooms"][source]
        host = next(n for n in old_room["nodes"] if n["properties"]["action_id"] == reward["action_id"])
        old_room["nodes"].remove(host)
        host["properties"].update(position=[1100, 800], section_id="main")
        package["rooms"]["P-R22"]["nodes"].append(host)
        reward.update(room_id="P-R22", section_id="main", position=[1100, 800])

    def test_map_pickup_migrates_all_owned_indexes_and_preserves_receipt(self):
        world, design, seed, package = self.reward_fixture()
        self.relocate(seed, package, "TG01")
        before = copy.deepcopy(next(a for a in world["actions"] if a.get("reward_id") == "TG01"))
        importer.update_rewards(world, design, package, seed)
        action = next(a for a in world["actions"] if a.get("reward_id") == "TG01")
        self.assertEqual(("P-R22", "P_INTRO", "main"), (action["room_id"], action["node"], action["section_id"]))
        for field in ("id", "reward_id", "receipt_id", "requires", "grants", "persistent", "repeat"):
            self.assertEqual(before[field], action[field])
        source = next(r for r in world["collectibles"]["gear_sites"] if r["id"] == "TG01")
        self.assertEqual("P-R22", source["physical_room"])
        by_room = {r["id"]: r for r in world["rooms"]}
        for room_id, contains in (("P-R04", False), ("P-R22", True)):
            self.assertEqual(contains, "TG01" in by_room[room_id]["reward_ids"])
            self.assertEqual(contains, "TG01" in by_room[room_id]["collection_design_refs"]["source_ids"])
            row = next(r for r in design["room_index"] if r["room_id"] == room_id)
            self.assertEqual(contains, "TG01" in row["source_ids"])
            self.assertEqual(contains, "pickup_TG01" in row["world_action_refs"])
        acquisition = next(r for r in design["acquisition_contracts"] if r["reward_id"] == "TG01")
        self.assertEqual(("P-R22", ["P-R22"]), (acquisition["room_id"], acquisition["cue_room_ids"]))

    def test_list_only_relocation_is_rejected(self):
        world, design, seed, package = self.reward_fixture()
        package["rewards"][0]["room_id"] = "P-R22"
        with self.assertRaisesRegex(importer.ImportRejected, "physical interaction host"):
            importer.update_rewards(world, design, package, seed)

    def test_duplicate_or_deleted_host_is_not_a_valid_unchanged_reward(self):
        for duplicate in (False, True):
            with self.subTest(duplicate=duplicate):
                world, design, seed, package = self.reward_fixture()
                room = copy.deepcopy(seed["rooms"]["P-R04"])
                if duplicate: room["nodes"].append(copy.deepcopy(room["nodes"][0]))
                else: room["nodes"].clear()
                package["rooms"]["P-R04"] = room
                with self.assertRaisesRegex(importer.ImportRejected, "unique actual scene host"):
                    importer.update_rewards(world, design, package, seed)

    def test_complex_return_latch_is_not_a_simple_pickup_move(self):
        reward_id = next(r["reward_id"] for r in self.design["acquisition_contracts"]
                         if r["room_id"].startswith("P-R") and r["source_channel"] == "map"
                         and r.get("return_access_contract", {}).get("local_return_state_id"))
        world, design, seed, package = self.reward_fixture(reward_id)
        self.relocate(seed, package, reward_id)
        with self.assertRaisesRegex(importer.ImportRejected, "返程"):
            importer.update_rewards(world, design, package, seed)

    def test_topology_rewire_requires_full_source_contract(self):
        world = copy.deepcopy(self.world)
        connections = [copy.deepcopy(c) for c in world["connections"] if c["a"].startswith("P-R") or c["b"].startswith("P-R")]
        connections[0]["a"] = "P-R35"
        with self.assertRaisesRegex(importer.ImportRejected, "endpoint change"):
            importer.update_connections(world, copy.deepcopy(self.construction), {"connections": connections})

    def test_stale_hash_is_rejected_before_scene_processing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            files = ["config/world/" + n for n in CONFIG_FILES] + ["room.tscn"]
            for relative in files:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(relative)
            hashes = {relative: digest(root / relative) for relative in files}
            package = {"schema": importer.SCHEMA, "revision": 1, "baseline": "a" * 40,
                       "source_hashes": hashes, "base_content_version": "original", "rooms": {"P-R22": {
                           "schema": 1, "room_id": "P-R22", "revision": 1, "base_content_version": "original", "source_hash": hashes["room.tscn"]}}}
            (root / "config/world/world.json").write_text("concurrent source change")
            with patch.object(importer.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
                with self.assertRaisesRegex(importer.ImportRejected, "Source changed"):
                    importer.verify_baseline(root, package, {"rooms": [{"room_id": "P-R22", "scene_ref": "res://room.tscn"}]})

    def test_compiler_failure_restores_every_published_source_byte(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "config/world").mkdir(parents=True)
            (root / "config/world/construction.json").write_text("{}")
            changes = []
            for name in ("a.tscn", "b.json"):
                (root / name).write_bytes(b"original " + name.encode())
                candidate = root / (name + ".candidate")
                candidate.write_bytes(b"candidate " + name.encode())
                changes.append({"path": name, "candidate": str(candidate), "sha256": digest(candidate)})
            receipt = {"changes": changes, "candidate_content_version": "new"}
            with patch.object(importer, "verify_baseline"), patch.object(importer, "build", side_effect=[ValueError("invalid candidate"), (None, {"content_version": "old"})]):
                with self.assertRaisesRegex(ValueError, "invalid candidate"):
                    importer.publish(root, {}, receipt)
            for name in ("a.tscn", "b.json"):
                self.assertEqual(b"original " + name.encode(), (root / name).read_bytes())


if __name__ == "__main__":
    unittest.main()
