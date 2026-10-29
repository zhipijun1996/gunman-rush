# MOBILE-WEB-AUDIO-FIX-03

用户真机确认独立线程测试入口加载后声音正常；随后明确修复最重要，完成后关闭空中瞄准/反冲及瞄准触发慢时的额外音效，攻击风铃机关应有清脆风铃声。

普通Web改用官方Godot4.7.2线程导出，原有缓存worker负责同源隔离和一次受限reload，保现有页面/UI比例/DPR、玩法、选定工坊音源与五BGM。不加新加载UI、不改全Stream、不降低画质。已知单线程补给排队的原始AB/PCM证据沿用mobile_web_audio_02，手机结论只覆盖用户已报告场景/时长。

瞄准附加音从实际消费者关闭，不删除其他共用cue；反冲先检查是否存在独立cue，不能误删用户已选主枪声。机关复用现有可追溯清脆风铃原件、保持接受命中/冷却规则。

验证：真实demo专项、标准Web冷启动与旧worker迁移、COI/SAB/shared-ring实际路径、Home/Plains实际声音、原UI比例；定向docs/web-cache/web-bundle及独立审查。部署到普通试玩入口，PR117保持draft不自动merge。最终长时真机听感另记，不能把云端软件渲染FPS当手机性能。
