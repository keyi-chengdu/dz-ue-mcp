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
    Start-Sleep -Milliseconds 400
  }
  return $null
}

$id = 3900
$enemy = '/Game/Maps/Test_Level/UEDPIE_0_Lv_Test_AI.Lv_Test_AI:PersistentLevel.BP_Enemy_C_0'

# 敌人位置采样 x2（移动验证）
$t1 = Call (++$id) 'editor_toolset.toolsets.actor.ActorTools' 'get_actor_transform' @{ actor = @{ refPath = $enemy } }
Write-Output ("E-T0: $t1")
Start-Sleep -Seconds 10
$t2 = Call (++$id) 'editor_toolset.toolsets.actor.ActorTools' 'get_actor_transform' @{ actor = @{ refPath = $enemy } }
Write-Output ("E-T1(+10s): $t2")

# ASC 能力激活状态（攻击验证）
$ga = Call (++$id) 'GASToolsets.AbilitySystemInspectorToolset' 'GetGrantedAbilities' @{ actor = @{ refPath = $enemy } }
Write-Output ("GRANTED: $ga")

Write-Output "BEHAVIOR PROBE DONE"
