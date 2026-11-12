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

$script:id = 10840
$bp = 'editor_toolsets_toolsets_placeholder'
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$gref = '/Game/STT_Test.STT_Test:EventGraph'
$c0 = "$gref.K2Node_CallFunction_0"; $c3 = "$gref.K2Node_CallFunction_3"
$br = "$gref.K2Node_IfThenElse_0"

Write-Output "=== A1. ADD EventToSend STRUCT VARIABLE ==="
$v1 = Call (++$script:id) $bp 'add_struct_variable' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' }; name = 'EventToSend'; struct_type = @{ refPath = '/Script/StateTreeModule.StateTreeEvent' } }
Write-Output ("VAR-EVENT: " + $v1)

Write-Output "=== A2. INSTANCE-EDITABLE bSendOnExit ==="
$ie = Call (++$script:id) $bp 'set_variable_instance_editable' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' }; variable_name = 'bSendOnExit'; instance_editable = $true }
Write-Output ("EDITABLE: " + $ie)

Write-Output "=== A3. COMPILE BP ==="
$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("BP-COMPILE: " + $cb)

Write-Output "=== A4. GET EventToSend NODE ==="
$vg = Call (++$script:id) $bp 'create_node' @{ graph = @{ refPath = $gref }; type_id = '|GetEventToSend'; pos = @{ x = 1300; y = 420 } }
Write-Output ("GET-NODE: " + $vg)
try { $vgr = (($vg | ConvertFrom-Json).returnValue).refPath } catch { $vgr = $null }

if ($vgr) {
  $w = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (N $vgr 'EGPD_Output' 0); input_pin = (N $c3 'EGPD_Input' 1) }
  Write-Output ("W EventToSend->Send.Event: " + $w)
  $cb2 = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
  Write-Output ("BP-COMPILE2: " + $cb2)
} else { Write-Output "GET-NODE FAIL" }

Write-Output "=== B. SET bSendOnExit=true (retry) ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = '/Game/ST_ParTest.ST_ParTest' }; nodeID = 'BF94AEA4-F9AC-DEA5-804E-A96BB0FDB173'; values = @{ bSendOnExit = 'true' } }
Write-Output ("SET-FLAG: " + $sv)

Write-Output "=== C. DESCRIBE ROOT (ParDone real refPath) ==="
$s = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0' } }
Write-Output ("ROOT: " + $s)
Write-Output "FIX-ROUND1 DONE"
