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

$script:id = 21000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'

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

$green = 0; $red = 0
foreach ($t in $trees) {
  foreach ($f in $fields) {
    $null = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $t }; paramName = $f.name; valueType = $f.vt; valueTypeObjectPath = $f.path }
  }
  if ($t -match '05004101') {
    $null = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $t }; paramName = 'LAST_SELFATTACKER'; valueType = 'Object'; valueTypeObjectPath = '/Script/Engine.Actor' }
  }
  $cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $t } }
  $ok = '?'; $firstErr = ''
  try {
    $rv = (($cp | ConvertFrom-Json).returnValue)
    $ok = $rv.bSucceeded
    if (-not $ok -and $rv.messages) { $firstErr = $rv.messages[0].message }
  } catch {}
  $sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($t) }
  if ($ok -eq $true) { $green++; Write-Output ("GREEN: " + $t) }
  else { $red++; Write-Output ("RED: " + $t + "  ERR=" + $firstErr) }
}
Write-Output ("SUMMARY GREEN=" + $green + " RED=" + $red)
Write-Output 'FIXFIELDS DONE'
