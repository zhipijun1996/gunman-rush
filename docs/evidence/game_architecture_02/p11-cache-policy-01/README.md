# P11 外部冻结候选

源 C59，App 以 structure 已确认 P10 frozen be61aebd 为 base。这里只是纯规则抽取；没有 main/engine/CI 操作。candidate-relative-p10.patch 应在 P10 实际应用/验证后按准确 source 使用；full-c59-stack-proof.patch **仅整栈证明，不可当 P11 单独提交补丁**，其中包含已审 P10 其它 Stage/test 变化。

生产共4文件含UID：App、Generator、CacheRewardPolicy、UID。测试仅既有 expansion runner 增两调用+两个函数；原完整源码逆删除新增内容后 byte-equal，所有93原 check call sites、循环/动作/预算保持。新增12 check call sites（6纯边界+4组×6实际App检查，运行数依实际分支）；不冒签它们已执行。实际App配置空 V5 catalog provider 是既有合法 seam，其 generate 返回 insufficient_legal_candidates，明确不是宣称这些是自然生成 seed 的零候选。原其它真实eligible item/claim/meta retry/audio tests继续负责其合同。

同步快照证明纠正初设计措辞：HealthState 继承 ActorResourceState，current/capacity 为 `get: return _current` / `get: return _capacity`，无写入/回调；不是直接公开字段。原本每个 heart 读一次，新版在同段开始读一次，且仍位于原 create_cache_offer/null-return/copy/init/clear 之后。ResourceRewardChoice.make 和 ItemDefinition 没有自定义 _init；make 只建资源、赋普通导出字段，既无 await/signal 也无外部 getter；此期间生命无同步变化。见 candidate.json 六个相关源 SHA。这个证明不推广到任意未来有副作用 getter/构造器。

ResourceRewardChoice/RewardService 源未改。所有既有 source/claim/grant/meta/epoch/order 留原位；policy 不引用 App/Service/Build/health/Node/RNG。资源候选数量/顺序/重复ID/既有资源模式补items[1]原缺陷保留。新数组不 clone ItemDefinition，App通过原 candidates.assign保数组身份。

prepare.py 在外部有限文件镜像独立 git apply/check/reverse 两个 patch，完整字节比较均通过；没有Godot语法/运行签字。静态依赖 proof 使用现有 scanner，原842文件0error，新leaf只指向既有四文件 ResourceRewardChoice 闭包，有限边界无新环。未改 Harness185/profile/预算；input-coverage.json 按现有 inputs核实际叶。

待root原命令：region `python3 tools/run_plains_region_tests.py`（总1500，expansion150）；`python3 tools/run_item_v5_tests.py --suite formal`（240）；`--suite random-context`（240）；`python3 tools/run_audio_feedback_tests.py`（240）。可复用P10已经同源完成的结果，但P11改动影响的结果不得追签。Generator完整100seed manifest before/after需实际比较，不能只观察summary marker或盲刷golden。先保C59/P10相同原生成器的实际完整manifest，再在P11输出同seed逐字对比；独立临时只读dump复用原generate，必须另记source，不需要新产品机制。

原缺陷 bounded probe 计划见 preexisting-defect-probe-plan.md，独立功能缺陷未修也未native复现。当前候选只等待独审和root原预算执行。
