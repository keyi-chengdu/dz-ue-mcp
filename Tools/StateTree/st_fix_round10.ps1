param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
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

function TName($path) { ($path -replace '.*/','') -replace '\..*','' }

$id = 1800
$treePath = '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'

# 1) 配置 05004101 Schema 的 AIController Context 类型为蓝图控制器
$set = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'SetSchemaAIControllerClass' @{ stateTree = @{ refPath = $treePath }; aiControllerClass = @{ refPath = '/Game/Core/BP_DZAIController.BP_DZAIController_C' } }
Write-Output ("SET-AIControllerClass: " + $set)

# 2) 全部 23 棵树编译
$order = @(
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_HurtReaction.ST_Sub_HurtReaction',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Jump.ST_Sub_Jump',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_NoCombat.ST_Sub_NoCombat',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn.ST_Sub_Turn',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged',
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack',
  '/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle.ST_Sub_05002103_Battle',
  '/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle.ST_Sub_05002104_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle.ST_Sub_05003101_Battle',
  '/Game/Blueprint/StateTree/EnemyTest/ST_Enemy_Test.ST_Enemy_Test',
  '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test',
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

$green = 0; $red = 0
foreach ($path in $order) {
  $c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $path }; targetStructId = $zeroGuid }
  $ok = '?'
  $errLines = @()
  try {
    $cr = ($c | ConvertFrom-Json).returnValue
    $ok = $cr.bSucceeded
    foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { $errLines += ("    [{0}] {1}" -f $msg.severity, $msg.message) } }
  } catch { $ok = 'PARSE-ERR' }
  if ($ok -eq $true) { $green++ } else { $red++ }
  Write-Output ("{0} | compile={1}" -f (TName $path), $ok)
  $errLines | ForEach-Object { Write-Output $_ }
}
Write-Output "SUMMARY: green=$green red=$red"

# 3) 全部保存
$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)

Write-Output "ROUND10 DONE"
