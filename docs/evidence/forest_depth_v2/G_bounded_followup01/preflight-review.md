# Preflight lexical memo independent review

**ACCEPT — bounded path-calculation optimization.** Candidate SHA256 `ca19c51a595220c999c3426534741f955e9a70a3eb7f191161852fe9e77c9ee6`; current dirty source bound against HEAD in AUDIT. No native or full-suite rerun by reviewer.

The two dictionaries are initialized inside each required_input_preflight invocation; keys contain current ROOT and name. Values are immutable lexical Path/ancestor tuple and relative-name string/None. No inode, symlink state, existence, mode/permissions, bytes, JSON result or verdict is cached. No resolve is introduced. The complete ancestor sequence is the original filtered sequence in its original order; every call still invokes is_symlink with original short circuit then fresh stat/is_file/open/read. JSON/Markdown reads, Git ls-files and source enumeration, selected inputs/dependency expansion, strict blocked decisions all remain fresh. Relative-name membership for outside-root None cannot match original tracked string keys, equivalent to original outer containment guard. ROOT/name lexical construction reuse does not remove filesystem guards.

All AST outside the single function matches HEAD; archived before file equals HEAD bytes. The only diff within it is lexical cache declarations/lookups replacing the repeated pure path expressions. Test file remains exact8ca605, profile935160,342 assertions unchanged.

Independently reran the author's real temporary-Git comparison into a separate reviewer directory: unchanged accepted; same-call deletion, permission0 and ancestor-symlink replacement blocked with old/new complete results equal; a cross-call malformed JSON update is freshly rejected. Five actual comparisons pass, not mocks of preflight results. This does not prove resistance to arbitrary concurrent filesystem races beyond the original contract.

Reviewed unprofiled original CLI once:87 tests24.368s, outer24.549332s, exit0 under original60; three before/after source hashes independently match actual files. No assertions/timeout/selected scope reduced. Earlier32preflight/44.37sec profiled diagnostic includes instrumentation overhead and is not an original baseline timing. G original87-dot timeout60.041 remains an actual failure, not cancelled or retroactively passed. This local result does not guarantee CI timing or identify an exclusive cause.

Legacy asset closure review is separate; gameplay/Queen/overall REVISE, release and final full CI remain outside scope. Only build report/independent temporary Git comparison written; reports frozen.
