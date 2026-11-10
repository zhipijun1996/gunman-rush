"""Guard actual avatar provenance, anatomical controls and stable foot registration.

These are raster measurements, not a substitute for the real animation review.
"""
import hashlib,json,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'assets/player_presentation_01/wake_wall'
class PoseRegistration(unittest.TestCase):
    def test_charging_reference_and_anatomy(self):
        directory=ROOT/'assets/player_presentation_01/charging'
        data=json.loads((directory/'build.json').read_text())
        self.assertEqual(data['reference'],'assets/player_presentation_01/motion_v1/motion_source.png')
        live=Image.open(ROOT/data['reference']).getchannel('A').point(lambda x:255 if x>=128 else 0)
        control=Image.open(directory/'generated/player.png').getchannel('A').point(lambda x:255 if x>=128 else 0)
        for name,a,b in [('hood',(130,60,252,151),(150,52,315,184)),('torso',(125,155,236,209),(150,185,305,255)),('boots',(125,220,240,242),(145,278,302,302))]:
            aa=live.crop(a).getbbox();bb=control.crop(b).getbbox()
            aw=(aa[2]-aa[0])*44/182;bw=(bb[2]-bb[0])*44/250
            self.assertLessEqual(abs(aw-bw),3.0,(name,aw,bw))
        self.assertAlmostEqual(data['uniform_scale'],46/250)
        self.assertEqual(len(set(f['pixel_sha256'] for f in data['frames'][1:11])),10)

    def test_charging_contact_and_station_layers(self):
        directory=ROOT/'assets/player_presentation_01/charging'
        image=Image.open(directory/'poses.png')
        for i in range(12):
            alpha=image.crop((i%4*80,i//4*64,i%4*80+80,i//4*64+64)).getchannel('A')
            self.assertEqual(alpha.getbbox()[3],58)
        back=Image.open(directory/'station.png');front=Image.open(directory/'station_front.png')
        self.assertEqual(back.size,(96,96))
        self.assertIsNone(front.crop((27,49,69,86)).getbbox())
        self.assertIsNotNone(front.crop((27,86,69,92)).getbbox())
        for y in range(96):
            for x in range(96):
                if front.getpixel((x,y))[3]:self.assertEqual(front.getpixel((x,y)),back.getpixel((x,y)))

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
