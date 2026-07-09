param(
    [switch]$DryRun,
    [switch]$VerifyOnly,
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "coding-transform.config.json"),
    [string]$BaseToken,
    [string]$TableId,
    [string]$ViewId,
    [string]$CredentialPath,
    [string]$StatePath
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$env:PYTHONUTF8 = "1"

$script:SyncMarkerPrefix = "CODING同步"

function New-EmptyState {
    return [ordered]@{
        version = 1
        baseToken = $BaseToken
        tableId = $TableId
        viewId = $ViewId
        updatedAt = $null
        records = [ordered]@{}
    }
}

function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-Hashtable $InputObject[$key]
        }
        return $result
    }
    if ($InputObject -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-Hashtable $property.Value
        }
        return $result
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ,(ConvertTo-Hashtable $item)
        }
        return $items
    }
    return $InputObject
}

function Import-Config {
    if ([string]::IsNullOrWhiteSpace($ConfigPath) -or -not (Test-Path -LiteralPath $ConfigPath)) {
        return [ordered]@{}
    }
    return Get-Content -LiteralPath $ConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json | ConvertTo-Hashtable
}

function Resolve-Setting {
    param(
        [string]$Name,
        [string]$Value,
        [System.Collections.IDictionary]$Config,
        [string]$EnvName,
        [string]$Default,
        [switch]$Required
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) { return $Value }
    if ($Config.Contains($Name) -and -not [string]::IsNullOrWhiteSpace([string]$Config[$Name])) { return [string]$Config[$Name] }
    $envValue = [Environment]::GetEnvironmentVariable($EnvName)
    if (-not [string]::IsNullOrWhiteSpace($envValue)) { return $envValue }
    if (-not [string]::IsNullOrWhiteSpace($Default)) { return $Default }
    if ($Required) {
        throw "缺少配置：$Name。复制 coding-transform.config.example.json 为 coding-transform.config.json，或设置环境变量 $EnvName。"
    }
    return $null
}

function Resolve-LarkCliCommand {
    $cmd = Get-Command "lark-cli.cmd" -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }

    $cmd = Get-Command "lark-cli" -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }

    throw "未找到 lark-cli。请先安装飞书 CLI，并确保 lark-cli 在 PATH 中。"
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return New-EmptyState
    }

    $state = Get-Content -LiteralPath $StatePath -Encoding UTF8 -Raw | ConvertFrom-Json | ConvertTo-Hashtable
    if ($state.baseToken -ne $BaseToken -or $state.tableId -ne $TableId -or $state.viewId -ne $ViewId) {
        throw "状态文件目标与本次固定目标不一致，已停止，避免写错飞书表。StatePath=$StatePath"
    }
    if (-not $state.Contains("records") -or $null -eq $state.records) {
        $state.records = [ordered]@{}
    }
    return $state
}

function Save-State {
    param($State)

    $State.updatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $dir = Split-Path -Parent $StatePath
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $json = $State | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($StatePath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-CodingToken {
    if (-not (Test-Path -LiteralPath $CredentialPath)) {
        throw "未找到 CODING DPAPI 凭据文件：$CredentialPath"
    }
    $cred = Import-Clixml -LiteralPath $CredentialPath
    $token = $cred.GetNetworkCredential().Password
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "CODING 凭据文件存在，但 token 为空。"
    }
    return $token
}

function Invoke-CodingApi {
    param([hashtable]$Payload, [string]$Token)

    $body = $Payload | ConvertTo-Json -Depth 20 -Compress
    $headers = @{
        Authorization = "token $Token"
        "Content-Type" = "application/json"
    }
    return Invoke-RestMethod -Method Post -Uri $script:CodingOpenApi -Headers $headers -Body $body
}

function Get-CodingWorkbenchIssues {
    param([string]$Token)

    $issues = @()
    $page = 1
    $pageSize = 500
    do {
        $payload = @{
            Action = "DescribeWorkbenchIssueList"
            PageNumber = $page
            PageSize = $pageSize
            ProjectId = 0
            ShowImageOutUrl = $false
        }
        $response = Invoke-CodingApi -Payload $payload -Token $Token
        $data = $response.Response.Data
        if ($null -eq $data) {
            throw "CODING API 返回缺少 Response.Data。"
        }
        foreach ($issue in @($data.IssueList)) {
            $issues += $issue
        }
        $totalPage = [int]$data.TotalPage
        $page += 1
    } while ($page -le $totalPage)

    return $issues
}

function Invoke-FeishuCliJson {
    param([string[]]$Arguments)

    $output = & $script:LarkCliCommand @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw (($output | Out-String).Trim())
    }
    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    $lines = @($output | ForEach-Object { [string]$_ })
    $jsonStart = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimStart()
        if ($line.StartsWith("{") -or $line.StartsWith("[")) {
            $jsonStart = $i
            break
        }
    }
    if ($jsonStart -gt 0) {
        $text = ($lines[$jsonStart..($lines.Count - 1)] -join [Environment]::NewLine).Trim()
    }
    return $text | ConvertFrom-Json
}

