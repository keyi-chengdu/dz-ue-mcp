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

$script:id = 33000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$obj = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack'
$main = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'

Write-Output "=== 1. FIND OLD CHINESE STATE ==="
$d0 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
$rj = $null
try { $rj = ($d0 | ConvertFrom-Json).returnValue } catch {}
if (-not $rj) { Write-Output "FATAL: tree not found"; exit 1 }
$rootId = $rj.rootParametersId
$rootRef = $rj.subTrees[0].refPath
Write-Output ("ROOT: " + $rootRef)
$dd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $rootRef } }
$ch = $null
try { $ch = (($dd | ConvertFrom-Json).returnValue).children } catch {}
$oldRef = ''; $newRef = ''
foreach ($c in @($ch)) {
  $cd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $c.refPath } }
  $cn = ''
  try { $cn = (($cd | ConvertFrom-Json).returnValue).name } catch {}
  Write-Output ("ROOT-CHILD: [" + $cn + "] :: " + $c.refPath)
  if ($cn -eq 'DetectNoCoolDown') { $newRef = $c.refPath } else { $oldRef = $c.refPath }
}
if (-not $newRef) { Write-Output "FATAL: no DetectNoCoolDown child"; exit 1 }

if ($oldRef) {
  Write-Output "=== 2. REMOVE OLD STATE ==="
  $rm = Call (++$script:id) $st 'RemoveState' @{ state = @{ refPath = $oldRef } }
  Write-Output ("REMOVE: " + $rm)
} else {
  Write-Output "=== 2. NO OLD STATE (clean) ==="
}

Write-Output "=== 3. VERIFY TREE ==="
$d1 = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $rootRef } }
Write-Output ("ROOT-CHILDREN-AFTER: " + $d1)

Write-Output "=== 4. BINDABLE SOURCES (zeroGuid) ==="
$zero = '00000000-0000-0000-0000-000000000000'
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $obj }; targetStructId = $zero }
$rayInst = ''; $atkInst = ''
try {
  $arr = ($bs | ConvertFrom-Json).returnValue
  foreach ($s in $arr) {
    if ($s.structType -and $s.structType.refPath -match 'STT_LineTrace_C$') { $rayInst = $s.iD }
    if ($s.structType -and $s.structType.refPath -match 'STT_Attack$') { $atkInst = $s.iD }
  }
} catch { Write-Output ("SRC-PARSE-ERR: " + $_.Exception.Message + " RAW: " + $bs.Substring(0, [Math]::Min(300, $bs.Length))) }
Write-Output ("RAY-INST: " + $rayInst + "  ATK-INST: " + $atkInst)
if ($rayInst) {
  $b1 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootId; sourcePath = 'ACTOR_TARGET'; targetStructID = $rayInst; targetPath = 'inTargetActor' } }
  Write-Output ("B-RAY: " + $b1)
}
if ($atkInst) {
  $b2 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootId; sourcePath = 'ATTACK_TARGET'; targetStructID = $atkInst; targetPath = 'InAttackTarget' } }
  Write-Output ("B-ATK: " + $b2)
  $b3 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootId; sourcePath = 'EnemyAttackData'; targetStructID = $atkInst; targetPath = 'RefAttackTaskData' } }
  Write-Output ("B-DATA: " + $b3)
}

Write-Output "=== 5. VERIFY NODE PROPS ==="
$pv1 = Call (++$script:id) $st 'GetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = '1E79E541-CE37-4FAD-C3DC-77D172C37DD7' }
Write-Output ("EC-PROPS-V: " + $pv1)
$pv2 = Call (++$script:id) $st 'GetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = 'E0A9C717-EE7B-F330-9F55-11FE71D8DBB3' }
Write-Output ("DELAY-PROPS-V: " + $pv2)
$pv3 = Call (++$script:id) $st 'GetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = '6E283D8A-AF8F-11A4-9991-4CE634464AA1' }
Write-Output ("NOTIFY-PROPS-V: " + $pv3)

Write-Output "=== 6. COMPILE + SAVE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $obj } }
Write-Output ("COMPILE-PA: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($obj) }
Write-Output ("SAVE-PA: " + $sv)
$mcp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $main } }
Write-Output ("MAIN-COMPILE: " + $mcp)
$msv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($main) }
Write-Output ("MAIN-SAVE: " + $msv)
Write-Output 'PA-FINISH-V4 DONE'
