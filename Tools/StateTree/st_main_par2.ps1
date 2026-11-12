param([string]$Session)
$ErrorActionPreference = 'Continue'
$base = 'http://127.0.0.1:8000/mcp'
if (-not $Session) { $Session = (Get-Content "C:\UE\Projects\DZ_Project_New\.dsh\st_work\mcp_sid_new.txt" -ErrorAction Stop).Trim() }

function Call($id, $toolset, $tool, $toolArgs) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $inner = @{ toolset_name = $toolset; tool_name = $tool; arguments = $toolArgs } | ConvertTo-Json -Depth 12 -Compress
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

$script:id = 7500
$st = 'DZStateTreeToolset.DZStateTreeEditTools'
$mainTree = '/Game/ST_Test.ST_Test'
$delayRef = '/Game/ST_Test.ST_Test:StateTreeEditorData_0.StateTreeState_0.StateTreeState_6'
$nodeId = 'C543DE26-3E8C-9B3D-7E54-9D4C0D54C5C6'

Write-Output "=== 1. SET StateTree REF (struct import text, single-level name) ==="
$sv = Call (++$script:id) $st 'SetNodeProperties' @{ stateTree = @{ refPath = $mainTree }; nodeID = $nodeId; values = @{ StateTree = '(StateTree=/Game/ST_ParTest.ST_ParTest.ST_ParTest)' } }
Write-Output ("SET-REF: " + $sv)

Write-Output "=== 2. DESCRIBE Delay STATE ==="
$s = Call (++$script:id) $st 'DescribeState' @{ state = @{ refPath = $delayRef } }
Write-Output ("DELAY: " + $s)

Write-Output "=== 3. COMPILE ==="
$cp = Call (++$script:id) $st 'CompileStateTree' @{ stateTree = @{ refPath = $mainTree } }
Write-Output ("COMPILE: " + $cp)
Write-Output "MAIN-PAR2 DONE"
