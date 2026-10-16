"""Real filesystem/lock/display checks for non-/workspace ecology invocations."""
import fcntl
import os
from pathlib import Path
import selectors
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import run_root_bell_ecology as ecology
import run_root_bell_spaces as spaces


class RuntimePathTests(unittest.TestCase):
    def test_non_workspace_default_lock_with_real_child_competition(self):
        with tempfile.TemporaryDirectory(prefix='root-bell-portable-') as name:
            root = Path(name) / 'checkout';root.mkdir()
            environment = {k:v for k,v in os.environ.items() if k!='GUNMAN_GODOT_LOCK'}
            with patch.dict(os.environ,environment,clear=True):
                lock = ecology.godot_lock_path(root)
                self.assertEqual(lock,root.parent/'toolchains/godot-verification.lock')
                self.assertIs(spaces.godot_lock_path,ecology.godot_lock_path)
                program = 'import fcntl,sys\nf=open(sys.argv[1],"a")\ntry:\n fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError:\n print("blocked");sys.exit(3)\nprint("acquired")\n'
                with lock.open('a') as handle:
                    fcntl.flock(handle,fcntl.LOCK_EX)
                    blocked = subprocess.run([sys.executable,'-c',program,str(lock)],capture_output=True,text=True,timeout=10)
                    self.assertEqual((blocked.returncode,blocked.stdout.strip()),(3,'blocked'))
                acquired = subprocess.run([sys.executable,'-c',program,str(lock)],capture_output=True,text=True,timeout=10)
                self.assertEqual((acquired.returncode,acquired.stdout.strip()),(0,'acquired'))

    def test_explicit_shared_lock_override_creates_parent(self):
        with tempfile.TemporaryDirectory(prefix='root-bell-shared-lock-') as name:
            selected = Path(name)/'nested/shared/godot.lock'
            with patch.dict(os.environ,{'GUNMAN_GODOT_LOCK':str(selected)}):
                actual = ecology.godot_lock_path(Path(name)/'other_checkout')
                self.assertEqual(actual,selected)
                with actual.open('a') as handle:fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
                self.assertTrue(actual.is_file())

    def test_non_workspace_xvfb_fallback_starts_actual_display(self):
        actual = shutil.which('Xvfb')
        if actual is None:
            candidate = Path(os.environ.get('GUNMAN_TOOLCHAIN_ROOT',str(ecology.ROOT.parent/'toolchains')))/'xvfb/usr/bin/Xvfb'
            actual = str(candidate) if candidate.is_file() else None
        self.assertIsNotNone(actual,'Actual path test requires installed Xvfb; no fake process or movie claim')
        with tempfile.TemporaryDirectory(prefix='root-bell-display-') as name:
            root = Path(name)/'checkout';root.mkdir()
            candidate = root.parent/'toolchains/xvfb/usr/bin/Xvfb';candidate.parent.mkdir(parents=True)
            candidate.symlink_to(actual)
            environment = {k:v for k,v in os.environ.items() if k!='GUNMAN_TOOLCHAIN_ROOT'}
            with patch.dict(os.environ,environment,clear=True), patch.object(ecology.shutil,'which',return_value=None):
                selected = ecology.xvfb_binary(root)
                self.assertEqual(selected,str(candidate))
            with (Path(name)/'display.log').open('wb') as log:
                process = subprocess.Popen([selected,'-displayfd','1','-screen','0','128x128x24','-nolisten','tcp','-ac'],stdout=subprocess.PIPE,stderr=log)
                try:
                    with selectors.DefaultSelector() as ready:
                        ready.register(process.stdout,selectors.EVENT_READ)
                        self.assertTrue(ready.select(10),'Actual Xvfb startup timed out')
                        self.assertTrue(process.stdout.readline().decode().strip().isdigit())
                finally:
                    process.terminate();process.wait(timeout=10);process.stdout.close()


if __name__=='__main__':unittest.main()
