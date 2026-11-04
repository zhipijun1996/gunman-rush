"""Current navigation and sparse paths: distinguish absent inputs from deletions."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_docs import document_target_exists, sparse_document_targets
from check_quality import skill_workflow_errors


class NavigationTests(unittest.TestCase):
    def test_concise_skill_is_valid_but_missing_empty_and_duplicate_sections_fail(self):
        concise = '## 适用任务\n明确范围\n\n## 操作\n执行具体消费者\n\n## 验证与交付\n给实际命令和结果\n'
        self.assertEqual(skill_workflow_errors(concise), [])
        self.assertTrue(skill_workflow_errors(concise.replace('执行具体消费者', '')))
        self.assertTrue(skill_workflow_errors(concise.replace('## 操作', '## 历史补充')))
        self.assertTrue(skill_workflow_errors(concise + '\n## 操作\n第二套流程\n'))

    def test_sparse_tracked_target_and_directory_resolve_but_local_deletion_fails(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def git(*args):
                return subprocess.run(["git", *args], cwd=root, check=True, capture_output=True)
            git("init", "-q")
            (root / "docs").mkdir()
            source = root / "docs/index.md"
            source.write_text("Current navigation")
            (root / "input").mkdir()
            target = root / "input/frozen.json"
            target.write_text("{}")
            deleted = root / "input/deleted.json"
            deleted.write_text("{}")
            git("add", ".")
            git("update-index", "--skip-worktree", "input/frozen.json")
            target.unlink()
            deleted.unlink()
            sparse = sparse_document_targets(root)
            self.assertTrue(document_target_exists(root, source, "../input/frozen.json", sparse))
            self.assertTrue(document_target_exists(root, source, "../input/", sparse))
            self.assertFalse(document_target_exists(root, source, "../input/deleted.json", sparse))
            self.assertFalse(document_target_exists(root, source, "../input/unknown.json", sparse))
            self.assertFalse(document_target_exists(root, source, "../../external.json", sparse))

    def test_fresh_reader_can_locate_resource_forest_and_mapgen_checks(self):
        navigation = (ROOT / "docs/project/module_map.md").read_text()
        scenarios = {
            "时间能量／弹药／共鸣": ("time_energy_v2.tres", "combat_and_recharge.md", "core"),
            "森林默认／版本／状态": ("thorn_forest_region_v2_v15.gd", "procedural_generation.md", "forest-bible-world-contract"),
            "mapgen风铃／端口／机制": ("runtime_map_v2_provider.gd", "procedural_generation.md", "runtime-map-windchime"),
        }
        for topic, required in scenarios.items():
            row = next(line for line in navigation.splitlines() if line.startswith("| " + topic + " |"))
            for value in required:
                self.assertIn(value, row)

    def test_entry_has_short_current_loading_and_document_maintenance_rule(self):
        entry = (ROOT / "AGENTS.md").read_text()
        self.assertLessEqual(len(entry.encode()), 4096)
        self.assertIn("最终交付件", entry)
        self.assertIn("docs/project/module_map.md", entry)
        self.assertIn("docs/project/worklines/", entry)
        self.assertNotIn("docs/handoff.md", entry)

    def test_retained_history_uses_exact_inputs_and_rejects_corruption_or_loss(self):
        import shutil
        import region_style_history as history
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            manifest = root / history.STYLE33_ARCHIVE / "manifest.json"
            manifest.parent.mkdir(parents=True)
            shutil.copy2(ROOT / history.STYLE33_ARCHIVE / "manifest.json", manifest)
            for path, (frozen, _) in history.FROZEN_CONTEXT_INPUTS.items():
                target = root / frozen
                target.parent.mkdir(parents=True, exist_ok=True)
                original = (ROOT / frozen).read_bytes()
                target.write_bytes(original)
                self.assertEqual(history.style33_source(root, path), original)
                target.write_bytes(original + b"changed")
                with self.assertRaisesRegex(AssertionError, "Frozen context input changed"):
                    history.style33_source(root, path)
                target.unlink()
                with self.assertRaises(ValueError):
                    history.style33_source(root, path)


if __name__ == "__main__":
    unittest.main()
