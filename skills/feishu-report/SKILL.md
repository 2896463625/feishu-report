---
name: feishu-report
version: 1.0.0
description: "Use when用户需要生成飞书日报/周报、汇总本周工作、整理下周计划、预览后填写工作汇报。"
metadata:
  requires:
    bins: ["lark-cli"]
    skills: ["coding-transform"]
  cliHelp: "lark-cli --help"
---

# 飞书智能日报/周报生成器

**CRITICAL — 开始前 MUST 先用 Read 工具读取 [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md)，其中包含认证、权限处理**

> 一句话描述：你什么都不用写，AI 自动帮你汇总一天的工作成果 ✨

## 周报硬性流程

用户说“生成周报 / 帮我写周报 / 总结本周工作”时，按这个流程走：

1. 先检查用户身份和 scope；若缺权限，只发起**一次**授权，scope 一次性包含完成周报所需权限，不要分多轮补权限：
   ```bash
   lark-cli auth login --scope "base:field:read base:record:read search:message im:message im:message.reactions:read contact:user.basic_profile:readonly search:docs:read docs:document.content:read" --no-wait --json
   ```
   拿到 `verification_url` 后必须生成二维码并展示。用户授权完成后再继续。
2. 周报素材必须尽量收集：
   - CODING 本周任务：优先调用 `coding-transform` 只读 / DryRun，不写入 Base；如果未安装或未配置，跳过该数据源并告知用户。
   - 用户最近一周本人聊天记录。
   - 用户最近一周被 @、被指派、被询问的聊天内容。
   - 飞书多维表格本周工作任务。
   - 下周计划任务和可延续工作。
   - 可适当总结学习、沉淀、流程优化；没有就写“无”。
3. 先给用户生成周报模板，不发布、不提交、不写入汇报。
4. 模板给出后询问是否需要调整；如果工具支持浏览器操作，再问是否填写进工作汇报，并要求用户提供汇报链接。
5. 浏览器填报时只填写“本周工作”“下周计划”“学习和沉淀”等对应字段；**不得点击提交**，除非用户明确要求提交。

## 周报输出模板

本周工作按项目 / 主题分组，格式固定如下。不要写“待排期 / 验证中 / 预计日期”等状态流水账，要把任务扩展成自然的工作描述：

```text
余姚项目
◦ 跟进六月水务营收数据差异分析，处理相关数据问题。
◦ 完成离线报警数据重构，报警信息内容进入验证。
◦ 排查取水、供水相关指标接口来源，确认页面数据与 API 返回差异。

凤阳项目
◦ 推进营收数据对接，梳理源表结构和统计口径。
◦ 梳理热线、营收两类数据接入逻辑，确认派单、受理、完成等业务规则。
◦ 分析费用表区域字段质量问题，推动区域维度映射或 ETL 清洗方案。

数仓平台 / 产品基线
◦ 处理数据同步任务创建后左侧数量统计未及时更新问题。
◦ 处理 API 管理新增接口按钮无反应和页面显示异常问题。
◦ 推进 Coding 任务同步到飞书多维表格流程，完成任务读取和状态匹配校验。
```

下周计划也按相同分组格式输出。学习和沉淀可写 1-3 条；没有明确素材就写“无”。

## 核心能力

| 数据源 | 采集内容 | 使用 API |
|--------|---------|----------|
| 📅 日历 | 今日/本周会议列表、时长、参会人 | `calendar +agenda` |
| ✅ 任务 | 已完成任务、进行中任务、截止时间 | `task +get-my-tasks` |
| 📝 文档 | 编辑过的文档标题、类型、时间 | `docs +search` |
| 💬 IM | 关键消息摘要（群聊、发送者、内容） | `im +messages-search` |
| CODING | 本周研发工作台任务、已完成/处理中事项 | `coding-transform` DryRun |
| Base | 本周工作任务、多维表格任务状态和描述 | `base +record-list` / `+record-get` |

