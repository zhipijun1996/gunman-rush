---
name: project-integration
description: 项目归整、依赖清理、分支整合、构建与Web交付。
---

# project-integration

## 适用任务

项目归整、依赖清理、分支整合、构建与Web交付。

## 操作

1. 检查Git工作区、基线／祖先、任务写集与用户授权。按模块导航核当前消费者、动态加载、UID、导出及许可，再移动或删除文件。
2. 按 [协作规则](../../../docs/cloud_production.md) 更新任务自己的交接；当前产品改变时才更新全局状态和对应设计。
3. 用影响计划选择验证。合入核精确提交与CI合流；试玩优先复用同源已验Web包，通过现有prepared工作流发布。
4. 发布后验证公开build-info、完整PCK身份和目标GUI入口。需要独立Preview时选择独立托管目标；记录实际可访问的媒体／构建链接。

## 验证与交付

使用 `production_plan.py`、相关Harness检查和 `check_release_evidence.py`。交付可审阅差异、删除依据、验证／未验范围与恢复命令；合并、发布各按当前授权执行。

任务使用 [现有设计卡](../../../docs/templates/cloud_workline.md)。质量阶段、独立审查、证据与未验声明共用 [开发质量](../../../docs/development_quality.md)；验证选择见 [Harness](../../../docs/harness.md)，代码落点见 [模块导航](../../../docs/module_map.md)。
