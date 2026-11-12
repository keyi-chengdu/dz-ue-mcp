# st_doc_push_feishu.ps1 — 把本地 Markdown 推送到飞书文档（lark-cli 封装）
#
# 用法：
#   .\st_doc_push_feishu.ps1 -DocUrl "https://pcnnehcdhvg9.feishu.cn/wiki/<token>" -ContentFile "doc.md" [-Command append|overwrite]
#
# 前置（一次性）：
#   lark-cli 的 user 身份必须已授权。⚠️ DSH 沙箱内跑 `auth login` 会因命名互斥量限制
#   保存 token 失败（授权成功但报 "failed to acquire token storage lock"）——
#   请在【自己的终端】（不经过 agent/沙箱）执行一次：
#     C:\UE\Projects\DZ_Project_New\DZ_Content\.lark-cli\lark-cli.exe auth login --domain docs,wiki
#   授权长期有效；本脚本（普通 API 调用读 token）在沙箱内可正常运行。
#
# 流程：检查 user 身份 → docs +update 写入（markdown @file）→ 回读 outline 验证。
param(
    [Parameter(Mandatory = $true)][string]$DocUrl,
    [Parameter(Mandatory = $true)][string]$ContentFile,
    [ValidateSet('append', 'overwrite')][string]$Command = 'append',
    [string]$CliPath = ""
)

$ErrorActionPreference = 'Stop'
if (-not $CliPath) {
    $CliPath = Join-Path $PSScriptRoot "..\..\..\..\DZ_Content\.lark-cli\lark-cli.exe"
}
$CliPath = [System.IO.Path]::GetFullPath($CliPath)

foreach ($check in @($CliPath, $ContentFile)) {
    if (-not (Test-Path $check)) { throw "文件不存在: $check" }
}
$ContentFile = [System.IO.Path]::GetFullPath($ContentFile)

Write-Host "[1/3] 检查 user 身份..."
$who = & $CliPath whoami --as user --json 2>$null | ConvertFrom-Json
if (-not $who.available) {
    throw @"
user 身份不可用（$($who.tokenStatus)）。请在自己的终端（非 agent 沙箱）执行一次：
  $CliPath auth login --domain docs,wiki
浏览器确认授权后重跑本脚本。
"@
}
Write-Host ("      OK: {0} (token {1})" -f $who.onBehalfOf.userName, $who.tokenStatus)

Write-Host "[2/3] 写入文档（$Command）..."
$update = & $CliPath docs +update --as user --doc $DocUrl --command $Command --doc-format markdown --content "@$ContentFile" 2>$null | ConvertFrom-Json
if (-not $update.ok) {
    $msg = $update.warnings -join '; '
    throw "写入失败: $($update.error.message) $msg"
}
Write-Host ("      OK: revision {0}" -f $update.data.document.revision_id)

Write-Host "[3/3] 回读目录验证..."
$fetch = & $CliPath docs +fetch --as user --doc $DocUrl --scope outline --doc-format markdown 2>$null | ConvertFrom-Json
if ($fetch.ok) {
    Write-Host "====== 文档当前目录 ======"
    $fetch.data.document.content -split "`n" | Where-Object { $_ -match '^#' } | ForEach-Object { Write-Host $_ }
    Write-Host "=========================="
    Write-Host ("完成: {0}" -f $update.data.document.url)
} else {
    Write-Warning "写入成功但回读失败，请手动打开文档确认。"
}
