# Lark Daily Report - 飞书智能日报/周报生成器

<p align="center">
  <strong>你什么都不用写，AI 自动帮你汇总一天的工作成果 ✨</strong>
</p>

<p align="center">
  <a href="#-功能特性">功能特性</a> •
  <a href="#-快速开始">快速开始</a> •
  <a href="#-报告示例">报告示例</a> •
  <a href="#-作为飞书-cli-skill-使用">Skill 使用</a> •
  <a href="#-配置选项">配置</a>
</p>

---

## 参赛信息

**🏆 飞书 CLI 创作者大赛 - GitHub 赛道作品**

本作品基于 [飞书 CLI](https://github.com/larksuite/cli) 开发，完全符合参赛要求：

| 要求 | 状态 |
|------|------|
| 基于飞书 CLI 开发 | ✅ 核心依赖 |
| 代码开源 + 清晰 README | ✅ 本文件 |
| 原创、无知识产权纠纷 | ✅ 纯原创开发 |
| 解决明确业务痛点 | ✅ 自动化工作报告 |
| 有独特技术亮点 | ✅ AI 分析 + 效率洞察 |
| 技术可行性验证通过 | ✅ 全链路测试 |

---

## ✨ 功能特性

### 核心能力

- 📅 **自动采集会议记录** — 从飞书日历提取今日/本周所有会议详情
- ✅ **任务进展追踪** — 自动汇总已完成和进行中的任务（含截止时间）
- 📝 **文档动态整理** — 汇总最近编辑的飞书文档（含类型标签）
- 💬 **沟通摘要提取** — 提取关键 IM 消息（智能去重去噪）

### 差异化亮点

- 🤖 **AI 智能分析** — 接入 LLM API（OpenAI/DeepSeek/通义千问/Ollama），自动生成专业工作总结
- 🔍 **效率洞察** — 会议时长分析、任务完成率评估、工作节奏诊断
- 💡 **智能建议** — 基于数据自动生成下一步行动建议
- 📤 **多渠道输出** — 一键写入飞书文档 / 发送到群聊

## 快速开始

### 前置条件

```bash
# 1. 安装飞书 CLI
brew install lark-cli  # 或参考官方文档安装

# 2. 完成认证
lark-cli auth login

# 3. 克隆本项目
git clone https://github.com/你的用户名/larkcli.git
cd larkcli
```

### 一键生成日报

```bash
# 生成今日日报
./start.sh daily

# 生成本周周报
./start.sh weekly

# 生成日报并发送到指定群聊
./start.sh daily oc_xxxxxxxxxx
```

### 分步执行

```bash
# Step 1: 采集数据
python3 skills/lark-daily-report/scripts/collect.py --mode daily > data.json

# Step 2: 生成报告（自动调用 AI 分析）
python3 skills/lark-daily-report/scripts/generate.py --data data.json --output report.md

# Step 3: 发布到飞书文档
python3 skills/lark-daily-report/scripts/publish.py --report report.md --mode doc
```

## 报告示例

生成的报告包含以下板块：

```
# 📋 工作日报 - 2026-04-03

> 自动生成于 2026-04-03T10:45:00 | 数据来源：飞书日历 / 任务 / 文档 / 即时通讯 | 🤖 AI 增强

---

## 📊 今日概览

| 指标 | 数据 |
|------|------|
| 会议场次 | 3 场（120 分钟） |
| 已完成任务 | 5 个 |
| 进行中任务 | 3 个 |
| 编辑文档 | 8 个 |
| 关键消息 | 12 条 |

> 🤖 **AI 智能分析**
>
> 今日主要完成了产品评审会的讨论，推进了登录模块重构和 API 文档编写...
> 整体工作效率良好，建议关注即将到期的 3 个任务。

## 🔍 效率洞察

> 📊 会议时间 120 分钟，节奏适中
> 🎯 任务完成率 62%，持续推进中
> 📝 文档协作活跃（8 个）

## 📅 会议记录

**1. 产品评审会**
   - 时间：10:00 | 时长：60分钟（8人参会）📍 3F-A会议室

**2. 技术对齐**
   - 时间：14:00 | 时长：30分钟（4人参会）

> 总计：2 场会议，120 分钟

## ✅ 任务进展

### 已完成任务
- **完成登录页面重构** 截止: 2026-04-02 [查看](url)
- **修复 #123 Bug** [查看](url)

### 🔄 进行中任务
- **API 文档编写** 截止: 2026-04-05 [查看](url)
- **性能优化方案设计** 截止: 2026-04-08 [查看](url)

## 💡 下一步建议

- 优先推进带截止日期的任务：API 文档编写、性能优化方案设计
- 跟进今日会议的行动项：产品评审会结论落地

---

*本报告由 **Lark Daily Report** Skill 自动生成 ✨*
```

## 架构设计

```
larkcli/
├── start.sh                              # 一键启动脚本
├── .env.example                          # 环境配置模板
├── .gitignore
├── README.md
└── skills/lark-daily-report/             # 飞书 CLI Skill（符合官方规范）
    ├── SKILL.md                          # Skill 定义
    ├── AGENTS.md                         # Agent 执行指南
    └── scripts/
        ├── collect.py                    # 数据采集引擎
        │   ├── collect_calendar()         # 日历日程采集
        │   ├── collect_tasks()            # 任务状态采集
        │   ├── collect_documents()        # 文档编辑记录
        │   └── collect_messages()         # IM 消息摘要
        ├── generate.py                   # 报告生成引擎
        │   ├── _generate_ai_summary()     # AI 智能总结
        │   ├── _generate_insights()       # 效率洞察分析
        │   ├── _generate_suggestions()    # 下一步建议
        │   └── template rendering        # Markdown 模板渲染
        ├── ai_engine.py                  # LLM AI 引擎
        │   ├── analyze_work_summary()     # 工作内容总结
        │   ├── generate_insights()        # 数据洞察生成
        │   └── suggest_next_steps()       # 行动建议生成
        └── publish.py                    # 报告发布器
            ├── publish_to_doc()           # 写入飞书文档
            └── publish_to_chat()          # 发送到群聊
```

## 作为飞书 CLI Skill 使用

本仓库完全符合 [飞书 CLI Skill 规范](https://github.com/larksuite/cli)，可直接作为 Skill 安装：

```bash
# 方式一：复制到 Trae skills 目录
cp -r skills/lark-daily-report ~/.trae-cn/skills/

# 方式二：在 Trae IDE 中引用本项目的 skills 目录
```

安装后，在任何支持飞书 CLI 的 AI Agent 中说 **"帮我写日报"** 即可触发。

## Feishu Report Skill 使用说明

飞书周报 / 日报生成 skill。当前安装名为 `feishu report`，仓库路径保留为 `skills/lark-daily-report` 以兼容原目录。

### 适用场景

- 生成本周周报、本日日报或工作总结。
- 从飞书聊天、多维表格、CODING 任务中整理工作内容。
- 先生成可复制的周报模板，再按用户确认填写进飞书工作汇报。

### 周报数据源

- CODING 本周任务：优先使用 `coding-transform` DryRun，只读采集。
- 飞书聊天记录：采集用户最近一周本人消息。
- 飞书被 @ 内容：采集用户最近一周被 @、被指派、被询问的内容。
- 飞书多维表格：读取本周工作任务、任务描述和必要上下文。
- 可选文档材料：需要时读取相关飞书文档，不强行堆入周报。

### 周报输出格式

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

### 安全边界

- 默认只生成模板，不发布、不提交、不写入汇报。
- 填写工作汇报前必须先问用户是否需要调整，以及是否要填写进工作汇报。
- 浏览器填写时只填“本周工作”“下周计划”“学习和沉淀”等对应字段。
- 禁止点击提交，除非用户明确要求提交。
- 不输出 token、App Secret、账号密码等敏感信息。

## 配置选项

复制 `.env.example` 为 `.env` 并按需配置：

```bash
cp .env.example .env
```

### LLM AI 引擎配置（可选）

不配置时使用本地模板模式，配置后启用真正的 AI 分析：

```bash
# OpenAI (推荐)
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-xxx

# DeepSeek (国内推荐)
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=sk-xxx

# 通义千问
LLM_PROVIDER=qwen
DASHSCOPE_API_KEY=sk-xxx

# 本地 Ollama (免费无需 API Key)
LLM_PROVIDER=ollama
```

### 输出配置

```bash
LARK_REPORT_CHAT_ID=oc_xxx          # 默认发送目标群聊
LARK_REPORT_FOLDER_TOKEN=folder_xxx  # 默认文档存放文件夹
LARK_REPORT_MODE=daily               # 默认报告模式
```

## 所需权限

生成周报前先检查 `lark-cli auth status --json --verify`。缺权限时一次性请求：

```bash
lark-cli auth login --scope "base:field:read base:record:read search:message im:message im:message.reactions:read contact:user.basic_profile:readonly search:docs:read docs:document.content:read" --no-wait --json
```

| Scope | 用途 |
|-------|------|
| `base:field:read` | 读取多维表格字段 |
| `base:record:read` | 读取多维表格记录 |
| `search:message` | 搜索消息记录 |
| `search:docs:read` | 搜索文档 |
| `im:message` | 获取消息内容 |
| `im:message.reactions:read` | 读取消息互动 |
| `contact:user.basic_profile:readonly` | 解析联系人名称 |
| `docs:document.content:read` | 读取文档内容 |

## 技术栈

- **运行环境**: Python 3.9+（无第三方依赖）
- **核心依赖**: 飞书 CLI (`lark-cli`)
- **AI 能力**: OpenAI 兼容 API / 本地 Ollama
- **输出格式**: Markdown → 飞书文档 / IM 消息

## License

[MIT](LICENSE)

---

<div align="center">

**Made with ❤️ for 飞书 CLI 创作者大赛**

如果这个项目对你有帮助，欢迎给一个 ⭐ Star！

</div>
