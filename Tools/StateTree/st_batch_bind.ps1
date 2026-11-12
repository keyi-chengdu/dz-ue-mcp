param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
$zeroGuid = '00000000-0000-0000-0000-000000000000'
$netParamGuid = '6E657450-6172-614D-4354-786553746174'

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

$script:id = 4900

# 全树清单（子树优先主树殿后）
$trees = @(
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

function TreeName($p) { ($p -replace '.*/','') -replace '\..*','' }

# 递归收集：节点分类（task/cond 名 -> [id, name]）
function ScanTree($rp, $bag) {
  $si = Call (++$script:id) 'DZStateTreeToolset.DZStateTreeEditTools' 'DescribeState' @{ state = @{ refPath = $rp } }
  try {
    $s = ($si | ConvertFrom-Json).returnValue
    foreach ($t in $s.tasks) {
      if ($t.name -match '攻击' -and $t.name -notmatch '射线') { $script:bag += @(@{ kind='attack'; id=$t.iD; name=$t.name }) }
      elseif ($t.name -match '移动') { $script:bag += @(@{ kind='move'; id=$t.iD; name=$t.name }) }
    }
    foreach ($c in $s.enterConditions + ($s.transitions | ForEach-Object { $_.conditions })) {
      if ($c.name -eq '是否有交战对象') { $script:bag += @(@{ kind='hasbattle'; id=$c.iD; name=$c.name }) }
      elseif ($c.name -eq '是否有目标对象') { $script:bag += @(@{ kind='hastarget'; id=$c.iD; name=$c.name }) }
      elseif ($c.name -match '检测与目标对象距离') { $script:bag += @(@{ kind='dist'; id=$c.iD; name=$c.name }) }
    }
    foreach ($ch in $s.children) {
      $crp = $ch.refPath; if (-not $crp) { $crp = $ch.objectPath }
      ScanTree $crp $bag
    }
  } catch {}
}

$report = @()
foreach ($tree in $trees) {
  $script:bag = @()
  $root = "$tree`:StateTreeEditorData_0.StateTreeState_0"
  ScanTree $root $bag
  if ($script:bag.Count -eq 0) { continue }

  # 现有绑定
  $b = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'GetPropertyBindings' @{ stateTree = @{ refPath = $tree }; targetStructId = $zeroGuid }
  $binds = @()
  try { $binds = ($b | ConvertFrom-Json).returnValue } catch {}
  $hasBind = @{}
  foreach ($bd in $binds) {
    $key = "$($bd.targetStructID)|$($bd.targetPath)"
    $hasBind[$key] = $true
  }

  $fixed = 0
  foreach ($item in $script:bag) {
    $rules = @()
    switch ($item.kind) {
      'attack'    { $rules = @(@{ p='InAttackTarget'; s='ATTACK_TARGET' }) }
      'move'      { $rules = @(@{ p='InActorTarget'; s='ACTOR_TARGET' }, @{ p='InHasPointTarget'; s='HAS_POINT_TARGET' }, @{ p='InTargetPoint'; s='POINT_TARGET' }) }
      'hasbattle' { $rules = @(@{ p='InAttackTarget'; s='ATTACK_TARGET' }) }
      'hastarget' { $rules = @(@{ p='InActorTarget'; s='ACTOR_TARGET' }, @{ p='InHasPointTarget'; s='HAS_POINT_TARGET' }) }
      'dist'      { $rules = @(@{ p='InTargetActor'; s='ACTOR_TARGET' }) }
    }
    foreach ($r in $rules) {
      $key = "$($item.id)|$($r.p)"
      if (-not $hasBind.ContainsKey($key)) {
        $r2 = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $netParamGuid; sourcePath = $r.s; targetStructID = $item.id; targetPath = $r.p } }
        if ($r2 -notmatch 'Cannot resolve|error|ERR') { $fixed++ } else { Write-Output ("  SKIP {0} {1} {2}: {3}" -f (TreeName $tree), $item.name, $r.p, $r2) }
      }
    }
  }
  $n = TreeName $tree
  Write-Output ("{0}: scanned={1} fixed={2}" -f $n, $script:bag.Count, $fixed)
  if ($fixed -gt 0) {
    $c = Call (++$id) 'DZStateTreeToolset.DZStateTreeEditTools' 'CompileStateTree' @{ stateTree = @{ refPath = $tree }; targetStructId = $zeroGuid }
    $ok = '?'; try { $ok = (($c | ConvertFrom-Json).returnValue).bSucceeded } catch {}
    Write-Output ("  COMPILE {0}: {1}" -f $n, $ok)
  }
}

$sv = Call (++$id) 'editor_toolset.toolsets.asset.AssetTools' 'save_assets' @{ asset_paths = @() }
Write-Output ("SAVE: " + $sv)
Write-Output "BATCH-BIND DONE"
