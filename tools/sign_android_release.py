"""Sign an already verified release APK. Private keys/passwords stay outside Git."""
from __future__ import annotations
import argparse, hashlib, json, os, re, secrets, subprocess
from pathlib import Path
from export_native import ROOT, version
KEY_DIR=ROOT.parent/'.private/gunman-rush'

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('apk',type=Path);p.add_argument('--create-key',action='store_true');p.add_argument('--apksigner',type=Path);args=p.parse_args()
 key=KEY_DIR/'android-release.jks';password_file=KEY_DIR/'android-release.password';env=os.environ.copy()
 if not key.exists():
  if not args.create_key:raise RuntimeError('No release signing key; explicitly create one or restore the existing private key')
  if password_file.exists():raise RuntimeError('An existing signing password exists without its key; restore the key instead of rotating it')
  KEY_DIR.mkdir(parents=True,exist_ok=True);KEY_DIR.chmod(0o700)
  password_file.write_text(secrets.token_urlsafe(48));password_file.chmod(0o600)
  env['GUNMAN_ANDROID_STORE_PASS']=password_file.read_text()
  subprocess.run(['keytool','-genkeypair','-storetype','JKS','-keystore',str(key),'-storepass:env','GUNMAN_ANDROID_STORE_PASS','-keypass:env','GUNMAN_ANDROID_STORE_PASS','-alias','gunman-rush','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=Gunman Rush Android Release,O=Gunman Rush,C=CN','-noprompt'],env=env,check=True,capture_output=True)
  key.chmod(0o600)
 if not password_file.is_file():raise RuntimeError('Release signing password is unavailable')
 env['GUNMAN_ANDROID_STORE_PASS']=password_file.read_text()
 apk=args.apk.resolve();report=apk.parent/'build-report.json';info=json.loads(report.read_text())
 digest=hashlib.file_digest(apk.open('rb'),'sha256').hexdigest()
 if info.get('source_dirty') or info.get('mode')!='release' or info.get('platform')!='android' or info.get('signed') is not False or info.get('unsigned_artifact',{}).get('sha256')!=digest:raise RuntimeError('Only the byte-verified unsigned release APK may be signed')
 jar=args.apksigner or Path(env.get('GUNMAN_APKSIGNER_JAR',str(Path(env.get('ANDROID_HOME',''))/'build-tools/35.0.1/lib/apksigner.jar')))
 if not jar.is_file():raise RuntimeError('Missing Android 35.0.1 apksigner.jar')
 output=apk.parent/('GunmanRush-v'+version()+'-android-arm64.apk')
 subprocess.run(['java','-jar',str(jar),'sign','--ks',str(key),'--ks-key-alias','gunman-rush','--ks-pass','env:GUNMAN_ANDROID_STORE_PASS','--key-pass','env:GUNMAN_ANDROID_STORE_PASS','--v1-signing-enabled','true','--v2-signing-enabled','true','--v3-signing-enabled','true','--out',str(output),str(apk)],env=env,check=True,capture_output=True)
 checked=subprocess.run(['java','-jar',str(jar),'verify','--verbose','--print-certs',str(output)],capture_output=True,text=True,check=True)
 cert=re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)',checked.stdout)
 if cert is None or 'Verified using v2 scheme (APK Signature Scheme v2): true' not in checked.stdout:raise RuntimeError('Missing verified APK v2 signature/certificate')
 info.update(signed=True,certificate_sha256=cert[1].lower(),artifact={'file':output.name,'bytes':output.stat().st_size,'sha256':hashlib.file_digest(output.open('rb'),'sha256').hexdigest()})
 (apk.parent/'android-build-info.json').write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'artifact':info['artifact'],'certificate_sha256':info['certificate_sha256'],'source_commit':info['source_commit']}))
if __name__=='__main__':main()
