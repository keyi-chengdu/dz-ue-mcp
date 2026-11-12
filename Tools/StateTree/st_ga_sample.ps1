param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

$id = 4600
$enemy = '/Game/Maps/Test_Level/UEDPIE_0_Lv_Test_AI.Lv_Test_AI:PersistentLevel.BP_Enemy_C_0'

# 6 次间隔采样 GA 激活状态（抓 bIsActive=true 窗口）
for ($i = 1; $i -le 6; $i++) {
  $ga = Call (++$id) 'GASToolsets.AbilitySystemInspectorToolset' 'GetGrantedAbilities' @{ actor = @{ refPath = $enemy } }
  $active = '?'
  try {
    $list = (($ga | ConvertFrom-Json).returnValue) | Where-Object { $_.bIsActive -eq $true }
    $active = (@($list) | ForEach-Object { $_.abilityName }) -join ','
    if (-not $active) { $active = '(none)' }
  } catch { $active = 'PARSE-ERR' }
  Write-Output ("SAMPLE ${i}: active=[$active]")
  Start-Sleep -Seconds 4
}

Write-Output "GA-SAMPLE DONE"
