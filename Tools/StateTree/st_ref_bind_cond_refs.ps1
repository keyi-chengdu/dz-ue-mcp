param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'

function Call($id, $tool, $toolArgs) {
  $inner = @{ toolset_name = 'DZStateTreeToolset.DZStateTreeEditTools'; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 8 -Compress
  $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -and $txt.Trim()) {
        if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
        return (($txt | ConvertFrom-Json).result.content[0].text)
      }
    } catch { if ($attempt -eq 3) { return "HTTP-ERR" } }
    Start-Sleep -Milliseconds 600
  }
  return $null
}

$id = 2800
# 条件 Ref 字段链式绑定规则（树内条件读通道；主树参数为值、子树参数为 Ref 接线柱，source 各自可达）
$rules = @(
  @{ nodeType = @{ refPath = '/Script/DZProject.STC_Server_HasBattleTarget' }; inputPropertyName = 'RefAttackTarget'; paramName = 'ATTACK_TARGET'; bOverwriteExisting = $false },
  @{ nodeType = @{ refPath = '/Script/DZProject.STC_Server_HasBattleTarget' }; inputPropertyName = 'RefActorTarget';  paramName = 'ACTOR_TARGET';    bOverwriteExisting = $false },
  @{ nodeType = @{ refPath = '/Script/DZProject.STC_Server_CheckHasTarget' };  inputPropertyName = 'RefActorTarget';  paramName = 'ACTOR_TARGET';    bOverwriteExisting = $false },
  @{ nodeType = @{ refPath = '/Script/DZProject.STC_Server_CheckDistance' };   inputPropertyName = 'RefTargetActor';  paramName = 'ACTOR_TARGET';    bOverwriteExisting = $false }
)

$trees = @(
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack',
  '/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle.ST_Sub_05002103_Battle',
  '/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle.ST_Sub_05002104_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle.ST_Sub_05003101_Battle',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged',
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

foreach ($tree in $trees) {
  $name = ($tree -replace '.*/','') -replace '\..*',''
  $treeArg = @{ stateTree = @{ refPath = $tree }; rules = $rules }
  $b = Call (++$id) 'BindTaskInputsFromTreeParameters' $treeArg
  $bound = '?'
  try { $bound = ($b | ConvertFrom-Json).returnValue } catch { $bound = $b }
  $cr = ((Call (++$id) 'CompileStateTree' @{ stateTree = @{ refPath = $tree } }) | ConvertFrom-Json).returnValue
  Write-Output ("{0}: condRefBinds={1} compile={2}" -f $name, $bound, $cr.bSucceeded)
  if (-not $cr.bSucceeded) { foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { Write-Output ("  [{0}] {1}" -f $msg.severity, $msg.message) } } }
}
