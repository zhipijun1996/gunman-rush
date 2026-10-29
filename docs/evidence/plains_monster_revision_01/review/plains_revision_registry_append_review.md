# PLAINS-MONSTER-REVISION-01 · registry技术追加独审

**限定ACCEPT：两份旧中央registry登记的技术续绑有效，原292项及非assets字段保留，新7项为真实已有文件登记。** 审查者 `/root/revision_r3_review`，只读，没有编辑Game仓库，没有运行Godot或Harness，不签美术、许可、听感、用户或设备认可。

## 真实失败保留

原163适用profile的attempt01只执行到第8项quality：前7项passed，quality实际因两份旧registry的source SHA及缺失process任务行失败；另155项未执行。独审读了归档report与原quality.log，归档quality.log与build原件字节一致。不能称163项已跑完或将这轮追签通过。当前新完整回归是否通过须由它的新report独立证明；本审查不预签。

## 独立重新计算，而非信任proof布尔值

从真实base `0d33ab56cb06d5bb37b30bd82387415ae5c7725e` 用git show读原 `assets/manifest.json` 字节，与当前文件独立比较：

- 原292项严格等于当前299项的前292项；所有非assets字段完整相等。
- 还按JSON token定位到原最后一个对象末尾，比较从文件开头至该点的全部原始字节：193,869bytes完全相等，包含原header、所有292对象、顺序和格式。原数组收尾仅因继续追加而增加逗号／新项；没有只靠对象值相等掩盖旧项重写。
- 原manifest SHA=`06aae899dd8fc1d43bcb4fe10d9bfa9080f0dc07ad657a7e1e8cf0d1ff32958d`，当前=`47a0efadbb9d62a2539142a3d0d45f1417ac0a516f50a8d1c21cc44ab1ba1c86`，与append-proof实际记录匹配。
- proof的7项严格等于当前后缀，六PNG与低铃WAV逐文件实际hash均吻合，并与冻结production `7edda9f5f2a20c5406391ff3f7edebbeb2322047` 字节一致。此metadata修复未再改source pixels或音频。

## 两份旧记录的续绑

`before/fine-space-05-asset-registry.json`和`before/demo_ui_01_r2_registry.json`分别与真实base原记录完整字节相同。当前记录只改content_version追加标识、source_sha256与revision_impact；其他字段完整相等，license_status/license_source、visual_status、user_acceptance_evidence均未修改。

revision_impact的previous_record_path/SHA准确指向各自本轮保留原件，proof路径准确，文字明确“仅技术追加、主观／用户／设备仍未验”。原记录的更早revision_impact保存在本轮before原件里，不覆盖历史链。原manifest中央记录仍production_record_only/runtime_paths=[]，没有用它们代替六PNG或声音本身的独立来源记录；生成美术unknown许可没有被中央元数据续绑伪改成CC0。低铃现有来源的独立许可也不被本技术意见重签。

`PLAINS-REVISION-GUARD-01`任务行现在唯一存在，与独立process记录ID对应。主怪物任务的美术／所有动作没有因此改为已通过。tools/check_quality.py、tools/quality.py、tools/check_quality_diff.py、Harness实现与profiles相对真实base没有修改；本次不是削弱守门来消除失败。

## 范围

本技术续绑有实际字节证明，可解除旧registry SHA失配这一元数据依赖。后续原163检查重跑及其任何实际运行失败继续按原断言／预算处理，不能用本ACCEPT代替。全量状态、视觉最终认可与完整G5仍独立。

独立核验细节：`/tmp/plains_revision_registry_append_review.json`。以下为审查时实际计算的数据，不是重新回填原失败report：

