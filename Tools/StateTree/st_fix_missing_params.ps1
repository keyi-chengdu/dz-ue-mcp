param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
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

$script:id = 34000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'

$paramMap = @{
  'ACTOR_TARGET'       = @('Object', '/Script/Engine.Actor')
  'ATTACK_TARGET'      = @('Object', '/Script/Engine.Actor')
  'LAST_SELFATTACKER'  = @('Object', '/Script/Engine.Actor')
  'POINT_TARGET'       = @('Struct', '/Script/CoreUObject.Vector')
  'HAS_POINT_TARGET'   = @('Bool', '')
  'ATTACK_RANGE'       = @('Float', '')
  'ENGAGE_RANGE'       = @('Float', '')
  'EnemyAttackData'    = @('Struct', '/Script/DZProject.AttackTaskData')
}
# display-name words -> FName lookup
$dnMap = @{
  'ACTOR TARGET' = 'ACTOR_TARGET'
  'ATTACK TARGET' = 'ATTACK_TARGET'
  'LAST SELFATTACKER' = 'LAST_SELFATTACKER'
  'POINT TARGET' = 'POINT_TARGET'
  'HAS POINT TARGET' = 'HAS_POINT_TARGET'
  'ATTACK RANGE' = 'ATTACK_RANGE'
  'ENGAGE RANGE' = 'ENGAGE_RANGE'
  'Enemy Attack Data' = 'EnemyAttackData'
}

$trees = @(
  # leaf subtrees first, main trees last
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn.ST_Sub_Turn',
  '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test',
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  '/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle.ST_Sub_05002103_Battle',
  '/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle.ST_Sub_05002104_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle.ST_Sub_05003101_Battle',
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101'
)

$dirtyList = @()
foreach ($t in $trees) {
  $name = ($t -split '/')[ -1 ] -replace '\..*',''
  $green = $false
  $added = @()
  for ($round = 1; $round -le 3; $round++) {
    $c = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $t } }
    $ok = ''; $msgs = ''
    try { $rj = ($c | ConvertFrom-Json).returnValue; $ok = $rj.bSucceeded; $msgs = ($rj.messages | ConvertTo-Json -Depth 5 -Compress) } catch { $msgs = $c }
    if ($ok -eq $true -or $ok -eq 'True') { $green = $true; break }
    # extract missing source properties
    $found = [regex]::Matches($msgs, "source property '([^']+)'")
    $newParams = @()
    foreach ($m in $found) {
      $dn = $m.Groups[1].Value
      if ($dnMap.ContainsKey($dn)) {
        $fname = $dnMap[$dn]
        if ($added -notcontains $fname) { $newParams += $fname }
      } else {
        Write-Output ("  UNKNOWN-SRC [" + $name + "]: '" + $dn + "'")
      }
    }
    if ($newParams.Count -eq 0) { break }
    foreach ($p in $newParams) {
      $pm = $paramMap[$p]
      $null = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $t }; paramName = $p; valueType = $pm[0]; valueTypeObjectPath = $pm[1] }
      $added += $p
    }
  }
  # final compile
  if (-not $green) {
    $c = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $t } }
    try { $green = (($c | ConvertFrom-Json).returnValue).bSucceeded } catch { $green = $false }
  }
  if ($added.Count -gt 0 -or -not $green) {
    $sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($t) }
    $dirtyList += $name
  }
  $status = 'GREEN'; if (-not $green) { $status = 'STILL-RED' }
  Write-Output ($name + " => " + $status + " added=[" + ($added -join ',') + "]")
}
Write-Output ("Touched: " + ($dirtyList -join ', '))
Write-Output 'BATCH-FIX-PARAMS DONE'
