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

$script:id = 10890
$bp = 'editor_toolset.toolsets.blueprint.BlueprintTools'
$ot = 'editor_toolset.toolsets.object.ObjectTools'
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$ed = 'EditorToolset.EditorAppToolset'
$lg = 'EditorToolset.LogsToolset'
$tagv = 'StateTree.ParTest.Done'

Write-Output "=== 1. SET CDO DEFAULT EventToSend.Tag ==="
$cdo = Call (++$script:id) $bp 'get_default_object' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
Write-Output ("CDO: " + $cdo)
try { $cdoref = (($cdo | ConvertFrom-Json).returnValue).refPath } catch { $cdoref = $null }
if ($cdoref) {
  $sp = Call (++$script:id) $ot 'set_properties' @{ instance = @{ refPath = $cdoref }; values = '{"EventToSend": "(Tag=StateTree.ParTest.Done)"}' }
  Write-Output ("SET-DEFAULT: " + $sp)
  $gp = Call (++$script:id) $ot 'get_properties' @{ instance = @{ refPath = $cdoref }; properties = @('EventToSend', 'bSendOnExit') }
  Write-Output ("VERIFY: " + $gp)
  $cb = Call (++$script:id) $bp 'compile_blueprint' @{ blueprint = @{ refPath = '/Game/STT_Test.STT_Test' } }
  Write-Output ("BP-COMPILE: " + $cb)
} else { Write-Output "CDO FAIL" }

Write-Output "=== 2. START PIE ==="
$pi = Call (++$script:id) $ed 'StartPIE' @{ options = @{ bSimulate = $true; playMode = 'PlayMode_InViewPort'; warmupSeconds = 2 } }
Write-Output ("PIE: " + $pi)

Start-Sleep -Seconds 5

Write-Output "=== 3. LOGS ==="
$e = Call (++$script:id) $lg 'GetLogEntries' @{ category = 'LogBlueprintUserMessages'; pattern = '.'; maxEntries = 25 }
Write-Output ("LOGS: " + $e)

Write-Output "=== 4. STOP PIE ==="
$spx = Call (++$script:id) $ed 'StopPIE' @{}
Write-Output ("STOP: " + $spx)
Write-Output "EVT-FINAL3 DONE"
