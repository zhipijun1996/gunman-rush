"""Real Git and filesystem contracts for fresh complete production snapshots."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import production_loop as loop


class ProductionSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.git("init", "--quiet")
        self.root_patch = patch.object(loop, "ROOT", self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)

    def git(self, *argv):
        return subprocess.check_output(["git", *argv], cwd=self.root)

    def serial_snapshot(self):
        names = self.git("ls-files", "-z", "--cached", "--others", "--exclude-standard").decode().split("\0")
        return {name: hashlib.sha256((self.root / name).read_bytes()).hexdigest()
                if (self.root / name).is_file() else "deleted" for name in names if name}

    def test_full_inventory_bytes_deleted_and_order_match_original(self):
        (self.root / ".gitignore").write_text("ignored/\n")
        for name, data in {"tracked.bin": bytes(range(256)) * 2049, "empty": b"", "deleted": b"old",
                           "becomes_directory": b"old", "z tracked": b"z"}.items():
            (self.root / name).write_bytes(data)
        self.git("add", ".")
        (self.root / "deleted").unlink()
        (self.root / "becomes_directory").unlink()
        (self.root / "becomes_directory").mkdir()
        (self.root / "a 新 untracked").write_bytes(b"\x00\xff\xfe\n")
        (self.root / "ignored").mkdir()
        (self.root / "ignored" / "output").write_bytes(b"excluded by Git")
        expected = self.serial_snapshot()
        actual = loop.snapshot()
        self.assertEqual(list(actual.items()), list(expected.items()))
        self.assertEqual(actual["deleted"], "deleted")
        self.assertEqual(actual["becomes_directory"], "deleted")
        self.assertIn("a 新 untracked", actual)
        self.assertNotIn("ignored/output", actual)
        self.assertEqual(actual["empty"], hashlib.sha256(b"").hexdigest())

    def test_each_call_reads_real_same_size_writes_new_files_and_deletions(self):
        source = self.root / "source"
        source.write_bytes(b"before")
        self.git("add", "source")
        before = loop.snapshot()
        metadata = source.stat()
        source.write_bytes(b"after!")
        os.utime(source, ns=(metadata.st_atime_ns, metadata.st_mtime_ns))
        (self.root / "new.bin").write_bytes(b"\xff\x00")
        after = loop.snapshot()
        self.assertNotEqual(before["source"], after["source"])
        self.assertEqual(after["source"], hashlib.sha256(b"after!").hexdigest())
        self.assertIn("new.bin", after)
        source.unlink()
        (self.root / "new.bin").unlink()
        deleted = loop.snapshot()
        self.assertEqual(deleted["source"], "deleted")
        self.assertNotIn("new.bin", deleted)

    def test_symlink_and_broken_symlink_keep_original_filesystem_semantics(self):
        (self.root / "target").write_bytes(b"target bytes")
        (self.root / "link").symlink_to("target")
        (self.root / "broken").symlink_to("absent")
        self.git("add", ".")
        self.assertEqual(list(loop.snapshot().items()), list(self.serial_snapshot().items()))
        self.assertEqual(loop.snapshot()["broken"], "deleted")

    def test_git_errors_propagate(self):
        with tempfile.TemporaryDirectory() as outside, patch.object(loop, "ROOT", Path(outside)):
            with self.assertRaises(subprocess.CalledProcessError):
                loop.snapshot()

    def test_unreadable_real_file_errors_propagate(self):
        if os.geteuid() == 0:
            self.skipTest("Root bypasses filesystem read permissions")
        source = self.root / "unreadable"
        source.write_bytes(b"must not become a deletion or cached hash")
        self.git("add", "unreadable")
        loop.snapshot()
        source.chmod(0)
        try:
            with self.assertRaises(PermissionError):
                loop.snapshot()
        finally:
            source.chmod(0o600)


if __name__ == "__main__":
    unittest.main()
