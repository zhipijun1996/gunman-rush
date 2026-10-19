import ast, hashlib, io, json, subprocess, sys, time, types, unittest
from pathlib import Path
from unittest.mock import patch

root = Path('/workspace/gunman-rush-design')
out = Path(__file__).resolve().parent
sys.path.insert(0, str(root / 'tools'))
import production_loop as loop
real_run, real_sleep = subprocess.run, time.sleep
results = []
for name, path in [('before', out / 'before.py'), ('after', root / 'tests/test_production_loop.py')]:
    source = path.read_text()
    module = types.ModuleType('clock_probe_' + name)
    module.__file__ = str(root / 'tests/test_production_loop.py')
    exec(compile(source, module.__file__, 'exec'), module.__dict__)
    injected = []
    def run_with_stdlib_wait(*args, **kwargs):
        # Deterministically exercise the same stdlib clock namespace used by
        # subprocess.Popen._wait(timeout). Keep the real Git call and result.
        if args and args[0][:3] == ['git', 'ls-files', '-z']:
            injected.append(True)
            time.sleep(0.001)
        return real_run(*args, **kwargs)
    suite = unittest.TestSuite([module.SelectedInputPreflightTests(
        'test_prompt_and_host_request_bind_exact_profile_command_timeout_and_marker')])
    log = io.StringIO()
    with patch.object(subprocess, 'run', side_effect=run_with_stdlib_wait):
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
    (out / (name + '.log')).write_text(log.getvalue())
    results.append({'name': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                    'tests': result.testsRun, 'errors': len(result.errors),
                    'failures': len(result.failures), 'success': result.wasSuccessful(),
                    'real_git_snapshot_waits_exercised': len(injected),
                    'stdlib_sleep_preserved_after_test': time.sleep is real_sleep})
assert not results[0]['success'] and results[0]['errors'] == 1
assert 'host_request.json' in (out / 'before.log').read_text()
assert results[1]['success'] and results[1]['real_git_snapshot_waits_exercised'] > 0
assert all(x['stdlib_sleep_preserved_after_test'] for x in results)
before = ast.parse((out / 'before.py').read_text())
after = ast.parse((root / 'tests/test_production_loop.py').read_text())
def assertions(tree):
    return [ast.dump(x, include_attributes=False) for x in ast.walk(tree)
            if isinstance(x, ast.Call) and isinstance(x.func, ast.Attribute)
            and x.func.attr.startswith('assert')]
assert assertions(before) == assertions(after)
receipt = {'results': results, 'all_assertion_calls_ast_exact': True,
           'limits': 'Deterministic test transport isolation only; no native/gameplay approval. Original CI error retained.'}
(out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))
