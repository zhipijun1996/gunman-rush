"""Hydrate the registered runtime closure in a filtered/sparse Git checkout.

Only tracked inputs selected by the existing export owner are downloaded. This
does not check out historical art archives or commit generated asset lists.
"""
from pathlib import Path
import subprocess,sys
import export_runtime

ROOT=Path(__file__).resolve().parents[1]
def main():
    names=set(subprocess.check_output(['git','ls-tree','-r','--name-only','HEAD'],cwd=ROOT,text=True).splitlines())
    def restore(rows):
        rows=[r for r in rows if not (ROOT/r).exists()]
        if not rows:return
        subprocess.run(['git','restore','--ignore-skip-worktree-bits','--worktree','--pathspec-from-file=-','--pathspec-file-nul'],cwd=ROOT,input=('\0'.join(rows)+'\0').encode(),check=True)
    restore([n for n in names if n.endswith('.gdignore')])
    restore([n for n in names if any(n.startswith(p+'/') for p in export_runtime.DYNAMIC_FAMILIES) and Path(n).suffix in export_runtime.RESOURCE | {'.json'} and not export_runtime.ignored(ROOT/n)])
    # The export closure hashes this generated input too. Fresh CI checkouts
    # have no build/ artifacts, so create it from the existing source compiler.
    subprocess.run([sys.executable,'-c',
        "import json,sys;from pathlib import Path;sys.path.insert(0,'tools/world');"
        "from preview_catalog import preview_catalog;"
        "target=Path('build/preview/preview-world.json');target.parent.mkdir(parents=True,exist_ok=True);"
        "target.write_text(json.dumps(preview_catalog(Path.cwd()),ensure_ascii=False,separators=(',',':'))+'\\n')"],cwd=ROOT,check=True)
    # Exact static references and manifest-derived filenames are discovered by
    # the same export traversal, rather than a second hand-maintained allowlist.
    original_is_file=Path.is_file;original_read_text=Path.read_text
    def ensure(path):
        if original_is_file(path):return
        try:relative=path.resolve().relative_to(ROOT).as_posix()
        except ValueError:return
        if relative in names:restore([relative])
    def is_file(path):ensure(path);return original_is_file(path)
    def read_text(path,*args,**kwargs):ensure(path);return original_read_text(path,*args,**kwargs)
    try:
        Path.is_file=is_file;Path.read_text=read_text
        plan=export_runtime.manifest()
    finally:Path.is_file=original_is_file;Path.read_text=original_read_text
    print('Hydrated registered runtime inputs:',len(plan['files']))
if __name__=='__main__':main()