function Write-TempJson {
    param($Body)

    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("coding-transform-{0}.json" -f ([System.Guid]::NewGuid().ToString("N")))
    $json = $Body | ConvertTo-Json -Depth 20 -Compress
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
    return $path
}

function Get-FeishuRecord {
    param([string]$RecordId)

    $args = @(
        "bitable", "record", "get",
        "--base-token", $BaseToken,
        "--table-id", $TableId,
        "--record-id", $RecordId
    )
    return Invoke-FeishuCliJson -Arguments $args
}

function Upsert-FeishuRecord {
    param(
        $Fields,
        [string]$RecordId
    )

    $body = @{ fields = $Fields }
    if ($DryRun -or $VerifyOnly) {
        return [pscustomobject]@{
            dryRun = $true
            recordId = $RecordId
            fields = $Fields
        }
    }

    $tmp = Write-TempJson -Body $body
    try {
        $args = @(
            "bitable", "record", "upsert",
            "--base-token", $BaseToken,
            "--table-id", $TableId,
            "--config-file", $tmp
        )
        if (-not [string]::IsNullOrWhiteSpace($RecordId)) {
            $args += @("--record-id", $RecordId)
        }
        return Invoke-FeishuCliJson -Arguments $args
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Find-ViewRecordByTitle {
    param([string]$Title)

    $args = @(
        "bitable", "record", "list",
        "--base-token", $BaseToken,
        "--table-id", $TableId,
        "--view-id", $ViewId,
        "--limit", "200",
        "--offset", "0"
    )
    $page = Invoke-FeishuCliJson -Arguments $args
    $titleIndex = [array]::IndexOf($page.fields, "任务简述")
    if ($titleIndex -lt 0) { return $null }
    for ($i = $page.data.Count - 1; $i -ge 0; $i--) {
        if ([string]$page.data[$i][$titleIndex] -eq $Title) {
            return [string]$page.record_id_list[$i]
        }
    }
    return $null
}

function Get-RecordMarker {
    param($RecordResponse)

    if ($null -eq $RecordResponse -or $null -eq $RecordResponse.record) {
        return $null
    }
    return [string]$RecordResponse.record."详情(备注)"
}

function Assert-SyncOwnedRecord {
    param([string]$Code, [string]$RecordId)

    $record = Get-FeishuRecord -RecordId $RecordId
    $marker = Get-RecordMarker -RecordResponse $record
    $expected = "{0};code={1}" -f $script:SyncMarkerPrefix, $Code
    if ($marker -notlike "$expected*") {
        throw "record_id=$RecordId 不包含同步标记 $expected，已拒绝更新，避免误改手工任务。"
    }
    return $record
}

function Convert-CodingTimeToDateText {
    param($Value)

    if ($null -eq $Value) { return $null }
    try { [int64]$raw = $Value } catch { return $null }
    if ($raw -le 0) { return $null }

    $minMs = 946684800000
    $maxMs = 4102444800000
    foreach ($divisor in @(1, 1000, 1000000)) {
        $ms = [int64][Math]::Floor($raw / $divisor)
        if ($ms -ge $minMs -and $ms -le $maxMs) {
            $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($ms).ToLocalTime().DateTime
            return $dt.ToString("yyyy-MM-dd 00:00:00")
        }
    }
    return $null
}

function Convert-CodingStatusToBaseStatus {
    param([string]$StatusName, [string]$StatusType)

    if ($StatusName -match "已完成|完成|已关闭|关闭") {
        return "已完成"
    }
    if ($StatusName -match "测试未通过|待测试|待开发|待处理|待排期|未开始") {
        return "待排期"
    }
    if ($StatusName -match "开发中|进行中|处理中" -or $StatusType -match "PROCESSING|IN_PROGRESS") {
        return "进行中"
    }
    return "待排期"
}

function Get-ProjectKey {
    param($Issue)

    if ($Issue.Project -and -not [string]::IsNullOrWhiteSpace($Issue.Project.Name)) {
        return [string]$Issue.Project.Name
    }
    return "unknown-project"
}

function Get-ProjectDisplayName {
    param($Issue)

    if ($Issue.Project -and -not [string]::IsNullOrWhiteSpace($Issue.Project.DisplayName)) {
        return [string]$Issue.Project.DisplayName
    }
    return (Get-ProjectKey -Issue $Issue)
}

function Resolve-TeamRecordId {
    param($Issue)

    $title = [string]$Issue.Name
    $projectKey = Get-ProjectKey -Issue $Issue
    $projectName = Get-ProjectDisplayName -Issue $Issue

    if ($title -match "数仓" -or $projectKey -eq "product-baseline-v2" -or $projectName -eq "产品基线") {
        return $script:WaterBiRecordId
    }
    if ($projectName -match "余姚" -or $title -match "余姚") {
        return $script:YuyaoRecordId
    }

    return $null
}

function Get-CodingIssueUrl {
    param($Issue)

    $projectKey = Get-ProjectKey -Issue $Issue
    return "https://{0}/p/{1}/issues/{2}" -f $script:CodingTeamHost, $projectKey, $Issue.Code
}

function New-FeishuFieldsFromIssue {
    param($Issue, [string]$SyncedAt)

    $teamRecordId = Resolve-TeamRecordId -Issue $Issue
    if ([string]::IsNullOrWhiteSpace($teamRecordId)) {
        throw "未能解析团队事项：code=$($Issue.Code), project=$(Get-ProjectDisplayName -Issue $Issue)"
    }

    $statusName = [string]$Issue.IssueStatus.Name
    $statusType = [string]$Issue.IssueStatus.Type
    $baseStatus = Convert-CodingStatusToBaseStatus -StatusName $statusName -StatusType $statusType
    $projectKey = Get-ProjectKey -Issue $Issue
    $issueUrl = Get-CodingIssueUrl -Issue $Issue
    $syncDate = (Get-Date).ToString("yyyy-MM-dd 00:00:00")
    $startDate = Convert-CodingTimeToDateText -Value $Issue.StartDate
    $dueDate = Convert-CodingTimeToDateText -Value $Issue.DueDate
    if ([string]::IsNullOrWhiteSpace($startDate)) { $startDate = $syncDate }
    if ([string]::IsNullOrWhiteSpace($dueDate)) { $dueDate = $syncDate }

    $marker = "{0};code={1};project={2};status={3};synced_at={4}" -f $script:SyncMarkerPrefix, $Issue.Code, $projectKey, $statusName, $SyncedAt

    return [ordered]@{
        "任务简述" = [string]$Issue.Name
        "团队事项" = @(@{ id = $teamRecordId })
        "当前状态" = $baseStatus
        "开始日期" = $startDate
        "预计完成日期" = $dueDate
        "负责人.部门" = @($script:OwnerDepartment)
        "任务负责人" = @(@{ id = $script:OwnerOpenId })
        "文档" = "[{0}]({0})" -f $issueUrl
        "详情(备注)" = $marker
        "事项类型" = "产品迭代"
        "是否本周任务" = "是"
    }
}

function Get-RecordIdFromUpsertResponse {
    param($Response, [string]$FallbackRecordId)

    if (-not [string]::IsNullOrWhiteSpace($FallbackRecordId)) {
        return $FallbackRecordId
    }
    if ($null -eq $Response) { return $null }
    if ($Response.record -and $Response.record.record_id) { return [string]$Response.record.record_id }
    if ($Response.record_id) { return [string]$Response.record_id }
    if ($Response.data -and $Response.data.record -and $Response.data.record.record_id) { return [string]$Response.data.record.record_id }
    return $null
}

function New-CompletedFields {
    param([string]$Code, $ExistingState, [string]$SyncedAt)

    $title = $ExistingState.title
    $projectKey = $ExistingState.project
    if ([string]::IsNullOrWhiteSpace($title)) { $title = "CODING任务 $Code" }
    if ([string]::IsNullOrWhiteSpace($projectKey)) { $projectKey = "unknown-project" }

    return [ordered]@{
        "任务简述" = $title
        "当前状态" = "已完成"
        "详情(备注)" = "{0};code={1};project={2};status=已完成;synced_at={3};completed_by_sync_at={3}" -f $script:SyncMarkerPrefix, $Code, $projectKey, $SyncedAt
    }
}

$config = Import-Config
$BaseToken = Resolve-Setting -Name "baseToken" -Value $BaseToken -Config $config -EnvName "CODING_TRANSFORM_BASE_TOKEN" -Required
$TableId = Resolve-Setting -Name "tableId" -Value $TableId -Config $config -EnvName "CODING_TRANSFORM_TABLE_ID" -Required
$ViewId = Resolve-Setting -Name "viewId" -Value $ViewId -Config $config -EnvName "CODING_TRANSFORM_VIEW_ID" -Required
$CredentialPath = Resolve-Setting -Name "credentialPath" -Value $CredentialPath -Config $config -EnvName "CODING_TRANSFORM_CREDENTIAL_PATH" -Required
$StatePath = Resolve-Setting -Name "statePath" -Value $StatePath -Config $config -EnvName "CODING_TRANSFORM_STATE_PATH" -Default "$env:USERPROFILE\.codex\state\coding-transform\sync-state.json"
$script:CodingTeamHost = Resolve-Setting -Name "codingTeamHost" -Config $config -EnvName "CODING_TRANSFORM_TEAM_HOST" -Required
$script:CodingOpenApi = Resolve-Setting -Name "codingOpenApi" -Config $config -EnvName "CODING_TRANSFORM_OPEN_API" -Default ("https://{0}/open-api" -f $script:CodingTeamHost)
$script:TeamTableId = Resolve-Setting -Name "teamTableId" -Config $config -EnvName "CODING_TRANSFORM_TEAM_TABLE_ID" -Required
$script:WaterBiRecordId = Resolve-Setting -Name "waterBiRecordId" -Config $config -EnvName "CODING_TRANSFORM_WATERBI_RECORD_ID" -Required
$script:YuyaoRecordId = Resolve-Setting -Name "yuyaoRecordId" -Config $config -EnvName "CODING_TRANSFORM_YUYAO_RECORD_ID" -Required
$script:OwnerOpenId = Resolve-Setting -Name "ownerOpenId" -Config $config -EnvName "CODING_TRANSFORM_OWNER_OPEN_ID" -Required
$script:OwnerDepartment = Resolve-Setting -Name "ownerDepartment" -Config $config -EnvName "CODING_TRANSFORM_OWNER_DEPARTMENT" -Default "后端组"
$script:LarkCliCommand = Resolve-LarkCliCommand

$summary = [ordered]@{
    mode = $(if ($DryRun) { "dry-run" } elseif ($VerifyOnly) { "verify-only" } else { "write" })
    baseToken = $BaseToken
    tableId = $TableId
    viewId = $ViewId
    codingIssueCount = 0
    stateRecordCount = 0
    created = @()
    updated = @()
    completed = @()
    skipped = @()
    errors = @()
}

try {
    $state = Read-State
    $summary.stateRecordCount = @($state.records.Keys).Count
    $token = Get-CodingToken
    $issues = @(Get-CodingWorkbenchIssues -Token $token)
    $summary.codingIssueCount = $issues.Count
    $syncedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $currentCodes = @{}
    foreach ($issue in $issues) {
        $code = [string]$issue.Code
        $currentCodes[$code] = $true
        try {
            $fields = New-FeishuFieldsFromIssue -Issue $issue -SyncedAt $syncedAt
            $recordId = $null
            if ($state.records.Contains($code)) {
                $recordId = [string]$state.records[$code].recordId
                if (-not [string]::IsNullOrWhiteSpace($recordId)) {
                    Assert-SyncOwnedRecord -Code $code -RecordId $recordId | Out-Null
                }
            } else {
                $recordId = Find-ViewRecordByTitle -Title ([string]$issue.Name)
                if (-not [string]::IsNullOrWhiteSpace($recordId)) {
                    Assert-SyncOwnedRecord -Code $code -RecordId $recordId | Out-Null
                }
            }

            $response = Upsert-FeishuRecord -Fields $fields -RecordId $recordId
            $resolvedRecordId = Get-RecordIdFromUpsertResponse -Response $response -FallbackRecordId $recordId
            if ([string]::IsNullOrWhiteSpace($resolvedRecordId)) {
                $resolvedRecordId = Find-ViewRecordByTitle -Title ([string]$issue.Name)
            }
            if ([string]::IsNullOrWhiteSpace($resolvedRecordId) -and ($DryRun -or $VerifyOnly)) {
                $resolvedRecordId = $recordId
            }

            if (-not [string]::IsNullOrWhiteSpace($resolvedRecordId)) {
                $state.records[$code] = [ordered]@{
                    recordId = $resolvedRecordId
                    title = [string]$issue.Name
                    project = Get-ProjectKey -Issue $issue
                    lastCodingStatus = [string]$issue.IssueStatus.Name
                    lastBaseStatus = [string]$fields["当前状态"]
                    lastSyncedAt = $syncedAt
                }
            }

            if ([string]::IsNullOrWhiteSpace($recordId)) {
                $summary.created += [ordered]@{ code = $code; recordId = $resolvedRecordId; title = [string]$issue.Name; status = [string]$fields["当前状态"] }
            } else {
                $summary.updated += [ordered]@{ code = $code; recordId = $recordId; title = [string]$issue.Name; status = [string]$fields["当前状态"] }
            }
        }
        catch {
            $summary.errors += [ordered]@{ code = $code; message = $_.Exception.Message }
        }
    }

    foreach ($code in @($state.records.Keys)) {
        if ($currentCodes.ContainsKey($code)) { continue }
        $recordState = $state.records[$code]
        $recordId = [string]$recordState.recordId
        if ([string]::IsNullOrWhiteSpace($recordId)) { continue }

        try {
            Assert-SyncOwnedRecord -Code $code -RecordId $recordId | Out-Null
            $fields = New-CompletedFields -Code $code -ExistingState $recordState -SyncedAt $syncedAt
            Upsert-FeishuRecord -Fields $fields -RecordId $recordId | Out-Null
            $state.records[$code].lastBaseStatus = "已完成"
            $state.records[$code].lastCodingStatus = "已从CODING工作台移除"
            $state.records[$code].lastSyncedAt = $syncedAt
            $summary.completed += [ordered]@{ code = $code; recordId = $recordId; title = $recordState.title; status = "已完成" }
        }
        catch {
            $summary.errors += [ordered]@{ code = $code; recordId = $recordId; message = $_.Exception.Message }
        }
    }

    if (-not $DryRun -and -not $VerifyOnly) {
        Save-State -State $state
    }

    $summary | ConvertTo-Json -Depth 20
}
catch {
    $summary.errors += [ordered]@{ message = $_.Exception.Message }
    $summary | ConvertTo-Json -Depth 20
    exit 1
}
