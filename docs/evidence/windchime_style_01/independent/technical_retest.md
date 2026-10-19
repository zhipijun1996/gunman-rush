# Independent technical correction review (worktree checkpoint)

The original draft REJECT is retained. Root production author corrected the lifetime and introduced a sample-only actual projectile skin. Review agent did not edit production.

- The original 9 actual-death/shot predicates remain. The updated probe only reacquires enemy references after root changed Restart to reconstruct the world, then adds old-token rejection and reset enemy3HP. `lifecycle_retest.gd`: **11 checks / 0 failures**, strict Godot4.7.2 native exit0, no script errors or native owner leaks. WC-R2 is corrected at this checkpoint.
- `repeat_probe.gd`: **223 checks / 0 failures**, 20 real ShootAbility shots, new projectile presentation consumers, catalog→Restart, monotonic scope invalidation, projectile cancellation, exactly2 enemy bodies/3 registry targets after world recreation, zero enemies/1 target in Materials, actual enemy pause, Home pause cleanup, final group cleanup. Native exit0, no errors/leaks.
- The repeat test first incorrectly assumed each Restart refilled shot stamina; initial run209 checks/28 failures reflected preserved stamina depletion, not a damage-scope regression. That run was not considered production failure. Corrected test permits180 actual physics ticks on ground for real configured recovery before each shot; no resource values were written by the test and no production constants were changed to pass.
- Initial muzzle diagnostic measured 5.47–11.87 world-unit separation between the draft's manually drawn gun and hidden CourierVisual technical muzzle across5 aim directions. Root subsequently changed new visual to synchronize the shared technical anchor in process and pure-read it in draw. The initial log is diagnostic of the old visual and does not sign final-pixel barrel alignment.

This is a technical worktree checkpoint, not the final frozen build. New palette, texture, regional background, corrected Chinese HUD and real new projectile pixels still require actual final export inspection. User and physical-device acceptance remain unverified.

Independent production runner: `python3 tools/run_windchime_tests.py` passed actual layout1800/0 and lab120/0; stdout retained in `production-tests.log`. Independent masonry occupied-interior property review (`masonry_probe.gd`) covered MAP01, MAP00 and a negative-coordinate thin frame with a large internal hole:27141/0, native exit0 and clean teardown. It verifies clip bounds/determinism/input immutability, not beauty.

Latest user rejection of the warm art is recorded in `user_rejection_addendum.md`: visual/player acceptance FAILED. This technical checkpoint does not admit or authorize deployment of that rejected art.
