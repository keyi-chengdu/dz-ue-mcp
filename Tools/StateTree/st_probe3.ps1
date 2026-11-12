param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

function Call($id, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = 'DZStateTreeToolset.DZStateTreeEditTools'; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 8 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 1000

# 1) 旧 schema 树（ST_RangeEnemy_Test）的绑定源列表
Write-Output "===== SOURCES ST_RangeEnemy_Test (old schema) ====="
$s = Call (++$id) 'GetBindableSources' @{ stateTree = @{ refPath = '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test' }; targetStructId = $zeroGuid }
Write-Output $s

# 2) 新 schema 子树（Melee）的绑定源列表 —— 验证 EDB3CD97 是否为 Actor Context
Write-Output "===== SOURCES ST_Sub_SurroundPlayer_Melee (new schema) ====="
$s = Call (++$id) 'GetBindableSources' @{ stateTree = @{ refPath = '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee' }; targetStructId = $zeroGuid }
Write-Output $s

# 3) 旧 schema 类名（原始 JSON）
Write-Output "===== RAW DescribeStateTree ST_RangeEnemy_Test ====="
$d = Call (++$id) 'DescribeStateTree' @{ stateTree = @{ refPath = '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test' } }
Write-Output $d

Write-Output "PROBE3 DONE"
