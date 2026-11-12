param([string]$Session, [string]$Tree)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($i = 1; $i -le 5; $i++) {
    try {
      $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
      $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 180 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { Start-Sleep -Seconds 1 }
  }
  return "HTTP-ERR-ALL"
}

$script:id = 35200
$st = 'DZStateTreeToolset.DZStateTreeEditTools'

$obj = $Tree
$root = $obj + ':StateTreeEditorData_0.StateTreeState_0'
$d0 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
$rootParamsId = ''
try { $rootParamsId = (($d0 | ConvertFrom-Json).returnValue).rootParametersId } catch {}
Write-Output ("ROOT-PARAMS: " + $rootParamsId)

# walk states, collect parametersId (parallel arrays - PS5.1 flattens nested arrays)
$script:stateNames = @()
$script:statePids = @()
function Walk($refPath, $pathName, $depth) {
  if ($depth -gt 8) { return }
  $d = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $refPath } }
  $x = $null
  try { $x = ($d | ConvertFrom-Json).returnValue } catch { return }
  if (-not $x) { return }
  $pid2 = ''
  try { $pid2 = $x.parametersId } catch {}
  $script:stateNames += ($pathName + "/" + $x.name)
  $script:statePids += $pid2
  foreach ($c in @($x.children)) { Walk $c.refPath ($pathName + "/" + $x.name) ($depth + 1) }
}
Walk $root '' 0

for ($si = 0; $si -lt $script:stateNames.Count; $si++) {
  $pname = $script:stateNames[$si]
  $p = $script:statePids[$si]
  if (-not $p -or $p.Length -lt 36) { continue }
  $pb = Call (++$script:id) $st 'GetPropertyBindings' @{ stateTree = @{ refPath = $obj }; targetStructId = $p }
  $cnt = -1
  try { $cnt = @((($pb | ConvertFrom-Json).returnValue)).Count } catch { $cnt = -1 }
  if ($cnt -lt 7) {
    Write-Output ("PARTIAL-PARAMS " + $pname + " id=" + $p + " bindings=" + $cnt + " -> completing supply bindings")
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'EnemyPlayMontageTag'; targetStructID = $p; targetPath = 'EnemyPlayMontageTag' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'EnemyAttackData'; targetStructID = $p; targetPath = 'EnemyAttackData' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'ACTOR_TARGET'; targetStructID = $p; targetPath = 'ACTOR_TARGET' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'ATTACK_TARGET'; targetStructID = $p; targetPath = 'ATTACK_TARGET' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'POINT_TARGET'; targetStructID = $p; targetPath = 'POINT_TARGET' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'HAS_POINT_TARGET'; targetStructID = $p; targetPath = 'HAS_POINT_TARGET' } }
    $null = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $obj }; binding = @{ sourceStructID = $rootParamsId; sourcePath = 'MoveRequestOver'; targetStructID = $p; targetPath = 'MoveRequestOver' } }
  } else {
    Write-Output ("PARAMS " + $pname + " id=" + $p + " bindings=" + $cnt)
  }
}
$c = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $obj } }
$head = $c
if ($head.Length -gt 500) { $head = $head.Substring(0,500) }
Write-Output ("COMPILE: " + $head)
$at = 'editor_toolset.toolsets.asset.AssetTools'
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($obj) }
Write-Output ("SAVE: " + $sv)
Write-Output 'FIX-STATEPARAMS DONE'
