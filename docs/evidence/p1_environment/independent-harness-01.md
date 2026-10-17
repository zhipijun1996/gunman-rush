# P1-ENV-01 测试迁移独立审查：ACCEPT_SCOPED

不同作者审查者 `/root/environment_art_review`；未编写或修改被审生产/测试，只读相对 `e545b05e5de5c33656cc489cc5f3d3ebaf69432d` diff。仅写此审查记录。采用gameplay-reviewer及项目测试不得降标要求。

结论：**接受本次既有测试绑定迁移，未发现删有效核心断言或为本轮画面放宽门槛。** 此结论只针对指定测试/route源码差异，不签整套Harness已运行通过，不签P1艺术/生成器/设备准入。

实际读取的当前字节：

- `tests/test_visual_director.py` SHA256 `75b953d9172ca90d21ec141646e60c692377bc0c3c68d99e71f76e59a2562e31`
- `tests/test_level_design_routing.py` SHA256 `33b5e16f1a4e5a957215657c6ee31e46b3b7698329c44a513f57efcb778539f3`
- `tools/visual_director.py` SHA256 `5a9a30b2d23fedd48ee9d8af16bd6c5b85e6cb78e725ef383bef88e08bfa0479`
- `tools/level_design.py` SHA256 `82b8fc31b136ada52047e535ef1c109587c8cd6781acdd2f3cbe1ea5386936fe`
- `tools/harness/profiles.json` SHA256 `064ced4e1993acf611a4d106612084a8cd88ccc921f1422eee3794932044a3cf`

## 迁移理由与核对

- `test_level_design_routing.py`旧状态 `first_space_static_accept_scoped` 改为 `candidate_with_native_evidence_not_automatic_admission`，并绑定P1-ENV质量记录与新实际采集脚本，新增“制作风铃平原美术”同入口及证据允许路径检查。旧sources非空、只读/作者/审查次序、区域ID、native preflight、无generation写权限、混合玩法走preproduction断言都保留。这比借旧首空间接受更准确。
- `test_visual_director.py`中5条变更（加66/删5为两测试文件合计）针对旧绘画消费者绑定：旧 `p1_candidate.json` profile/method不再可证明新environment consumer；现明确要求环境地形脚本、REWORK历史、P1-ENV记录、无新增碰撞编辑授权。旧技术/源SHA/作用域/独审边界断言保留。
- golden任务去掉 `visual-director-terrain` 是撤掉不相关消费者的局部任务绑定。实际profiles里该检查仍是 `tools/run_visual_director_space_tests.py --painted-terrain`，原180秒/成功标记/输入及art/full配置保留；相对基线profiles和旧fixture无改动。不能拿旧painted fixture替新environment签技术或美术。
- `validate_native`旧实际trace、source drift、扩展closure、禁止live PNG、禁止teleport/resource injection/disable、正式runtime及清理等原guard未移除。新environment分支额外校验地图/策略/政策、共享plan、初末physics来源绑定、非正式池、少女唯一表现所有者、角色源SHA及完整route cases。
- 追加的environment单元fixture明说fixture-not-real，允许保留失败路线作为有效采证，不冒真实路线通过；其负例覆盖plan漂移、来源漂移、teleport、live PNG、非法请求/素材借用、engine/清理错误、角色重复及源错误。旧capture测试保留，未以新fixture替旧真实媒体证据。
- `level_design.route_request`扩匹配“制作/重做/绘制/create”，仍限定平原+美术且排除玩法/碰撞/物理等混合请求；无权限扩展至generation。recipe直接声明首实现REWORK，计划不算执行，严格路线不算艺术准入，phase变化不算结构变化。

## 必须保留的边界

新route golden检查列表没有一个已注册的environment原生check；因此这里接受的是消费者绑定迁移，不是“短route已经自动执行环境native”的证明。本轮probe/full实际capture可作为单独运行证据，未来宿主须真的按goal执行采集/审查，不能由Python测试绿代签。未实际在本审查中运行测试或Godot；测试执行结果归作者原始日志，本记录不补造。

`test_change_justification`可准确引用以上迁移理由和本记录，但不得把此ACCEPT_SCOPED填成首黄金/整体艺术通过。首视觉独审仍REWORK，旧失败保留。


## P1-ENV-ROUTING-01 最终冻结字节复核

独立只读复核绑定最终运行源 `4d4803773d21dbe9e9443b42bc0a87dbc35137c6`。实际以 `git show` 逐文件读取最终提交与已审 `1b755922` 的Git原始字节，并与当前工作树逐字节比较；以下5文件全部相同，无需因版本号变化重做差异判断。

| 文件 | 最终源SHA256 | 与1b755922及当前工作树 |
| --- | --- | --- |
| `tests/test_visual_director.py` | `75b953d9172ca90d21ec141646e60c692377bc0c3c68d99e71f76e59a2562e31` | 相同 |
| `tests/test_level_design_routing.py` | `33b5e16f1a4e5a957215657c6ee31e46b3b7698329c44a513f57efcb778539f3` | 相同 |
| `tools/visual_director.py` | `5a9a30b2d23fedd48ee9d8af16bd6c5b85e6cb78e725ef383bef88e08bfa0479` | 相同 |
| `tools/level_design.py` | `82b8fc31b136ada52047e535ef1c109587c8cd6781acdd2f3cbe1ea5386936fe` | 相同 |
| `tools/harness/profiles.json` | `064ced4e1993acf611a4d106612084a8cd88ccc921f1422eee3794932044a3cf` | 相同 |

流程子记录 `P1-ENV-ROUTING-01` 可引用上述最终源，维持 **ACCEPT_SCOPED：仅测试迁移与route消费者绑定**。不签测试实际执行或短route自动完成native；原边界全部保留。实际地区艺术仍 **REWORK**，最终独审 `independent-native-03.md` 的停止当前端肩接法、不扩B/Seeds结论不变。本次未改生产或新增框架。
