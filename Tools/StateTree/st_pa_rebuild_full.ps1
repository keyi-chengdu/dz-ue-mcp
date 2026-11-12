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

function P($refPath, $dir, $idx) { return @{ node = @{ refPath = $refPath }; direction = $dir; index_id = $idx } }

$script:id = 26000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$tree = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack.ST_Sub_05002102_ParallelAttack'

Write-Output "=== 1. DELETE OLD TREE ==="
$del = Call (++$script:id) $at 'delete' @{ path = $tree }
Write-Output ("DELETE: " + $del)
Start-Sleep -Seconds 2

Write-Output "=== 2. CREATE SAME-NAME TREE ==="
$cr = Call (++$script:id) $st 'CreateStateTree' @{ packagePath = '/Game/Blueprint/StateTree/05002102'; assetName = 'ST_Sub_05002102_ParallelAttack'; schemaClass = @{ refPath = '/Script/DZProject.DZAIStateTreeSchema' } }
Write-Output ("CREATE: " + $cr)

$rootId = ''
$d = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $tree } }
try { $rootId = (($d | ConvertFrom-Json).returnValue).rootParametersId } catch {}
Write-Output ("ROOT-PARAMS: " + $rootId)
$rootRef = $tree + ':StateTreeEditorData_0.StateTreeState_0'

Write-Output "=== 3. ADD TREE PARAMETERS x3 ==="
foreach ($f in @(
  @{ n = 'EnemyAttackData'; vt = 'Struct'; p = '/Script/DZProject.AttackTaskData' },
  @{ n = 'ACTOR_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' },
  @{ n = 'ATTACK_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' }
)) {
  $r = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $tree }; paramName = $f.n; valueType = $f.vt; valueTypeObjectPath = $f.p }
  Write-Output ("ADD-PARAM " + $f.n + ": " + $r)
}

Write-Output "=== 4. ADD STATES (english temp names) ==="
$s1 = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $tree }; Name = 'DetectNoCoolDown'; Type = 'State'; ParentState = @{ refPath = $rootRef } }
Write-Output ("S-DETECT: " + $s1)
$detectRef = ''
try { $detectRef = (($s1 | ConvertFrom-Json).returnValue).refPath } catch {}
if (-not $detectRef) { $detectRef = $rootRef + '.StateTreeState_1' }
Write-Output ("DETECT-REF: " + $detectRef)

foreach ($sn in @('RayCheck', 'AttackBehavior', 'RetryCooldown', 'AttackFinishedNotify')) {
  $null = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $tree }; Name = $sn; Type = 'State'; ParentState = @{ refPath = $detectRef } }
}
$dd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $detectRef } }
$rayRef = ''; $atkRef = ''; $retryRef = ''; $notifyRef = ''
try {
  $x = ($dd | ConvertFrom-Json).returnValue
  foreach ($c in $x.children) {
    $nm = $c.refPath
    if ($nm -match 'StateTreeState_3$') { $rayRef = $nm }
    elseif ($nm -match 'StateTreeState_4$') { $atkRef = $nm }
    elseif ($nm -match 'StateTreeState_0$') { $retryRef = $nm }
    else { $notifyRef = $nm }
  }
} catch { Write-Output ("CHILD-ERR: " + $_.Exception.Message) }
Write-Output ("RAY: " + $rayRef)
Write-Output ("ATK: " + $atkRef)
Write-Output ("RETRY: " + $retryRef)
Write-Output ("NOTIFY: " + $notifyRef)

Write-Output "=== 5. EC ON DETECT STATE ==="
$ec = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $detectRef }; Slot = 'EnterCondition'; NodeType = @{ refPath = '/Script/DZProject.STC_Server_HasAnyTag' } }
Write-Output ("EC-NODE: " + $ec)
$ecId = ''
try { $ecId = ($ec | ConvertFrom-Json).returnValue } catch {}
if ($ecId) {
  $ep = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $tree }; nodeID = $ecId; values = @{ GameplayTags = '(GameplayTags=((TagName="DZ.GameplayEffect.Character.Enemy.Common.Attack.CoolDown")))' } }
  Write-Output ("EC-PROPS: " + $ep)
}

