param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($i = 1; $i -le 4; $i++) {
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

$script:id = 37000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$main = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'
$battleRef = $main + ':StateTreeEditorData_0.StateTreeState_0.StateTreeState_9'
$tagEv = 'DZ.StateTree.EnemyEvent.TargetAcquired'

# skip if capture state already exists
$dd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $battleRef } }
$x = $null
try { $x = ($dd | ConvertFrom-Json).returnValue } catch {}
$capRef = ''
foreach ($c in @($x.children)) {
  $cd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $c.refPath } }
  $cn = ''
  try { $cn = (($cd | ConvertFrom-Json).returnValue).name } catch {}
  if ($cn -match 'TargetCapture|Capture') { $capRef = $c.refPath }
}
if ($capRef) {
  Write-Output ("CAPTURE-EXISTS: " + $capRef)
} else {
  Write-Output "=== 1. ADD CAPTURE STATE ==="
  $s1 = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $main }; Name = 'TargetCapture'; Type = 'State'; ParentState = @{ refPath = $battleRef } }
  $capRef = ''
  try { $capRef = (($s1 | ConvertFrom-Json).returnValue).refPath } catch {}
  if (-not $capRef) {
    $dd2 = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $battleRef } }
    foreach ($c in @((($dd2 | ConvertFrom-Json).returnValue).children)) {
      $cd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $c.refPath } }
      $cn = ''
      try { $cn = (($cd | ConvertFrom-Json).returnValue).name } catch {}
      if ($cn -match 'TargetCapture') { $capRef = $c.refPath }
    }
  }
  Write-Output ("CAPTURE-REF: " + $capRef)
}
if (-not $capRef) { Write-Output "FATAL: no capture state"; exit 1 }

Write-Output "=== 2. SET RequiredEventToEnter ==="
$sp = Call (++$script:id) $ot 'set_properties' @{ instance = @{ refPath = $capRef }; properties = @{ bHasRequiredEventToEnter = 'true'; RequiredEventToEnter = '(Tag=(TagName="' + $tagEv + '"),PayloadStruct=/Script/DZProject.FSTTargetAcquiredPayload)' } }
Write-Output ("SET-EVENT: " + $sp)

Write-Output "=== 3. ADD CAPTURE TASK ==="
$tn = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $capRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/DZProject.STT_CaptureEventActor' } }
$taskId = ''
try { $taskId = ($tn | ConvertFrom-Json).returnValue } catch {}
Write-Output ("TASK-ID: " + $taskId)
if ($taskId) {
  $np = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $main }; nodeID = $taskId; values = @{ MirrorKey = 'ACTOR_TARGET' } }
  Write-Output ("MIRROR-KEY: " + $np)
}

Write-Output "=== 4. BINDABLE SOURCES (Enter Event + Parameters) ==="
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $main }; targetStructId = $taskId }
Write-Output ("SOURCES: " + $bs.Substring(0, [Math]::Min(1600, $bs.Length)))
$evtSrc = ''; $paramSrc = ''
$d0 = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $main } }
$rootParamsId = ''
try { $rootParamsId = (($d0 | ConvertFrom-Json).returnValue).rootParametersId } catch {}
try {
  foreach ($s in (($bs | ConvertFrom-Json).returnValue)) {
    if ($s.source -eq 'StateEvent') { $evtSrc = $s.iD }
    if ($s.source -eq 'Parameter') { $paramSrc = $s.iD }
  }
} catch {}
Write-Output ("EVT-SRC: " + $evtSrc + "  PARAM-SRC: " + $paramSrc + "  ROOTPARAMS: " + $rootParamsId)

Write-Output "=== 5. BINDINGS x2 ==="
if ($evtSrc) {
  $b1 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $main }; binding = @{ sourceStructID = $evtSrc; sourcePath = 'TargetActor'; targetStructID = $taskId; targetPath = 'InEventActor' } }
  Write-Output ("B-EVT: " + $b1)
}
if ($paramSrc) {
  $b2 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $main }; binding = @{ sourceStructID = $paramSrc; sourcePath = 'ACTOR_TARGET'; targetStructID = $taskId; targetPath = 'RefTargetParam' } }
  Write-Output ("B-REF: " + $b2)
}

Write-Output "=== 6. TRANSITIONS ==="
$selRef = $battleRef + '.StateTreeState_6'
$engRef = $battleRef + '.StateTreeState_3'
$surRef = $battleRef + '.StateTreeState_1'
$t1 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $selRef }; settings = @{ Trigger = 'OnEvent'; EventTag = $tagEv; Type = 'GotoState'; TargetState = @{ refPath = $capRef }; bEnabled = 'true' } }
Write-Output ("T-SEL: " + $t1)
$t2 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $engRef }; settings = @{ Trigger = 'OnEvent'; EventTag = $tagEv; Type = 'GotoState'; TargetState = @{ refPath = $capRef }; bEnabled = 'true' } }
Write-Output ("T-ENG: " + $t2)
$t3 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $surRef }; settings = @{ Trigger = 'OnEvent'; EventTag = $tagEv; Type = 'GotoState'; TargetState = @{ refPath = $capRef }; bEnabled = 'true' } }
Write-Output ("T-SUR: " + $t3)
$t4 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $capRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $selRef }; bEnabled = 'true' } }
Write-Output ("T-BACK: " + $t4)

Write-Output "=== 7. COMPILE + SAVE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $main } }
Write-Output ("COMPILE: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($main) }
Write-Output ("SAVE: " + $sv)
Write-Output 'CAPTURE-SURGERY DONE'
