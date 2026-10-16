# 原诊断的无损便携归档

A3 CI run38872475547在quality阶段发现本机build路径缺9件；未进入gameplay，未部署。这是本轮真实交付遗漏，不是Godot、网络或环境失败。

这9件原字节无损gzip保存，原路径/原SHA/原长度与压缩SHA均见[index](index.json)及对应质量卡。全部已解压逐字比较；原source_commit、method、observed及失败范围不改签。`gzip -dc FILE.gz`恢复原JSON/log。29,545,901原字节压为1,485,131字节，不以最终成功trace替代历史失败。

后续提交须在不含旧build的干净checkout通过原quality门槛；新增精确commit证据闭包守门会在昂贵CI安装/生产前拒绝同类本机依赖，原schema/SHA验证保留。
