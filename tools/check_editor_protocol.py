"""Run the editor's cross-owner and real-component boundary checks."""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def run(args):subprocess.run(args,cwd=ROOT,check=True)
run([sys.executable,'tools/world/build.py'])
run(['bash','tools/godot.sh','--headless','--path','.','--script','tools/world/export_editor_documents.gd'])
run([sys.executable,'tools/world/export_editor_project.py'])
run(['bash','tools/godot.sh','--headless','--path','.','--script','tests/world/editor_documents.gd'])
run([sys.executable,'-m','unittest','tests.test_editor_protocol'])
print('EDITOR PROTOCOL: passed')
