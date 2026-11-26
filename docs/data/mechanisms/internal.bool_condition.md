# 布尔条件

`sources` 按实例 ID 和布尔输出引用同一区段、同一状态寿命的成员。所有输入满足（all）或任一满足（any）后可取反。允许条件引用另一条件；环和重复源在装配时报告。运行时每次提交按依赖顺序求值，任一下游无法安全切换时保留原有受控状态。读取存档重新求值时保持安静。

[定义](../../../production/config/world_elements/definitions/internal.bool_condition.json) · [共用联动合同](../失序之钟_基本机关库.md)
