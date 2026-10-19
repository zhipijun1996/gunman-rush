"""Add accurate scoped review labels without changing tested runtime/PCK bytes."""
from pathlib import Path
import json,hashlib,zipfile,shutil
root=Path('/workspace/art-direction-exploration');out=Path('/tmp/plains_world_rebuild/delivery/build_01');bundle=out/'plains-world-rebuild-candidate-linux-x86_64'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
receipt=json.loads((out/'build_receipt.json').read_text())
assert sha(bundle/'world-review.pck')==receipt['pck_sha256']
receipt['internal_art_review']={'verdict':'ACCEPT_SCOPED','scope':'Two finite candidate layouts; not complete-region, random-seed, user, commercial or device admission','reports':{str(p.relative_to(root)):sha(p) for p in [root/'docs/evidence/plains_world_rebuild/independent-art-03.md',root/'docs/evidence/plains_world_rebuild/independent-art-04.md']}}
receipt['manual_variants']={'default':0,'alternative':'./play.sh --variant=1','scope':'Two authored structural variations sharing four painted PNGs; not full-region procedural generation'}
receipt['metadata_finalizer_sha256']=sha(Path(__file__))
receipt['scope']='Local Linux finite-world candidate; two layouts internally ACCEPT_SCOPED, no user/full-region/random-seed/commercial/device/listening admission'
(bundle/'README.txt').write_text('''失序之钟：连续世界重建候选 · Linux x86_64

运行 ./play.sh，默认布局0；./play.sh --variant=1 切换另一结构布局。A/D移动、空格跳跃、鼠标瞄准与左键射击。保留真实PlayerMotor与战斗，不写存档；手动入口无自动驾驶。

两种有限布局通过内部限定艺术审查（ACCEPT_SCOPED）。这不是用户艺术定稿、完整随机平原、商业品质或设备认可。两个布局共享四张绘画PNG；此包没有证明任意随机Seed均可用。原失败方案和独立审查另见项目证据。

版本与严格打包验证见version.json：当前源PCK全部字节校验、空工作目录headless与GUI启动、实际世界消费者与冻结GUI收据完整相等、干净退出。启动验证不代替路线验证；实际输入路线录像另见本轮证据。

未进行真人、手机、手柄或实际听音验收。云端GUI使用软件渲染和Dummy音频，用户play.sh采用正常设备。Godot许可见GODOT_LICENSE.txt；新图像模型与商用许可未独立确认，不声明商店发行授权。
''')
write(out/'build_receipt.json',receipt);write(bundle/'version.json',receipt)
(bundle/'recovery').mkdir(exist_ok=True)
for name in ('prepare_bundle.py','finalize_metadata.py'):shutil.copy2(out.parent/name,bundle/'recovery'/name)
archive=out/(bundle.name+'.zip')
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(bundle.rglob('*')):
  if p.is_file():z.write(p,p.relative_to(out))
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert hashlib.sha256(z.read(bundle.name+'/world-review.pck')).hexdigest()==receipt['pck_sha256']
download={'path':str(archive),'bytes':archive.stat().st_size,'sha256':sha(archive),'source_commit':receipt['source_commit'],'scope':receipt['scope'],'zip_crc_all_members_passed':True};write(out/'download.json',download);print(json.dumps(download))
