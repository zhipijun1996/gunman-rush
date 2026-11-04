---
name: project-integration
description: 项目归整、依赖清理、分支整合、构建与Web交付。
---

# project-integration

## 适用任务

项目归整、依赖清理、分支整合、构建与Web交付。

## 操作

1. 核 Git 工作区、基线、依赖、写集与授权；通过模块导航检查实际引用、动态加载、UID、导出和许可，再移动或删除。
2. 先整理受影响的设计与数据正文，再同步实现和配置；按 [协作规则](../../../docs/project/cloud_production.md) 更新当前交接，清理临时稿并保留必要证据。
3. 运行四项日常 CI 和相关专项，核精确提交、接口与结果，交付可审阅差异；合并和发布按本次授权。
4. 试玩优先复用同源已验 Web 包，通过现有 prepared 工作流发布并核公开 build-info、PCK 身份和实际入口；独立预览使用独立目标。

## 验证与交付

使用 `tools/ci.py`、显式相关专项及现行导出／部署工具。交付可审阅差异、删除依据、验证／未验范围与恢复命令；合并、发布各按当前授权执行。

模板：[现有设计卡](../../../docs/project/templates/cloud_workline.md)。验收方法见 [开发质量](../../../docs/project/development.md)，实现与检查入口见 [模块导航](../../../docs/project/module_map.md)。
