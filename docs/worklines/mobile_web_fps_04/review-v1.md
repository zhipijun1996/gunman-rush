# MOBILE-WEB-FPS-04 独立静态审查

审查者：`/root/perf_release_pair`。日期：2026-10-30。基线：`5f55716a838a754a938997920ff18cb3b17452b5`。

本次只审查 root 的固定几何前缀缓存生产 diff、`build_frame_profile.py` 候选注入、另一 agent 的 `run_frame_profile.py`，并只读查看关联 probe 和现有测量文件。没有运行 Godot、浏览器或重新导出，没有修改运行源。本人编写的 `prepare_frame_pair.py` **不在独立签审范围**。

结论：所审生产 diff 和本次指定输入的诊断注入未发现阻断性正确性问题；可继续定向等价验证和同条件测量。此结论不是合入／发布验收，不证明手机 FPS、GPU 收益、整帧提速或完整 Release 导出的功能等价。

## 固定几何前缀

生产文件 SHA256：`61acf1704ac0c622f2741d36828175bd3c8b6364ab581140deab78d34ce44a09`。

`_fixed_protection()` 只替换 `_protection()` 原来的固定几何 loop。完整有序 `_fixed_world`、canvas `Transform2D`、viewport `Rect2` 使用 exact equality；命中后恢复原 loop 的四项输出，再执行原有动态、UI、碰撞、奖励等流程。没有更改这些流程的次序、保护参数、Shader、素材、resident 生命周期、风动或透明度时钟。

`_add()` 的固定 source 不进入 `_dynamic_protect`。前缀需要保存的可变状态是 `_protect`、`_static_protect`、`_source_counts`、`_overflow`，当前实现均保存。特别是 overflow 为过程中置位的状态，不能从最后矩形数重算；当前保留了它。快照保存时 duplicate，命中恢复时 assign／duplicate，后续动态并集合并不会改写快照。数组元素是 Rect2 值类型，source-count 值是整数，无嵌套可变引用要求深拷贝。

相机平移／缩放、viewport 或固定几何内容／顺序变化会失效。固定输入未变但动态/UI变化仍每帧执行，符合原语义。该缓存并不修复原代码未主动重建静态几何的既有情况，也未新增这种依赖。持续镜头移动可能连续 miss；不能把整个 `_protection` 耗时当作可节省上限以外的实际收益。

需要定向覆盖：命中后动态合并不污染后续命中、三个 key 分别改变、相同数组对象内元素改变、几何重排、空前缀、曾超过64矩形后又被合并的 sticky overflow。审查时新增等价测试尚未完成，故不签该测试已通过。

旧入口 `tools/verify_foreground_continuity.gd` 覆盖相机往返、resident 身份／离屏回收、重复 refresh 时钟、真实碰撞 guard、恢复等待和暂停风动；`tools/capture_foreground_continuity.gd` 覆盖六个定位窗。但二者通过 `capture_depth_frame.gd` 使用 `DemoApp.new()`，只能补充回归，不能代替当前真实 `demo.tscn` Web 对照。

## 候选包注入

`build_frame_profile.py` SHA256：`98ab1d909ff52a3e45c92222e7e58a889de8c44c1958a8ba6fbb901bef1fa44d`。

候选参数仅替换 foreground 输入；另外8个源文件从基线 commit 读取。计时 wrapper 对目标调用顺序未作改变，并对原方法使用完整原参数。静态检查9个源文件的目标方法未发现 await，当前不存在把协程调度时间误当完整异步运行时间的问题。嵌套计时为 inclusive，报告已明确不可求和；wrapper 自身记录和 probe 开销仍存在。

只读核对 `profile-baseline-01/receipt.json` 与 `profile-fixed-cache-01/receipt.json`：仅 foreground source SHA 不同，probe SHA 相同，candidate SHA 与上述生产文件一致。两个诊断 PCK 的目录内容签名（长度、MD5；忽略物理偏移）也仅 foreground 条目不同；`project.binary` 和 probe 字节直接比较相同。沿用的 `write_pack()` 在构造时核验替换字节和未修改条目元数据。

- baseline diagnostic PCK：`17c68ad5f187d176d6181184e389640a139c56f7c38e5c721ba3ec725374194c`
- candidate diagnostic PCK：`0664a4d2254b05d3e46097d5f6b7e42f9028097e4ea23ad116d73d28ddc6bbd5`

