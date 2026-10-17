# FOREST-DEPTH-02: H spatial audit (G0, no Motor pass claimed)

Source inspected: bee850c66b2f402d644d7daa4c13db91c8abe8f8, clean at first read. Skills: ability-creator / challenge-choreographer / level-module-creator. Scope: actual traversal, current forest grammar, candidate geometry. No engine executed for this audit; no production/test edits performed for the audit.

## Runtime facts

- Actual `resources/player/traversal.tres` overrides class defaults: range231, kick(240,-240), launch.10s. Do not use the definition class's460/600/.20 fallback values. Initial hook origin is body+(0,-6). All finite directions are normalized;360deg is implemented.
- Body is24x36, half-extents12/18. Anchor Area circle radius12; hook probe circle radius12. A visible/raycast-clear centreline does not certify the body's dilated pull corridor. The probe can hit any collider; a nearer solid/nonhookable body becomes a miss. Solid LOS ray is also checked. Anchors must not be buried in support rectangles.
- Windup.065s, flight1650/s, pull1150/s, stop30 from sampled contact point, contact hold.10s; pull times out after.8s. Body approach is committed by the sole normal Motor step; collision preventing approach while distance>32 aborts the pull. No teleport/swing/orbit/rope-length control exists.
- Kick side is sign(cast_origin.x - hit.x), i.e. horizontal AWAY from the target, with upward24px. It is not a forward154px dash and not a kick along the aiming direction. A right-facing anchor normally kicks the player LEFT/up. Exactly vertical hits use -facing as horizontal fallback.
- Important current rule: not a permanent one-H-per-flight cap. Cast spends hook_used; empty/blocked/dead target does NOT restore it. Actual pull completion then contact hold then kick restores H (and D only if granted); landed also restores. An airborne real committed enemy projectile hit restores H. Thus continuous real anchor-to-anchor flights are legal; arbitrary airborne retries are not. H does not refill basic air shots or grant D/W.
- Cast/fly/pull/contact are busy: shots and jumps are not accepted there. hook_kick itself is not busy; a shot can replace its remaining tiny burst. For a full24px-kick proof, wait for its normal completion, then shoot. Requesting grapple requires state free, so a second H cannot simply interrupt hook_kick.
- Config ground260, gravity2600, fall800. PulseLv1 baseline recoil:1100*.14=154 airborne,84.7 grounded; cooldown.25; one jump/two shots before actual restores. Gun burst replaces motion, does not add154 to an already running H burst. Do not generalize Pulse timing to all six weapons without actual consumers.
- Existing target contact protection applies to the hooked target and finite grace, not other enemies/projectiles/spikes. A live target disappearing while pulling is a genuine miss; fixed fallback must remain.

## Current forest grammar, beyond labels

`_path` is one repeated primitive: anchor=(current.x±170,current.y-rise-12), receiver=(current.x±140,current.y-rise), a200x20 one-way slab. Families change sign arrays/counts/rise72 or120, not movement grammar. Every outward transition rises. cache_climb is exactly three leftward repeats; return uses drop-through descent and is genuinely different from outward climbing, but not a new hook direction. Main fast/growth choose different sign sequences then identical crown approach. There are only2/3 enemies and one cache-underfloor thorn strip; no branch-hole threading or intentional H→R spatial coupling in the main geometry.

`family`, `layout_id`, `requires`, step count, reward `action_signature`, or hook events alone are not a rich action-space proof. There IS an actual H-dependent vine shape: accepted arrival/kick on the named crown key unlocks the arena. This is an event-operated gate, not evidence every preceding gap is geometrically H-only. Existing ordinary jumps and R can bypass individual teaching steps. A truthful new grammar must retain discovered alternatives rather than hide them.

## Compared candidate cards (all G0/unverified)

Coordinates use +y down, player body centre; platform rectangles [x,y,w,h]. Need real initial velocities, accepted actions, body sweep, arrival support and return before promotion.

### A: horizontal relay under an arch

Entry solid[-220,18,300,80], body initially(0,0). Tall root ceiling[-220,-520,570,410] has underside-110; its top is too high for a casual upward-shot bypass, to be tested. Anchor1(200,-40), cast after a normal short jump. Tiny kick returns to the left of that anchor; one LEFT-directed airborne shot moves RIGHT154 toward the outside of the arch. Anchor2(470,-130), anchor3(580,-270); upper receiver[500,-222,260,24]. Expected approximate contact/kick centres must be sampled, not authored as passed: A1 around(158,-35)→(134,-59), R endpoint around(288,-59); A2 around(430,-115)→(406,-139); A3 around(547,-246)→(523,-270). The second pull must clear the arch corner with the whole12x18 half-body, not just the hook tip. Failing to shoot leaves A2 beyond legal range; the third H uses the actual kick restore. Main risk is body/ceiling contact from the REAL cast/fly gravity phase, not static range.

