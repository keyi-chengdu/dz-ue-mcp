param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 2; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 14 -Compress
    $payload = '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/call","params":{"name":"call_tool","arguments":' + $inner + '}}'
    try {
      $r = Invoke-WebRequest -Uri $base -Method Post -ContentType 'application/json; charset=utf-8' -Headers @{ 'mcp-session-id' = $Session } -Body ([Text.Encoding]::UTF8.GetBytes($payload)) -TimeoutSec 300 -UseBasicParsing
      $txt = (New-Object IO.StreamReader($r.RawContentStream, [Text.Encoding]::UTF8)).ReadToEnd()
      if ($txt -match '(?s)^data:\s*(.*)$') { $txt = $Matches[1] }
      return (($txt | ConvertFrom-Json).result.content[0].text)
    } catch { if ($attempt -eq 2) { return "HTTP-ERR: $($_.Exception.Message)" } }
    Start-Sleep -Milliseconds 300
  }
  return $null
}

function N($refPath, $dir, $idx) { return @{ node = @{ refPath = $refPath }; direction = $dir; index_id = $idx } }

$script:id = 10830
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$gref = '/Game/STT_Test.STT_Test:EventGraph'
$c0 = "$gref.K2Node_CallFunction_0"   # FinishTask
$c1 = "$gref.K2Node_CallFunction_1"   # PrintString
$c3 = "$gref.K2Node_CallFunction_3"   # SendEvent
$mk = "$gref.K2Node_MakeStruct_0"     # MakeEventPayload
$br = "$gref.K2Node_IfThenElse_0"     # Branch

Write-Output "=== 1. GET bSendOnExit NODE ==="
$vg = Call (++$script:id) $bp 'create_node' @{ graph = @{ refPath = $gref }; type_id = '|GetbSendOnExit'; pos = @{ x = 920; y = 420 } }
Write-Output ("GET-NODE: " + $vg)
try { $vgr = (($vg | ConvertFrom-Json).returnValue).refPath } catch { $vgr = $null }

Write-Output "=== 2. BREAK PrintString.then -> FinishTask.execute ==="
$bk = Call (++$script:id) $bp 'break_pins' @{ output_pin = (N $c1 'EGPD_Output' 0); input_pin = (N $c0 'EGPD_Input' 0) }
Write-Output ("BREAK: " + $bk)

Write-Output "=== 3. WIRES ==="
$w1 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $c1 'EGPD_Output' 0); input_pin = (N $br 'EGPD_Input' 0) }
Write-Output ("W PrintString->Branch: " + $w1)
$w2 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $br 'EGPD_Output' 0); input_pin = (N $c3 'EGPD_Input' 0) }
Write-Output ("W Branch.then->Send: " + $w2)
$w3 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $br 'EGPD_Output' 1); input_pin = (N $c0 'EGPD_Input' 0) }
Write-Output ("W Branch.else->FinishTask: " + $w3)
$w4 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $mk 'EGPD_Output' 0); input_pin = (N $c3 'EGPD_Input' 1) }
Write-Output ("W Make->Send.Event: " + $w4)
if ($vgr) {
  $w5 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $vgr 'EGPD_Output' 0); input_pin = (N $br 'EGPD_Input' 1) }
  Write-Output ("W bSendOnExit->Branch.Cond: " + $w5)
} else { Write-Output "W5 SKIP (no var-get node)" }

Write-Output "=== 4. COMPILE STT_Test ==="
$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("BP-COMPILE: " + $cb)

Write-Output "=== 5. SET bSendOnExit=true ON PARALLEL TREE INSTANCE ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = '/Game/ST_ParTest.ST_ParTest' }; nodeID = 'BF94AEA4-F9AC-DEA5-804E-A96BB0FDB173'; values = @{ bSendOnExit = 'true' } }
Write-Output ("SET-FLAG: " + $sv)

Write-Output "=== 6. MAIN TREE: ADD ParDone STATE ==="
$sa = Call (++$script:id) $st 'AddState' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' }; Name = 'ParDone'; Type = 'State'; ParentState = @{ refPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0' } }
Write-Output ("ADDSTATE: " + $sa)
$parDoneRef = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_1'

Write-Output "=== 7. ADD TRANSITION Delay --OnEvent--> ParDone ==="
$tr = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_6' }; settings = @{ Trigger = 'OnEvent'; Type = 'GotoState'; TargetState = @{ refPath = $parDoneRef }; bEnabled = $true } }
Write-Output ("TRANSITION: " + $tr)

Write-Output "=== 8. ADD STT_Test1 TASK TO ParDone ==="
$tn = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $parDoneRef }; Slot = 'Task'; NodeType = @{ refPath = '/Game/STT_Test1.STT_Test1_C' } }
Write-Output ("TEST1 NODE: " + $tn)
try { $tng = ($tn | ConvertFrom-Json).returnValue } catch { $tng = $null }

Write-Output "=== 9. BIND main param -> InInt ==="
$bd = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' }; Binding = @{ SourceStructID = '8F810993-47F9-5FD6-F37C-D79665AA8B8B'; SourcePath = 'Out INt'; TargetStructID = $tng; TargetPath = 'InInt' } }
Write-Output ("BINDING: " + $bd)

Write-Output "=== 10. COMPILE MAIN ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' } }
Write-Output ("COMPILE: " + $cp)
Write-Output "EVT-WIRE DONE"