Write-Output "=== 6. ADD TASK NODES ==="
$tRay = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $rayRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_LineTrace.STT_LineTrace_C' } }
$tAtk = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $atkRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/DZProject.STT_Attack' } }
$tRetry = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $retryRef }; Slot = 'Task'; NodeType = @{ refPath = '/Script/StateTreeModule.StateTreeDelayTask' } }
$tNotify = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $notifyRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/Blueprint/StateTree/Common/Task/STT_ParallelNotify.STT_ParallelNotify_C' } }
try { $rayId = (($tRay | ConvertFrom-Json).returnValue) } catch { $rayId = '' }
try { $atkId = (($tAtk | ConvertFrom-Json).returnValue) } catch { $atkId = '' }
try { $retryId = (($tRetry | ConvertFrom-Json).returnValue) } catch { $retryId = '' }
try { $notifyId = (($tNotify | ConvertFrom-Json).returnValue) } catch { $notifyId = '' }
Write-Output ("IDS: ray=" + $rayId + " atk=" + $atkId + " retry=" + $retryId + " notify=" + $notifyId)

Write-Output "=== 7. NODE PROPS (delay + notify payload) ==="
if ($retryId) {
  $dp = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $tree }; nodeID = $retryId; values = @{ Time = '0.5' } }
  Write-Output ("DELAY-PROPS: " + $dp)
}
if ($notifyId) {
  $np = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $tree }; nodeID = $notifyId; values = @{ EventToSend = '(Tag=(TagName="DZ.StateTree.EnemyEvent.ParallelAttack.Finished"),Payload=/Script/CoreUObject.Vector(X=0,Y=0,Z=0),Origin="")' } }
  Write-Output ("NOTIFY-PROPS: " + $np)
}

Write-Output "=== 8. TRANSITIONS ==="
$tr1 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $atkRef }; bEnabled = 'true' } }
Write-Output ("T1 ray->atk: " + $tr1)
$tr2 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
Write-Output ("T2 ray->retry: " + $tr2)
$tr3 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $notifyRef }; bEnabled = 'true' } }
Write-Output ("T3 atk->notify: " + $tr3)
$tr4 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
Write-Output ("T4 atk->retry: " + $tr4)
$tr5 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $notifyRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $detectRef }; bEnabled = 'true' } }
Write-Output ("T5 notify->detect: " + $tr5)

Write-Output "=== 9. BINDINGS (root params -> tasks) ==="
$rayInst = ''
$atkInst = ''
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $tree }; targetStructId = $zb }
try {
  $arr = ($bs | ConvertFrom-Json).returnValue
  foreach ($s in $arr) {
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_LineTrace_C$') { $rayInst = $s.iD }
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_Attack$') { $atkInst = $s.iD }
  }
} catch {}
Write-Output ("RAY-INST: " + $rayInst + "  ATK-INST: " + $atkInst)
if ($rayInst) {
  $b1 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $rootId; sourcePath = 'ACTOR_TARGET'; targetStructID = $rayInst; targetPath = 'inTargetActor' } }
  Write-Output ("B-RAY: " + $b1)
}
if ($atkInst) {
  $b2 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $rootId; sourcePath = 'ATTACK_TARGET'; targetStructID = $atkInst; targetPath = 'InAttackTarget' } }
  Write-Output ("B-ATK: " + $b2)
  $b3 = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = $tree }; binding = @{ sourceStructID = $rootId; sourcePath = 'EnemyAttackData'; targetStructID = $atkInst; targetPath = 'RefAttackTaskData' } }
  Write-Output ("B-DATA: " + $b3)
}

Write-Output "=== 10. COMPILE + SAVE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $tree } }
Write-Output ("COMPILE: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($tree) }
Write-Output ("SAVE: " + $sv)
Write-Output 'PA-REBUILD DONE'
