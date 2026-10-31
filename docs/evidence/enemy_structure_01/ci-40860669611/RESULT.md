# ENEMY-STRUCTURE-01：精确596a完整CI技术收据

[实际run40860669611](https://github.com/zhipijun1996/gunman-rush/actions/runs/40860669611)，attempt1，运行源 `596a2eee230eb1b9d23dc2ff878c1ff3259cf293`，integration base `45e98dbbf38d906dc5eae9686dc9ee5ee6a99acc`。Prepare、parallel、serial、affected 全部实际success；独立收据审计通过。

| 原检查范围 | 选定／实际执行／通过 | 复用 | 超时／未执行 |
| --- | ---: | ---: | ---: |
| parallel | 91／91／91 | 0 | 0／0 |
| serial | 75／75／75 | 0 | 0／0 |
| 完整full | 166／166／166 | 0 | 0／0 |

森林原80套（10固定根seed×两map×四原route）唯一完整、均exit0／errors空，含原最终通过标记；原600秒预算，实际404.511秒。原165检查合同与上轮5b全部不变，新结构检查仍原300秒，只追加缓存测试输入。

全部166项已核原argv／预算／expanded argv／唯一token、input digest、原stdout完整SHA、通过标记、strict脚本／shader／load／退出泄漏命中0及完整有限非负timing。实际affected原合流步骤success；merged原报告 `status=passed,partial=false,approval_scope=selected_profiles_technical,release=true`，精确引用两份原phase报告SHA。详见 `merge-binding.json`、`check-hashes.json`、`final-audit.json`。

两phase与merged的30,040项源快照前后一致，context与两phase／merged的Git metadata相符。CI有同一56处 `resources/foundry/` 准备改动，untracked空：这是相同prepared source，不能写成Git clean。CPU capacity没有专门收据，保持未观察，不宣称CI核数。

小产物均核API id／size／完整digest／head，ZIP成员与日志SHA保留；已校验的serial／parallel ZIP复用，无重复下载。新增context仅18,489B，merged仅3,661,752B；未取106MB serial大lane、22MB parallel大lane或preparedsource／Foundry大包。临时签名URL未输出或写入收据。

可归档的最小清单见 `archive-index.json`：四份原ZIP（总8,349,668B）＋摘要／每check hashes／原API元数据／合流绑定。原大JSON报告保留/tmp，原报告和原stdout均已包含在API绑定的ZIP内；无需把原展开JSON重复入库。

此次只签精确596a完整fresh166技术检查。旧5b的108通过／1超时／57未执行及更旧4af selector失败原件未变；不覆盖这些失败、不签后来HEAD、视觉、音频听审、实体设备、玩家或G5。审计过程未启动Godot、未派发CI、未改root工作树／HEAD。
