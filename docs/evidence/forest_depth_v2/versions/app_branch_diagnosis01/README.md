# Three-branch version leak diagnosis

One frozen original runner was copied into a build-only diagnostic with explicit generation/app2/app1 selectors. The original default full90 path was preserved; selected branches use a different diagnostic marker and full_version_check=false, so their results cannot substitute for the complete check.

Actual strict editor import followed by all three bounded processes took17.8898s. Generation without App produced43/0, App map2 without hash reload21/0, and App map1 including hash reload26/0. All three independently failed strict exit with the same GDScriptNativeClass/GDScript refcount1 and player_tuning.gd resource in use. Original2010 source hashes and diagnostic script SHA stayed unchanged.

Consequently executing App or hash fallback reload is not a necessary condition for this failure. The result does not locate the remaining script reference owner, and a live pre-quit WeakRef alone is not evidence of a leak. No original assertion, PlayerTuning implementation, tuning configuration or strict filter was changed. The proposed next controlled candidate explicitly preloads the tuning script and actually uses that same script's load_default method; it was not executed in this archive.
