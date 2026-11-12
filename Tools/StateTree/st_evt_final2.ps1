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

$script:id = 10880
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$gt = 'GameplayTagsToolset.GameplayTagsToolset'
$ed = 'EditorToolset.EditorAppToolset'
$lg = 'EditorToolset.LogsToolset'
$parDone = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_0'
$tagv = 'StateTree.ParTest.Done'

Write-Output "=== 1. REGISTER TAG ==="
$at = Call (++$script:id) $gt 'AddTag' @{ tagName = $tagv; tagSource = ''; comment = 'ST_Test parallel exit-signal POC' }
Write-Output ("ADDTAG: " + $at)

Write-Output "=== 2. EDITABLE EventToSend ==="
$ie = Call (++$script:id) $bp 'set_variable_instance_editable' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' }; variable_name = 'EventToSend'; instance_editable = $true }
Write-Output ("EDITABLE: " + $ie)

Write-Output "=== 3. SET EVENT TAG ON PARALLEL INSTANCE ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = '/Game/ST_ParTest.ST_ParTest' }; nodeID = 'BF94AEA4-F9AC-DEA5-804E-A96BB0FDB173'; values = @{ EventToSend = "(Tag=$tagv)" } }
Write-Output ("SET-EVENT: " + $sv)

Write-Output "=== 4. ADD TRANSITION WITH TAG ==="
$tr = Call (++$script:id) $st 'AddTransition' @{ state = @{ refPath = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_6' }; settings = @{ Trigger = 'OnEvent'; Type = 'GotoState'; TargetState = @{ refPath = $parDone }; RequiredEventTag = $tagv; bEnabled = $true } }
Write-Output ("TRANSITION: " + $tr)

Write-Output "=== 5. COMPILE MAIN ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = '/Game/ST_Test.ST_Test' } }
Write-Output ("COMPILE: " + $cp)

Write-Output "=== 6. START PIE ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{ options = @{ bSimulate = $true; playMode = 'PlayMode_InViewPort'; warmupSeconds = 2 } }
Write-Output ("PIE: " + $pi)

Start-Sleep -Seconds 6

Write-Output "=== 7. LOGS ==="
$e = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = '.'; maxEntries = 30 }
Write-Output ("LOGS: " + $e)

Write-Output "=== 8. STOP PIE ==="
$spx = Call (++$script:id) $ed 'StopPIE' @{}
Write-Output ("STOP: " + $spx)
Write-Output "EVT-FINAL2 DONE"
