---
name: coding-transform
description: Use when the user asks to read, preview, or sync CODING/Coding DevOps workbench tasks into a Feishu Base task table.
---

# Coding Transform

把当前用户的 CODING DevOps 研发工作台任务同步到用户配置的飞书多维表格任务表。默认先 DryRun 预览，只有用户明确要求同步时才写入 Base。

## Required Config

先复制配置模板，并填入自己的 Feishu Base、CODING 团队和负责人信息：

```powershell
Copy-Item "$env:USERPROFILE\.codex\skills\coding-transform\coding-transform.config.example.json" "$env:USERPROFILE\.codex\skills\coding-transform\coding-transform.config.json"
```

脚本默认读取 `coding-transform.config.json`，也支持用同名参数或环境变量覆盖。配置项见 `coding-transform.config.example.json`。

CODING token 不写进配置文件。Windows 推荐保存为 DPAPI 凭据文件：

```powershell
$token = Read-Host "Paste CODING token" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential("coding", $token)
$cred | Export-Clixml "$env:USERPROFILE\.codex\credentials\coding.credential.xml"
```

然后把该路径填到 `credentialPath`。

## Commands

只预览，不写入：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\coding-transform\scripts\sync-coding-transform.ps1" -DryRun
```

写入/更新 Base：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\coding-transform\scripts\sync-coding-transform.ps1"
```

只检查配置、凭据和远端读取链路：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\coding-transform\scripts\sync-coding-transform.ps1" -VerifyOnly
```

执行后用中文简要告诉用户：读取到多少个 CODING 任务、创建几条、更新几条、标记完成几条、跳过/失败原因。

## Sync Rules

1. 从 CODING OpenAPI `DescribeWorkbenchIssueList` 读取研发工作台待办事项。
2. 读取 `statePath` 保存的同步状态，只记录脚本写入过的 CODING code 与 Feishu record_id。
3. 当前 CODING 任务不存在本地状态时创建记录，存在时只更新对应 record_id。
4. 状态文件中存在、但本次 CODING 工作台已不存在的任务，只把对应记录的 `当前状态` 更新为 `已完成`。
5. 同步所有权只看本地状态文件和 `详情(备注)` 中的 `CODING同步;code=` 标记，不根据标题相似或链接猜测。

## Field Mapping

目标 Base 需要包含这些字段：

- `任务简述`: CODING issue title。
- `团队事项`: 根据项目写入配置中的关联 record_id。
- `当前状态`: `待排期`、`进行中`、`已完成`。
- `开始日期`、`预计完成日期`: CODING 有日期就同步，没有就用同步当天。
- `负责人.部门`: `ownerDepartment`。
- `任务负责人`: `ownerOpenId`。
- `文档`: CODING issue URL。
- `详情(备注)`: `CODING同步;code=<code>;project=<projectKey>;status=<codingStatus>;synced_at=<time>`。

## Safety

- 不删除飞书记录。
- 不修改没有 `CODING同步;code=` 标记的手工任务。
- 缺少配置时直接停止。
- 不在回答、日志、Skill 或脚本里输出明文 token。
- 写入前先 DryRun；生产 Base 写操作需要用户明确确认。
