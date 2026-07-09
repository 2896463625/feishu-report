# Coding Transform 目标表映射

## 目标配置

目标 Base 不再写死在 skill 里。复制 `coding-transform.config.example.json` 为 `coding-transform.config.json`，填写：

- `baseToken`: 飞书 Base token。
- `tableId`: 任务表 ID。
- `viewId`: 任务视图 ID。
- `teamTableId`: `团队事项` 关联表 ID。
- `waterBiRecordId`: 数仓/产品基线类任务的关联记录 ID。
- `yuyaoRecordId`: 余姚或默认项目类任务的关联记录 ID。
- `ownerOpenId`: 飞书负责人 open_id。
- `ownerDepartment`: 负责人部门。

## 字段

| 飞书字段 | 类型 | 写入规则 |
|---|---|---|
| `任务简述` | text | CODING issue title |
| `团队事项` | link | 根据项目类型写入配置中的关联 record_id |
| `当前状态` | select | `待排期` / `进行中` / `已完成` |
| `开始日期` | datetime | `YYYY-MM-DD 00:00:00` |
| `预计完成日期` | datetime | `YYYY-MM-DD 00:00:00` |
| `负责人.部门` | multiselect | `ownerDepartment` |
| `任务负责人` | user | `ownerOpenId` |
| `文档` | url/text | CODING issue URL |
| `详情(备注)` | text | 同步所有权标记 |

## 同步所有权

只把同时满足以下条件的记录视为脚本管理记录：

1. 本地状态文件中存在 CODING code -> record_id。
2. 飞书记录 `详情(备注)` 包含 `CODING同步;code=<code>`。

历史上手工任务的 `文档` 字段可能包含 `coding.net` 链接，但这不是同步所有权标记，不能更新。
