# AGENTS.md - 飞书智能日报/周报生成器

## 触发条件

当用户表达以下意图时，触发本 Skill：

- "帮我写日报" / "写个周报" / "生成工作报告"
- "今天做了什么" / "汇总一下这周的工作"
- "自动填报告" / "工作总结"
- "daily report" / "weekly report"

## 执行流程

### Phase 1: 授权预检

用户要求生成周报时，先检查 `lark-cli auth status --json --verify` 和必要 scope。缺权限时只发起一次授权链接，scope 一次性包含：

```bash
lark-cli auth login --scope "base:field:read base:record:read search:message im:message im:message.reactions:read contact:user.basic_profile:readonly search:docs:read docs:document.content:read" --no-wait --json
```

拿到 `verification_url` 后必须生成二维码并展示。用户回复已授权后，再由 agent 执行 `lark-cli auth login --device-code <device_code>` 完成登录。

### Phase 2: 数据采集

周报默认范围为本周一至今天。只读采集，先不写入、不提交：

- CODING 本周任务：优先运行 `coding-transform` 的 DryRun，读取当前待办、可完成项、状态变化，不写 Base；未安装或未配置时跳过并在素材缺口中说明。
- 用户本人最近一周聊天记录：`lark-cli im +messages-search --query='' --sender=<user_open_id> --start ... --end ... --page-all --format=json --as=user`。
- 用户被 @ / 被指示内容：`lark-cli im +messages-search --query='' --is-at-me --start ... --end ... --page-all --format=json --as=user`。
- 飞书多维表格本周工作任务：解析用户给出的 Base URL，读取字段、视图记录，再按 record_id 回查必要字段。
- 可选文档材料：需要时搜索或读取文档，但不要把无关文档堆进周报。

### Phase 3: 报告生成

先生成给用户看的模板，不发布、不填写 OA、不提交。

本周工作格式：

```text
xx项目
◦ xxxxxx。
◦ xxxx。
◦ xxxx。

xx项目
◦ xxxxxx。
◦ xxxx。
◦ xxxx。
```

写法要求：

- 按项目或主题分组，例如“余姚项目”“凤阳项目”“淮北项目”“数仓平台 / 产品基线”“飞书 / Agent 工具接入”。
- 不写“待排期 / 验证中 / 预计日期”等状态流水账。
- 可以基于任务名、聊天上下文和被 @ 内容扩展成自然工作描述。
- 下周计划按同样分组格式输出。
- 学习和沉淀有素材就写 1-3 条；没有就写“无”。

### Phase 4: 用户确认和填写

报告模板生成后先问用户是否需要调整。用户确认后再问：

- 是否需要填写进工作汇报？
- 如果需要，请提供汇报链接。

若浏览器操作可用，打开汇报链接后只填写对应字段：

- 本周工作
- 下周计划
- 学习和沉淀

**禁止点击提交**，除非用户明确说“提交”或“帮我提交”。

## 错误处理

| 错误场景 | 处理策略 |
|---------|---------|
| `lark-cli` 未安装 | 提示用户安装飞书 CLI |
| 权限不足 | 一次性生成包含全部周报 scope 的授权链接，不要分多次补 |
| 某个数据源返回空 | 不阻断流程，对应板块显示"暂无记录" |
| 文档创建失败 | 尝试重试一次，仍失败则输出 Markdown 到终端供手动复制 |
| 群聊发送失败 | 输出错误信息，建议检查 bot 是否在群中 |

## 输出规范

成功后，向用户展示：

1. 本周工作模板
2. 下周计划模板
3. 学习和沉淀
4. 明确询问“需要调整吗？是否要填写进工作汇报？”

## 示例对话

```
User: 帮我写今天的日报
Agent: [执行 collect → generate → publish]
       ✅ 日报已生成！今日参加了 3 场会议，完成了 5 个任务
       📄 查看完整报告：https://xxx.docx

User: 把周报发到产品群
Agent: 请提供产品群的 chat_id，或者我来帮你搜索群聊？
       [获取 chat_id 后执行 publish --mode chat]
```
