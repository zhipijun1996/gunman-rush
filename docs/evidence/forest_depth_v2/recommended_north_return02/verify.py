"""Offline package integrity and original strict-reader replay; never starts Godot."""
from pathlib import Path
import ast
import gzip
import hashlib
import json

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
def digest(blob):
    return hashlib.sha256(blob).hexdigest()
def read(name):
    return json.loads((HERE / name).read_text())

def main():
    index = read('index.json')
    actual = {str(p.relative_to(HERE)) for p in HERE.rglob('*') if p.is_file() and p.name != 'index.json' and '__pycache__' not in p.parts}
    assert actual == set(index['files']), 'artifact domain differs'
    for name, row in index['files'].items():
        p = HERE / name
        assert not p.is_symlink() and p.stat().st_size == row['bytes'] and digest(p.read_bytes()) == row['sha256'], name
    results = read('results.json')
    captures = {}
    for tag in ('01', '02'):
        blob = gzip.decompress((HERE / tag / 'capture.json.gz').read_bytes())
        assert digest(blob) == results[tag]['capture_original_sha256']
        captures[tag] = json.loads(blob)
        inventory = read(f'{tag}/source-inventory-2068.json')['source_files']
        assert len(inventory) == 2068
        for p in (HERE / tag / 'selected-source').rglob('*.txt'):
            relative = str(p.relative_to(HERE / tag / 'selected-source'))[:-4]
            assert digest(p.read_bytes()) == inventory[relative], relative
    assert results['01']['status'] == 'failed' and results['01']['reader_errors'] == ['shot_not_actual_router_request']
    assert results['02']['status'] == 'passed' and results['02']['reader_errors'] == []
    assert results['01']['native_exit'] == results['02']['native_exit'] == 0
    reader_path = 'selected-source/tools/run_forest_depth_region.py.txt'
    old = (HERE / '01' / reader_path).read_bytes()
    new = (HERE / '02' / reader_path).read_bytes()
    proof = read('reader-exact-proof.json')
    assert old == new and digest(new) == proof['old_file_sha256'] == proof['new_file_sha256']
    code = new.decode()
    node = next(n for n in ast.parse(code).body if isinstance(n, ast.FunctionDef) and n.name == 'validate')
    assert digest(ast.get_source_segment(code, node).encode()) == proof['validate_function_sha256']
    assert "r.get('aim')==e.get('aim')" in code
    trace_path = 'selected-source/tests/forest_depth_region_trace.gd.txt'
    trace_old = (HERE / '01' / trace_path).read_text()
    trace_new = (HERE / '02' / trace_path).read_text()
    before_a, rest_a = trace_old.split('func request(', 1)
    before_b, rest_b = trace_new.split('func request(', 1)
    assert before_a == before_b and rest_a.split('\nfunc ', 1)[1] == rest_b.split('\nfunc ', 1)[1]
    chain = read('actual-direction-chain.json')
    request = next(x for x in captures['02']['requests'] if x['tick'] == 232 and x['kind'] == 'shoot_release')
    shot = next(x for x in captures['02']['events'] if x['tick'] == 232 and x['kind'] == 'shot_fired')
    projectile = next(x for x in captures['02']['events'] if x['tick'] == 232 and x['kind'] == 'actual_projectile_spawned')
    assert chain['actual_request'] == request and chain['actual_shot'] == shot and chain['actual_projectile'] == projectile
    assert request['queued'] and request['router_type'] == 'shoot_release' and request['router_sequence'] == 7 and request['router_epoch'] == 3
    assert request['input_aim'] != request['aim'] == shot['aim'] == projectile['direction']
    assert shot['serial'] == projectile['serial'] == 1 and projectile['session_id'] == 2 and projectile['weapon_epoch'] == 0
    assert [e['tick'] for e in captures['02']['events'] if e['kind'] == 'shot_fired'] == [232, 763, 843]
    assert len(captures['02']['frames']) == 1013 and len(captures['02']['completed_legs']) == 14
    assert captures['02']['final_snapshot']['health'] == 5 and captures['02']['final_snapshot']['energy'] == 100 and captures['02']['final_snapshot']['shots'] == 2
    namespace = {'__name__': 'archived_reader_offline', '__file__': str(HERE / '02' / reader_path)}
    exec(compile(code, namespace['__file__'], 'exec'), namespace)
    namespace['ROOT'] = REPO
    for tag in ('01', '02'):
        errors = namespace['validate'](captures[tag])
        assert errors == results[tag]['reader_errors'], (tag, errors)
    print(f"PASS: {len(index['files'])} artifact hashes; both lossless captures; exact unchanged reader; 01 original FAIL / 02 strict PASS replay; 3 accepted shots and queue chain. No native run.")

if __name__ == '__main__':
    main()
