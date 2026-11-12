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

$script:id = 20000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'

# five fields mirrored to root params (LAST_SELFATTACKER only for 05004101, appended below)
$fields = @(
  @{ name = 'ATTACK_TARGET'; vt = 'Object'; path = '/Script/Engine.Actor' },
  @{ name = 'POINT_TARGET'; vt = 'Struct'; path = '/Script/CoreUObject.Vector' },
  @{ name = 'HAS_POINT_TARGET'; vt = 'Bool'; path = 'None' },
  @{ name = 'ATTACK_RANGE'; vt = 'Float'; path = 'None' },
  @{ name = 'ENGAGE_RANGE'; vt = 'Float'; path = 'None' }
)

$trees = @(
  '/Game/Blueprint/StateTree/05002101/ST_05002101.ST_05002101',
  '/Game/Blueprint/StateTree/05002101/ST_Sub_05002101_Battle.ST_Sub_05002101_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_Battle.ST_Sub_05002102_Battle',
  '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack',
  '/Game/Blueprint/StateTree/05002103/ST_05002103.ST_05002103',
  '/Game/Blueprint/StateTree/05002103/ST_Sub_05002103_Battle.ST_Sub_05002103_Battle',
  '/Game/Blueprint/StateTree/05002104/ST_05002104.ST_05002104',
  '/Game/Blueprint/StateTree/05002104/ST_Sub_05002104_Battle.ST_Sub_05002104_Battle',
  '/Game/Blueprint/StateTree/05002105/ST_05002105.ST_05002105',
  '/Game/Blueprint/StateTree/05002105/ST_Sub_05002105_Battle.ST_Sub_05002105_Battle',
  '/Game/Blueprint/StateTree/05003101/ST_05003101.ST_05003101',
  '/Game/Blueprint/StateTree/05003101/ST_Sub_05003101_Battle.ST_Sub_05003101_Battle',
  '/Game/Blueprint/StateTree/05004101/ST_05004101.ST_05004101',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SelectTarget.ST_Sub_SelectTarget',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Melee.ST_Sub_SurroundPlayer_Melee',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_SurroundPlayer_Ranged.ST_Sub_SurroundPlayer_Ranged',
  '/Game/Blueprint/StateTree/Common/Subtree/ST_Sub_Turn.ST_Sub_Turn',
  '/Game/Blueprint/StateTree/EnemyTest/ST_RangeEnemy_Test.ST_RangeEnemy_Test'
)

$grandTotal = 0
foreach ($t in $trees) {
  Write-Output ("===== " + $t + " =====")
  $d = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $t } }
  $rootId = ''
  try { $rootId = (($d | ConvertFrom-Json).returnValue).rootParametersId } catch {}
  if (-not $rootId) { Write-Output "  SKIP: no rootParametersId"; continue }

  foreach ($f in $fields) {
    $ap = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $t }; paramName = $f.name; valueType = $f.vt; valueTypeObjectPath = $f.path }
    if ($ap -match 'error|Error') { Write-Output ("  ADD-PARAM-ERR " + $f.name + ": " + $ap) }
  }
  if ($t -match '05004101') {
    $null = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $t }; paramName = 'LAST_SELFATTACKER'; valueType = 'Object'; valueTypeObjectPath = '/Script/Engine.Actor' }
  }

  $rb = Call (++$script:id) $st 'RebindNetParamContextToRootParameters' @{ stateTree = @{ refPath = $t }; rootParametersID = $rootId }
  Write-Output ("  REBIND: " + $rb)

  $cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $t } }
  $ok = '?'
  try { $ok = (($cp | ConvertFrom-Json).returnValue).bSucceeded } catch {}
  Write-Output ("  COMPILE: " + $ok)

  $sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($t) }
  Write-Output ("  SAVE: " + $sv)
}
Write-Output 'NETPARAM-MIGRATE DONE'
