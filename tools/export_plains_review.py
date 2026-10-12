"""Export the explicit Boss8 review fixture, restoring the formal entry afterwards.
Run separately from other exports/imports. Does not publish or alter saves.
"""
from pathlib import Path
import re,subprocess
r=Path(__file__).resolve().parents[1]
p=r/'project.godot'; original=p.read_text()
try:
 p.write_text(re.sub(r'run/main_scene=.*', 'run/main_scene="res://scenes/demo/plains_polish_review.tscn"',original))
 out=r/'build/verification/polish-review';out.mkdir(parents=True,exist_ok=True)
 subprocess.run(['bash','tools/godot.sh','--headless','--path','.','--editor','--quit'],cwd=r,check=True,stdout=subprocess.DEVNULL,timeout=120)
 subprocess.run(['bash','tools/godot.sh','--headless','--path','.','--export-debug','Web Playtest',str(out/'index.html')],cwd=r,check=True,stdout=subprocess.DEVNULL,timeout=120)
finally:p.write_text(original)
