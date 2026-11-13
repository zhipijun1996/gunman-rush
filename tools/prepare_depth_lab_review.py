"""Stage current and prior real captures for the existing private review page."""
import argparse
from pathlib import Path
import subprocess,shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);args=p.parse_args()
src=ROOT/'build/depth-lab';dst=args.output.resolve();dst.mkdir(parents=True,exist_ok=True)
for room,folder in [('indoor',src),('outdoor',src/'outdoor')]:
 for version in ['', 'before-']:
  video=folder/'comparison.mp4' if not version else src/'before'/f'{room}.mp4'
  image=folder/'frame-240.png' if not version else src/'before'/f'{room}.png'
  for mode,crop in [('flat','crop=640:600:0:60'),('spatial','crop=640:600:640:60'),('comparison','null')]:
   subprocess.run(['ffmpeg','-v','error','-y','-i',str(video),'-vf',crop+',scale=in_range=pc:out_range=tv,format=yuv420p','-c:v','libx264','-preset','fast','-crf','23','-color_range','tv','-movflags','+faststart','-an',str(dst/f'{room}-{version}{mode}.mp4')],check=True)
  shutil.copyfile(image,dst/f'{room}-{version}still.png')
  im=Image.open(image);im.convert('RGB').save(dst/f'{room}-{version}still.jpg',quality=95)
  for mode,x in [('flat',0),('spatial',640)]:im.crop((x,60,x+640,660)).convert('RGB').save(dst/f'{room}-{version}{mode}.jpg',quality=95)
  subprocess.run(['ffmpeg','-v','error','-y','-t','6','-i',str(video),'-filter_complex','fps=8,scale=640:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none','-loop','0',str(dst/f'{room}-{version}preview.gif')],check=True)
print('BEFORE/AFTER MEDIA PREPARED')
