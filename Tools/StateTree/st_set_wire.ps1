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

function P($refPath, $dir, $idx) { return @{ node = @{ refPath = $refPath }; direction = $dir; index_id = $idx } }

$script:id = 10940
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$ed = 'EditorToolset.EditorAppToolset'
$lg = 'EditorToolset.LogsToolset'
$gref = '/Game/STT_Test.STT_Test:EventGraph'
$c1 = "$gref.K2Node_CallFunction_1"; $c0 = "$gref.K2Node_CallFunction_0"
$br = "$gref.K2Node_IfThenElse_0"; $se = "$gref.K2Node_VariableSet_0"
$send = "$gref.K2Node_CallFunction_4"

Write-Output "=== 1. SET EventToSend VALUE (struct text) ==="
$pv = Call (++$script:id) $bp 'set_pin_value' @{ pin = (P $se 'EGPD_Input' 1); value = '(Tag=StateTree.ParTest.Done)' }
Write-Output ("PIN-VALUE: " + $pv)

Write-Output "=== 2. WIRES ==="
$w1 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (P $c1 'EGPD_Output' 0); input_pin = (P $se 'EGPD_Input' 0) }
Write-Output ("W PrintString->Set: " + $w1)
$w2 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (P $se 'EGPD_Output' 0); input_pin = (P $br 'EGPD_Input' 0) }
Write-Output ("W Set->Branch: " + $w2)
$w3 = Call (++$script:id) $bp 'connect_pins' @{ output_pin = (P $send 'EGPD_Output' 0); input_pin = (P $c0 'EGPD_Input' 0) }
Write-Output ("W Send->FinishTask: " + $w3)

$cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("BP-COMPILE: " + $cb)

Write-Output "=== 3. START PIE ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{ options = @{ bSimulate = $true; playMode = 'PlayMode_InViewPort'; warmupSeconds = 2 } }
Write-Output ("PIE: " + $pi)

Start-Sleep -Seconds 5

Write-Output "=== 4. LOGS ==="
$e1 = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = '.'; maxEntries = 15 }
Write-Output ("BP-MSG: " + $e1)
$e2 = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogStateTree'; pattern = '.'; maxEntries = 15 }
Write-Output ("ST-LOG: " + $e2)

Write-Output "=== 5. STOP PIE ==="
$spx = Call (++$script:id) $ed 'StopPIE' @{}
Write-Output ("STOP: " + $spx)
Write-Output "SET-WIRE DONE"