限制：`--foreground-candidate` 接受任意文件，本身不强制“只能修改缓存”；本次由人工 diff 与 SHA 绑定完成该约束。输入包校验采用 build_id 前缀，并信任 build-info 中 source commit；它不是任意来源包的完整可复现构建证明。完整输入 SHA 已进入 receipt，本次基线身份另有核验。

## 浏览器 runner 与边界

`run_frame_profile.py` SHA256：`daa1192a39ac629c619926b97498f96433d021fbbaa8998f34c548e2b67b4257`。两个 Python 文件通过 `ast.parse` 静态语法检查；此操作未执行浏览器。

runner 通过实际 Start、Home RUN SEED 和 Explore 操作进入，捕获窗口内没有游戏状态设置、音频 tap、GPU readback 或截图。画布／renderer查询和截图位于窗口外。固定 CSS viewport、DPR，记录 COI、canvas、种子和 manifest；本次已完成的 Debug／Release profile 的 Home player/camera 与 Plains player/camera 相同，种子均为 `mobile-fps-04`，manifest 均为 `d38685563f9fc81224e96af0eef040e3c736b50bd3bc90d83d9d27b4f0ab0a1f`。

当前 observer 等待时间戳达到 closure request 的 RAF，防止已排队旧时间戳遗漏最后长帧；超时、overflow 和不足样本会保留失败证据并拒绝成功。窗口 wall throughput 与完整 RAF interval rate 分开报告，初尾未覆盖时间也保留。原生 probe 是浏览器窗口中的另外计时子区间，不应把两者当作完全相同窗口。

只读查看 `build/mobile_web_fps_04/frame-boundary-selftest-02.json`：修正后的样本保留383.3ms间隔，RAF覆盖率约98.3%，旧算法约49.1%。这证明该注入案例的 RAF 末尾截断修正。两个 selftest 的 LongTask 列表均为空，故不能由这个文件签认 LongTask observer 的完整性，更不能据“0 LongTask”排除卡顿。P95也可能不包含单个稀有长帧，必须同时读 max、coverage 和原始区间。

测量解释的必要限制：

- runner 保存 `identity-json` 和 served metadata，但没有自动证明二者对应；两者结构也可能不同。需要最终报告按 receipt／build-info 字段对应核对，不能仅凭 captured 状态认定包身份。
- `--expected-manifest` 为可选，未传时仍校验实际 seed 和非 debug entry，但跨组 manifest 一致性需由汇总核对。
- vanilla 两组记录的 runner SHA 不同，且早期边界算法有失败记录；不能直接把旧 summary 当成当前算法的完整同条件证据。当前 Debug／Release profile 的 runner SHA 均等于本次审查版本。
- 原生 `Performance` process／physics 是引擎监视器值；RAF 是浏览器回调间隔，均不是 GPU 时间或物理手机帧率。

以上限制不阻止缓存的定向验证，但阻止把当前局部、带观察开销的云端样本升级为手机／全场景／整帧稳定提速结论。最终功能验收、候选测量和独立于本人代码的配对 helper 审查由 root 继续收口。

## 后续补审：原生等价测试、预算与反序控制

补审仍只读源码和 root 产生的证据，没有执行引擎。新增审查文件：

- `tests/underworld_plains/test_foreground_fixed_cache.gd`，SHA256 `924ba2a9a763189858151795c0b163c99931ade8669375e39fc22527c2a7c1a3`。
- `tools/run_underworld_formal_tests.py`，SHA256 `fd9f34e0add38a5b0883b03843f7fef3ea9edac60a92f0a0504a13ab1bcd27fe`。

未发现新增阻断。测试实例化真实 `scenes/demo/demo.tscn`，通过正常 Home 与 seeded Plains 业务入口组装消费者；后续对相机、viewport、演员和UI的修改明确属于同步 fixture。`full_case()` 在没有 await 的同一时刻比较缓存路径与强制 miss 路径的五项有序输出，并用不参与语义的 marker 区分 hit／miss；这能避开演员运动造成的伪差异。原始固定 loop 另在 synthetic 用例和微基准直接调用，覆盖70个分离矩形、enclosure先后顺序导致的sticky overflow、严格union阈值、零面积／外部／接边和空前缀。几何增删改重排、相机平移／缩放、viewport、动态actor、UI与结果／输入数组alias也有显式断言。

