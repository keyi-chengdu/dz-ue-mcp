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

$id = 2600
# 字段 -> Ref 默认值类型（refTypeName, typeObjectPath）
$fieldTypes = @{
  'ACTOR_TARGET'       = @('Object', '/Script/Engine.Actor')
  'ATTACK_TARGET'      = @('Object', '/Script/Engine.Actor')
  'LAST_SELFATTACKER'  = @('Object', '/Script/Engine.Actor')
  'HAS_POINT_TARGET'   = @('Bool',   '')
  'POINT_TARGET'       = @('Struct', '/Script/CoreUObject.Vector')
  'EnemyAttackData'    = @('Struct', '/Script/DZProject.AttackTaskData')
  'EnemyPlayMontageTag'= @('Struct', '/Script/GameplayTags.GameplayTag')
}

$subtrees = @(
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack',
  '/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle.ST_Sub_05002103_Battle',
  '/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle.ST_Sub_05002104_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle.ST_Sub_05003101_Battle',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged'
)

foreach ($tree in $subtrees) {
  $name = ($tree -replace '.*/','') -replace '\..*',''
  $treeArg = @{ stateTree = @{ refPath = $tree } }
  $fails = 0
  # 1) bag 相关字段换 Ref 接线柱（仅该树已有字段才换——先查）
  $params = ((Call (++$id) 'GetTreeParameters' $treeArg) | ConvertFrom-Json).returnValue
  $existing = @{}
  foreach ($p in $params) { $existing[$p.name] = $true }
  foreach ($kv in $fieldTypes.GetEnumerator()) {
    $f = $kv.Key
    if (-not $existing.ContainsKey($f)) { continue }
    $null = Call (++$id) 'RemoveTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = $f }
    $null = Call (++$id) 'AddTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = $f; valueType = 'Struct'; valueTypeObjectPath = '/Script/StateTreeModule.StateTreeBlueprintPropertyRef' }
    $r3 = Call (++$id) 'SetTreeParameterRefDefault' @{ stateTree = @{ refPath = $tree }; paramName = $f; refTypeName = $kv.Value[0]; typeObjectPath = $kv.Value[1] }
    if ($r3 -notmatch 'true') { $fails++; Write-Output "  SETFAIL $name ${f}: $r3" }
  }
  # 2) 迁移工具幂等重建任务链式绑定
  $m = Call (++$id) 'MigrateWriteParamToPropertyRef' $treeArg
  # 3) 编译
  $cr = ((Call (++$id) 'CompileStateTree' $treeArg) | ConvertFrom-Json).returnValue
  Write-Output ("{0}: fails={1} compile={2}" -f $name, $fails, $cr.bSucceeded)
  if (-not $cr.bSucceeded) { foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { Write-Output ("  [{0}] {1}" -f $msg.severity, $msg.message) } } }
}

# 主树 feed 补全（7 字段全量）
$mains = @(
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)
$feed = @('ACTOR_TARGET','ATTACK_TARGET','LAST_SELFATTACKER','HAS_POINT_TARGET','POINT_TARGET','EnemyAttackData','EnemyPlayMontageTag')
Write-Output '---- main trees ----'
foreach ($tree in $mains) {
  $name = ($tree -replace '.*/','') -replace '\..*',''
  $treeArg = @{ stateTree = @{ refPath = $tree } }
  $b = Call (++$id) 'BindLinkedStateParametersFromTree' @{ stateTree = @{ refPath = $tree }; paramNames = $feed }
  $bound = '?'
  try { $bound = ($b | ConvertFrom-Json).returnValue } catch { $bound = $b }
  $cr = ((Call (++$id) 'CompileStateTree' $treeArg) | ConvertFrom-Json).returnValue
  Write-Output ("{0}: feed={1} compile={2}" -f $name, $bound, $cr.bSucceeded)
  if (-not $cr.bSucceeded) { foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { Write-Output ("  [{0}] {1}" -f $msg.severity, $msg.message) } } }
}
