param([string]$Session)
$ErrorActionPreference = 'Continue'

$base = 'http://127.0.0.1:8000/mcp'

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

function TreeArg($path) { @{ stateTree = @{ refPath = $path } } }

$id = 900

# ---- A 类：距离源丢失的树：根参数 + 相关绑定 ----
$distanceTrees = @(
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged',
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle'
)

foreach ($path in $distanceTrees) {
  $name = ($path -replace '.*/','') -replace '\..*',''
  Write-Output "===== TREE $name ====="
  $p = Call (++$id) 'GetTreeParameters' (TreeArg $path)
  try {
    $params = ($p | ConvertFrom-Json).returnValue
    Write-Output ("ROOT PARAMS: " + (($params | ForEach-Object { "$($_.Name)/$($_.ValueType)" }) -join ', '))
  } catch { Write-Output "ROOT PARAMS ERR: $p" }
  $b = Call (++$id) 'GetPropertyBindings' (TreeArg $path)
  try {
    $binds = ($b | ConvertFrom-Json).returnValue
    $dist = $binds | Where-Object { $_.sourcePath -match '距离' -or $_.targetPath -match '距离' }
    Write-Output ("DIST BINDINGS: " + $dist.Count)
    $dist | ForEach-Object { Write-Output ("  src='{0}' -> dst='{1}'" -f $_.sourcePath, $_.targetPath) }
  } catch { Write-Output "BINDINGS ERR: $b" }
}

# ---- B 类：主树链接态参数 + 根参数 ----
$mainTrees = @(
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

foreach ($path in $mainTrees) {
  $name = ($path -replace '.*/','') -replace '\..*',''
  Write-Output "===== TREE $name ====="
  $p = Call (++$id) 'GetTreeParameters' (TreeArg $path)
  try {
    $params = ($p | ConvertFrom-Json).returnValue
    Write-Output ("ROOT PARAMS: " + (($params | ForEach-Object { "$($_.Name)/$($_.ValueType)" }) -join ', '))
  } catch { Write-Output "ROOT PARAMS ERR: $p" }
  $ls = Call (++$id) 'DescribeLinkedStates' (TreeArg $path)
  try {
    $lines = ($ls | ConvertFrom-Json).returnValue
    $lines | ForEach-Object { Write-Output ("LINKED: " + $_) }
  } catch { Write-Output "LINKED ERR: $ls" }
  $b = Call (++$id) 'GetPropertyBindings' (TreeArg $path)
  try {
    $binds = ($b | ConvertFrom-Json).returnValue
    $stale = $binds | Where-Object { $_.sourcePath -match 'LAST_SELFATTACKER|EnemyAttackData|EnemyPlayMontageTag' }
    Write-Output ("REF-RELATED BINDINGS: " + $stale.Count)
    $stale | ForEach-Object { Write-Output ("  src='{0}'[{1}] -> dst='{2}'" -f $_.sourcePath, $_.sourceStructID, $_.targetPath) }
  } catch { Write-Output "BINDINGS ERR: $b" }
}

# ---- C 类：ST_RangeEnemy_Test 根参数 ----
Write-Output "===== TREE ST_RangeEnemy_Test ====="
$p = Call (++$id) 'GetTreeParameters' (TreeArg '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test')
try {
  $params = ($p | ConvertFrom-Json).returnValue
  Write-Output ("ROOT PARAMS: " + (($params | ForEach-Object { "$($_.Name)/$($_.ValueType)" }) -join ', '))
} catch { Write-Output "ROOT PARAMS ERR: $p" }

# ---- D 类：ST_05004101 找 SumonLocation 任务节点 ----
Write-Output "===== NODES ST_05004101 ====="
$info = Call (++$id) 'DescribeStateTree' (TreeArg '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101')
try {
  $rv = ($info | ConvertFrom-Json).returnValue
  Write-Output ("SCHEMA: " + $rv.schemaClass.path)
  foreach ($sub in $rv.subTrees) {
    $si = Call (++$id) 'DescribeState' @{ state = @{ objectPath = $sub.path } }
    try {
      $s = ($si | ConvertFrom-Json).returnValue
      foreach ($t in $s.tasks) {
        if ($t.name -match 'Sumon|Summon') {
          Write-Output ("FOUND TASK: id=" + $t.id + " name=" + $t.name + " nodeType=" + $t.nodeType.path + " path=" + $s.path)
          $np = Call (++$id) 'GetNodeProperties' @{ stateTree = @{ refPath = '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101' }; nodeID = $t.id }
          Write-Output ("PROPS: " + $np)
        }
      }
      foreach ($c in $s.children) {
        $ci = Call (++$id) 'DescribeState' @{ state = @{ objectPath = $c.path } }
        try {
          $cc = ($ci | ConvertFrom-Json).returnValue
          foreach ($t in $cc.tasks) {
            if ($t.name -match 'Sumon|Summon') {
              Write-Output ("FOUND TASK(child): id=" + $t.id + " name=" + $t.name + " nodeType=" + $t.nodeType.path + " path=" + $cc.path)
              $np = Call (++$id) 'GetNodeProperties' @{ stateTree = @{ refPath = '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101' }; nodeID = $t.id }
              Write-Output ("PROPS: " + $np)
            }
          }
        } catch {}
      }
    } catch { Write-Output ("DESCRIBE-STATE ERR: " + $si) }
  }
} catch { Write-Output ("DESCRIBE ERR: " + $info) }

Write-Output "PROBE DONE"
