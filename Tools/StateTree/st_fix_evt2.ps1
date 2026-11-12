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

$script:id = 10850
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$gref = '/Game/STT_Test.STT_Test:EventGraph'
$c0 = "$gref.K2Node_CallFunction_0"; $br = "$gref.K2Node_IfThenElse_0"
$parDone = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_0'

Write-Output "=== 1. DELETE SendEvent NODE (break by-ref deadlock) ==="
$dn = Call (++$script:id) $bp 'delete_node' @{ node = @{ refPath = "$gref.K2Node_CallFunction_3" } }
Write-Output ("DEL: " + $dn)

Write-Output "=== 2. COMPILE (expose EventToSend) ==="
$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("BP-COMPILE: " + $cb)

Write-Output "=== 3. RECREATE SendEvent + GetEventToSend ==="
$n1 = Call (++$script:id) $bp 'create_node' @{ graph = @{ refPath = $gref }; type_id = 'StateTree|StateTreeSendEvent'; pos = @{ x = 1400; y = 256 } }
Write-Output ("SEND: " + $n1)
$n4 = Call (++$script:id) $bp 'create_node' @{ graph = $graph; type_id = '|GetEventToSend'; pos = @{ x = 1300; y = 420 } }
Write-Output ("GETEVT: " + $n4)
try { $n1r = (($n1 | ConvertFrom-Json).returnValue).refPath; $n4r = (($n4 | ConvertFrom-Json).returnValue).refPath } catch { $n1r = $null; $n4r = $null }

if ($n1r -and $n4r) {
  $w1 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $br 'EGPD_Output' 0); input_pin = (N $n1r 'EGPD_Input' 0) }
  Write-Output ("W Branch.then->Send: " + $w1)
  $w2 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $n4r 'EGPD_Output' 0); input_pin = (N $n1r 'EGPD_Input' 1) }
  Write-Output ("W EventToSend->Send.Event: " + $w2)
  $cb2 = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
  Write-Output ("BP-COMPILE2: " + $cb2)
} else { Write-Output "NODE-CREATE FAIL" }

Write-Output "=== 4. TRANSITION Delay --OnEvent--> ParDone ==="
$tr = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_6' }; settings = @{ Trigger = 'OnEvent'; Type = 'GotoState'; TargetState = @{ refPath = $parDone }; bEnabled = $true } }
Write-Output ("TRANSITION: " + $tr)

Write-Output "=== 5. STT_Test1 TASK ON ParDone ==="
$tn = Call (++$script:id) $st 'AddStateNode' @{ state = @{ refPath = $parDone }; Slot = 'Task'; NodeType = @{ refPath = '/Game/STT_Test1.STT_Test1_C' } }
Write-Output ("TEST1-NODE: " + $tn)
try { $tng = ($tn | ConvertFrom-Json).returnValue } catch { $tng = $null }

Write-Output "=== 6. BIND (OutINt -> InInt) ==="
$bd = Call (++$script:id) $st 'AddPropertyBinding' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' }; Binding = @{ SourceStructID = '8F810993-47F9-5FD6-F37C-D79665AA8B8B'; SourcePath = 'OutINt'; TargetStructID = $tng; TargetPath = 'InInt' } }
Write-Output ("BINDING: " + $bd)

Write-Output "=== 7. COMPILE MAIN ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' } }
Write-Output ("COMPILE: " + $cp)
Write-Output "FIX-ROUND2 DONE"
