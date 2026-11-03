# 0.2.0参考包开发验证

这是开发工具流程，不是Godot/Web算法调用。脚本固定发行head、外ZIP SHA和四个宿主比对成员，先核包再执行包内原验证器。输出目录必须全新，失败不覆盖。

```sh
curl -fL https://raw.githubusercontent.com/zhipijun1996/map-gen/0d338c2309d4e17bd8e9b128f745eb93938e99b2/reference_package/releases/0.2.0/mapgen-python-reference-0.2.0.zip -o /tmp/mapgen-reference-0.2.0.zip
python3 tools/verify_mapgen_reference.py \
  --archive /tmp/mapgen-reference-0.2.0.zip \
  --host-data resources/levels/mapgen_host_v2_01 \
  --out /tmp/mapgen-reference-verification-new
```

工具固定核 `25f05861b68a99eee1e9d588eb2cab761e30c85b7cc109b0536292fcc98867f6`，安全提取单根目录，在无关cwd调用包内原 `reference.py verify/replay --case all --module-zip …`，保stdout/stderr/退出码和原收据；再比较成功样例map及M16/M18/M21的完整原字节。提取目录也保原request/config/module-lock/provenance及91成员清单。工具不会写宿主资源、调用Godot或把Python/ZIP注册进运行时。

实际包manifest.source是1b20031c，发行head为0d338c2；包中的原算法baseline178c4016与依赖module-pack1.1.0另记，不能混用版本。readiness的Godot/Web runtime仍为NOT_IMPLEMENTED。样例失败结果SEARCH_EXHAUSTED的map=null/store空保持失败原义，不把验证其拒绝合同称生成成功。

正式参考包换版时，先明确更新发行锁/核包并跑原verify/replay，再比对和审查内容差异；不要以同文件名覆盖原attempt，不改runtime-map/v2协议来迁就宿主，不把旧Manifest字段补进公开地图。本轮成功比对没有更换现有map/content；以后实际内容变化须产生新map_content/host_load identity，旧恢复记录拒绝。

原结果及三个拒绝例见[证据](../../evidence/mapgen_host_v2_02/README.md)。游戏只消费现有7个冻结JSON；实际导出已证实无.py/.zip/开发证据。完整算法包的Godot/Web交付、调度/取消与完整地图消费者继续单独推进。
