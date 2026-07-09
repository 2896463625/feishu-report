param(
    [string]$CodingConfigPath = (Join-Path $PSScriptRoot "..\skills\coding-transform\coding-transform.config.json"),
    [switch]$StrictCoding
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$script:Failed = $false

function Write-Check {
    param(
        [bool]$Ok,
        [string]$Message,
        [string]$Hint = ""
    )

    if ($Ok) {
        Write-Host "[通过] $Message"
        return
    }

    $script:Failed = $true
    Write-Host "[失败] $Message"
    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        Write-Host "       处理建议：$Hint"
    }
}

function Write-Warn {
    param([string]$Message, [string]$Hint = "")
    Write-Host "[提醒] $Message"
    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        Write-Host "       说明：$Hint"
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "Feishu Report Skill 环境检查"
Write-Host "仓库目录：$repoRoot"
Write-Host ""

$larkCli = Get-Command "lark-cli.cmd" -ErrorAction SilentlyContinue
if ($null -eq $larkCli) {
    $larkCli = Get-Command "lark-cli" -ErrorAction SilentlyContinue
}
Write-Check -Ok ($null -ne $larkCli) -Message "已找到 lark-cli" -Hint "请先安装飞书 CLI，并确保 lark-cli 在 PATH 中。"

$python = Get-Command "python3" -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command "python" -ErrorAction SilentlyContinue
}
Write-Check -Ok ($null -ne $python) -Message "已找到 Python" -Hint "日报/周报脚本需要 Python 3。"

Write-Check -Ok (Test-Path (Join-Path $repoRoot "skills\feishu-report\SKILL.md")) -Message "已找到 feishu-report skill"
Write-Check -Ok (Test-Path (Join-Path $repoRoot "skills\coding-transform\SKILL.md")) -Message "已找到 coding-transform skill"

$syncScript = Join-Path $repoRoot "skills\coding-transform\scripts\sync-coding-transform.ps1"
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($syncScript, [ref]$tokens, [ref]$parseErrors) | Out-Null
Write-Check -Ok ($parseErrors.Count -eq 0) -Message "coding-transform PowerShell 脚本语法正常" -Hint (($parseErrors | Select-Object -First 1).Message)

if ($null -ne $larkCli) {
    try {
        $authRaw = & $larkCli.Source auth status --json --verify 2>$null
        $auth = ($authRaw | Out-String | ConvertFrom-Json)
        Write-Check -Ok ([bool]$auth.verified) -Message "lark-cli 用户授权可用" -Hint "请执行 README 中的一次性授权命令。"
    }
    catch {
        Write-Warn -Message "暂未确认 lark-cli 授权状态" -Hint "如果要生成周报，请先运行 README 中的一次性授权命令。"
    }
}

if (Test-Path -LiteralPath $CodingConfigPath) {
    try {
        $config = Get-Content -LiteralPath $CodingConfigPath -Encoding UTF8 -Raw | ConvertFrom-Json
        $required = @(
            "baseToken",
            "tableId",
            "viewId",
            "credentialPath",
            "codingTeamHost",
            "teamTableId",
            "waterBiRecordId",
            "yuyaoRecordId",
            "ownerOpenId"
        )
        foreach ($name in $required) {
            $value = $config.$name
            Write-Check -Ok (-not [string]::IsNullOrWhiteSpace([string]$value)) -Message "coding-transform 配置项 $name 已填写" -Hint "请在 coding-transform.config.json 中补充该字段。"
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$config.credentialPath)) {
            Write-Check -Ok (Test-Path -LiteralPath $config.credentialPath) -Message "CODING 凭据文件存在" -Hint "请按 README 使用 DPAPI 保存 CODING token，并更新 credentialPath。"
        }
    }
    catch {
        Write-Check -Ok $false -Message "coding-transform 配置文件无法解析" -Hint $_.Exception.Message
    }
}
else {
    if ($StrictCoding) {
        Write-Check -Ok $false -Message "未找到 coding-transform.config.json" -Hint "复制 coding-transform.config.example.json 后填入自己的配置。"
    }
    else {
        Write-Warn -Message "未找到 coding-transform.config.json" -Hint "不使用 CODING 数据源时可以忽略；需要 CODING 周报素材时请先配置。"
    }
}

if ($script:Failed) {
    Write-Host ""
    Write-Host "检查结果：存在需要处理的问题。"
    exit 1
}

Write-Host ""
Write-Host "检查结果：基础环境可用。"