Return: leave high receiver to the left, fall outside the root's x350 face, descend below its underside before aiming left to A1. Kick returns right/up, shoot RIGHT to recoil LEFT toward entry. No intermediate injected energy, reset, landing or forced enemy hit. Lower fallback platform may catch a missed run; do not claim global geometric H lock if that floor enables a legitimate bypass. Dangerous depth envelope provides a physical failure comparator before recovery; the lower floor is a safe recovery endpoint, not a reward route.

### B: fall, side-hook, recoil into a receiving bough

Entry centre(0,-240); side anchor(220,-20); lower receiver[350,60,270,24]. Commit hook while body≈(20,-70), frozen hook origin(20,-76), centre distance207.7<231. Real falling velocity keeps moving during windup/flight; do not use that point as the later pull start. Body arrives from below-left, kick moves left/up; LEFT shot then moves right to receiver. Recovery broad floor[−220,220,900,40] with a walk-back path. H visibly arrests the fall; noH naive fall reaches the lower recovery, not the bough. BUT full two-R may substitute: this is NOT a hard H gate unless a real predecessor establishes a scarce-shot state. Reject a mere label saying “needs H”. Best as an optional fast descent/vertical loop, not first mandatory lock.

### C: diagonal root-hole threading

Entry(0,0), normal jump to approximately(0,-60), anchor(180,-140), cast-origin distance194.6. Root wall upper[60,-260,20,70], lower[60,-42,20,300] leaves opening y[-190,-42]. Body centre through aperture must lie y[-172,-60], including leading/trailing edges. Receiver[110,-94,190,20]. Expected arrival≈(141,-125), kick≈(117,-149); support bounds allow a stable landing while the kick naturally moves back toward the hole. A direct early ground hook strikes the lower root / body obstruction; a correctly timed short jump + diagonal H can pass. A held ordinary jump may also pass, so this is a body-clearance/aim decision, NOT proven H-only. No arbitrary radius threshold or impossible70px-wide avatar assumptions.

### D: aim direction has a real recoil consequence

From the post-C contact/kick state around(117,-149), upper receiving shelf[260,-160,230,20] cannot be landed on by merely drifting from the tiny kick (its required standing centre is-178). Shoot down-left with direction(-.8,.6): predicted burst(+123.2,-92.4), then ordinary drift/fall to shelf. An incorrectly horizontal shot has insufficient lift; a downward shot has insufficient horizontal reach. Without-H alternate jump/R sequences must be measured; no guarantee that H itself is geometrically mandatory. This is a useful later branch challenge only after a clear safe first H, not an unseen triple-demand teaching room.

## Choice and bounded implementation

Choose ONE composite A golden first: horizontal H → real away-side kick → side R beyond root edge → diagonal H → upward diagonal H → stable high branch → controlled outward drop/left H/R return. It demonstrates actual directional change and scarce-shot use, rather than multiplying the old up-left/up-right platform staircase. Retain a wide stable observation entry and receiver. Fixed anchors first; living targets are a later optional shortcut with a fixed fallback, not an invisible body blocking this calibration.

Geometry factory should emit the same platform/anchor/danger/step dictionaries for later v2 forest assembler use, and adapt these to existing PlatformingModuleDefinition for the single golden. No new player/controller/physics/damage framework. Base PulseLv1+H only. This is a provisional geometry, not content admission.

Comparison requirements: intended, noH, naivejump, onlyR; bound to the same geometry, entry, health/resource defaults and engine bytes. Record actual Router acceptances, grounded/support, positions, full-body swept danger contact, real health if production policy installed, and native termination. No-H failure is a physical route/danger conclusion for specified real strategies, not a mathematical exhaustive-input proof. If a real alternate succeeds, keep it as an alternate and withdraw H-hard-lock claims. Two bounded geometry/driver rounds without progress stop this candidate, preserve failures and switch to B/C rather than widening physics or unlimited seed/tick searching.

## First actual bounded calibration (2026-10-17)

Round01 real fixed60 InputRouter run failed with source_before==source_after. H1 accepted pull/contact/kick (body134.821,-59.162), one real leftward shot moved body to288.821,-59.162, H2 accepted contact/kick (body410.411,-132.351). Third hook missed at107 due the receiving solid in the hook corridor; body then physically intersected the authored depth danger on ticks130–133. No HP was applied: this golden currently proves full-body geometric danger contact only, not production FrameDamagePolicy damage/segment return. The actual ordinary catch floor/two-jump recovery returned the player to entry at365ticks without teleport or resource grants.

One permitted geometry correction for round02: move only crown_ring from(580,-270) to(500,-320). Its cast-centre distance from observed H2 release is approximately203<231; the higher/nearer ring should bring the BODY above the receiver's leading edge before drifting right to land. Original wrong geometry/trace remain immutable in build/forest_depth/traversal/round01-intended. No physics or existing tests changed. This correction is not a Motor pass until the second actual capture. If it fails without progress, stop this candidate and retain the failure; do not search dozens of input times.

Round02 closed dirty-overlay snapshot completed the ENTIRE outbound phrase and12 consecutive real grounded/full-width crown frames, then failed the return. At tick203 the body(388.922,-62.594) was already falling800px/s; the far-side H windup/flight had not reached the ring when the body touched depth danger at213. Original outcome remains REJECT for complete out-and-return; ordinary recovery still completed at433. Do not repair this by pretending fall freezes, moving an input a few ticks earlier or calling reached=true a pass.

