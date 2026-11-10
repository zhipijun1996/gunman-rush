"""Load the actual exported PCK in an empty project, without repository resources."""
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path
from run_tests import REPO, run_engine
from check_web_bundle import Pack, check_fixed_world_payload

def main():
    folder = Path(sys.argv[1] if len(sys.argv)>1 else REPO/'build/web').resolve()
    metadata = json.loads((folder/'build-info.json').read_text())
    pack = folder/metadata['pack']
    check_fixed_world_payload(Pack(pack), REPO)
    with tempfile.TemporaryDirectory(prefix='world-pack-') as isolated:
        probe = Path(isolated)/'probe.gd'
        shutil.copyfile(REPO/'tests/world/pack.gd', probe)
        output = run_engine(['--headless','--path',isolated,'--main-pack',str(pack),'--script',str(probe),'--fixed-fps','60'],180)
        if re.search(r'^ERROR:',output,re.M) or 'WORLD PACK failures=0' not in output:
            raise RuntimeError('Isolated world PCK probe failed')
    print('PASS: isolated fixed world PCK, 35 plains scenes and the clockheart, real start and no authoring sources')
if __name__=='__main__': main()