只读核对 `build/mobile_web_fps_04/native-cache-1793326121-6939431/report.json`：383 checks、0 failures，60个对照 case 全部 equal，生产SHA与本次审查一致。这支持上述输入覆盖范围的功能等价，不是逐像素验收或自然战斗路径测试。一个范围细节：Plains `resumed` 的UI计数仍为55、protect仍为1，与 `paused` 相同；同步resume时UI隐藏尚未结算。因此该用例不能宣称覆盖了菜单关闭后稳定画面的时序恢复。原生Plains canvas为1.6倍，亦不能把其微基准绝对值冒充固定Web场景时延。

wrapper 保留原正式两图消费者检查和原120秒总预算，第二个引擎调用只获得 monotonic deadline 的剩余时间；底层 `run_engine` 继续检查原生退出码、脚本／Shader错误、泄漏与超时，未降低门槛。更新的marker正则要求正数checks、failures=0及非空output路径；静态AST与四个正／负marker案例通过。首轮 `formal-cache-01.log` 因旧正则不接受新output字段而失败，其383/0不能覆盖wrapper失败；修复后 `formal-cache-02.log` 记录真正 Harness `underworld-formal: passed`，报告位于 `build/verification/harness/20261030T020908.640501Z/report.json`。两份日志都保留。

微基准两轮反序合计每模式64次，包含共同reset；均值如下（微秒／固定前缀调用）：

| 场景 | warm cache | 原loop | 移动candidate | 移动原loop |
| --- | ---: | ---: | ---: | ---: |
| Home | 3.156 | 35.000 | 36.719 | 27.094 |
| Plains | 4.063 | 134.547 | 202.313 | 157.047 |

命中可减少这段CPU工作，miss有真实额外成本；该结果只支持“小范围固定输入缓存”，不支持“各种移动情况下都提速”。两轮很短的CPU微基准没有手机／GPU外推效力。

root 的 `summarize_profiles_02.py` 和 `profile-comparison-audit-02.json` 已补齐之前指出的外部身份约束：对应诊断PCK SHA／served metadata／pair variant、runner SHA、音频线程、manifest及原生initial／final位姿、视口、前景计数都核对一致。静态查看该汇总脚本，没有把初末快照等同整个窗口世界模拟状态。该补审只认可核对逻辑和保留的结果，不构成本人对自己配对helper的独立签审。

首次 >90% RAF覆盖硬检查的失败保留；原Debug Plains repeat0覆盖约77.7%，初始空档约2.95秒，后续结果将其标记为不适合代表性RAF百分位比较，同时保留独立计时原生样本。这是范围标注，不把失败样本消失或改判为完整RAF窗口。

反序 baseline-return 的Plains约8.69 FPS，candidate约8.88 FPS；`_protection`分别约5.05–5.64ms和4.72–4.80ms。云端整帧差异很小且有运行顺序噪声，审查不签稳定整帧提升。当前可交付结论仍是：明确可命中的局部CPU缓存、已覆盖边界的功能等价、已披露miss开销；手机流畅度和完整视觉／音频回归仍须按对应真实证据验收。

## 发布工作流与报告文字补审

只读审查 `.github/workflows/deploy-prepared-playtest.yml`，SHA256 `bd4b0772eaf09bcd50edca906e6d7336eec6820abe2a8769601fa21e23ebccab`。对照基线，删除新增 optional FPS reconstruction 步骤后全文字节相同。权限、ref选择、concurrency、environment、10分钟预算、原root重建、旧audio-before重建和上传／部署步骤均未修改。

新增步骤只在 `prepared-web/perf-04/build-info.json` 存在时，调用同一已检出的 helper 重建该子目录；不存在则不进入分支，保持旧包路径。存在时未设置 continue-on-error、没有吞错或备用通过分支，helper 非零退出向上传播并阻止后续上传。沿用helper核验安全PCK文件名、build ID、字节数、分块地址／长度／SHA及完整PCK SHA；本补审没有执行该重建或实际部署。此步骤提供候选子目录的运输支持，不表示已经合入main，也不能单凭工作流证明准备包的root／audio-before字节未被另行修改；该部分仍由准备包身份核验负责。没有发现工作流diff阻断。

报告 `docs/evidence/mobile_web_fps_04/README.md` SHA256 `add8827b5b909dcd508563b67fdad8087205a654efbb196e6a248c23c5c1a7f4` 已只读核对。首段、结果表、微基准和结尾均明确手机FPS/P95未知，云端软件渲染与原生微基准不代替手机结果；保留反序噪声、移动miss成本、旧observer失败、专项而非完整CI、现有main红灯及候选不自动合main。未发现把局部CPU变化冒称手机／稳定整帧提速的表述。
