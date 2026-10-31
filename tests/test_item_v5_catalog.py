"""Actual source-workbook imports and intentional corrupted-workbook controls."""
from __future__ import annotations

from collections import Counter
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("import_items_v5", ROOT / "tools/import_items_v5.py")
IMPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORT)


class ItemV5CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.archive = ROOT / IMPORT.ARCHIVE
        cls.snapshot = IMPORT.read_workbook(cls.archive)
        cls.catalog = IMPORT.build_catalog(cls.snapshot)
        cls.synergies = IMPORT.build_synergies(cls.snapshot, cls.catalog)

    def source(self):
        return deepcopy(self.snapshot)

    def row(self, source, prefix, id, column="B"):
        return next(r for r in IMPORT.find_sheet(source, prefix)["rows"] if IMPORT.cells(r).get(column) == id)

    def parameter(self, source, id, key, level="通用"):
        return next(r for r in IMPORT.find_sheet(source, "03 ")["rows"] if IMPORT.cells(r).get("A") == id and IMPORT.cells(r).get("E") == key and IMPORT.cells(r).get("F") == level)

    def cell(self, row, column):
        return row["cells"][f"{column}{row['row']}"]

    def item(self, id, catalog=None):
        return next(r for r in (catalog or self.catalog)["items"] if r["stable_id"] == id)

    def test_exact_original_attachment_and_deterministic_output(self):
        self.assertEqual("222d7dd49918ab613d5430a03fcc07f45bce1fbaa89ba6ea072c5a21174b545f", hashlib.sha256(self.archive.read_bytes()).hexdigest())
        self.assertEqual(107499, self.archive.stat().st_size)
        self.assertEqual((ROOT / IMPORT.SNAPSHOT).read_bytes(), IMPORT.encoded(self.snapshot))
        self.assertEqual((ROOT / IMPORT.CONFIG).read_bytes(), IMPORT.encoded(self.catalog))
        self.assertEqual((ROOT / IMPORT.SYNERGIES).read_bytes(), IMPORT.encoded(self.synergies))

    def test_all_worksheets_cells_formulas_and_types_preserved(self):
        self.assertEqual(10, len(self.snapshot["sheets"]))
        formula_count = 0
        with zipfile.ZipFile(self.archive) as archive:
            for sheet in self.snapshot["sheets"]:
                native = ET.fromstring(archive.read(sheet["member"]))
                cells = native.findall("m:sheetData/m:row/m:c", IMPORT.NS)
                recorded = [c for row in sheet["rows"] for c in row["cells"].values()]
                self.assertEqual(len(cells), len(recorded))
                self.assertEqual(hashlib.sha256(archive.read(sheet["member"])).hexdigest(), sheet["xml_sha256"])
                for actual, saved in zip(cells, recorded):
                    self.assertEqual(dict(actual.attrib), saved["attributes"])
                    formula = actual.find("m:f", IMPORT.NS)
                    self.assertEqual(None if formula is None else formula.text, saved["formula"])
                    formula_count += formula is not None
        self.assertGreater(formula_count, 0)

    def test_active_deleted_and_rarity_counts_are_exact_and_disjoint(self):
        self.assertEqual(72, len(self.catalog["items"]))
        ids = {r["stable_id"] for r in self.catalog["items"]}
        self.assertEqual(72, len(ids))
        self.assertEqual(21, len(self.catalog["deleted_ids"]))
        self.assertFalse(ids.intersection(self.catalog["deleted_ids"]))
        self.assertEqual({"BLUE": 29, "PURPLE": 28, "GOLD": 15}, Counter(r["rarity"] for r in self.catalog["items"]))
        self.assertIn("N01", ids)
        self.assertIn("N02", ids)

    def test_blue_five_and_gold_one_are_independent(self):
        self.assertEqual(("BLUE", 5), (self.item("B26")["rarity"], self.item("B26")["gear_cost"]))
        self.assertEqual(("GOLD", 1), (self.item("G01")["rarity"], self.item("G01")["gear_cost"]))

    def test_only_detailed_approved_sixteen_items_upgrade(self):
        upgraded = {r["stable_id"] for r in self.catalog["items"] if r["max_level"] == 3}
        self.assertEqual(16, len(upgraded))
        self.assertIn("N01", upgraded)
        self.assertNotIn("P06", upgraded)
        self.assertEqual(16, self.catalog["upgradeable_count"])
        self.assertTrue(any(c["kind"] == "summary_upgrade_count" for c in self.catalog["conflicts"]))

    def test_every_effect_and_parameter_retains_cell_provenance(self):
        for item in self.catalog["items"]:
            self.assertTrue(item["effect_parameters"])
            self.assertEqual(set(item["effect_parameters"]), set(item["parameter_sources"]))
            for key, value in item["effect_parameters"].items():
                provenance = item["parameter_sources"][key]
                if key.endswith("_by_level"):
                    self.assertEqual(3, len(value))
                    self.assertEqual(3, len(provenance))
                    self.assertTrue(all("03 数值参数!H" in cell for cell in provenance))
                else:
                    self.assertIsInstance(provenance, str)
                    self.assertIn("!", provenance)

    def test_atomic_H_edits_win_without_resigning_old_snapshot(self):
        source = self.source()
        row = self.parameter(source, "G01", "target_cooldown_s")
        self.cell(row, "H")["text"] = "6.5"
        result = IMPORT.build_catalog(source)
        item = self.item("G01", result)
        self.assertEqual(6.5, item["effect_parameters"]["target_cooldown_s"])
        self.assertIn("同目标6.5秒", item["description"])
        self.assertEqual(6, item["source_snapshot_parameters"]["target_cooldown_s"])
        self.assertTrue(any(c["kind"] == "01_snapshot_vs_03_H" and c["stable_id"] == "G01" for c in result["conflicts"]))

    def test_known_text_conflicts_preserve_original_and_resolve_explicitly(self):
        item = self.item("G16")
        self.assertIn("各0.60D", item["source_mechanism_text"])
        self.assertIn("各0.90D", item["description"])
        self.assertEqual(0.9, item["effect_parameters"]["damage_ratio_D_each"])
        self.assertIn("7秒", self.item("G01")["source_mechanism_text"])
        self.assertIn("6秒", self.item("G01")["description"])
        self.assertEqual("玩家主动攻击合法命中", self.item("P29")["trigger"])
        self.assertIn("新地图", self.item("G03")["trigger"])

    def test_explicit_text_only_cooldowns_are_data_not_code_fallbacks(self):
        for id, value in {"B23": 6, "B15": 7, "B24": 3, "P16": 12, "P20": 12, "G06": 1.5, "P24": 12, "P25": 10}.items():
            item = self.item(id)
            self.assertEqual(value, item["effect_parameters"]["cooldown_s"])
            self.assertIn("03未列", item["parameter_sources"]["cooldown_s"])
        self.assertEqual(15, self.item("P02")["effect_parameters"]["minimum_skill_cost"])

    def test_missing_or_formula_H_is_rejected(self):
        for action in ("missing", "formula"):
            source = self.source()
            row = self.parameter(source, "B03", "primary_damage_multiplier_by_level", "2")
            if action == "missing":
                del row["cells"][f"H{row['row']}"]
            else:
                self.cell(row, "H")["formula"] = "1+1"
            with self.assertRaises(ValueError):
                IMPORT.build_catalog(source)

    def test_numeric_parameter_rejects_string_negative_and_nonfinite(self):
        for value, kind in (("bad", "s"), ("-1", "n"), ("NaN", "n"), ("Infinity", "n")):
            source = self.source()
            row = self.parameter(source, "G01", "target_cooldown_s")
            self.cell(row, "H").update(text=value, type=kind)
            with self.assertRaises(ValueError):
                IMPORT.build_catalog(source)

    def test_duplicate_or_removed_active_id_is_rejected(self):
        source = self.source()
        row = self.row(source, "01 ", "B03")
        self.cell(row, "B")["text"] = "B05"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)
        source = self.source()
        row = self.row(source, "02 ", "B03")
        self.cell(row, "L")["text"] = "否"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_missing_level_and_duplicate_atomic_row_are_rejected(self):
        source = self.source()
        row = self.parameter(source, "B03", "primary_damage_multiplier_by_level", "2")
        IMPORT.find_sheet(source, "03 ")["rows"].remove(row)
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)
        source = self.source()
        row = self.parameter(source, "B03", "primary_damage_multiplier_by_level", "2")
        IMPORT.find_sheet(source, "03 ")["rows"].append(deepcopy(row))
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_gear_and_price_edit_rejects_fraction_and_out_of_range(self):
        for column, value in (("G", "0"), ("G", "6"), ("G", "1.5"), ("I", "-1"), ("I", "0"), ("I", "2.5")):
            source = self.source()
            row = self.row(source, "01 ", "B03")
            self.cell(row, column)["text"] = value
            with self.assertRaises(ValueError):
                IMPORT.build_catalog(source)

    def test_unauthorized_growth_and_throw_mode_are_rejected(self):
        source = self.source()
        row = self.row(source, "01 ", "P06")
        self.cell(row, "K")["text"] = "3"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)
        source = self.source()
        row = self.parameter(source, "G14", "mode")
        self.cell(row, "H")["text"] = "DEPLOY_AND_THROW"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_magnet_mask_cannot_admit_chests_rewards_or_shop_goods(self):
        source = self.source()
        row = self.parameter(source, "B01", "resource_pickup_mask")
        self.cell(row, "H")["text"] = "coin|reward_object"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_original_direct_cli_reaches_all_import_guards(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/import_items_v5.py"), "--check"], cwd=ROOT, capture_output=True, text=True, timeout=10)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn("72 active, 21 deleted, 16 upgradeable", result.stdout)

    def test_all_sixteen_synergies_preserved_only_nine_enabled(self):
        records = self.synergies["synergies"]
        self.assertEqual({f"S{n:02}" for n in range(1, 17)}, set(records))
        self.assertEqual({"enabled": 9, "pending_redesign": 3, "disabled_deleted_item": 4}, self.synergies["counts"])
        self.assertEqual({"S01", "S02", "S06", "S07", "S09", "S10", "S12", "S13", "S15"}, {id for id, row in records.items() if row["enabled"]})
        for record in records.values():
            self.assertEqual(9, len(record["source"]["cells"]))
            self.assertEqual(record["required_items"], [id.strip() for id in record["source"]["cells"]["B"].split("+")])
            if not record["enabled"]:
                self.assertFalse(record["parameters"])

    def test_synergy_parameters_have_single_explicit_sources(self):
        records = self.synergies["synergies"]
        self.assertEqual({"max_drones_per_marked_target": 2}, records["S02"]["parameters"])
        self.assertEqual({"intercept_cooldown_multiplier": 0.9}, records["S09"]["parameters"])
        self.assertEqual({"recovery_threshold": 5, "skill_cost_credit": 5}, records["S10"]["parameters"])
        self.assertEqual({"total_damage_budget_multiplier": 1.15}, records["S13"]["parameters"])
        self.assertIn("×1.2", records["S13"]["source"]["cells"]["F"])
        self.assertNotIn("×1.2", records["S13"]["safety_text"])
        self.assertFalse(any("energy" in key for key in records["S15"]["parameters"]))
        candidate = self.synergies["implementation_candidates"][0]
        self.assertIsNone(candidate["value"])
        self.assertEqual("unspecified_by_workbook", candidate["status"])

    def test_synergy_budget_tracks_atomic_H_without_stacking_old_multiplier(self):
        source = self.source()
        row = self.parameter(source, "G15", "total_damage_budget_multiplier")
        self.cell(row, "H")["text"] = "1.25"
        catalog = IMPORT.build_catalog(source)
        records = IMPORT.build_synergies(source, catalog)["synergies"]
        self.assertEqual(1.25, records["S13"]["parameters"]["total_damage_budget_multiplier"])
        self.assertIn("×1.25", records["S13"]["safety_text"])

    def test_synergy_cannot_enable_deleted_or_reinvent_unknown_recipes(self):
        source = self.source()
        row = self.row(source, "05 ", "S03", "A")
        self.cell(row, "D")["text"] = "有效但效果需实测"
        with self.assertRaises(ValueError):
            IMPORT.build_synergies(source, self.catalog)

    def test_required_parameter_contract_does_not_rebaseline_a_missing_source_key(self):
        source = self.source()
        row = self.parameter(source, "B24", "dot_duration_s")
        IMPORT.find_sheet(source, "03 ")["rows"].remove(row)
        # Even deleting the same key from the mutable U snapshot cannot bless it.
        item_row = self.row(source, "01 ", "B24")
        u = self.cell(item_row, "U")
        u_data = json.loads(u["text"])
        del u_data["dot_duration_s"]
        u["text"] = json.dumps(u_data)
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_zero_duration_fails_but_positive_balance_edits_remain_supported(self):
        for value in ("0", "0.25", "4.5"):
            source = self.source()
            row = self.parameter(source, "B24", "dot_duration_s")
            self.cell(row, "H")["text"] = value
            if value == "0":
                with self.assertRaises(ValueError):
                    IMPORT.build_catalog(source)
            else:
                item = self.item("B24", IMPORT.build_catalog(source))
                self.assertEqual(float(value), item["effect_parameters"]["dot_duration_s"])
                self.assertIn("dot_duration_s", item["parameter_contract"]["positive_keys"])

    def test_required_contract_rejects_extra_source_key_and_fractional_counts(self):
        source = self.source()
        row = deepcopy(self.parameter(source, "B24", "dot_duration_s"))
        self.cell(row, "E")["text"] = "misspelled_duration_s"
        IMPORT.find_sheet(source, "03 ")["rows"].append(row)
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)
        source = self.source()
        row = self.parameter(source, "G06", "chain_targets")
        self.cell(row, "H")["text"] = "1.5"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)

    def test_zero_scale_and_healing_exceptions_are_explicit_without_allowing_zero_radius(self):
        for id, key in (("P06", "world_time_scale_while_air_aiming"), ("P18", "normal_healing_multiplier")):
            item = self.item(id)
            self.assertEqual(0, item["effect_parameters"][key])
            self.assertIn(key, item["parameter_contract"]["zero_allowed_keys"])
        source = self.source()
        row = self.parameter(source, "P09", "radius_px")
        self.cell(row, "H")["text"] = "0"
        with self.assertRaises(ValueError):
            IMPORT.build_catalog(source)
        source = self.source()
        row = self.parameter(source, "B03", "primary_damage_multiplier_by_level", "2")
        self.cell(row, "H")["text"] = "0"
        self.assertEqual(0, self.item("B03", IMPORT.build_catalog(source))["effect_parameters"]["primary_damage_multiplier_by_level"][1])

    def test_original_archive_corruption_cannot_refresh_schema_approval(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            target = root / IMPORT.ARCHIVE
            target.parent.mkdir(parents=True)
            target.write_bytes(b"not the approved original workbook")
            with mock.patch.object(IMPORT, "ROOT", root), self.assertRaises(ValueError):
                IMPORT.build_catalog(self.snapshot)

    def test_explicit_revised_input_records_current_hash_separately_from_original(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "edited-positive-parameter.xlsx"
            target_sheet = IMPORT.find_sheet(self.snapshot, "03 ")["member"]
            row = self.parameter(self.snapshot, "B24", "dot_duration_s")
            target_cell = f"H{row['row']}"
            with zipfile.ZipFile(self.archive) as original, zipfile.ZipFile(path, "w") as edited:
                for member in original.infolist():
                    data = original.read(member.filename)
                    if member.filename == target_sheet:
                        tree = ET.fromstring(data)
                        cell = next(c for c in tree.findall("m:sheetData/m:row/m:c", IMPORT.NS) if c.attrib["r"] == target_cell)
                        cell.find("m:v", IMPORT.NS).text = "4.5"
                        data = ET.tostring(tree)
                    edited.writestr(member, data)
            snapshot = IMPORT.read_workbook(path)
            catalog = IMPORT.build_catalog(snapshot)
            self.assertEqual(IMPORT.ORIGINAL_SHA256, catalog["source"]["sha256"])
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), catalog["source"]["current_source_sha256"])
            self.assertNotEqual(catalog["source"]["sha256"], catalog["source"]["current_source_sha256"])
            self.assertEqual(4.5, self.item("B24", catalog)["effect_parameters"]["dot_duration_s"])
            synergies = IMPORT.build_synergies(snapshot, catalog)
            self.assertEqual(IMPORT.ORIGINAL_SHA256, synergies["source"]["sha256"])
            self.assertEqual(catalog["source"]["current_source_sha256"], synergies["source"]["current_source_sha256"])
        source = self.source()
        row = self.row(source, "05 ", "S16", "A")
        self.cell(row, "A")["text"] = "S17"
        with self.assertRaises(ValueError):
            IMPORT.build_synergies(source, self.catalog)


if __name__ == "__main__":
    unittest.main()
