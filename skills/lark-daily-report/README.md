# Feishu Report Skill

飞书周报 / 日报生成 skill。当前安装名为 `feishu report`，仓库路径保留为 `skills/lark-daily-report` 以兼容原目录。

## 适用场景

- 生成本周周报、本日日报或工作总结。
- 从飞书聊天、多维表格、CODING 任务中整理工作内容。
- 先生成可复制的周报模板，再按用户确认填写进飞书工作汇报。

## 周报数据源

- CODING 本周任务：优先使用 `coding-transform` DryRun，只读采集。
- 飞书聊天记录：采集用户最近一周本人消息。
- 飞书被 @ 内容：采集用户最近一周被 @、被指派、被询问的内容。
- 飞书多维表格：读取本周工作任务、任务描述和必要上下文。
- 可选文档材料：需要时读取相关飞书文档，不强行堆入周报。

## 一次性授权

生成周报前先检查 `lark-cli auth status --json --verify`。缺权限时一次性请求：

```bash
lark-cli auth login --scope "base:field:read base:record:read search:message im:message im:message.reactions:read contact:user.basic_profile:readonly search:docs:read docs:document.content:read" --no-wait --json
```

拿到 `verification_url` 后必须生成二维码给用户授权。用户授权完成后，再执行：

```bash
lark-cli auth login --device-code <device_code>
```

## 输出格式

本周工作和下周计划按项目或主题分组，不写状态流水账，不写预计日期。

```text
余姚项目
◦ 跟进六月水务营收数据差异分析，处理相关数据问题。
◦ 完成离线报警数据重构，报警信息内容进入验证。
◦ 排查取水、供水相关指标接口来源，确认页面数据与 API 返回差异。

凤阳项目
◦ 推进营收数据对接，梳理源表结构和统计口径。
◦ 梳理热线、营收两类数据接入逻辑，确认派单、受理、完成等业务规则。
```

学习和沉淀有素材就写 1-3 条；没有就写“无”。

## 安全边界

- 默认只生成模板，不发布、不提交、不写入汇报。
- 填写工作汇报前必须先问用户是否需要调整，以及是否要填写进工作汇报。
- 浏览器填写时只填“本周工作”“下周计划”“学习和沉淀”等对应字段。
- 禁止点击提交，除非用户明确要求提交。
- 不输出 token、App Secret、账号密码等敏感信息。

