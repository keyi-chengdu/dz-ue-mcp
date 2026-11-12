param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'

$netParamGuid = '6E657450-6172-614D-4354-786553746174'
$staleBlackboardGuid = 'EDB3CD97-95F9-4E0A-BD15-207B98645CDC'
$zeroGuid = '00000000-0000-0000-0000-000000000000'

function Call($id, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = 'DZStateTreeToolset.DZStateTreeEditTools'; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 10 -Compress
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

function TreeArg($path) { @{ stateTree = @{ refPath = $path }; targetStructId = $zeroGuid } }
function RVal($json) { try { return ($json | ConvertFrom-Json).returnValue } catch { return $null } }
function TName($path) { ($path -replace '.*/','') -replace '\..*','' }

$id = 1300

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

# ============ Phase C2: 悬空黑板距离绑定 -> NetParam ============
$distMap = @{}
$distMap[[string]([char]0x4EA4 + [char]0x6218 + [char]0x8DDD + [char]0x79BB)] = 'ENGAGE_RANGE'
$distMap[[string]([char]0x653B + [char]0x51FB + [char]0x8DDD + [char]0x79BB)] = 'ATTACK_RANGE'

foreach ($path in $order) {
  $b = Call (++$id) 'GetPropertyBindings' (TreeArg $path)
  $binds = RVal $b
  if (-not $binds) { Write-Output ("BIND {0}: NONE ({1})" -f (TName $path), $b); continue }
  $stale = @($binds | Where-Object { $_.sourceStructID -eq $staleBlackboardGuid })
  Write-Output ("BIND {0}: total={1} stale={2}" -f (TName $path), @($binds).Count, $stale.Count)
  foreach ($sb in $stale) {
    $newSrc = $null
    if ($distMap.ContainsKey($sb.sourcePath)) { $newSrc = $distMap[$sb.sourcePath] } else { $newSrc = 'ATTACK_RANGE' }
    $add = Call (++$id) 'AddPropertyBinding' @{ stateTree = @{ refPath = $path }; binding = @{ sourceStructID = $netParamGuid; sourcePath = $newSrc; targetStructID = $sb.targetStructID; targetPath = $sb.targetPath } }
    Write-Output ("REBIND {0}: '{1}' -> {2} dst='{3}' : {4}" -f (TName $path), $sb.sourcePath, $newSrc, $sb.targetPath, $add)
  }
}

# ============ Phase E: 全树编译 ============
$green = 0; $red = 0
foreach ($path in $order) {
  $c = Call (++$id) 'CompileStateTree' (TreeArg $path)
  $ok = '?'
  $errLines = @()
  try {
    $cr = RVal $c
    $ok = $cr.bSucceeded
    foreach ($msg in $cr.messages) { if ($msg.severity -ne 'Info') { $errLines += ("    [{0}] {1}" -f $msg.severity, $msg.message) } }
  } catch { $ok = 'PARSE-ERR' }
  if ($ok -eq $true) { $green++ } else { $red++ }
  Write-Output ("{0} | compile={1}" -f (TName $path), $ok)
  $errLines | ForEach-Object { Write-Output $_ }
}
Write-Output "SUMMARY: green=$green red=$red"
Write-Output "ROUND5 DONE"
