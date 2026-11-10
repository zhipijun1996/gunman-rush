"""Guard actual avatar provenance, anatomical controls and stable foot registration.

These are raster measurements, not a substitute for the real animation review.
"""
import hashlib,json,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/wake_wall'
class PoseRegistration(unittest.TestCase):
    def test_live_avatar_reference(self):
        data=json.loads((D/'build.json').read_text())
        path=ROOT/data['reference']
        self.assertEqual(data['reference'],'assets/player_presentation_01/motion_v1/motion_source.png')
        self.assertEqual(data['reference_sha256'],hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(data['reference_rect'],[0,0,256,256])
        self.assertEqual(data['reference_body_height'],182)
    def test_neutral_anatomy(self):
        live=Image.open(ROOT/'assets/player_presentation_01/motion_v1/motion_source.png').getchannel('A').point(lambda x:255 if x>=128 else 0)
        control=Image.open(D/'generated/source.png').getchannel('A').point(lambda x:255 if x>=128 else 0)
        # Curated anatomical windows in both ORIGINALS, in the same standing pose.
        for name,a,b in [('hood',(130,60,252,151),(120,35,260,139)),('torso',(125,155,236,209),(115,145,245,210)),('boots',(125,220,240,242),(110,227,250,249))]:
            aa=live.crop(a).getbbox();bb=control.crop(b).getbbox()
            aw=(aa[2]-aa[0])*44/182;bw=(bb[2]-bb[0])*44/214
            self.assertLessEqual(abs(aw-bw),2.0,(name,aw,bw))
    def test_look_support_matches_live_stance(self):
        image=Image.open(D/'look.png')
        # The live pivot lies LEFT of boot midpoint; previous midpoint-to-zero
        # registration shifted the whole character when looking.
        live_center=((129+234)/2-168)*44/182
        for i in range(6):
            alpha=image.crop((i%3*80,i//3*64,i%3*80+80,i//3*64+64)).getchannel('A')
            box=alpha.getbbox();boots=alpha.crop((0,53,80,58)).getbbox()
            self.assertEqual(box[3],58)
            center=((boots[0]+boots[2])/2-40)*44/46
            self.assertLessEqual(abs(center-live_center),1.6,(i,center,live_center))
    def test_single_scale_and_unique_poses(self):
        d=json.loads((D/'build.json').read_text())
        self.assertAlmostEqual(d['uniform_scale'],46/214)
        self.assertEqual(len(set(f['pixel_sha256'] for f in d['frames'])),18)
        self.assertEqual(d['frames'][7]['runtime_body'],'existing idle renderer')
if __name__=='__main__':unittest.main()
