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

$script:id = 32000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$pkg = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack'
$obj = $pkg + '.ST_Sub_05002102_ParallelAttack'
$disk = "C:\UE\Projects\DZ_Project_New\DZ_Content\Content\Blueprint\StateTree\05002102\ST_Sub_05002102_ParallelAttack.uasset"

Write-Output "=== 1. REGISTRY READY CHECK ==="
$e0 = Call (++$script:id) $at 'exists' @{ path = $pkg }
Write-Output ("EXISTS0: " + $e0)
if ($e0 -notmatch 'true') { Write-Output "FATAL: registry has no entry (not scanned or already gone) - abort to avoid wrong branch"; exit 1 }

Write-Output "=== 2. DELETE ==="
$d1 = Call (++$script:id) $at 'delete' @{ path = $pkg }
Write-Output ("DEL: " + $d1)
Start-Sleep -Seconds 3
$e1 = Call (++$script:id) $at 'exists' @{ path = $pkg }
Write-Output ("EXISTS1: " + $e1)
if (Test-Path $disk) { Remove-Item $disk -Force; Write-Output "DISK: stale file force-removed by filesystem" }
Start-Sleep -Seconds 1
if (Test-Path $disk) { Write-Output "FATAL: disk file still present"; exit 1 }

Write-Output "=== 3. CLEAN CREATE ==="
$cr = Call (++$script:id) $st 'CreateStateTree' @{ packagePath = '/Game/Blueprint/StateTree/05002102'; assetName = 'ST_Sub_05002102_ParallelAttack'; schemaClass = @{ refPath = '/Script/DZProject.DZAIStateTreeSchema' } }
Write-Output ("CREATE: " + $cr)
Start-Sleep -Seconds 1
$d = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
$rj = $null
try { $rj = ($d | ConvertFrom-Json).returnValue } catch {}
if (-not $rj) { Write-Output "FATAL: tree not created"; exit 1 }
$rootId = $rj.rootParametersId
$rootRef = $rj.subTrees[0].refPath
Write-Output ("SCHEMA: " + $rj.schemaClass.refPath)
Write-Output ("ROOT-PARAMS: " + $rootId)
if ($rj.schemaClass.refPath -notmatch 'DZAIStateTreeSchema') {
  $sr = Call (++$script:id) $st 'SetTreeSchema' @{ stateTree = @{ refPath = $obj }; schemaClass = @{ refPath = '/Script/DZProject.DZAIStateTreeSchema' } }
  Write-Output ("SCHEMA-FIX: " + $sr)
}

Write-Output "=== 4. TREE PARAMETERS x3 ==="
foreach ($f in @(
  @{ n = 'EnemyAttackData'; vt = 'Struct'; p = '/Script/DZProject.AttackTaskData' },
  @{ n = 'ACTOR_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' },
  @{ n = 'ATTACK_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' }
)) {
  $r = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $obj }; paramName = $f.n; valueType = $f.vt; valueTypeObjectPath = $f.p }
  Write-Output ("ADD-PARAM " + $f.n + ": " + $r)
}

Write-Output "=== 5. DETECT STATE ==="
$s1 = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $obj }; Name = 'DetectNoCoolDown'; Type = 'State'; ParentState = @{ refPath = $rootRef } }
$detectRef = ''
try { $detectRef = (($s1 | ConvertFrom-Json).returnValue).refPath } catch {}
if (-not $detectRef) {
  $dd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $rootRef } }
  try { $detectRef = ((($dd | ConvertFrom-Json).returnValue).children)[0].refPath } catch {}
}
Write-Output ("DETECT-REF: " + $detectRef)
if (-not $detectRef) { Write-Output "FATAL: no detect ref"; exit 1 }