## 工作流程

### Step 1: 数据采集

```bash
# 采集今日数据（默认）
python scripts/collect.py --mode daily

# 采集本周数据
python scripts/collect.py --mode weekly

# 指定日期
python scripts/collect.py --mode daily --date 2026-04-03

# 输出到文件供后续使用
python scripts/collect.py --mode daily > /tmp/daily_data.json
```

### Step 2: 报告生成

```bash
# 从采集数据生成 Markdown 报告
python scripts/generate.py --data /tmp/daily_data.json

# 指定模式
python scripts/generate.py --data /tmp/daily_data.json --mode weekly

# 输出到文件
python scripts/generate.py --data /tmp/daily_data.json --output /tmp/report.md
```

### Step 3: 发布报告

```bash
# 写入飞书文档
python scripts/publish.py --report /tmp/report.md --mode doc

# 发送到群聊（需指定 chat_id）
python scripts/publish.py --report /tmp/report.md --mode chat --chat-id oc_xxx

# 同时写入文档和发送群聊
python scripts/publish.py --report /tmp/report.md --mode both --chat-id oc_xxx
```

### 一键完整流程

```bash
# 日报一键生成
python scripts/collect.py --mode daily | python scripts/generate.py --data - --output /tmp/daily_report.md && python scripts/publish.py --report /tmp/daily_report.md --mode doc

# 周报一键生成
python scripts/collect.py --mode weekly | python scripts/generate.py --data - --output /tmp/weekly_report.md && python scripts/publish.py --report /tmp/weekly_report.md --mode doc
```

## 报告结构说明

生成的报告包含以下板块：

1. **📊 今日/本周概览** — 核心指标仪表盘（会议数、任务数、文档数、消息数）
2. **AI 智能分析** — 基于数据的自动总结（可接入 LLM 增强）
3. **📅 会议记录** — 时间线排列的所有会议详情
4. **✅ 任务进展** — 已完成任务 vs 进行中任务分类展示
5. **📝 文档动态** — 最近编辑的文档列表（含类型标签和链接）
6. **💬 沟通摘要** — 关键消息提取（去重、去噪）
7. **🎯 下周计划建议**（仅周报）— 基于未完成任务自动生成建议

## 权限要求

周报优先使用用户身份。缺权限时一次性请求以下 scope，不要一个失败补一次：

| 操作 | 所需 Scope |
|------|-----------|
| 读取 Base 字段 | `base:field:read` |
| 读取 Base 记录 | `base:record:read` |
| 搜索消息记录 | `search:message` |
| 获取消息内容 | `im:message` |
| 读取消息表情/互动 | `im:message.reactions:read` |
| 解析联系人名称 | `contact:user.basic_profile:readonly` |
| 搜索云空间文档 | `search:docs:read` |
| 读取文档内容 | `docs:document.content:read` |

如遇权限不足，运行：
```bash
lark-cli auth login --scope "base:field:read base:record:read search:message im:message im:message.reactions:read contact:user.basic_profile:readonly search:docs:read docs:document.content:read" --no-wait --json
```

## 配置选项

可通过环境变量自定义行为：

| 环境变量 | 说明 | 默认值 |
|---------|------|-------|
| `LARK_REPORT_CHAT_ID` | 默认发送目标群聊 ID | 无 |
| `LARK_REPORT_FOLDER_TOKEN` | 默认文档存放文件夹 | 无 |
| `LARK_REPORT_MODE` | 默认报告模式 (daily/weekly) | daily |

## 注意事项

- 所有数据采集均使用 `--as user` 身份，确保获取的是**用户自己的**数据
- IM 消息搜索仅返回用户有权限访问的群聊消息
- 文档搜索基于"最近打开时间"，可能包含浏览但未编辑的文档
- 周报先预览给用户确认；发布、填写 OA、提交汇报都必须等用户明确要求
- 报告中的 AI 总结部分可进一步接入 LLM API 实现真正的智能分析