```json
{
  "reviewer": "/root/revision_r3_review",
  "baseline": "0d33ab56cb06d5bb37b30bd82387415ae5c7725e",
  "frozen_production": "7edda9f5f2a20c5406391ff3f7edebbeb2322047",
  "scope": "Technical central registry append only; no visual or license acceptance inferred",
  "manifest_before_sha256": "06aae899dd8fc1d43bcb4fe10d9bfa9080f0dc07ad657a7e1e8cf0d1ff32958d",
  "manifest_after_sha256": "47a0efadbb9d62a2539142a3d0d45f1417ac0a516f50a8d1c21cc44ab1ba1c86",
  "original_count": 292,
  "current_count": 299,
  "raw_prefix_bytes": 193869,
  "raw_prefix_sha256": "8b43535ed5010a88e3d27b27723ca0b8dcbf28135536f8eb1797a51f3e42f9a9",
  "raw_prefix_byte_equal": true,
  "other_fields_exact": true,
  "append_proof_sha256": "b27667813c209b3a05b9463940d611b475ce4460bcee7d85f75c1786f128d90d",
  "appended_assets": [
    {
      "path": "assets/plains_revision_01/charger.png",
      "sha256": "1e74096275fb4c492f9ec68983438eba39a9e90261dbcffa115c70912eaa662b",
      "matches_frozen_production": true
    },
    {
      "path": "assets/plains_revision_01/fan_sentry.png",
      "sha256": "48ecaea34430a5a93d7a50d1cf91c077861165e01cfc3ec4a2e1a5166bcb619b",
      "matches_frozen_production": true
    },
    {
      "path": "assets/plains_revision_01/hopper.png",
      "sha256": "c8cbd2f86a93e0e1f4fe61c482c624ad018f5ec8e7dcc8423dba2e133cc3e79f",
      "matches_frozen_production": true
    },
    {
      "path": "assets/plains_revision_01/patrol.png",
      "sha256": "12269d5e2abeb78245d4d5a201f4cff7007fae7b23768da83816d25828315f45",
      "matches_frozen_production": true
    },
    {
      "path": "assets/plains_revision_01/root_bell.png",
      "sha256": "f51e9794dfa005b12e98a0a1aacfcbf26a517f5124b851ceb1f358507c983696",
      "matches_frozen_production": true
    },
    {
      "path": "assets/plains_revision_01/sentry.png",
      "sha256": "0203c8354d9f9d612ef60628d1fc5adddd70d5aab9f4aa5d3a6f4730018dee1b",
      "matches_frozen_production": true
    },
    {
      "path": "assets/audio/plains_revision_01/root_bell_fall.wav",
      "sha256": "6d59721d87c6cddfd2be662b7a140e6f304d0acb254b33ec1bba5d2ca4a059a9",
      "matches_frozen_production": true
    }
  ],
  "records": [
    {
      "path": "docs/quality/asset_records/fine-space-05-asset-registry.json",
      "before_byte_sha256": "902ba394eeb04b55950378dddad04eb29f28d439f4a4dba8c520f1395c7a953a",
      "current_byte_sha256": "9a0caa8c14f5ba41ad464761bde87bed7d419d80041f4b14ecb72b700cbfd6a3",
      "before_exact_baseline_bytes": true,
      "allowed_changes_only": [
        "content_version",
        "revision_impact",
        "source_sha256"
      ],
      "license_visual_acceptance_unchanged": true
    },
    {
      "path": "docs/quality/asset_records/demo_ui_01_r2_registry.json",
      "before_byte_sha256": "dfc24d60d5dbe54ee0893931be33017861e344f434d1dd632e169176fc9cd79f",
      "current_byte_sha256": "f742db4927709cd965f8acf25b96bdf03681bceab916675290a576c44505a0ff",
      "before_exact_baseline_bytes": true,
      "allowed_changes_only": [
        "content_version",
        "revision_impact",
        "source_sha256"
      ],
      "license_visual_acceptance_unchanged": true
    }
  ],
  "process_task_index_row_count": 1,
  "verification": "Independent Python/git byte assertions, no Godot/Harness execution"
}
```