New, independently bounded return phrase: a fixed near ring at(415,-40), seen from the stable crown, catches the outward-side fall before aiming back to the far ring. Cast threshold remains-70 and original outbound input is unchanged. Arrival from the left gives an away-left/up kick; estimated whole-body left edge remains >350 until the player is below the arch underside. Actual short cast/fly, descent arrest, full kick, restored H, far-side return and recoil-to-entry must all occur in normal Motor frames. This return candidate has at most two geometry revisions; no live enemy or automatic time freeze.

## 第二候选：可见荆棘窄口（新实现，尚未原生执行）

保留03原`build()`与快照、失败、电影，不将它的危险代理说成实际受伤。新增独立`build_narrow()`：横向H→向来侧上踢→向左射击产生右向154px反冲，穿过x210..270、y-94..-24的70px上下荆棘净口。24x36身体的合法中心高区间[-76,-42]，03真实反冲高度约-59.16，双侧约17px余量。接收岸左扩至x250、宽320、顶-24，反冲末点全足落岸余量约26.82px。反向不强迫再穿窄口：宽岸观察后向右走到x600、落下层宽安全地面，再经旧step自然跳回entry。

危险矩形准确画出实体色块、边界和内侧荆刺。每个矩形使用既有`DemoContactEmitter`扫掠24x36身体，进入真实`FrameDamagePolicy`，使用player场景原有HealthState配置（当前HP5，不额外加血）。非致命受伤先实际扣血，再由既有`SegmentRespawn`验证过的entry锚返回并保护；这种生产返回单独记账，不算成功物理穿越。成功需无伤、宽岸完整身体连续落稳、下层自然完整返程。反例为固定noH/naivejump/onlyR策略，实际替代方案若成功必须承认，不能由标签或钩次数硬判H必要。

比较过斜向墙洞口与下落侧钩：前者需另验斜向LOS/上下扫掠，后者vy800时每帧13.3px、围刺会压缩可观察承诺时间；本轮先选恒高窄口。其余保留不同方向素材，不拿平台缩窄制造难度。该新候选待独立快照、原45s intended首诊；尚未签其可玩性、损血或回程。

### narrow01 → narrow02 的实际纠正与边界

narrow01 首正向422连续观测帧、每帧1Motor、HP5→5，真实H→完整来侧24px踢→154px反冲穿口，宽岸落稳后从右侧落下层、自然跳回entry。实际窄口身体上下余量16.838/17.162px。仅此一例不能证明H必要。首次noH/naive原驾驶未处理无伤落到恢复地面，分别以1100tick超时；原负例预期还错误要求所有失败都必须扣血。这些失败、旧预期、旧日志均保留，不能倒签通过。

经实际同几何六个输入时机采样纠正了“只有约100ms窗口”的初估：现有Motor在向上burst结束后已有apex hold0.075/blend0.14，最晚比默认射击延迟9tick（150ms）仍无伤完整出返。早4tick可以合法由R接管kick，但只完成16px/轴，原完整24px断言仍拒；早2tick实际free与射击同帧，原严格先后断言仍拒。六个稀疏成功样本不是逐帧最大窗口或真机易用性证明。输入没有新增缓冲：contact期间提交的shoot_release仍会被busy拒绝，kick期间射击合法但会接管剩余kick。提前瞄准可做，不能把busy拒绝说成排队成功。

narrow02 明确新呈现/驾驶/对照合同版本，没有改变factory文件、身体、能力或危险数值。noH/naive在真实落到宽recovery后松轴，经原step自然回entry；仍硬核未达正确出口、下层连续完整支撑与12帧entry、HP/Policy事实一致，不强迫走进刺。onlyR继续要求实际环境扣血和生产SegmentRespawn返回。一次fresh全4实际严格通过：intended422帧HP5→5完整出返；noH241/naive230帧均未达出口、HP5→5、自然恢复；onlyR50帧HP5→4、一次真实伤害和一次生产返回。intended与onlyR的身体帧、事件、请求、DamageResult与01完全相等，因此改进归因是驾驶/预期修正和呈现，不能说关卡数值改进。

01电影确证下刺右20px被平台纹理遮挡且有DEEPDROP误导标签。02仅对narrow清除模块的绘制用danger列表（真实Policy/segment仍读完整原manifest），将模块纹理置于准确危险绘制下方；上下矩形、边界与内部尖齿完整显示。02唯一新GL intended电影426帧/60fps/7.1s，作者实际检查decoded58/65，危险覆盖和标签修正可见。旧onlyR电影只能说明旧呈现下的真实受伤恢复，不能声称为02重新录制；新旧Policy/body结果另有精确比较。

现有narrow接收岸右侧是必须保留的下落回程口，不能依据factory的暂写crown-right seam标签续同高平台；当前仅适合作为entry左口进入、原口返回的完整reward loop。宏观嵌入、相邻支撑/LOS、敌人叠加与正式区域通关仍须分别实际验证。
