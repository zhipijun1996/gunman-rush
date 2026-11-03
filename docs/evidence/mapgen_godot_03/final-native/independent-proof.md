# Mapgen0.3 最终十二项原Harness独立核验

限定接受精确源 `7f65ab03949bf7a9665033ae58a74847f72e5fbc`，原release/jobs1单次201.203秒：12fresh、0reuse、0失败。不是完整178项CI；此证明不签Web、浏览器、PR或后续0.4。

|检查|实际计数/失败|耗时/原预算秒|
|---|---:|---:|
|runtime-map-generated-identity|48/0|24.113/180|
|runtime-map-generation-job|883/0|36.808/240|
|runtime-map-generated-slice|56/0|29.274/240|
|runtime-map-v2-host|199/0|5.144/180|
|cloud-preview-runtime|45/0|6.949/120|
|web-resource-contract-tests|71/0|1.228/60|
|mapgen-candidate-installation|14/0|1.281/60|
|cloud-production-planner-tests|54/0|0.374/60|
|runtime-map-m35-provider|76/0|27.015/180|
|runtime-map-m35-runtime|67/0|52.699/240|
|cloud-delivery-tests|42/0|2.845/60|
|architecture-tests|13/0|0.128/60|

实际读取12原log、cloud-preview内层native/report及3份native JSON；marker、exit、预算、原命令与无错误/泄漏均一致。精选原件逐字存于 `/tmp/mapgen-v3-final-native-proof-raw`。

原Harness在每项前后与最终重算全源digest并未拒绝；targeted报告没有序列化双inventory，未冒称已独立比较两份原快照。报告Git clean与当前受验Git/manifest一致。保留Android build-tools提示和244.215ms单次advance峰值，不签Android或16ms/设备帧率。5b0旧初始定位缺陷和旧失败原件不追签。

JSON SHA：`887554ffd1a4a6e06271e223ec40c96f6444fd39658d290c03acb1f29365e9bb`。
