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

$script:id = 31000
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$at = 'editor_toolset.toolsets.asset.AssetTools'
$pkg = '/Game/Blueprint/StateTree/05002102/ST_Sub_05002102_ParallelAttack'
$obj = $pkg + '.ST_Sub_05002102_ParallelAttack'

Write-Output "=== 1. CREATE TREE ==="
$cr = Call (++$script:id) $st 'CreateStateTree' @{ packagePath = '/Game/Blueprint/StateTree/05002102'; assetName = 'ST_Sub_05002102_ParallelAttack'; schemaClass = @{ refPath = '/Script/DZProject.DZAIStateTreeSchema' } }
Write-Output ("CREATE: " + $cr)
Start-Sleep -Seconds 1

$d = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $obj } }
$rj = $null
try { $rj = ($d | ConvertFrom-Json).returnValue } catch {}
if (-not $rj) { Write-Output "FATAL: tree not created"; exit 1 }
$rootId = $rj.rootParametersId
$rootRef = $rj.subTrees[0].refPath
Write-Output ("ROOT-PARAMS: " + $rootId)
Write-Output ("ROOT-REF: " + $rootRef)

Write-Output "=== 2. TREE PARAMETERS x3 ==="
foreach ($f in @(
  @{ n = 'EnemyAttackData'; vt = 'Struct'; p = '/Script/DZProject.AttackTaskData' },
  @{ n = 'ACTOR_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' },
  @{ n = 'ATTACK_TARGET'; vt = 'Object'; p = '/Script/Engine.Actor' }
)) {
  $r = Call (++$script:id) $st 'AddTreeParameter' @{ stateTree = @{ refPath = $obj }; paramName = $f.n; valueType = $f.vt; valueTypeObjectPath = $f.p }
  Write-Output ("ADD-PARAM " + $f.n + ": " + $r)
}

Write-Output "=== 3. DETECT STATE ==="
$s1 = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $obj }; Name = 'DetectNoCoolDown'; Type = 'State'; ParentState = @{ refPath = $rootRef } }
$detectRef = ''
try { $detectRef = (($s1 | ConvertFrom-Json).returnValue).refPath } catch {}
if (-not $detectRef) {
  $dd = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $rootRef } }
  try { $detectRef = ((($dd | ConvertFrom-Json).returnValue).children)[0].refPath } catch {}
}
Write-Output ("DETECT-REF: " + $detectRef)
if (-not $detectRef) { Write-Output "FATAL: no detect ref"; exit 1 }

Write-Output "=== 4. CHILD STATES x4 (index-discovered) ==="
foreach ($sn in @('RayCheck', 'AttackBehavior', 'RetryCooldown', 'AttackFinishedNotify')) {
  $null = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = $obj }; Name = $sn; Type = 'State'; ParentState = @{ refPath = $detectRef } }
  Start-Sleep -Milliseconds 200
}
$dd2 = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $detectRef } }
$ch = $null
try { $ch = ((($dd2 | ConvertFrom-Json).returnValue).children) } catch {}
Write-Output ("CHILD-COUNT: " + @($ch).Count)
Write-Output ("CHILD-JSON: " + ($ch | ConvertTo-Json -Depth 6 -Compress))
if (@($ch).Count -lt 4) { Write-Output "FATAL: children missing"; exit 1 }
$rayRef = $ch[0].refPath; $atkRef = $ch[1].refPath; $retryRef = $ch[2].refPath; $notifyRef = $ch[3].refPath
Write-Output ("REFS: ray=" + $rayRef + " atk=" + $atkRef + " retry=" + $retryRef + " notify=" + $notifyRef)

Write-Output "=== 5. EC (NeedMatchTagContainer) ==="
$ec = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $detectRef }; Slot = 'EnterCondition'; NodeType = @{ refPath = '/Script/DZProject.STC_Server_HasAnyTag' } }
$ecId = ''
try { $ecId = ($ec | ConvertFrom-Json).returnValue } catch {}
Write-Output ("EC-ID: " + $ecId)
if ($ecId) {
  $ep = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $ecId; values = @{ NeedMatchTagContainer = '(GameplayTags=((TagName="DZ.GameplayEffect.Character.Enemy.Common.Attack.CoolDown")))' } }
  Write-Output ("EC-PROPS: " + $ep)
}

Write-Output "=== 6. TASKS x4 (correct parents) ==="
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

Write-Output "=== 7. NODE PROPS (Duration + EventToSend) ==="
if ($retryId) {
  $dp = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $retryId; values = @{ Duration = '0.5' } }
  Write-Output ("DELAY-PROPS: " + $dp)
}
if ($notifyId) {
  $np = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $obj }; nodeID = $notifyId; values = @{ EventToSend = '(Tag=(TagName="DZ.StateTree.EnemyEvent.ParallelAttack.Finished"),Payload=/Script/CoreUObject.Vector(X=0,Y=0,Z=0),Origin="")' } }
  Write-Output ("NOTIFY-PROPS: " + $np)
}

Write-Output "=== 8. TRANSITIONS x5 ==="
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $atkRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $rayRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $notifyRef }; bEnabled = 'true' } }
$null = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $atkRef }; settings = @{ Trigger = 'OnStateFailed'; Type = 'GotoState'; TargetState = @{ refPath = $retryRef }; bEnabled = 'true' } }
$tr5 = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = $notifyRef }; settings = @{ Trigger = 'OnStateSucceeded'; Type = 'GotoState'; TargetState = @{ refPath = $detectRef }; bEnabled = 'true' } }
Write-Output ("T5: " + $tr5)

Write-Output "=== 9. BINDINGS x3 ==="
$rayInst = ''; $atkInst = ''
$bs = Call (++$script:id) $st 'GetBindableSources' @{ stateTree = @{ refPath = $obj } }
try {
  $arr = ($bs | ConvertFrom-Json).returnValue
  foreach ($s in $arr) {
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_LineTrace_C$') { $rayInst = $s.iD }
    if ($s.source -eq 'Task' -and $s.structType -and $s.structType.refPath -match 'STT_Attack$') { $atkInst = $s.iD }
  }
} catch { Write-Output ("SRC-ERR: " + $_.Exception.Message) }
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

Write-Output "=== 10. COMPILE + SAVE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $obj } }
Write-Output ("COMPILE: " + $cp)
$sv = Call (++$script:id) $at 'save_assets' @{ asset_paths = @($obj) }
Write-Output ("SAVE: " + $sv)

Write-Output "=== 11. MAIN TREE REFERENCE CHECK ==="
$main = '/Game/Blueprint/StateTree/05002102/ST_05002102.ST_05002102'
$md = Call (++$script:id) $st 'DescribeStateTree' @{ stateTree = @{ refPath = $main } }
if ($md.Length -gt 800) { Write-Output ("MAIN(HEAD): " + $md.Substring(0,800)) } else { Write-Output ("MAIN: " + $md) }
$mcp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $main } }
Write-Output ("MAIN-COMPILE: " + $mcp)
Write-Output 'PA-BUILD-V2 DONE'
