from pathlib import Path
import tempfile,subprocess,json,hashlib,shlex
R=Path(__file__).resolve().parent; loop=(R/'mirror-loop.sh').read_text(); results=[]
def exercise(label,legacy=None,deb822=None):
 with tempfile.TemporaryDirectory(prefix='apt-uri-fixture-') as folder:
  root=Path(folder); a=root/'sources.list'; b=root/'sources.list.d/ubuntu.sources'
  for p,text in [(a,legacy),(b,deb822)]:
   if text is not None:p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
  # Actual emitted shell/sed, with only target paths redirected into the temporary
  # fixture and sudo replaced by an ordinary command-forwarding shell function.
  script='sudo() { "$@"; }\n'+loop.replace('/etc/apt/sources.list.d/ubuntu.sources',shlex.quote(str(b))).replace('/etc/apt/sources.list',shlex.quote(str(a)))
  process=subprocess.run(['bash','--noprofile','--norc','-e','-o','pipefail','-c',script],text=True,capture_output=True)
  assert process.returncode==0,(label,process.stderr)
  output=[]
  for p,text in [(a,legacy),(b,deb822)]:
   if text is None:assert not p.exists();output.append(None)
   else:output.append(p.read_text())
  results.append({'fixture':label,'exit_code':process.returncode,'actual_shell_and_sed':True,'no_real_sudo_or_system_source_write':True})
  return output
legacy='deb [arch=amd64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://azure.archive.ubuntu.com/ubuntu noble main restricted\ndeb https://azure.archive.ubuntu.com/ubuntu/ noble-updates universe multiverse\ndeb https://mirror.example/ubuntu noble-security main\n'
deb822='Types: deb\nURIs: http://azure.archive.ubuntu.com/ubuntu https://azure.archive.ubuntu.com/ubuntu/\nSuites: noble noble-updates noble-backports\nComponents: main restricted universe multiverse\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n\nTypes: deb\nURIs: http://security.ubuntu.com/ubuntu\nSuites: noble-security\nComponents: main restricted\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n'
outputs=exercise('traditional_and_deb822',legacy,deb822)
for original,actual in zip([legacy,deb822],outputs):
 expected=original.replace('http://azure.archive.ubuntu.com/ubuntu','https://archive.ubuntu.com/ubuntu').replace('https://azure.archive.ubuntu.com/ubuntu','https://archive.ubuntu.com/ubuntu')
 assert actual==expected
 for key in ('Suites:','Components:','Signed-By:'):
  assert [line for line in original.splitlines() if line.startswith(key)]==[line for line in actual.splitlines() if line.startswith(key)]
unknown='URIs: https://azure.archive.ubuntu.com.evil/ubuntu http://azure.archive.ubuntu.com/ubuntux https://azure.archive.ubuntu.com/ubuntu-security https://mirror.example/cache/http://azure.archive.ubuntu.com/ubuntu\nSuites: noble\nSigned-By: /original/key.gpg\n'
assert exercise('unknown_host_or_nonexact_path_unchanged',unknown,unknown)==[unknown,unknown]
assert exercise('both_sources_absent')==[None,None]
assert exercise('one_source_absent',legacy,None)==[outputs[0],None]
# Idempotence: rewritten official sources stay byte-identical.
assert exercise('official_source_idempotent',outputs[0],outputs[1])==outputs
(R/'shell-fixture-results.json').write_text(json.dumps({'scope':'actual shell/sed temporary source fixtures only; no apt, sudo privileges, network or Godot','fixtures':results,'suite_components_signed_by_exact':True,'traditional_signed_by_options_exact':True,'unknown_hosts_and_nonexact_paths_unchanged':True},indent=2)+'\n')
print('PASS:5 real shell fixtures; both URI forms, exact scope, fields, absent files and idempotence')
