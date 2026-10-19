from pathlib import Path
p=Path('.github/workflows/environment.yml');old=p.read_text();Path('build/verification/ci_lanes01/environment.before.yml.txt').write_text(old)
start=old.index('  core:\n');end=old.index('  windows:\n',start);core=old[start:end]
core=core.replace('  core:\n','  core_checks:\n',1).replace('    timeout-minutes: 60\n','    timeout-minutes: 60\n    strategy:\n      fail-fast: false\n      matrix:\n        lane: [parallel, serial]\n',1)
core=core.replace('${{ github.job }}','${{ github.job }}-${{ matrix.lane }}')
core=core.replace('      # Evidence is part of the frozen input: four isolated full checkouts would\n      # duplicate several GiB each. Run the identical fresh checks in one lane.\n      - run: python3 tools/harness.py --profile gameplay --profile art --jobs 1 --release\n', '''      # Each machine runs its exact disjoint lane, with original per-check caps.
      - run: python3 tools/harness.py --profile gameplay --profile art --jobs 1 --release --lane ${{ matrix.lane }}
      - name: Collect the unique original phase report and check stdout logs
        if: always()
        env:
          HARNESS_LANE: ${{ matrix.lane }}
        run: |
          python3 - <<'PYCODE'
          import json
          import os
          from pathlib import Path
          import shutil
          reports = list(Path('build/verification/harness').glob('*/report.json'))
          if len(reports) != 1:
              raise SystemExit('Expected exactly one original Harness phase report')
          report = reports[0]
          proof = Path('build/verification/ci-lane-proof') / os.environ['HARNESS_LANE']
          proof.mkdir(parents=True, exist_ok=False)
          shutil.copy2(report, proof / 'report.json')
          seen = set()
          for check in json.loads(report.read_text())['checks']:
              relative = Path(check['log'])
              if relative.is_absolute() or '..' in relative.parts or relative in seen or relative == Path('report.json'):
                  raise SystemExit('Invalid or repeated original check log path')
              seen.add(relative)
              source = report.parent / relative
              if source.is_symlink() or not source.resolve().is_relative_to(report.parent.resolve()) or not source.is_file():
                  raise SystemExit('Original check stdout log missing or outside report directory')
              target = proof / relative
              target.parent.mkdir(parents=True, exist_ok=True)
              shutil.copy2(source, target)
          PYCODE
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: harness-phase-proof-${{ matrix.lane }}
          path: build/verification/ci-lane-proof/${{ matrix.lane }}/
          if-no-files-found: error
          retention-days: 7
''')
core=core.replace('      - name: Check actual platform pixels (software GPU, not device approval)\n','      - name: Check actual platform pixels (software GPU, not device approval)\n        if: matrix.lane == \'serial\'\n')
core=core.replace('      - run: >-\n          python3 tools/run_audio_lifecycle_tests.py','      - if: matrix.lane == \'serial\'\n        run: >-\n          python3 tools/run_audio_lifecycle_tests.py')
core=core.replace('          name: harness-gameplay\n','          name: harness-gameplay-${{ matrix.lane }}\n')
aggregate='''  core:
    needs: [prepare, core_checks]
    if: always()
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Require both matrix lanes to have succeeded
        env:
          LANES_RESULT: ${{ needs.core_checks.result }}
          PREPARE_RESULT: ${{ needs.prepare.result }}
        run: test "$LANES_RESULT" = success && test "$PREPARE_RESULT" = success
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - uses: actions/download-artifact@v4
        with:
          name: validated-foundry
          path: resources/foundry/
      - uses: actions/download-artifact@v4
        with:
          name: harness-phase-proof-parallel
          path: build/verification/ci-lane-proof/parallel/
      - uses: actions/download-artifact@v4
        with:
          name: harness-phase-proof-serial
          path: build/verification/ci-lane-proof/serial/
      - name: Verify exact same-source complete fresh check coverage and original logs
        run: >-
          python3 tools/harness.py
          --verify-lanes build/verification/ci-lane-proof/parallel/report.json build/verification/ci-lane-proof/serial/report.json
          --profile gameplay --profile art
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: harness-gameplay-merged
          path: build/verification/harness/
          if-no-files-found: warn
          retention-days: 7
'''
p.write_text(old[:start]+core+aggregate+old[end:]);print('workflow checkpoint written')
