from pathlib import Path
logs = sorted(Path('build/verification/harness').glob('*/generated-consumers.log'))
if logs:
    print('\n'.join(logs[-1].read_text(errors='replace').splitlines()[-100:]))
