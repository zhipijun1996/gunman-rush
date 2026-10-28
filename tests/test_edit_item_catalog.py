"""Exercise real authoring CLI transactions against isolated JSON files."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/edit_item_catalog.py"


class ItemAuthoringCliTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.folder = Path(self.directory.name)
        self.base = self.folder / "base.json"
        self.authoring = self.folder / "authoring.json"
        self.backups = self.folder / "backups"
        source = json.loads((ROOT / "config/items_v5.json").read_text())
        row = next(row for row in source["items"] if row["stable_id"] == "B11")
        self.base.write_text(json.dumps({"items": [row], "deleted_ids": ["B25"]}))
        self.document = {"schema_version": 1, "metadata": {"B11": {"tags": ["item_v5"], "required_tags": [], "required_capabilities": [], "exclusive_tags": [], "icon_key": "heart", "channel": "PASSIVE", "appearance_weight": 1.0}}, "overrides": {}, "additions": [], "disabled_ids": []}
        self.authoring.write_text(json.dumps(self.document))

    def run_cli(self, *args, success=True, output=None):
        command = [sys.executable, str(TOOL), "--base", str(self.base), "--authoring", str(self.authoring), "--backup-dir", str(self.backups)]
        if output is not None:
            command += ["--output", str(output)]
        result = subprocess.run(command + list(args), text=True, capture_output=True, timeout=10)
        self.assertEqual(0 if success else 2, result.returncode, result.stderr + result.stdout)
        return result

    def saved(self):
        return json.loads(self.authoring.read_text())

    def test_parameter_edit_preserves_base_and_backs_up_exact_previous_bytes(self):
        previous = self.authoring.read_bytes()
        frozen = self.base.read_bytes()
        result = self.run_cli("set", "B11", "effect_parameters.max_hp_add_by_level", "[2,3,4]")
        self.assertEqual([2, 3, 4], self.saved()["overrides"]["B11"]["effect_parameters"]["max_hp_add_by_level"])
        self.assertEqual(previous, Path(json.loads(result.stdout)["backup"]).read_bytes())
        self.assertEqual(frozen, self.base.read_bytes())
        shown = json.loads(self.run_cli("show", "B11").stdout)
        self.assertEqual([2, 3, 4], shown["effect_parameters"]["max_hp_add_by_level"])

    def test_disable_enable_and_reset_keep_identity_and_independent_override(self):
        self.run_cli("set", "B11", "shop_price", "45")
        self.run_cli("disable", "B11")
        self.run_cli("disable", "B11")
        self.assertEqual(["B11"], self.saved()["disabled_ids"])
        shown = json.loads(self.run_cli("show", "B11").stdout)
        self.assertEqual("B11", shown["stable_id"])
        self.assertEqual(0, shown["runtime_metadata"]["appearance_weight"])
        self.assertEqual(45, shown["shop_price"])
        self.run_cli("enable", "B11")
        self.assertEqual([], self.saved()["disabled_ids"])
        self.assertEqual(45, self.saved()["overrides"]["B11"]["shop_price"])
        self.run_cli("reset", "B11")
        self.assertEqual({}, self.saved()["overrides"])

    def test_static_addition_and_growth_are_data_only(self):
        self.run_cli("add-static", "EXTRA_HEART", "--name", "测试心匣", "--params", '{"max_hp_add_by_level":[1,2,4]}', "--gear-cost", "2", "--price", "35", "--rarity", "GOLD")
        row = self.saved()["additions"][0]
        self.assertEqual(("EXTRA_HEART", 3, 2, "GOLD"), (row["stable_id"], row["max_level"], row["gear_cost"], row["rarity"]))
        self.assertEqual(["max_hp_add_by_level"], row["parameter_contract"]["required_keys"])
        self.assertEqual("PASSIVE", row["runtime_metadata"]["channel"])
        self.assertEqual(2, len(json.loads(self.run_cli("list").stdout)))
        self.run_cli("check")

    def test_new_proposal_does_not_modify_source_or_frozen_catalog(self):
        before = self.authoring.read_bytes()
        frozen = self.base.read_bytes()
        proposal = self.folder / "new" / "proposal.json"
        self.run_cli("set", "B11", "runtime_metadata.icon_key", '"coil"', output=proposal)
        self.assertEqual(before, self.authoring.read_bytes())
        self.assertEqual(frozen, self.base.read_bytes())
        self.assertEqual("coil", json.loads(proposal.read_text())["overrides"]["B11"]["runtime_metadata"]["icon_key"])
        self.assertFalse(self.backups.exists())

    def test_invalid_parameters_and_fields_leave_file_and_output_unchanged(self):
        before = self.authoring.read_bytes()
        for field, value in [("effect_parameters.misspelled", "1"), ("effect_parameters.max_hp_add_by_level", "[1]"), ("effect_parameters.max_hp_add_by_level", "[1,NaN,3]"), ("effect_parameters", "{}"), ("runtime_metadata", "{}"), ("gear_cost", "true"), ("unknown", "1"), ("runtime_metadata.channel", '"UNKNOWN"')]:
            with self.subTest(field=field, value=value):
                self.run_cli("set", "B11", field, value, success=False)
                self.assertEqual(before, self.authoring.read_bytes())
        proposal = self.folder / "invalid.json"
        self.run_cli("set", "B11", "shop_price", "0", output=proposal, success=False)
        self.assertFalse(proposal.exists())
        self.assertFalse(self.backups.exists())

    def test_deleted_duplicate_or_fake_complex_additions_are_rejected(self):
        before = self.authoring.read_bytes()
        for key, params in [("B25", '{"max_hp_add":1}'), ("B11", '{"max_hp_add":1}'), ("../escape", '{"max_hp_add":1}'), ("NEW_SKILL", '{"primary_damage_multiplier":1.5}')]:
            with self.subTest(key=key):
                self.run_cli("add-static", key, "--name", "拒绝样本", "--params", params, "--gear-cost", "1", "--price", "15", success=False)
                self.assertEqual(before, self.authoring.read_bytes())

    def test_duplicate_json_keys_and_nonfinite_data_are_not_silently_accepted(self):
        self.authoring.write_text('{"schema_version":1,"schema_version":1}')
        before = self.authoring.read_bytes()
        self.run_cli("disable", "B11", success=False)
        self.assertEqual(before, self.authoring.read_bytes())
        self.authoring.write_text(json.dumps(self.document))
        before = self.authoring.read_bytes()
        self.run_cli("set", "B11", "effect_parameters", '{"max_hp_add_by_level":[1,2,3],"max_hp_add_by_level":[2,3,4]}', success=False)
        self.assertEqual(before, self.authoring.read_bytes())

    def test_cannot_overwrite_frozen_base_or_disable_unknown_id(self):
        frozen = self.base.read_bytes()
        self.run_cli("set", "B11", "shop_price", "35", output=self.base, success=False)
        self.assertEqual(frozen, self.base.read_bytes())
        self.run_cli("disable", "missing", success=False)

    def test_malformed_existing_addition_contract_cannot_be_rewritten(self):
        self.run_cli("add-static", "EXTRA_HEART", "--name", "测试心匣", "--params", '{"max_hp_add":1}', "--gear-cost", "1", "--price", "15")
        broken = self.saved()
        broken["additions"][0]["parameter_contract"]["schema_source_sha256"] = "not-a-schema-hash"
        self.authoring.write_text(json.dumps(broken))
        before = self.authoring.read_bytes()
        backup_count = len(list(self.backups.iterdir()))
        self.run_cli("set", "B11", "shop_price", "35", success=False)
        self.assertEqual(before, self.authoring.read_bytes())
        self.assertEqual(backup_count, len(list(self.backups.iterdir())))

    def test_static_numeric_parameter_cannot_be_reclassified_as_text(self):
        self.run_cli("add-static", "EXTRA_HEART", "--name", "测试心匣", "--params", '{"max_hp_add":1}', "--gear-cost", "1", "--price", "15")
        broken = self.saved()
        row = broken["additions"][0]
        row["effect_parameters"]["max_hp_add"] = "foo"
        row["parameter_contract"]["positive_keys"] = []
        row["parameter_contract"]["text_modes"] = {"max_hp_add": ["foo"]}
        self.authoring.write_text(json.dumps(broken))
        before = self.authoring.read_bytes()
        backups = len(list(self.backups.iterdir()))
        self.run_cli("check", success=False)
        self.run_cli("set", "B11", "shop_price", "35", success=False)
        self.assertEqual(before, self.authoring.read_bytes())
        self.assertEqual(backups, len(list(self.backups.iterdir())))

    def test_designer_overrides_cannot_forge_or_remove_component_roles(self):
        source = json.loads((ROOT / "config/items_v5.json").read_text())
        authored = json.loads((ROOT / "config/item_v5_authoring.json").read_text())
        base = {"items": [row for row in source["items"] if row["stable_id"] in ("B04", "P24")], "deleted_ids": source["deleted_ids"]}
        document = {"schema_version": 1, "metadata": {key: authored["metadata"][key] for key in ("B04", "P24")}, "overrides": {}, "additions": [], "disabled_ids": []}
        self.base.write_text(json.dumps(base))
        original = json.dumps(document).encode()
        changes = [("B04", "tags", '["item_v5","active"]'), ("B04", "channel", '"ACTIVE"'), ("P24", "tags", '["item_v5"]'), ("P24", "channel", '"PASSIVE"')]
        for key, field, value in changes:
            with self.subTest(key=key, field=field):
                self.authoring.write_bytes(original)
                self.run_cli("set", key, "runtime_metadata." + field, value, success=False)
                self.assertEqual(original, self.authoring.read_bytes())
                broken = json.loads(original)
                broken["overrides"] = {key: {"runtime_metadata": {field: json.loads(value)}}}
                self.authoring.write_text(json.dumps(broken))
                invalid = self.authoring.read_bytes()
                self.run_cli("check", success=False)
                self.assertEqual(invalid, self.authoring.read_bytes())
                self.assertFalse(self.backups.exists())
        self.authoring.write_bytes(original)
        self.run_cli("set", "B04", "runtime_metadata.icon_key", '"item_B03"')
        self.assertEqual("item_B03", self.saved()["overrides"]["B04"]["runtime_metadata"]["icon_key"])


if __name__ == "__main__":
    unittest.main()