Write-Output "=== 6. CHILD STATES x4 ==="
foreach ($sn in @('RayCheck', 'AttackBehavior', 'RetryCooldown', 'AttackFinishedNotify')) {
  $null = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $obj }; Name = $sn; Type = 'State'; ParentState = @{ refPath = $detectRef } }
  Start-Sleep -Milliseconds 200
}
$dd2 = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $detectRef } }
$ch = $null
try { $ch = ((($dd2 | ConvertFrom-Json).returnValue).children) } catch {}
if (@($ch).Count -lt 4) { Write-Output ("CHILD-JSON: " + ($ch | ConvertTo-Json -Depth 6 -Compress)); Write-Output "FATAL: children missing"; exit 1 }
$rayRef = $ch[0].refPath; $atkRef = $ch[1].refPath; $retryRef = $ch[2].refPath; $notifyRef = $ch[3].refPath
Write-Output ("CHILD-COUNT: " + @($ch).Count)

Write-Output "=== 7. EC ==="
$ec = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $detectRef }; Slot = 'EnterCondition'; NodeType = @{ refPath = '/Script/DZProject.STC_Server_HasAnyTag' } }
$ecId = ''
try { $ecId = ($ec | ConvertFrom-Json).returnValue } catch {}
if ($ecId) {
  $ep = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $ecId; values = @{ NeedMatchTagContainer = '(GameplayTags=((TagName="DZ.GameplayEffect.Character.Enemy.Common.Attack.CoolDown")))' } }
  Write-Output ("EC-PROPS: " + $ep)
}

Write-Output "=== 8. TASKS x4 ==="
$tRay = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $rayRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_LineTrace.STT_LineTrace_C' } }
$tAtk = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $atkRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/DZProject.STT_Attack' } }
$tRetry = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $retryRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/StateTreeModule.StateTreeDelayTask' } }
$tNotify = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $notifyRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify_C' } }
$rayId = ''; $atkId = ''; $retryId = ''; $notifyId = ''
try { $rayId = (($tRay | ConvertFrom-Json).returnValue) } catch {}
try { $atkId = (($tAtk | ConvertFrom-Json).returnValue) } catch {}
try { $retryId = (($tRetry | ConvertFrom-Json).returnValue) } catch {}
try { $notifyId = (($tNotify | ConvertFrom-Json).returnValue) } catch {}
Write-Output ("IDS: ray=" + $rayId + " atk=" + $atkId + " retry=" + $retryId + " notify=" + $notifyId)

Write-Output "=== 9. NODE PROPS ==="
if ($retryId) {
  $dp = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $retryId; values = @{ Duration = '0.5' } }
  Write-Output ("DELAY-PROPS: " + $dp)
}
if ($notifyId) {
  $np = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $notifyId; values = @{ EventToSend = '(Tag=(TagName="DZ.StateTree.EnemyEvent.ParallelAttack.Finished"),Payload=/Script/CoreUObject.Vector(X=0,Y=0,Z=0),Origin="")' } }
  Write-Output ("NOTIFY-PROPS: " + $np)
}

Write-Output "=== 10. TRANSITIONS x5 ==="
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $atkRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $notifyRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
$tr5 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $notifyRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $detectRef }; bEnabled = 'true' } }
Write-Output ("T5: " + $tr5)

Write-Output "=== 11. BINDINGS x3 ==="
$rayInst = ''; $atkInst = ''
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $obj } }
Write-Output ("SRC-RAW: " + $bs.Substring(0, [Math]::Min(400, $bs.Length)))
try {
  $arr = ($bs | ConvertFrom-Json).returnValue
  foreach ($s in $arr) {
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_LineTrace_C$') { $rayInst = $s.iD }
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_Attack$') { $atkInst = $s.iD }
  }
} catch { Write-Output ("SRC-PARSE-ERR: " + $_.Exception.Message) }
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

Write-Output "=== 12. COMPILE + NAMED SAVE (no save-all) ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $obj } }
Write-Output ("COMPILE: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($obj) }
Write-Output ("SAVE: " + $sv)

Write-Output "=== 13. MAIN TREE CHECK ==="
$main = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'
$mcp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $main } }
Write-Output ("MAIN-COMPILE: " + $mcp)
$msv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($main) }
Write-Output ("MAIN-SAVE: " + $msv)
Write-Output 'PA-BUILD-V3 DONE'
