# Host poll clock mock isolation

Actual push Documentation run39086044032 at source4856d8c5 failed87 tests with one error: the selected profile-command test replaced the shared stdlib time.sleep. A real git ls-files subprocess wait invoked the fake host response before host_request existed. Original API-bound ZIP and extracted log/report are retained; ZIP SHA256 caafdf0559b2ce881a6a5fad802d3986cfbf4989f4b4530823003ba11b62505b.

The only executable delta first wraps loop.time in a module-local facade, then patches its sleep. stdlib/subprocess time stays real. All assertion-call ASTs are exact; actual snapshot/Git, lease clocks,30-second subprocess limit and60-second Harness cap remain. No production/gameplay files change.

probe.py deterministically inserts a real stdlib sleep at the git snapshot call and delegates unchanged to real Git. The original whole test fails with the same missing request; the revised whole test passes. This scheduler diagnostic is distinct from the untouched full87-test run, which actually passes in30.384s. It is not native or gameplay evidence, and does not re-sign the old CI failure. The next source CI must still validate all normal consumers.

Probe scope correction: its insertion is before delegating subprocess.run, not an instrumented OS wait. The original branch throws before reaching delegated Git; the revised branch reaches real Git. The receipt key real_git_snapshot_waits_exercised counts scheduling insertions, not actual OS waits in both branches. The original CI traceback independently shows the real Popen._wait path.
