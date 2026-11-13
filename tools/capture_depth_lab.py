"""Render the isolated comparison in an actual graphics window; encode normal-time media."""
import os,subprocess,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/depth-lab'
extra=[]
if '--outdoor' in sys.argv:
    OUT=OUT/'outdoor';extra=['--outdoor']
OUT.mkdir(parents=True,exist_ok=True)
if not os.environ.get('DISPLAY'):
    raise SystemExit('A graphics display is required; run in a desktop session or Xvfb with OpenGL.')
for name,args in [('comparison',[]),('orthographic',['--ortho'])]:
    with (OUT/(name+'.log')).open('w') as log:
        subprocess.run(['bash','tools/godot.sh','--path','.', '--audio-driver','Dummy','--fixed-fps','60','--write-movie',str(OUT/(name+'.avi')),'game/presentation/experiments/depth_lab/depth_lab.tscn','--','--capture',*args,*extra],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=180)
    text=(OUT/(name+'.log')).read_text()
    if 'ERROR:' in text or 'DEPTH LAB CAPTURE COMPLETE' not in text:raise RuntimeError(text)
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(OUT/(name+'.avi')),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-an',str(OUT/(name+'.mp4'))],check=True)
# Preserve real-render pixel content; only crop the matching orthographic panel.
subprocess.run(['ffmpeg','-v','error','-y','-i',str(OUT/'frame-240.png'),'-i',str(OUT/'ortho-frame-240.png'),'-filter_complex','[1:v]crop=640:720:640:0[o];[0:v][o]hstack=inputs=2','-frames:v','1',str(OUT/'three-way.png')],check=True)
subprocess.run(['ffmpeg','-v','error','-y','-i',str(OUT/'comparison.mp4'),'-filter_complex','fps=8,scale=640:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none','-loop','0',str(OUT/'comparison.gif')],check=True)
for name in ['capture.json','ortho-capture.json']:
    m=json.loads((OUT/name).read_text());assert len(m['samples'])==4 and m['frames']>=720
    a,b=m['samples'][0]['points'],m['samples'][1]['points']
    displacement={z:round(b[z][0]-a[z][0],3) for z in a}
    print(name,'screen-x displacement by depth:',displacement)
print('DEPTH LAB: real graphics capture, both projection modes and media encoding passed')
